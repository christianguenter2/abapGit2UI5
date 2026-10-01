# Diff view (inline): design

Date: 2026-10-01. Status: approved in chat.

## Goal

Show what differs in one file between the system and the remote. This is the
first part of the diff view; side by side follows later. The choices made in
chat:

- The diff opens from the status list.
- The layout is **inline** first.
- By default it shows the **changes with 3 lines of context**, plus a "Show all"
  button.

## Flow

1. Pressing a row in the status table calls `nav_app_call` with
   `zcl_ag2ui5_app_diff=>create( key, path, filename, obj_type, obj_name )`.
2. The diff app calls `get_diff( key, path, filename )` once, on init.
3. Back calls `nav_app_leave`, which returns to the status page without
   reloading it.

## Service

`get_diff( iv_key, iv_path, iv_filename ) RETURNING ty_diff`:

- The authorization check, the silent progress indicator and
  `get_online_repo` run as in the other methods.
- The local file comes from `get_files_local( )` and the remote file from
  `get_files_remote( )`, both matched by path and filename. A missing side
  becomes an empty xstring.
- Binary files: `zcl_abapgit_utils=>is_binary` on whichever side has data. The
  result is `binary = X` with no lines.
- Otherwise the diff is computed with
  `zcl_abapgit_diff_factory=>get( )->create( iv_new = local iv_old = remote )`.
  This is abapGit's own convention: local is new and remote is old.
- `map_diff( abapGit diff lines )` turns the result into plain lines.

`ty_diff_line`: `local_num`, `remote_num`, `text`, `kind`. `kind` is one of:

| `kind` | Meaning |
|---|---|
| `SAME` | The line is in both versions |
| `LOCAL` | The line exists only locally |
| `REMOTE` | The line exists only in the remote |
| `GAP` | Produced by `compact` for a run of unchanged lines |

`ty_diff`:

- `lines`
- `local_count` and `remote_count` (lines that exist only on one side)
- `binary`

Mapping of abapGit's `result` values:

| `result` | Becomes |
|---|---|
| space | one `SAME` line |
| `I` | one `LOCAL` line (`new`, `new_num`) |
| `D` | one `REMOTE` line (`old`, `old_num`) |
| `U` | two lines: `REMOTE` (the old text), then `LOCAL` (the new text) |

## Compact (no side effects)

`compact( it_lines, iv_context = 3 ) RETURNING lines`:

- Every non-`SAME` line is kept, together with up to `iv_context` `SAME` lines
  before and after it.
- Each run of `SAME` lines that is not kept becomes one `GAP` line with the
  text `… N unchanged lines …`.
- Without any change, the result is a single `GAP` line ("No differences"),
  or nothing if the file is empty.

## Page `ZCL_AG2UI5_APP_DIFF`

- Public data:
  - `ms_head`: the object, the file name, and the counts as text
    ("+N local, −M remote")
  - `mt_rows`: the visible rows. Each row is a line plus `highlight`
    (`Success` for LOCAL, `Error` for REMOTE, `Information` for GAP, `None`
    for SAME) and a `marker` column (`+` for local, `−` for remote)
  - `mv_show_all`
- Protected data:
  - `mt_all`: every line from the service, never sent to the browser
  - the key, path and filename
- The table has the columns Remote #, Local #, the marker, and Code. Code is
  monospace, with whitespace kept (CSS class `sapMonospaceFont`, or
  `renderWhitespace`). Each `ColumnListItem` binds `highlight`.
- A legend strip says: "Local: the version in this system. Remote: the version
  in Git."
- The button "Show all" / "Changes only" switches `mt_rows` between
  `compact( mt_all )` and `mt_all`, with no new fetch.
- A binary file shows a strip saying "Binary file - no line diff" instead of
  the table.

## Later: side by side

The lines carry both line numbers and the kind. Side by side is therefore a
second presentation function plus a toggle on the page; the service stays as
it is.

## Tests

- **Unit tests for `compact`:**
  - no change
  - a change in the middle with long gaps on both sides
  - a change on the first and on the last line
  - two changes whose context overlaps (no gap between them)
  - a context of 0
- **Unit tests for `map_diff`:** each result value (space, I, D, U) maps as
  described.
- **End to end:** after a local comment is added to `ZIF_ABAPGIT_UNIT_TEST`,
  the diff shows that line as `LOCAL`.
- **Browser:** through UI5 events.
- **Screenshot:** rendered headlessly.

## Out of scope

- Ignoring whitespace, indentation or case.
- Side by side.
- Opening a diff from the pull dialog.
- Patching or staging.
