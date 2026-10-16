# Architecture

Four views of how abapGit2UI5 fits together. The rules behind them are in
[AGENTS.md](../AGENTS.md) ("Design rules").

## Components

Only the repository service talks to abapGit. The apps get plain data from it
and never keep an abapGit object: abap2UI5 serializes every attribute of an
app on each round trip.

```mermaid
flowchart TB
    browser["Browser<br/>UI5, rendered by abap2UI5"]

    subgraph sap["SAP system"]
        http["ICF node /sap/bc/zabapgit2ui5<br/>ZCL_AG2UI5_HTTP"]
        z2ui5["abap2UI5<br/>z2ui5_cl_http_handler"]
        apps["Apps<br/>ZCL_AG2UI5_APP_*"]
        settings["ZCL_AG2UI5_SETTINGS<br/>table ZAG2UI5_SETTING"]
        service["ZCL_AG2UI5_REPO_SERVICE<br/>plain data in and out,<br/>checks everything again"]
        helpers["Helpers<br/>PROGRESS_SILENT, OBJECT_FILTER,<br/>BLOB_SOURCE"]
        run["Background runs<br/>RUN_STARTER, STATUS_RUN,<br/>table ZAG2UI5_RUN"]
        abapgit["abapGit<br/>repositories, serializer, Git client"]
        objects[("SAP objects<br/>TADIR, sources, DDIC")]
    end

    remote[("Git remote<br/>GitHub, GitLab, ...")]

    browser <-->|"JSON over HTTPS"| http
    http --> z2ui5
    z2ui5 <--> apps
    apps --> settings
    apps --> service
    service --> helpers
    service --> run
    service --> abapgit
    run --> abapgit
    abapgit <--> objects
    abapgit <-->|"Git smart HTTP"| remote
```

`ZCL_AG2UI5_HTTP` resets abapGit's repository service once per request and
marks requests on its own node, which the login needs. abapGit2UI5 also runs
under abap2UI5's standard node `/sap/bc/z2ui5`, without login.

## One round trip

Every click that needs the server is one stateless request. The app is
restored from abap2UI5's draft table, handles the event, and is saved again.

```mermaid
sequenceDiagram
    autonumber
    participant B as Browser
    participant H as ZCL_AG2UI5_HTTP
    participant Z as abap2UI5
    participant A as App
    participant S as Repo service
    participant G as abapGit

    B->>H: event + bound model values
    H->>H: request_start( )
    H->>Z: run( server )
    Z->>Z: restore app from draft table Z2UI5_T_01
    Z->>A: main( client )
    A->>S: e.g. get_status( key )
    S->>S: install silent progress, check authorization
    S->>G: read repository, serialize, fetch remote
    G-->>S: abapGit objects
    S-->>A: plain data, checked again
    A->>Z: view and model, or nav_app_call / nav_app_leave
    Z->>Z: ROLLBACK WORK, save app to Z2UI5_T_01
    Z-->>B: view XML and JSON model
```

Consequences:

- Writes that must stay commit themselves (`push`, settings, ignore rules),
  because abap2UI5 rolls back after `main( )`.
- The draft table holds every attribute as plain-text XML, so the login app
  clears its token in `main( )` before the save.
- Public attributes go to the browser. Only bound data is public; anything
  the browser sends is checked on the server against fresh abapGit data.

## Background Status run

Serializing the local objects is the slow part of a status. Status therefore
starts it in an aRFC task and polls. The task only serializes: no Git access
and no credentials, since the login lives in the HTTP session.

```mermaid
sequenceDiagram
    autonumber
    participant B as Browser
    participant A as Status app
    participant S as Repo service
    participant T as aRFC task<br/>Z_AG2UI5_SERIALIZE_LOCAL
    participant R as Table ZAG2UI5_RUN
    participant G as abapGit

    B->>A: open repository
    A->>S: start_status( key )
    S->>R: insert run row, user + key
    S-)T: STARTING NEW TASK
    S-->>A: run ID + head from the registration
    A-->>B: head at once, table busy,<br/>start_timer RUN_POLL:id

    par background
        T->>G: get_files_local( ), progress per object
        T->>R: progress, then files, state D
    and polling
        loop every tick while state is R
            B->>A: RUN_POLL:id
            A->>S: run_state( id, key )
            S->>R: read own row
            S-->>A: R, done / total
            A-->>B: progress text, re-arm timer
        end
    end

    B->>A: RUN_POLL:id
    A->>S: run_state( id, key )
    S-->>A: D
    A->>S: get_status( key, run_id )
    S->>R: take files, delete row
    S->>G: fetch remote, calculate status<br/>with the stored local files
    S-->>A: status rows
    A-->>B: rows, Pull and Stage enabled
```

- The run ID stays in a PROTECTED attribute. Rows are read, updated and
  deleted only for `sy-uname` and the repository key.
- abap2UI5 cancels the timer on every round trip, so Status re-arms it at the
  end of each round trip that stays on the page.
- States other than `R` and `D`: `E` (error) and `G` (gone) end the poll with
  a message. So does a run without progress for 15 minutes. If no task can
  be started, Status loads synchronously.
- Only Status uses runs. Pull, push, previews and Stage load fresh and
  synchronously.

## App navigation

`nav_app_call` opens a page on top (Back returns), `nav_app_leave` replaces
the current one. List, Status and repository Diff have their own URLs.

```mermaid
flowchart LR
    repos["Repository list<br/>#"]
    newrepo["New repository"]
    login["Login<br/>stateful session"]

    subgraph pages["Repository pages"]
        status["Status<br/>#/repo/key"]
        stage["Stage<br/>commit and push"]
        repodiff["Repository diff<br/>#/repo/key/diff"]
        diff["File diff"]
    end

    repos -->|call| newrepo
    newrepo -->|leave| status
    repos -->|call| status
    status -->|leave, Back| repos
    status -->|call| stage
    status -->|call| repodiff
    status -->|call| diff
    stage -->|call| repodiff
    stage -->|call| diff
    repodiff -->|call| diff
    repodiff -->|leave| status

    pages -.->|call| login
    newrepo -.->|call| login
```

Dashed: New repository and every repository page open Login when abapGit asks for credentials. It returns
with `LOGGED_IN:<host>`, and the app reloads what failed to load; actions are
not replayed. Stage returns `PUSHED` or `PUSHED:<message>` to Status, which
reloads. The list shows messages handed over with `nav_app_leave( r_data )`.
