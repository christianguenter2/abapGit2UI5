# Patch: staging single lines: design

Date: 2026-10-01. Status: approved in chat.

## Choices

- Lines are picked on the **diff page**, opened in patch mode from a staging
  row. There is no separate patch page for all files.
- The two halves of a changed line are **linked**, as in abapGit: a changed
  line is committed whole or not at all. Pure additions and removals are
  picked on their own. abapGit's `zcl_abapgit_git_add_patch` builds the
  content, unchanged, so the result is what abapGit itself would push.
- Whole-file staging stays as it is. A patch is an alternative per file.
- Push and credentials work as in slice 6.

## Flow in the UI

### Staging page

- Each row with a text diff gets an action "Pick lines". It opens the diff
  page in patch mode for that file. Clicking the row still opens the normal
  read-only diff.
- After lines are picked, the row's "Change" column shows e.g.
  `modify - 3 of 7 lines`, and the row is selected.
- If every line is picked, the row counts as the whole file again. If none is
  picked, the row goes back to how it was before.
- Binary files get no "Pick lines".

### Diff page in patch mode

- Inline view only; the side-by-side toggle is hidden.
- Every changed line has a checkbox. Both halves of a changed line carry the
  same patch ID. Ticking one sends a round trip, and the server ticks its
  partner, so both halves always show the same state.
- Header buttons: "All lines", "No lines", and "Apply". Apply returns to the
  staging page with the selection. Back without Apply discards it.
- When it opens, the page shows the lines picked earlier.

### Return of the selection

The staging app handles `check_on_navigated`: it takes the previous app (the
diff app) and reads its selection through a public getter. The selection is
stored in the row as a list of patch IDs plus the fingerprint of the diff it
was made on. A small method applies it to the row, so the app test can call it
without a real previous app.

## Service

### Patch IDs and fingerprint

- `ty_diff_line` gets `patch_id`, set by `map_diff`:
  - `N<new_num>` for insert rows and for **both** halves of an update row
  - `O<old_num>` for delete rows
  - empty for unchanged lines and gaps

  In staging the local side is always "new" (a file Git changed too is
  refused), so `N` is a local line number and `O` a Git line number: the
  numbers abapGit's `set_patch_new` / `set_patch_old` use.
- `ty_diff` gets `fingerprint`: the SHA1 of the local data followed by the
  remote data.
- `ty_stage_item` gets `patch_ids TYPE string_table` and `fingerprint`. An
  empty `patch_ids` means the whole file.

### Methods without side effects (unit-tested)

| Method | What it does |
|---|---|
| `map_diff` | Also sets `patch_id`, as above. |
| `apply_patch( it_diff, it_ids )` | Sets `patch_flag` on abapGit's diff rows for each ID. Raises if an ID does not name a changed row, or if `it_ids` is empty. |
| `patch_action( iv_lstate, iv_all )` | What to stage, as abapGit's `add_to_stage`: all lines of a deleted file give `rm`; all lines of an added file give `add` as added; anything else gives `add` as modified. |

### `commit_push` with a patched item

After the existing checks (`check_selection`, `check_push_allowed`, which
apply to patched files too):

1. Read the local and remote data of the file. This is the reading part of
   `get_diff`, moved into a private method `read_file_pair` that both use.
2. Compute the fingerprint. If it differs from the item's, the outcome is
   `changed` and nothing is pushed.
3. Build the diff with the local side as new, call `apply_patch`, then
   `zcl_abapgit_git_add_patch->get_patch_binary( )`.
4. Stage by `patch_action`: `add( data = patch, is_status = ... )` or `rm`.

After a partial push the file is still shown as modified, since the rest of
its changes stay local. The staging page reloads as today.

## Checks on what the client sends

- Patch IDs and fingerprint come from the browser. On push the server
  recomputes the diff from fresh data. A different fingerprint gives
  `changed`. `apply_patch` raises on any ID that does not name a changed line
  of the fresh diff.
- `AGENTS.md` lists `apply_patch` and the fingerprint under "checked again on
  the server".
- Token: the staging app gets the event `PATCH`. Coming back runs through
  `check_on_navigated`, which clears the token already. The app test covers
  `PATCH`. The diff app never sees the token.

## Tests

- **Service, written to fail first:**
  - `map_diff` patch IDs: insert gives `N`, delete gives `O`, both halves of
    an update share the same `N`, unchanged lines and gaps get none.
  - `apply_patch`: the right flags; raises on an unknown ID, on the ID of an
    unchanged line, and on an empty list.
  - `patch_action`: every combination of A, M, D with all or some lines.
  - Fingerprint: it changes when either side changes.
  - End to end, still without side effects: two texts, abapGit's diff,
    `apply_patch`, `zcl_abapgit_git_add_patch`, and the expected content.
- **Staging app:** the token is cleared on `PATCH`. Applying a selection
  selects the row and sets its change text; all lines give the whole file;
  no lines reset the row.
- **Diff app** (new test include, so it is deployed by a pull): ticking one
  half ticks its partner; "All lines" and "No lines".
- `npm run check`, and a headless screenshot of patch mode.
- **On A4H25**, `$UMLAUT` with two local changes in one file: staging page,
  Pick lines, Apply. The patch result is computed with a sapcli snippet,
  without a push, and compared with the expected content.
- **The real partial push:** Chris pushes on `$UMLAUT`. GitHub shows only the
  picked lines, and the staging page still lists the file as modified.

## Out of scope

- Patching in the side-by-side view.
- One checkbox per block of changes.
- Patching during a pull.
