# Status loads in the background: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Status opens at once and fills its file table when a background
task has serialized the local files.

**Architecture:** An aRFC task (`Z_AG2UI5_SERIALIZE_LOCAL`) serializes the
local files into the run table `ZAG2UI5_RUN`. Status polls with abap2UI5's
`start_timer`; when the run is done, `get_status` fetches the remote and
calculates the status with the stored files, passed to abapGit through a
wrapper around `zif_abapgit_repo`.

**Tech Stack:** ABAP 7.5x on A4H25, abapGit developer version, abap2UI5,
ABAP Unit with the ABAP SQL test double framework (`cl_osql_test_environment`).

**Spec:** `docs/superpowers/specs/2026-10-15-async-status-design.md`

## Global Constraints

- Every load serializes fresh; no result is reused across loads.
- The background task never touches Git or credentials.
- Run rows are read only for `UNAME = sy-uname` and the given repository key.
- The run ID is never public on an app (PROTECTED); it is a lookup key only.
- Pull, push, previews, Stage and the `.../diff` route stay synchronous.
- AGENTS.md applies: only `ZCL_AG2UI5_REPO_SERVICE` (and classes it uses)
  talk to abapGit; apps keep no abapGit references; booleans arrive as `X`
  or space; headers stay `OverflowToolbar` in `customHeader`.
- Deploy over ADT (`.sapcli/a4h25 class write ... --activate`, `--type
  testclasses`, `interface write`), back up before, read back after,
  compare ignoring CR. Run from `/home/chris/Projects/GIT/abapGit`.
- `npm run check` must pass (abaplint, abap2UI5 linter).
- Never print credentials.

## Review Focus

1. Refresh pressed twice quickly: only the newest run fills the table; an
   older timer chain stops instead of polling forever (Task 4 test
   `stale_poll_is_ignored`).
2. The task dumps (row stays `R`): Status gives up after 15 minutes without
   a change, instead of polling forever (Task 4 test `idle_run_times_out`;
   Task 3 `run_state` returns `idle_seconds`).
3. A run ID of another user or another repository: treated as gone, never
   read or deleted (Task 3 tests `foreign_user_is_gone`,
   `foreign_key_is_gone`).
4. The aRFC cannot start (no free work process): Status loads synchronously
   and shows no error (Task 3 `start_failure_returns_no_run`, Task 4
   `start_failure_loads_synchronously`).
5. The remote fetch after a finished run needs a login: the login page
   opens as today and the return loads a new run (Task 4
   `login_after_run_opens_login`).

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `src/zag2ui5_run.tabl.xml` | run table | 1 |
| `src/zag2ui5_run.fugr.*` | RFC function module, one-line call into `ZCL_AG2UI5_STATUS_RUN=>serialize` | 1 (spike body), 3 (final) |
| `src/zif_ag2ui5_run_starter.intf.abap` | seam: start the background task | 2 |
| `src/zcl_ag2ui5_run_starter.clas.abap` | aRFC start | 2 |
| `src/zcl_ag2ui5_status_run.clas.abap` (+ tests) | run rows: create, state, take files, task body, cleanup | 2 (stubs), 3 |
| `src/zcl_ag2ui5_progress_run.clas.abap` | abapGit progress -> run row counts | 2 (stub), 3 |
| `src/zcl_ag2ui5_repo_local_files.clas.abap` (+ tests) | `zif_abapgit_repo` wrapper returning stored local files | 2 (stub), 3 |
| `src/zif_ag2ui5_repo_service.intf.abap` | new types and methods | 2 |
| `src/zcl_ag2ui5_repo_service.clas.abap` (+ tests) | `start_status`, `run_state`, `get_status( iv_run_id )` | 2 (stubs), 3 |
| `src/zcl_ag2ui5_app_status.clas.abap` (+ tests) | busy head, polling, apply result | 4 |
| `src/zcl_ag2ui5_app_*.clas.testclasses.abap` | service doubles get `start_status` (empty run ID) | 2 |
| `AGENTS.md`, `README.md`, `docs/findings.md` | design rule, limits | 5 |

Work split: Claude does Tasks 1, 2 and 5. Task 3 goes to Codex (worktree
`../abapGit2UI5-async-backend`, branch `feature/async-status-backend`),
Task 4 to opencode (worktree `../abapGit2UI5-async-app`, branch
`feature/async-status-app`), both started from the contract commit of
Task 2. Reviews after the merge: Copilot (model Grok 4.7) for Task 3, omp
for Task 4.

