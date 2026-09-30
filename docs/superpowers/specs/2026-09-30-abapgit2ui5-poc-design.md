# abapGit2UI5 proof of concept: design

Date: 2026-09-30. Status: draft for review.

## Goal

A browser frontend for abapGit, built with abap2UI5, in its own repository.
It serves two purposes:

- **A daily tool** for the most common task: see a repository's status and
  pull it, without the SAP GUI HTML control and its client-specific quirks
  (IE and Edge controls, SAP GUI for Java, WebGUI).
- **A demonstration** for the abapGit and abap2UI5 maintainers that a UI5
  frontend on top of abapGit's APIs is viable. It has to tackle the hard parts
  honestly instead of hiding them.

abapGit itself stays untouched. It ships as a standalone program without
dependencies, and abap2UI5 is installed *with* abapGit, so this can only be an
add-on.

## Scope

First slice: **repository list → repository status → pull in abort mode, with
a conflict list.**

Not in scope: stage, commit, push, diff view, offline repositories,
transportable packages, background jobs, locking against parallel pulls, CI.

## Constraints

- ABAP 7.50 syntax, the same as abap2UI5 `main`. A 7.02 downport can be added
  later if needed.
- Depends on the abapGit **developer version** (`ZCL_ABAPGIT_*` global
  classes). The standalone program's local classes cannot be called from
  outside.
- Depends on abap2UI5 (installed on A4H25 in `$ABAP2UI5_*`, ICF node `Z2UI5`).
- Follows abap2UI5's app-building guide (`docs/agents/building-apps.md` in the
  abap2UI5 repository). An app is one class implementing `z2ui5_if_app`.
  **Every public attribute is serialized on each round trip and sent to the
  browser.** Only bound data may be public. abapGit object references must
  never be attributes at all.
- Development and testing on A4H25, package `$ABAPGIT2UI5` (repository key
  `000000000020`).

## Session model

Stateless, which is abap2UI5's default:

- Each round trip gets the abapGit objects afresh through
  `zcl_abapgit_repo_srv`. That is a database read and cheap.
- Computed results are kept as plain internal tables in protected
  attributes: the repository list, status rows and the pull result. abap2UI5
  serializes them with the app, so they survive round trips without reaching
  the browser.
- Status is recalculated only on an explicit Refresh. Like the SAP GUI UI,
  that fetches from the remote again.
- A pull runs completely within one round trip.

A stateful session (`client->set_session_stateful( )`) was considered and
rejected. It pins a work process per user, needs a switch back on every exit
path, and loses everything on reload. Nothing in this slice needs caches
across round trips.

## Components

All in package `$ABAPGIT2UI5`, with the prefix `ZCL_AG2UI5_` / `ZIF_AG2UI5_`.

### `ZIF_AG2UI5_REPO_SERVICE` / `ZCL_AG2UI5_REPO_SERVICE`

The only unit that talks to abapGit. It returns plain data only, never abapGit
object references, and raises `zcx_abapgit_exception`.

- `list_repos( )` returns a row per repository: key, package, name, URL,
  branch, last pull timestamp, and an online flag.
- `get_status( iv_key )` returns the remote commit
  (`zif_abapgit_repo_online~get_current_remote( )`) plus the rows of
  `zcl_abapgit_repo_status=>calculate`: object type and name, path, filename,
  `lstate`, `rstate`, `match`, `inactive`. Only rows with differences or
  inactive objects are kept.
- `pull( iv_key )` returns a result structure:
  - an outcome: `nothing`, `pulled`, `blocked` or `failed`
  - the blocking items, each with object, action and reason text
  - the informational items
  - the log messages
- `classify( is_checks )` applies the decision rule below to a
  `zif_abapgit_definitions=>ty_deserialize_checks`. It returns an outcome
  (`nothing`, `blocked` or `ready`), the adjusted checks, and the blocking and
  informational lists. It is a pure function over
  plain data, public for unit tests.

The interface exists so that the apps can be tested with a double later.

### `ZCL_AG2UI5_APP_REPOS`: the start app

- Started with `?app_start=zcl_ag2ui5_app_repos`.
- Shows a table of all repositories with a search field.
- Offline repositories are listed but cannot be selected.
- Pressing a row calls `client->nav_app_call( )` with a new
  `ZCL_AG2UI5_APP_STATUS` for that key.

### `ZCL_AG2UI5_APP_STATUS`: status and pull for one repository

- The header shows package, URL, branch and remote commit.
- A table lists the changed files, with icons for the local and remote state.
- There are three buttons: Refresh, Pull, and Back (`client->nav_app_leave( )`).
- The pull outcome is shown in this app:
  - `nothing`: a toast saying "Already up to date".
  - `pulled`: a success toast, then an automatic refresh.
  - `blocked`: a dialog (`popup_display`) listing the blocking and
    informational items. Nothing is imported.
  - `failed`: a MessageBox with the log messages.

There are two apps rather than three, because the pull result is a state of
the status screen, not a screen of its own.

## Pull data flow

`ZCL_AG2UI5_REPO_SERVICE->pull( iv_key )`:

1. `zcl_abapgit_repo_srv=>get_instance( )->get( iv_key )`. If the repository is
   offline, raise an exception.
