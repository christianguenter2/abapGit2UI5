# Pick lines in all files: design

Date: 2026-10-14. Status: draft for Chris.

## Goal

From Stage, open one page that shows the diffs of all Stage files and lets
the user pick lines in several files at once. Apply hands every file's
picked lines back to Stage, which commits them as it does today for a single
file (`patch_ids` + `fingerprint` per item, checked again by `commit_push`).

Decisions (Chris, 2026-10-14):

1. Entry from Stage only.
2. Files whose panel was never opened keep their Stage state (whole file or
   earlier picks).
3. Inline layout only.

## Shape

A **pick mode of the repository Diff page** (`ZCL_AG2UI5_APP_REPO_DIFF`),
not a new page type. It reuses the lazy panels (3 open on start, at most 25
at once), the server-side file list and the login handling.

### Entry (Stage)

- New header button **"Pick lines in all files"** (icon
  `sap-icon://multi-select`), enabled when Stage has rows.
- Stage builds the file list from its **server-side** copy of the service's
  stage items, never from `mt_rows` (posted by the browser). Today's
  PROTECTED `mt_remote` (path, filename, sha1) grows into that copy: it also
  keeps `obj_type`, `obj_name`, `object_link`, `lstate`, `rstate`.
- Rows hidden by the "Changed by" filter are still passed: the page shows
  all Stage files. (Simple and predictable; the filter is a view filter.)
- Earlier picks from `mt_patches` are passed in, so the page opens with them.

### Contract between Stage and the Diff page

Public on `ZCL_AG2UI5_APP_REPO_DIFF`:

```abap
TYPES:
  "! One file's picked lines, as the single-file Pick lines hands them back
  BEGIN OF ty_pick,
    path        TYPE string,
    filename    TYPE string,
    ids         TYPE string_table,
    "! Distinct patch IDs of the file
    total       TYPE i,
    fingerprint TYPE string,
  END OF ty_pick,
  ty_picks TYPE STANDARD TABLE OF ty_pick WITH EMPTY KEY,
  BEGIN OF ty_pick_result,
    "! Set by Apply; Back leaves it initial
    applied TYPE abap_bool,
    "! Only files whose panel was loaded; the others keep their Stage state
    picks   TYPE ty_picks,
  END OF ty_pick_result.

CLASS-METHODS create
  IMPORTING
    ... (unchanged)
    "! Pick mode: line checkboxes, Apply; the system is always the new side
    iv_pick   TYPE abap_bool DEFAULT abap_false
    "! Earlier picks per file (ids only are used; checked against the diff)
    it_picked TYPE ty_picks OPTIONAL

METHODS get_picks
  RETURNING VALUE(rs_result) TYPE ty_pick_result.
```

`it_files` keeps its type (`ty_status_rows`); Stage maps its items into it
(`path`, `filename`, `obj_type`, `obj_name`, `object_link`, `lstate`,
`rstate`, `remote_sha1`).

### Diff page in pick mode

- Title `Pick lines - <repo>`; no layout switch (inline only); header button
  **Apply** (emphasized); Back without Apply hands nothing back.
- Route: keeps the Stage route (`/repo/<key>`, not `.../diff`), like the
  single-file Pick lines; a cold start of that route opens Status as today.
- Every panel loads with `iv_remote_is_new = abap_false` (local changes:
  the system is the new side), with the SHA1 as today.
- Per loaded file a PROTECTED pick record: patch IDs of the diff (distinct,
  file order), the fingerprint, the picked IDs. It survives collapsing the
  panel (lines are dropped on collapse as today, picks are not).
- Earlier picks (`it_picked`) are applied on the first load of that file,
  keeping only IDs that are still changes of the diff (as `picked_in_order`
  does for one file).
- Each changed line gets a CheckBox (`PICK` event with panel index and
  patch ID). The server checks the index (`checked_index`) and that the ID
  belongs to that file's diff; otherwise nothing happens.
- Panel header shows `x of y lines` once loaded. Panel toolbar: **All
  lines** / **No lines** for that file (`PICK_ALL` / `PICK_NONE` with index).
- Binary files show their note and no checkboxes; they are never part of
  the result.
- Apply: `applied = X`, `picks` = one entry per loaded, non-binary file
  (ids in file order, total, fingerprint), then `nav_app_leave( )`.

### Back in Stage

`take_picks( rs_result )` loops over `picks` and applies each exactly as
`take_patch` does for one file (all lines -> whole file, none -> earlier
selection, some -> patch + `modify - x of y lines`). Files not in `picks`
stay untouched. `take_patch` is refactored so both use one per-file routine.

### Not changed

- `commit_push` and the service: already handle several patched files.
- Single-file Pick lines and Status's repository Diff page (pick mode off).

## Size and limits

- At most 25 open panels: their lines are in the app state (`Z2UI5_T_01`),
  as today. Picks of closed panels are a few IDs each.
- One `get_diff` per opened panel (about 0.4 s with the single-file fetch).

## Tests

- Repo diff (pick mode): pick/unpick checks index and ID; foreign ID or
  index ignored; picks survive collapse/expand; earlier picks restored and
  filtered; All/No lines per file; Apply returns only loaded non-binary
  files with ids in file order, total and fingerprint; Back returns nothing;
  remote_is_new is false in pick mode; no layout switch rendered.
- Stage: button builds the list from the server copy (posted `mt_rows`
  changes do not matter); passes earlier picks; `take_picks` applies some /
  all / none per file and leaves other files untouched.
- On A4H25: `$AG2UI5_TEST` with two changed files, pick in both, Apply,
  push to a throwaway branch only with Chris's OK (otherwise stop before
  push and check the items sent with a service snippet).