---

### Task 1: Spike: an aRFC task outlives the HTTP request (Claude)

**Files:**
- Create: `src/zag2ui5_run.tabl.xml` (final table)
- Create: `src/zag2ui5_run.fugr.*` (function group, spike body)

**Interfaces:**
- Produces: table `ZAG2UI5_RUN` with the fields of the spec; function
  module `Z_AG2UI5_SERIALIZE_LOCAL` (RFC-enabled), importing `IV_RUN_ID
  TYPE SYSUUID_C32`, `IV_KEY TYPE STRING`.

- [ ] **Step 1: Create the table** with abapgit-mcp `write_objects`
  (`dry_run: true`, then for real) in package `$ABAPGIT2UI5`: fields
  `MANDT` (`MANDT`, key), `RUN_ID` (`SYSUUID_C32`, key), `UNAME`
  (`SYUNAME`), `REPO_KEY` (`CHAR12`), `CREATED` and `CHANGED`
  (`TIMESTAMPL`), `STATE` (`CHAR1`), `DONE_COUNT` and `TOTAL_COUNT`
  (`INT4`), `MESSAGE` (`STRING`), `FILES` (`RAWSTRING`); delivery class A,
  data class APPL1, size category 0, no buffering.

- [ ] **Step 2: Create the function group** `ZAG2UI5_RUN` with
  `Z_AG2UI5_SERIALIZE_LOCAL` (remote-enabled) and the spike body:

```abap
FUNCTION z_ag2ui5_serialize_local.
*"  IMPORTING
*"     VALUE(IV_RUN_ID) TYPE  SYSUUID_C32
*"     VALUE(IV_KEY) TYPE  STRING
  WAIT UP TO 20 SECONDS.
  DATA lv_now TYPE timestampl.
  GET TIME STAMP FIELD lv_now.
  UPDATE zag2ui5_run SET state = 'D' changed = lv_now WHERE run_id = iv_run_id.
  COMMIT WORK.
ENDFUNCTION.
```

- [ ] **Step 3: Start it from a stateless HTTP request** (`abap run`, which
  is one ADT HTTP request):

```abap
DATA(lv_id) = CONV sysuuid_c32( cl_system_uuid=>create_uuid_c32_static( ) ).
DATA lv_now TYPE timestampl.
GET TIME STAMP FIELD lv_now.
INSERT zag2ui5_run FROM @( VALUE #( run_id = lv_id uname = sy-uname repo_key = '000000000025'
                                    created = lv_now changed = lv_now state = 'R' ) ).
COMMIT WORK.
CALL FUNCTION 'Z_AG2UI5_SERIALIZE_LOCAL' STARTING NEW TASK lv_id DESTINATION 'NONE'
  EXPORTING iv_run_id = lv_id iv_key = `000000000025`
  EXCEPTIONS resource_failure = 1 system_failure = 2 communication_failure = 3 OTHERS = 4.
out->write( |{ lv_id } subrc { sy-subrc }| ).
```

  Expected: `subrc 0`, the request returns at once.

- [ ] **Step 4: After 25 seconds, read the row** in a second `abap run`
  (`SELECT SINGLE state FROM zag2ui5_run WHERE run_id = ...`).
  Expected: `D`. If it stays `R`, stop and switch the mechanism to a
  background job (spec, "Background mechanism"); tell Chris first.

- [ ] **Step 5: Delete the spike row**, keep table and function group,
  serialize both with abapgit-mcp into `src/`, commit
  `Spike: aRFC task outlives the HTTP request` (the function body is
  replaced in Task 3).

### Task 2: Contract (Claude)

**Files:**
- Modify: `src/zif_ag2ui5_repo_service.intf.abap`
- Create: `src/zif_ag2ui5_run_starter.intf.abap`, `src/zcl_ag2ui5_run_starter.clas.abap`
- Create (stubs with test includes): `src/zcl_ag2ui5_status_run.clas.*`,
  `src/zcl_ag2ui5_progress_run.clas.*`, `src/zcl_ag2ui5_repo_local_files.clas.*`
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (stubs)
- Modify: service doubles in every app test include that implements
  `zif_ag2ui5_repo_service` (Status has two: lines ~354 and ~1211)

