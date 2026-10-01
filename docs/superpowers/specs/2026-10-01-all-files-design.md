# Status: all files, changes marked: design

Date: 2026-10-01. Status: approved in chat (bounded slice).

## Choices

- The status page lists **every file** of the repository, one row per file.
  A per-object view and a switch between the two views come in a later
  slice; the switch added here leaves room for it.
- Changed rows are marked with the row highlight (the bar at the left edge):
  - `Warning` for a local change (or an inactive object),
  - `Information` for a change in Git only,
  - `Error` when both sides changed.
- A switch in the header, "All files" / "Changes only", filters on the
  server from the rows already loaded; "All files" is the default.
- The table grows in steps of 200 rows (`$ABAP2UI5` has thousands of files).
- Stage, pull and diff stay as they are. An unchanged file's diff says
  "No differences".

## Service

- `ty_status_row` gets `changed` (abap_bool).
- `filter_status` becomes `status_rows( it_results )`: every row, `changed`
  set when the file does not match or is inactive.
- `change_highlight( iv_lstate, iv_rstate, iv_inactive )` gives the row
  highlight (`None` when unchanged).

Both are without side effects and unit-tested, written to fail first.

## Tests

- Unit tests for `status_rows` and `change_highlight`.
- `npm run check`, a headless screenshot.
- Browser on A4H25: `$UMLAUT` and `$ABAPGIT2UI5`, both views.
