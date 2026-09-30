# abapGit2UI5 PoC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A browser frontend for abapGit, built with abap2UI5, covering the
repository list, a repository's status, and pulling in abort mode with a
conflict list.

**Architecture:**

- One service class (`ZCL_AG2UI5_REPO_SERVICE`) wraps the abapGit developer
  version and returns plain data only.
- Two abap2UI5 apps (`ZCL_AG2UI5_APP_REPOS` and `ZCL_AG2UI5_APP_STATUS`) render
  that data, stateless.
- The abort-mode decision rule is a pure method (`classify`), covered by ABAP
  unit tests.

**Tech Stack:** ABAP 7.50, abap2UI5 1.146.0 (`z2ui5_cl_ui5_view_builder`), the
abapGit developer version (`ZCL_ABAPGIT_*`), abaplint, and
`@abap2ui5/linter`.

**Spec:** `docs/superpowers/specs/2026-09-30-abapgit2ui5-poc-design.md`

## Global Constraints

- ABAP syntax level: `v750`.
- Object names:
  - `ZCL_AG2UI5_*` and `ZIF_AG2UI5_*` only.
  - Package `$ABAPGIT2UI5`.
  - abapGit repository key on A4H25: `000000000020`.
- Only data that the view binds goes in PUBLIC. Everything else goes in
  PROTECTED. Never store abapGit object references in attributes.
- The service raises `zcx_abapgit_exception`. The apps catch it and show it with
  `client->message_box_display( type = `error` )`.
- Nothing may reach SAP GUI: no dynpro calls, and no
  `SAPGUI_PROGRESS_INDICATOR` (`ZCL_AG2UI5_PROGRESS_SILENT` handles that).
- Self-update guard: the app does not pull repositories whose URL is abapGit's
  (`zcl_abapgit_url=>is_abapgit_repo`) or whose package is `$ABAPGIT2UI5`.
- Deployment works by pushing a branch to `christianguenter2/abapGit2UI5` and
  running an abapgit-agent pull:

  ```sh
  .sapcli/venv/bin/python .sapcli/agent-pull.py refs/heads/<branch> --package '$ABAPGIT2UI5'
  ```

  Run it from `/home/chris/Projects/GIT/abapGit`.
- The abap2UI5 endpoint is
  `https://vhcala4hci25:50001/sap/bc/z2ui5?sap-client=001&app_start=<class>`.

## Review Focus

- **A status or pull request that fails remotely** (network, authentication)
  must end in an error MessageBox, never in a short dump. The TRY/CATCH in both
  apps' `on_event` covers it, and E2E step 8 checks it.
- **`overwrite` is empty but `overwrite_files` is not.** abapGit still has
  something to import, so the outcome must be `ready`, not `nothing`. There is
  a unit test for this in Task 2.
- **A blocking change with an empty `text`** must still show a reason. There
  is a unit test for the fallback in Task 2.
- **Objects that are inactive but match** must appear in the status list. There
  is a unit test for `filter_status` in Task 2.
- **Repository names or search input containing `{`** must not be treated as a
  UI5 binding. All data goes through `_bind`, never through `v = |…{ data }…|`.
  That is checked by the linter and by review in Tasks 4 and 5.

---

### Task 1: Project scaffold and the service interface

**Files:**
- Create: `.abapgit.xml`, `.gitignore`, `package.json`, `abaplint.jsonc`, `abap2ui5lint.jsonc`
- Create: `src/package.devc.xml`
- Create: `src/zif_ag2ui5_repo_service.intf.abap`, `src/zif_ag2ui5_repo_service.intf.xml`

**Interfaces:**
- Produces: `ZIF_AG2UI5_REPO_SERVICE`, with the types `ty_repo(s)`,
  `ty_status_row(s)`, `ty_status`, `ty_item(s)`, `ty_message(s)`,
  `ty_classification` and `ty_pull_result`, the constant `c_outcome`, and the
  methods `list_repos`, `get_status` and `pull`.