**Interfaces:**
- Produces (exact; Tasks 3 and 4 rely on them):

```abap
" zif_ag2ui5_repo_service
  CONSTANTS:
    BEGIN OF c_run_state,
      running TYPE string VALUE `R`,
      done    TYPE string VALUE `D`,
      error   TYPE string VALUE `E`,
      gone    TYPE string VALUE `G`,
    END OF c_run_state.
  TYPES:
    BEGIN OF ty_status_start,
      "! Empty: the task did not start; load synchronously
      run_id TYPE string,
      "! Status without rows and without remote commit
      head   TYPE ty_status,
    END OF ty_status_start.
  TYPES:
    BEGIN OF ty_run_state,
      state        TYPE string,
      done         TYPE i,
      total        TYPE i,
      message      TYPE string,
      "! Seconds since the row last changed
      idle_seconds TYPE i,
    END OF ty_run_state.

  "! Starts serializing the local files in the background
  METHODS start_status
    IMPORTING iv_key          TYPE string
    RETURNING VALUE(rs_start) TYPE ty_status_start
    RAISING   zcx_abapgit_exception.

  "! State of a background run of this user and repository; else gone
  METHODS run_state
    IMPORTING iv_run_id       TYPE string
              iv_key          TYPE string
    RETURNING VALUE(rs_state) TYPE ty_run_state.

  " get_status gets:  iv_run_id TYPE string OPTIONAL
  "   "! Finished background run: its local files are used and deleted

" zif_ag2ui5_run_starter
INTERFACE zif_ag2ui5_run_starter PUBLIC.
  "! Starts Z_AG2UI5_SERIALIZE_LOCAL; false when the system refuses
  METHODS start
    IMPORTING iv_run_id         TYPE sysuuid_c32
              iv_key            TYPE string
    RETURNING VALUE(rv_started) TYPE abap_bool.
ENDINTERFACE.

" zcl_ag2ui5_status_run (PUBLIC FINAL CREATE PRIVATE, static only)
  CLASS-METHODS create      IMPORTING iv_key TYPE string
                            RETURNING VALUE(rv_run_id) TYPE string.   " '' = not started
  CLASS-METHODS state       IMPORTING iv_run_id TYPE string iv_key TYPE string
                            RETURNING VALUE(rs_state) TYPE zif_ag2ui5_repo_service=>ty_run_state.
  CLASS-METHODS take_files  IMPORTING iv_run_id TYPE string iv_key TYPE string
                            RETURNING VALUE(rt_files) TYPE zif_abapgit_definitions=>ty_files_item_tt
                            RAISING   zcx_abapgit_exception.          " not done / not found
  "! Body of Z_AG2UI5_SERIALIZE_LOCAL
  CLASS-METHODS serialize   IMPORTING iv_run_id TYPE sysuuid_c32 iv_key TYPE string.
  CLASS-METHODS inject      IMPORTING ii_starter TYPE REF TO zif_ag2ui5_run_starter.  " tests

" zcl_ag2ui5_progress_run (PUBLIC FINAL CREATE PUBLIC)
  INTERFACES zif_abapgit_progress.
  METHODS constructor IMPORTING iv_run_id TYPE sysuuid_c32.

" zcl_ag2ui5_repo_local_files (PUBLIC FINAL CREATE PUBLIC)
  INTERFACES zif_abapgit_repo.
  METHODS constructor IMPORTING ii_repo  TYPE REF TO zif_abapgit_repo
                                it_files TYPE zif_abapgit_definitions=>ty_files_item_tt.
```

- [ ] **Step 1:** Add the interface parts above; `ZCL_AG2UI5_RUN_STARTER`
  with the real aRFC call:

```abap
  METHOD zif_ag2ui5_run_starter~start.
    DATA lv_message TYPE c LENGTH 200.
    DATA(lv_task) = CONV char32( iv_run_id ).
    CALL FUNCTION 'Z_AG2UI5_SERIALIZE_LOCAL'
      STARTING NEW TASK lv_task
      DESTINATION 'NONE'
      EXPORTING
        iv_run_id             = iv_run_id
        iv_key                = iv_key
      EXCEPTIONS
        resource_failure      = 1
        system_failure        = 2 MESSAGE lv_message
        communication_failure = 3 MESSAGE lv_message
        OTHERS                = 4.
    rv_started = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.
```

