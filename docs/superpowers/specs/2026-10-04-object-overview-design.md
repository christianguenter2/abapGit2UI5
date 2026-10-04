# Object overview alongside file overview

Chris requested a second status overview by object on 2026-10-04, with
implementation choices delegated to the agent.

## Behavior

- Status has a Files / Objects switch, independent of All / Changes only.
  Files remains the default for existing users. The choice is saved per SAP
  user as `STATUS_OVERVIEW` (`FILES` or `OBJECTS`).
- Objects shows one row per object type/name. Files without a complete
  object key are grouped under Repository files with no ADT link.
- Every object row shows changed/total file counts, local and remote
  states, inactive state and the existing yellow change highlight.
- Aggregate nonempty states: a single distinct state keeps its meaning;
  differing states show "mixed". Unchanged files do not dilute a change.
  Inactive and changed flags are ORed across the files. A changes-only
  object still counts all its files and opens all its files.
- Object rows are ordered by type/name, with changes on top when selected.
  The existing file sort selector applies only to Files.
- Clicking an object row opens a file list dialog. It shows full paths,
  states and highlights, sorted using the existing file sort. File clicks
  open the existing diff. Returning from diff reopens the file list.
  Close clears its bound data. Clicking the object name opens ADT directly.
- Online and offline repositories use the same overview. Without an
  uploaded offline ZIP, objects/files can be browsed but diff stays disabled.
- Pull, staging, branches and their validation are unchanged; grouping is a
  presentation of cached plain status data and requires no extra fetch.

## Implementation and checks

Pure `object_status_rows` on the service groups the existing file status
rows and returns plain rows with file/changed counts. The app builds only
the selected overview into its bound table; original file status remains
protected. Object file dialog data is public only while it is displayed.

Native tests cover aggregation, mixed states, inactive files, unmapped
files, distinct object types, sorting/filtering, saved overview, dialog
navigation and closing/returning. Run local lint/render checks, deploy
existing objects through ADT with backups and readback, and verify the
switch and dialog in the browser, including a narrow viewport.