- [ ] **Step 1: Scaffold the config**
  - Copy `abaplint.jsonc` from `abap2UI5/app-template`, then make three
    changes:
    - Pin the abap2UI5 dependency to `"branch": "1.146.0"`, the version
      installed on A4H25.
    - Add a second dependency:
      `{ "url": "https://github.com/abapGit/abapGit", "branch": "main", "files": "/src/**/*.*" }`.
    - Set `allowed_object_types` to `CLAS`, `DEVC` and `INTF`.
  - Copy `abap2ui5lint.jsonc`, `.gitignore` and `package.json` from the
    template, with the name changed to `abapgit2ui5`.
  - Write `.abapgit.xml` with `NAME` = `abapGit2UI5`, `MASTER_LANGUAGE` = `E`,
    `STARTING_FOLDER` = `/src/` and `FOLDER_LOGIC` = `PREFIX`.
- [ ] **Step 2: Write the interface.** The code is in
  `src/zif_ag2ui5_repo_service.intf.abap`. This plan's executor writes it
  verbatim as it appears in the commit.
- [ ] **Step 3: Install and lint.** Run `npm install`, then
  `npx abaplint abaplint.jsonc`. Expected result: 0 issues.
- [ ] **Step 4: Commit.**

### Task 2: `classify` and `filter_status`, test first

**Files:**
- Create: `src/zcl_ag2ui5_repo_service.clas.abap`, `.clas.testclasses.abap`, `.clas.xml`

**Interfaces:**
- Consumes: `ZIF_AG2UI5_REPO_SERVICE` types.
- Produces:
  - `zcl_ag2ui5_repo_service=>classify( is_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks ) RETURNING rs_result TYPE zif_ag2ui5_repo_service=>ty_classification`
  - `zcl_ag2ui5_repo_service=>filter_status( it_results TYPE zif_abapgit_definitions=>ty_results_tt ) RETURNING rt_rows TYPE zif_ag2ui5_repo_service=>ty_status_rows`

  Both are public static methods.

**Unit tests, one per rule:**

| Test | Checks |
|---|---|
| `nothing_to_pull` | Empty checks give `nothing` |
| `files_only_is_ready` | `overwrite_files` alone gives `ready` |
| `add_update_applied` | `add` and `update` get decision `Y` and outcome `ready` |
| `overwrite_blocks` | `overwrite` blocks, with the reason from `text` |
| `delete_blocks` | `delete` blocks |
| `delete_add_blocks` | `delete_add` blocks |
| `packmove_blocks` | `packmove` blocks |
| `no_support_is_info` | `no_support` gets decision `N`, appears in the info list, and the outcome stays `ready` |
| `empty_text_fallback` | A blocking item with an empty `text` gets a reason |
| `data_loss_blocks` | A non-empty `data_loss` blocks |
| `delete_tabl_blocks` | A non-empty `delete_tabl_with_data` blocks |
| `warning_package_blocks` | A non-empty `warning_package` blocks |
| `requirements_block` | `requirements-met = N` blocks |
| `dependencies_block` | `dependencies-met = N` blocks |
| `transport_blocks` | `transport-required` blocks |
| `customizing_blocks` | `customizing-required` blocks |
| `filter_status` | `match = X` with `inactive = space` is dropped. `match = X` with `inactive = X` and `match = space` are kept |

- [ ] **Step 1:** Write the test class and a class skeleton. The two methods
  return initial values.
- [ ] **Step 2:** Syntax-check locally:

  ```sh
  .sapcli/venv/bin/python .sapcli/agent.py syntax --files <abs path to .clas.abap>
  ```

- [ ] **Step 3:** Push the branch and pull it with abapgit-agent. Run
  `agent.py unit --files <testclasses>`. Expected result: the tests FAIL.
- [ ] **Step 4:** Implement the decision table from the spec.
- [ ] **Step 5:** Push, pull and run `unit` again. Expected result: all tests
  pass.
- [ ] **Step 6:** Run `npx abaplint abaplint.jsonc`: 0 issues. Commit.

### Task 3: Service methods against abapGit