- [ ] **Step 2:** Create the three classes with abapgit-mcp (main source,
  XML and an empty test include each), stub bodies: `create` returns `''`,
  `state` returns `gone`, `take_files` raises `Background run not found`,
  `serialize` does nothing, progress methods do nothing, the wrapper
  delegates every `zif_abapgit_repo` method to `ii_repo`.
- [ ] **Step 3:** Service stubs: `start_status` returns `head` from a new
  private `status_head( li_repo )` (the head part of today's `get_status`,
  which `get_status` then uses too) and calls
  `zcl_ag2ui5_status_run=>create( )`; `run_state` delegates to
  `zcl_ag2ui5_status_run=>state( )`; `get_status` with `iv_run_id` raises
  `Background run not found` until Task 3.
- [ ] **Step 4:** Every app test double that `INTERFACES
  zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED` and serves `get_status`
  gets `start_status` returning an empty `run_id` and the head of its
  `get_status` result, so today's tests keep the synchronous path.
- [ ] **Step 5:** `npm run check`; deploy all changed and new objects; all
  suites (service, stage, diff, status, repos, new_repo, repo_diff, login,
  settings, http) pass; readbacks match; commit
  `Contract: background Status runs`.

### Task 3: Backend (Codex)

**Files:**
- Modify: `src/zag2ui5_run.fugr.z_ag2ui5_serialize_local.abap`
- Modify: `src/zcl_ag2ui5_status_run.clas.abap` (+ `.testclasses.abap`)
- Modify: `src/zcl_ag2ui5_progress_run.clas.abap`
- Modify: `src/zcl_ag2ui5_repo_local_files.clas.abap` (+ `.testclasses.abap`)
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (+ `.testclasses.abap`)

**Interfaces:**
- Consumes: the contract of Task 2, exactly.
- Produces: working `start_status`, `run_state`, `get_status( iv_run_id )`.

- [ ] **Step 1: Function module body** (final):

```abap
FUNCTION z_ag2ui5_serialize_local.
*"  IMPORTING
*"     VALUE(IV_RUN_ID) TYPE  SYSUUID_C32
*"     VALUE(IV_KEY) TYPE  STRING
  zcl_ag2ui5_status_run=>serialize( iv_run_id = iv_run_id iv_key = iv_key ).
ENDFUNCTION.
```

- [ ] **Step 2: Failing tests for `ZCL_AG2UI5_STATUS_RUN`** with
  `cl_osql_test_environment=>create( VALUE #( ( 'ZAG2UI5_RUN' ) ) )` in
  `class_setup`, `clear_doubles( )` in `setup`, and a local starter double
  (`started` flag and the recorded run ID / key). Tests:
  - `create_writes_running_row`: starter returns true; one row with
    `uname = sy-uname`, `repo_key`, `state = 'R'`, `created = changed`;
    returned run ID equals the row's and the starter's.
  - `start_failure_returns_no_run`: starter returns false; `''` returned
    and no row left.
  - `create_cleans_old_rows`: a row of `sy-uname` created two hours ago is
    deleted; a row of another user with the same age stays.
  - `foreign_user_is_gone`, `foreign_key_is_gone`, `unknown_id_is_gone`:
    `state( )` returns `G`.
  - `state_reports_progress`: row `R`, 340 / 1419, `changed` 30 s ago
    (insert with a computed timestamp) gives `done = 340`, `total = 1419`,
    `idle_seconds` between 29 and 40.
  - `error_row_reports_message`: row `E` with message.
  - `take_files_returns_and_deletes`: row `D` with `FILES` written by the
    same export the task uses (`EXPORT files = lt_files TO DATA BUFFER
    lv_buffer COMPRESSION ON`); `take_files` returns two files equal to
    the input and the row is gone.
  - `take_files_refuses_running` (raises, row stays) and
    `take_files_refuses_foreign_user` (raises, row stays).

  Run: `.sapcli/venv/bin/python .sapcli/agent.py unit --files
  <worktree>/src/zcl_ag2ui5_status_run.clas.testclasses.abap`
  Expected: FAIL (stubs).

