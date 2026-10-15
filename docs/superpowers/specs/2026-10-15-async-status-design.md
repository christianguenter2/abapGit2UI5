# Status loads in the background: design

Date: 2026-10-15. Status: draft for Chris.

## Goal

Opening Status for a large repository blocks the page until abapGit has
serialized every local object. Status should open at once and fill its file
table when a background task has finished serializing.

Measured on A4H25 (`$ABAPGIT`, 1,419 files, abapGit's parallel processing
on):

| Step | Time |
|---|---|
| Remote fetch (`get_files_remote`) | 1.3 s |
| Local serialization (`get_files_local`) | 6.5 s |
| Status calculation | 16 ms |

Decisions (Chris, 2026-10-15):

1. Status first. Stage, the repository list and the `.../diff` route stay
   synchronous in this slice.
2. Every load serializes fresh: no result is reused across loads.
3. The page learns about the result by polling (`start_timer`). A websocket
   (abap2UI5's `Websocket` control with APC/AMC) is a later step that uses
   the same run table and run ID.

## Shape

The background task serializes **local files only**. It never touches Git
or credentials: abapGit's login manager is static per session, so a new
task would not have the session login of a private repository, and the
token must not travel anywhere else. Once the task is done, the next request
fetches the remote (as today) and calculates the status with the stored
local files.

```
Status load ──start_status──> run row (R) ──aRFC──> task: serialize, write files, D/E
     │                                                      
     └─ timer RUN_POLL (1 s) ──run_state──> R: progress text, poll again
                                          D: get_status( key, run_id ) -> rows
                                          E / gone / too old: error
```

### Background mechanism

aRFC: `CALL FUNCTION ... STARTING NEW TASK ... DESTINATION 'NONE'` without
a callback, so the HTTP request returns at once.

- It starts immediately and runs as the same user, so authorization is
  unchanged. abapGit's own parallel serialization still works inside it.
- It is limited by the dialog work-process runtime (`rdisp/max_wprun_time`).
- **The plan begins with a spike on A4H25:** the task must keep running
  after the HTTP request that started it has ended (stateless request,
  session gone). If it does not, the mechanism becomes a background job
  (`JOB_OPEN` / `SUBMIT` / `JOB_CLOSE` with immediate start, a report
  instead of the function module); everything else in this design stays.
  bgRFC is not used: it needs an inbound destination configured on every
  system.

### Run table `ZAG2UI5_RUN`

Transparent table, delivery class A, in `$ABAPGIT2UI5`.

| Field | Type | Meaning |
|---|---|---|
| `MANDT` | `MANDT` | key |
| `RUN_ID` | `SYSUUID_C32` | key |
| `UNAME` | `SYUNAME` | owner; every read checks it against `sy-uname` |
| `REPO_KEY` | `CHAR12` | abapGit repository key; every read checks it |
| `CREATED` | `TIMESTAMPL` | start time |
| `CHANGED` | `TIMESTAMPL` | last progress or state change |
| `STATE` | `CHAR1` | `R` running, `D` done, `E` error |
| `DONE_COUNT` | `INT4` | objects serialized so far |
| `TOTAL_COUNT` | `INT4` | objects to serialize (0 until known) |
| `MESSAGE` | `STRING` | error text for `E` |
| `FILES` | `RAWSTRING` | local files, `EXPORT ... TO DATA BUFFER ... COMPRESSION ON` |

- A result is deleted when `get_status` reads it.
- `start_status` first deletes the user's rows older than one hour.
- The task commits after every write (progress and final state), so the
  polling request sees them.

### Background task

New function group `ZAG2UI5_RUN` with the RFC-enabled function module
`Z_AG2UI5_SERIALIZE_LOCAL` (`IV_RUN_ID`, `IV_KEY`; no exporting parameters).

1. Install a progress class that writes `DONE_COUNT` / `TOTAL_COUNT` to the
   run row, at most once per second (new `ZCL_AG2UI5_PROGRESS_RUN`,
   implementing abapGit's progress interface like
   `ZCL_AG2UI5_PROGRESS_SILENT`).
2. Check abapGit's startup authorization, as every service method does.
3. Load the repository by key, `refresh( iv_drop_cache = abap_true )`,
   `get_files_local( )`.
4. Write the files and state `D`, commit.
5. Any `cx_root`: write its text and state `E`, commit. A dump leaves the
   row at `R`; the polling side handles that (see Errors).

Offline repositories serialize the same way: local serialization needs no
ZIP. The ZIP stays in the Status app and is restored by `get_status` as
today.

### Service (`ZIF_AG2UI5_REPO_SERVICE` / `ZCL_AG2UI5_REPO_SERVICE`)

- `start_status( iv_key ) RETURNING rs_start`: `rs_start-head` is the status
  head without rows and without a remote fetch (name, package, offline flag,
  labels, URL, branch and branch display/link from the registration; remote
  commit empty). It writes the run row and starts the task;
  `rs_start-run_id` is its ID. If the task cannot start
  (`RESOURCE_FAILURE`, `SYSTEM_FAILURE`, `COMMUNICATION_FAILURE`), it
  deletes the row and returns an empty `run_id`.
- `run_state( iv_run_id, iv_key ) RETURNING rs_state` (state, done, total,
  message, age in seconds). A row that does not exist or belongs to another
  user or repository returns state `G` (gone).
- `get_status( iv_key, iv_zip, iv_run_id )`: with `iv_run_id`, it reads the
  row (same owner and key checks; anything but `D` raises), imports the
  files, deletes the row, and computes the status as today, except that
  `zcl_abapgit_repo_status=>calculate` gets a wrapper around the repository
  instead of the repository itself. Without `iv_run_id` nothing changes.
- The wrapper (new local class or `ZCL_AG2UI5_REPO_LOCAL_FILES`) implements
  `zif_abapgit_repo` by delegating every method to the real repository,
  except `get_files_local` and `get_files_local_filtered`, which return the
  stored files (filtered with the given object filter as abapGit does). It
  copies `ms_data` from the repository. `calculate` uses only the interface
  and `ms_data` (checked on 2026-10-15).
- Pull, push, previews, Stage and the `.../diff` route keep their
  synchronous loads; they act on fresh data as AGENTS.md requires.

### Status app (`ZCL_AG2UI5_APP_STATUS`)

- `load_status( )` calls `start_status`. With a run ID it shows the head at
  once and sets the table busy with the text `Serializing...` or
  `Serializing 340 / 1,419`; Pull, Stage and Diff stay disabled
  (`mv_loaded` stays initial), Refresh stays enabled. Without a run ID (start
  failed), it loads synchronously as today.
- The run ID is PROTECTED (`mv_run_id`), never public.
- `client->follow_up_action( start_timer )` with `RUN_POLL` and 1000 ms. On
  `RUN_POLL`, the app asks `run_state( mv_run_id, mv_key )`:
  - `R`: update the progress text and start the timer again.
  - `D`: `get_status( iv_key = mv_key iv_zip = mv_zip iv_run_id = mv_run_id )`
    and continue as today's `load_status` after the service call.
  - `E`, `G`, or `R` with no change for 15 minutes: clear `mv_run_id`, show
    `Status could not be loaded` with the message, and leave Refresh
    enabled.
- A `RUN_POLL` whose run is no longer the app's current `mv_run_id` (an old
  timer after Refresh) is ignored.