**Files:**
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap`
- Create: `src/zcl_ag2ui5_progress_silent.clas.abap` / `.clas.xml`

The progress class implements `zif_abapgit_progress` with empty methods. It is
a global class rather than a local one, so the syntax helper and MCP can reach
it.

- [ ] **Step 1:** Implement `list_repos`, `get_status`, `pull`,
  `get_online_repo` and `assert_pull_allowed`, following the spec's data flow.
  Every public method first calls
  `zcl_abapgit_progress=>set_instance( NEW zcl_ag2ui5_progress_silent( ) )`.
- [ ] **Step 2:** Run abaplint and the syntax check. Push and pull.
- [ ] **Step 3: Integration smoke test.** Run a `sapcli abap run` snippet
  (from `$CLAUDE_JOB_DIR/tmp`) that:
  - prints `lines( list_repos( ) )`
  - prints the row count of `get_status( '000000000010' )` for `$UMLAUT`
  - calls `pull( '000000000007' )` and expects the guard exception.

  Expected result: numbers, and `ERROR: ...would replace code...`.
- [ ] **Step 4:** Commit.

### Task 4: Repository list app

**Files:** Create `src/zcl_ag2ui5_app_repos.clas.abap` / `.clas.xml`

- [ ] **Step 1: Write the app.**
  - PUBLIC:
    - `mt_repos`: the service rows plus a `nav_type` column, which is
      `Navigation` for online repositories and `Inactive` for offline ones.
    - `mv_search`.
  - PROTECTED:
    - `client`
    - `mt_all`
  - Events:
    - `SEARCH` filters on name, package and URL, case-insensitive.
    - `OPEN` has the argument `${KEY}`. For an offline repository it shows a
      toast. Otherwise it calls
      `client->nav_app_call( zcl_ag2ui5_app_status=>create( key ) )`.
    - `REFRESH` reloads the list.
- [ ] **Step 2:** Run `npm run check`, which covers abaplint and the abap2UI5
  linter. Run `npx abap2ui5lint --fix` for the chain layout.
- [ ] **Step 3:** Push and pull. Open
  `…/sap/bc/z2ui5?sap-client=001&app_start=zcl_ag2ui5_app_repos` in Chrome.
  Expected result: the table lists 15 repositories, the search filters them,
  and offline rows (if there are any) don't navigate.
- [ ] **Step 4:** Commit.

The status app doesn't exist until Task 5. Task 4 therefore ships a minimal
`zcl_ag2ui5_app_status` with `create( )` and a page showing only the key, so
that the repository list activates. Task 5 fills it in.

### Task 5: Status and pull app

**Files:** Modify `src/zcl_ag2ui5_app_status.clas.abap` / `.clas.xml`

- [ ] **Step 1: Write the app.**
  - PUBLIC: `ms_head` (name, package, URL, branch, commit), `mt_rows` (with
    the text columns `local` and `remote`), `mt_blocking`, `mt_info`.
  - PROTECTED: `client`, `mv_key`.
  - Events:
    - `BACK`: `nav_app_leave( )`.
    - `REFRESH`: load the status.
    - `PULL`: call `service->pull`. The outcome is handled as the spec says:
      - `nothing`: a toast.
      - `pulled`: a toast plus a refresh.
      - `blocked`: `popup_display` with the blocking and info lists, and a
        Close button wired to `cs_event-popup_close`.
      - `failed`: a MessageBox of type `error` with the messages in
        `details`.
  - The status is loaded when the app is first displayed
    (`check_on_init` → `load_status`).
- [ ] **Step 2:** Run `npm run check`.
- [ ] **Step 3:** Push and pull, then run the E2E checklist in Chrome:
  1. The list loads.
  2. The status of `$UMLAUT` is shown.
  3. First pull of `$TEST_ONLINE_FROM_ABAPGIT` gives `pulled`. Record the
     duration.
  4. Change an object in that package locally through MCP, then pull. The
     outcome is `blocked` and the dialog lists the object.
  5. Pulling `$ABAPGIT` shows the guard MessageBox.
  6. Pulling a repository again that is up to date gives "Already up to date".
  7. Status on `$VERTEX`. Record the duration.
  8. Back navigation works.
- [ ] **Step 4:** Commit.

### Task 6: README, AGENTS.md, findings

- [ ] README: purpose, prerequisites (the abapGit developer version and
  abap2UI5 ≥ 1.146.0), installation, the start URL, and a screenshot.
- [ ] `AGENTS.md`, short:
  - the self-update guard
  - no abapGit references in attributes
  - how to deploy (push + agent-pull)
  - that abap2UI5's `docs/agents/building-apps.md` is the guide for apps
- [ ] `docs/findings.md`: the E2E results, durations, and any dumps or
  timeouts (the purpose of the PoC).
- [ ] Commit.