- [ ] **Step 3: Implement `ZCL_AG2UI5_STATUS_RUN`.**
  - `create`: delete the user's rows with `created` older than one hour;
    insert the row; `COMMIT WORK`; `starter( )->start( )`; on false delete
    the row, `COMMIT WORK`, return `''`. `starter( )` returns the injected
    double or a new `ZCL_AG2UI5_RUN_STARTER`.
  - `state`: `SELECT SINGLE` with `run_id`, `uname = sy-uname`,
    `repo_key`; not found: `G`. `idle_seconds` from
    `cl_abap_tstmp=>subtract( now, changed )`.
  - `take_files`: same select; state must be `D` (else raise `Background
    run is not finished`); `IMPORT files = rt_files FROM DATA BUFFER`;
    `DELETE` the row and `COMMIT WORK` (abap2UI5 rolls back after
    `main( )`; `ZCL_AG2UI5_SETTINGS->set` commits the same way).
  - `serialize` (runs in the task): `zcl_abapgit_progress=>set_instance(
    NEW zcl_ag2ui5_progress_run( iv_run_id ) )`; inside `TRY`: startup
    authorization (`zcl_abapgit_auth=>is_allowed( startup )`, raise
    `You are not authorized to use abapGit`), `zcl_abapgit_repo_srv=>
    get_instance( )->get( iv_key )`, `refresh( iv_drop_cache = abap_true )`,
    `get_files_local( )`, export, `UPDATE` state `D`, `files`, `changed`,
    `COMMIT WORK`. `CATCH cx_root`: `UPDATE` state `E`, `message =
    get_text( )`, `COMMIT WORK`.
- [ ] **Step 4: `ZCL_AG2UI5_PROGRESS_RUN`:** `set_total` stores the total;
  `show( iv_current )` writes `done_count`, `total_count`, `changed` and
  commits, at most once per second (keep the last write time); `off` does
  nothing. Small test: two `show` calls within a second write once (OSQL
  double).
- [ ] **Step 5: `ZCL_AG2UI5_REPO_LOCAL_FILES`:** constructor stores both,
  `zif_abapgit_repo~ms_data = ii_repo->ms_data`; `get_files_local` returns
  the stored files; every other method delegates (`get_files_local_filtered`
  delegates too: `get_status` does not use a filter). Tests with a local
  `zif_abapgit_repo` double (`PARTIALLY IMPLEMENTED`, `get_key`,
  `get_package`, `get_files_local` returning other files):
  `local_files_are_the_stored_ones`, `other_calls_delegate`,
  `ms_data_is_copied`.
- [ ] **Step 6: Service.** `get_status( iv_run_id )`: when given, `li_files
  = zcl_ag2ui5_status_run=>take_files( )` **before** the remote fetch, then
  `calculate( NEW zcl_ag2ui5_repo_local_files( ii_repo = li_repo it_files =
  lt_files ) )`; everything else as today. Tests (service test include,
  starter double injected, OSQL double): `start_status_returns_head`
  (offline fixture double or a real registration available in tests:
  follow the existing test style in that include), `run_state_delegates`,
  `get_status_with_unfinished_run_raises`.
- [ ] **Step 7:** `npm run check`; deploy FM, the three classes (main and
  tests) and the service (main and tests); read back; run the suites of
  the touched classes plus service; commit `Background Status runs:
  backend`; write the report to the scratchpad folder given in the brief.

### Task 4: Status app (opencode)

**Files:**
- Modify: `src/zcl_ag2ui5_app_status.clas.abap`
- Modify: `src/zcl_ag2ui5_app_status.clas.testclasses.abap`

**Interfaces:**
- Consumes: `start_status`, `run_state`, `get_status( iv_run_id )`,
  `c_run_state` from Task 2. No backend code needed: tests use the
  service double.

- [ ] **Step 1: Split `load_status`.** Move everything after the service
  call into `status_apply( is_status )`, the head part into
  `head_apply( is_head )` (both PROTECTED). Today's behaviour stays; run
  the Status suite: unchanged count, all pass.