- Every existing `load_status( )` caller (open, Refresh, back from Stage,
  after a pull, login return, route changes) goes through this path.
- Leaving the page: no further poll reaches Status (another app ignores
  the unknown `RUN_POLL` event); the row is removed by the one-hour cleanup.

### Errors

- Task error (`E`): shown like today's load error.
- Login: the remote fetch in `get_status( ... iv_run_id )` can still need a
  login. `show_error( )` opens the login app as today; back with
  `LOGGED_IN:<host>`, Status loads again (a new run).
- Dump or lost task: state stays `R`, `CHANGED` stops moving; after 15
  minutes the app gives up as above.
- Start failure: synchronous load, no message.

## Tests

ABAP Unit (no task started; the service's run access goes through a small
seam that tests replace, like `ZCL_AG2UI5_SETTINGS` and `inject( )`):

- Run row: owner and key checks; a foreign or unknown run ID gives `G`;
  `get_status` with a run ID that is not `D` raises; the row is deleted
  after reading.
- The wrapper: `calculate` over stored files gives the same rows as over the
  repository itself (fixture repository double).
- `start_status` without a startable task returns an empty run ID and no
  row.
- Status app: busy head after load; `R` updates progress and restarts the
  timer; `D` fills rows; `E`, `G` and timeout show the error; a stale
  `RUN_POLL` is ignored; start failure loads synchronously.

Live on A4H25:

- The aRFC spike (first task of the plan).
- `$ABAPGIT`: page usable at once; time to full status measured.
- `$AG2UI5_TEST` with a local change: same rows as before the slice.
- Offline `$TEST_OFFLINE` with its ZIP.
- Refresh during a run; Back during a run.

## Out of scope

- Websocket notification (later step, same table and run ID).
- Stage, the repository list and the `.../diff` route.
- Reusing results across loads, or caching serialized objects.
