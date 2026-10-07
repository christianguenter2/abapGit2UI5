# Repository diff: all changes of a repository on one page

## Problem

The diff page (`ZCL_AG2UI5_APP_DIFF`) shows one file. To review everything
that differs between the system and Git, a user opens each file from the
status page in turn. Conventional abapGit has a repository-wide diff page
with all changed files stacked.

## Behavior

### Entry

The status page's table toolbar gets a **Diff** button (icon
`sap-icon://compare`) next to Files / Objects. It is disabled when no row is
changed, and for an offline repository without an uploaded ZIP (as the
single-file diff). It opens the new page with every changed file of the
status, independent of the All / Changes only filter and the sort, in the
status page's file order (`sort_status_rows` by `FILE`, changes first).

### Page `ZCL_AG2UI5_APP_REPO_DIFF`

- `create( iv_key, iv_title, iv_zip, it_files )`: `it_files` are the changed
  status rows (path, filename, obj_type, obj_name, object_link, lstate,
  rstate). The page keeps them in a PROTECTED table; the browser only sends
  an index, which is checked against that table.
- Header (overflow toolbar, as every page): Back, title
  `Diff – <repository>`, the summary `n files · +x −y` (x/y summed over the
  loaded files, with `(k not loaded)` while some are not), Inline / Side by
  side (one switch for all panels), **Expand all**, **Collapse all**.
- One `sap.m.Panel` per file, in the given order, rendered from a bound table
  with a template (nested binding: each file row carries its own line rows):
  - header toolbar: the file name, the object (Link to ADT when a link
    exists, else text), the state text (as on the status page:
    `local modified`, `remote added`, `both modified`, ...), the counts
    `+x −y` once loaded, and **Open** (navigates to the single-file diff for
    that file, which has the method summary, full file and Back).
  - content: the compacted diff (`compact`), inline or side by side, built
    with the same helpers as the single-file page (`map_diff` via
    `get_diff`, `code_html`, `tinted_html`, `to_side_by_side`). Only the rows
    of the current layout are filled.
  - a binary file shows `Binary file - no line diff`; a load error shows its
    text in the panel and does not stop the other files.
- Loading: on start the first 3 files are expanded and loaded through the
  existing `get_diff`; the rest are collapsed and carry no lines. Expanding a
  panel loads it; collapsing clears its line rows but keeps its counts.
  Expand all loads collapsed files up to 25 expanded files in total; a toast
  says how many stayed collapsed. Collapse all clears every panel's lines.
- Back returns to the status page; nothing is written anywhere.

### Out of scope

Line picking / patching (Stage and the single-file page keep it), the
method summary per panel (behind Open), writing, and a new service method:
`get_diff` already serializes only the file's object and restores the
offline ZIP per call.

## Checks

- Every `EXPAND`, `COLLAPSE` and `OPEN` argument is an index into the
  server-side file table; anything else is ignored.
- `get_diff` checks the authorization (unchanged).
- Only bound data is public: the file rows with their line rows, the head and
  the layout. The file table with keys and ZIP stays PROTECTED.

## Tests

App tests with a service double (`get_diff` records calls, can fail or
return binary):

- start loads exactly the first 3 files, the others have no lines
- expand loads one file, collapse clears its lines and keeps counts
- expand all stops at 25 expanded files and reports the rest
- forged and out-of-range indexes are ignored
- binary and failing files show their text, other files still load
- the layout switch rebuilds all loaded panels in the other layout
- Open navigates to the single-file diff with that file's data
- the summary sums loaded counts and reports not-loaded files

Status app tests: the Diff button passes only changed rows, in file order;
it is disabled without changes and for an offline repository without ZIP.

Lint/render gate, all native suites, readbacks, Chrome on `$UMLAUT`
(read-only).

## Deployment

The new class with its test include is created through abapgit-mcp
`write_objects` (dry run first) in `$ABAPGIT2UI5`; existing classes are
written over ADT as before.