- [ ] **Step 2: Failing tests** (service double gets `start_status`,
  `run_state`, and records `get_status`'s `iv_run_id`; client double
  records `follow_up_action` calls):
  - `run_shows_head_and_busy`: `start_status` returns run `R1` and a head;
    after load the head fields are set, `mv_busy = X`, `mv_loaded` initial,
    no rows, and a `start_timer` with event `RUN_POLL:R1` and `1000`.
  - `poll_running_updates_progress`: `run_state` returns `R`, 340 / 1419;
    event `RUN_POLL:R1`; progress text `Serializing 340 / 1,419`, a new
    `start_timer`, `get_status` not called.
  - `poll_done_loads_rows`: `run_state` `D`; `get_status` called with
    `iv_run_id = R1` (and `iv_zip = mv_zip`); rows filled, `mv_busy`
    initial, `mv_run_id` cleared, no new timer.
  - `poll_error_shows_message`: `E` with message; `mv_no_data = Status
    could not be loaded`, message shown, no new timer.
  - `poll_gone_shows_error` (`G`) and `idle_run_times_out` (`R`,
    `idle_seconds = 901`): same as error.
  - `stale_poll_is_ignored`: current run `R2`, event `RUN_POLL:R1`:
    `run_state` not called, no timer.
  - `start_failure_loads_synchronously`: empty run ID; `get_status`
    called without run ID, rows filled, no timer.
  - `login_after_run_opens_login`: `run_state` `D`, `get_status` raises
    the login error; the login app is called as in today's
    `show_error` tests.
  Run the Status suite. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
  - PROTECTED `mv_run_id TYPE string`; public bound `mv_busy TYPE
    abap_bool` (table `busy`), progress shown through the existing
    `mv_no_data` text (`Serializing...` / `Serializing 340 / 1,419`,
    thousands separator as in the test).
  - `load_status`: clear as today; `start_status( mv_key )` (exception:
    as today's error branch); empty run ID: today's synchronous path
    (`get_status` + `status_apply`); else `head_apply`, `mv_run_id`,
    `mv_busy = X`, clear rows, `start_timer` with `RUN_POLL:<run_id>` and
    `1000`.
  - `main`: an event starting with `RUN_POLL:` goes to `run_poll( )`
    before the other events. `run_poll`: suffix differs from
    `mv_run_id` or `mv_run_id` initial: return. Otherwise `run_state`:
    `R` and `idle_seconds <= 900`: progress text, `view_model_update( )`,
    new timer; `D`: `get_status( iv_key iv_zip iv_run_id )`, clear
    `mv_run_id` and `mv_busy`, `status_apply`, `view_display( )` (buttons
    depend on `mv_loaded`); everything else: clear run, `mv_busy`, rows,
    `mv_no_data = Status could not be loaded`, show the message
    (`show_error` for an exception from `get_status`, a message toast /
    box like today's error display for `E`/`G`/timeout), `view_display( )`.
  - Pull, Stage, Diff stay disabled while `mv_loaded` is initial; Refresh
    stays enabled and calls `load_status` (a new run).
- [ ] **Step 4:** Status suite passes; `npm run check` passes (render gate).
- [ ] **Step 5:** Deploy Status main and tests; read back; commit
  `Background Status runs: Status app`; write the report.

### Task 5: Merge, review, live test, docs (Claude)

- [ ] **Step 1:** Merge both branches into `feature/async-status`; `npm run
  check`; deploy everything changed; all suites pass; readbacks match.
- [ ] **Step 2:** Reviews in herdr panes, read-only, reports to files:
  Copilot with model Grok 4.7 on Task 3's diff, omp on Task 4's diff.
  Fix or send back findings; redeploy; suites again.
- [ ] **Step 3: Live on A4H25 (Chrome):** `$ABAPGIT` opens at once with
  progress, full status after the run (measure); `$AG2UI5_TEST` with a
  local comment on `ZIF_ABAPGIT_UNIT_TEST`: same rows as `get_status`
  without run (compare in a snippet), fixture restored afterwards;
  `$TEST_OFFLINE` with its ZIP; Refresh twice during a run; Back during a
  run; no leftover rows after an hour's cleanup (check own rows).
- [ ] **Step 4: Docs:** AGENTS.md design rule ("Background Status runs":
  task serializes local files only, no Git, no credentials; run rows
  checked by user and key; Status display only), the checks table
  (`ZCL_AG2UI5_STATUS_RUN`, `ZCL_AG2UI5_REPO_LOCAL_FILES` suites), README
  if it describes Status loading, `docs/findings.md` (aRFC runtime limit
  `rdisp/max_wprun_time`; websocket as next step).
- [ ] **Step 5:** Ask Chris "merge and push?"; at merge delete spec and plan.