2. **Self-update guard:** if `zcl_abapgit_url=>is_abapgit_repo( url )` is true,
   or the package is `$ABAPGIT2UI5`, raise "Pulling this repository would
   replace code that is running in this session". abapGit's own
   `check_self_update` only fires for `sy-cprog = 'ZABAPGIT'` and would not
   catch this case.
3. `refresh( iv_drop_cache = abap_true )`, then `deserialize_checks( )`.
4. Call `classify( )`. It returns `nothing` if `overwrite` and
   `overwrite_files` are both empty, and `blocked` if any rule blocks. In both
   cases the method returns without importing.
5. On `ready`: `create_new_log( 'Pull Log' )`, then `deserialize( is_checks,
   ii_log )`. No deletion step is needed, because deletions always block.
6. The outcome is `pulled` if `log->get_status( )` is OK, and `failed`
   otherwise. The log messages are copied into the result in both cases.

### Decision rule (abort mode)

`deserialize_checks-overwrite` lists **every** change, each with an `action`
from `zif_abapgit_objects=>c_deserialize_action`. abapGit's popup preselects
only `add`. Abort mode automates the decision as follows.

| Condition | Treatment |
|---|---|
| `add`: added remotely, or deleted locally | Decision `Y` |
| `update`: changed remotely only | Decision `Y` |
| `no_support` | Decision `N`, informational |
| `overwrite`: changed locally | Blocks |
| `delete`, `delete_add`: a local object would be deleted | Blocks |
| `packmove` | Blocks |
| `data_loss` or `delete_tabl_with_data` not empty | Blocks |
| `warning_package` not empty | Blocks |
| `requirements-met = N` or `dependencies-met = N` | Blocks |
| `transport-required` or `customizing-required` | Blocks (local packages only) |

Blocking deletions is deliberately conservative. A pull stops whenever a local
object has not been pushed yet.

## Error handling and runtime risks

- **Exceptions:** app event handlers catch `zcx_abapgit_exception` and show it
  with `client->message_box_display( )` as an error. Anything else (`cx_root`)
  is left to abap2UI5's own error handling.
- **Popups during `deserialize`:** `ZCL_ABAPGIT_UI_INJECTOR` is `FOR TESTING`,
  so abapGit's popups cannot be replaced in production code. If an object
  handler sends a dynpro during an HTTP request, the request dumps. The
  evidence against this happening: the ADT backend and abapgit-agent pull over
  HTTP through the same `deserialize` path, and the popups sit in
  `zcl_abapgit_services_repo`, which this design bypasses. So the risk is
  accepted and measured. Any dump is recorded as a finding, together with the
  object type that caused it.
- **Progress indicator:** set a no-op implementation of
  `zif_abapgit_progress` with `zcl_abapgit_progress=>set_instance( )` before
  status and pull, so `SAPGUI_PROGRESS_INDICATOR` is never called during HTTP
  requests.
- **Runtime and ICM timeouts:** measured on the test repositories. A timeout is
  recorded as a finding. Background processing is out of scope.

## Repository layout

- `.abapgit.xml`: `STARTING_FOLDER /src/`, `FOLDER_LOGIC PREFIX`.
- `src/`: flat to begin with.
- `abaplint.jsonc`:
  - `version: v750`
  - `dependencies` on `abapGit/abapGit` and `abap2UI5/abap2UI5`, so
    references resolve without a system
  - rules close to abap2UI5's
- `package.json`:
  - `npm run lint`: runs abaplint.
  - `npm run lint:ui5`: runs `npx @abap2ui5/linter src`.
- `AGENTS.md`, kept short and limited to what is not obvious:
  - the self-update guard
  - the rule that public attributes are serialized
  - a pointer to abap2UI5's `building-apps.md`
- `AGENTS-LOCAL.md`: Git-ignored, for local SAP setup.
- `README.md`: purpose, installation (abapGit developer version plus
  abap2UI5), start URL, and a screenshot.

## Testing

- **Unit tests** for `classify( )`: one test per row of the decision table,
  plus the "nothing to pull" case. They are built from hand-made
  `ty_deserialize_checks` data. They run on A4H25 through
  `.sapcli/agent.py unit` from the abapGit checkout. Transpiled unit tests are
  skipped, because transpiling abapGit and abap2UI5 as dependencies costs more
  than it gives a proof of concept.
- **Static checks:** `npm run lint` and `npm run lint:ui5`.
- **Manual end-to-end checklist on A4H25:**
  1. The repository list loads, and offline repositories cannot be selected.
  2. The status of `$UMLAUT` is shown.
  3. The first pull of `$TEST_ONLINE_FROM_ABAPGIT` gives `pulled`. Record the
     duration.
  4. Change an object locally, then pull. The outcome is `blocked` and the
     object appears in the dialog.
  5. Pulling `$ABAPGIT` shows the guard message.
  6. Pulling an up-to-date repository gives "Already up to date".
  7. Status and pull on a larger repository (such as `$VERTEX`). Record the
     duration and any timeout.
- **Deployment during development:** push the branch and pull `$ABAPGIT2UI5`
  with abapgit-agent (`agent-pull.py --package '$ABAPGIT2UI5'`), or make
  surgical edits through MCP.

## Step 0

On A4H25, abap2UI5 is installed and the repository is linked. The exact ICF
path of the abap2UI5 endpoint still has to be confirmed before the first
end-to-end test.
