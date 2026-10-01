# PoC findings

End-to-end test on A4H25 (abap2UI5 1.146.0, abapGit developer version at
`main` `0995f4c`), 2026-09-30, in Chrome.

## What worked

| Step | Result |
|---|---|
| Repository list | All 20 repositories listed; the offline one (`/DMO/FEATURE_SHOWCASE_APP`) cannot be selected |
| Search | Filters on name, package and URL; Refresh keeps the search term |
| Navigation | Pressing a row opens the status; Back returns to the list |
| Status `$UMLAUT` | 1 row: `ZCL_TEST_UMLAUT` changed locally |
| Status `$ABAPGIT` (about 1,400 files) | Loaded in under 10 s; shows exactly the known `zabapgit.tran.xml` difference |
| Pull `$UMLAUT` | **Blocked:** "Overwrite local object / CLAS ZCL_TEST_UMLAUT"; nothing imported |
| Pull `$ABAPGIT` | Refused by the self-update guard, with an error MessageBox |
| Pull `$ABAP-TBOX-STATS` | "Already up to date" toast |
| Pull `$AG2UI5_TEST` (`abapGit-tests/INTF`, created for this test) | **Pulled:** `ZIF_ABAPGIT_UNIT_TEST` imported and active; the status refreshed to "Local and remote match" |
| Short dumps (ST22) | None |

The main risk in the design didn't occur: no SAP GUI popup and no dynpro was
reached during status or pull over HTTP.

## What we learned

**Abort mode blocks most real repositories.** A dry run (`deserialize_checks`
plus `classify`, no import) over the 17 online repositories other than
`$ABAPGIT` and `$ABAPGIT2UI5` gave these results:

| Outcome | Repositories |
|---|---|
| Nothing to pull | 6 |
| Ready | 1 (`$ABAPGIT-AGENT`, file-level differences only) |
| Blocked | 10, for example `/DMO/FLIGHT` with 210 blocking items, `$ABAP2UI5-SAMPLES` with 134, and `ZABAP_PROCESSING_CENTER` with 19 |

The checks ran in 0 to 10 s per repository. `$ABAP2UI5-CONTROLS` was the
slowest at 10 s.

There are three causes:

- Genuine local changes (`$UMLAUT`, `$ZAPCOMMANDER`).
- Repositories that are linked but have never been pulled, while their objects
  already exist in the system. Without checksums, abapGit sees them as "added
  locally", with the action "Delete local object". `$TEST_ONLINE_FROM_ABAPGIT`
  is an example.
- Transportable packages (`/DMO/FLIGHT`, `ZABAP_PROCESSING_CENTER`).

**Consequence for the next slice:** a useful pull needs per-object decisions in
the UI, like abapGit's own popup, instead of a pure abort mode. The blocked
dialog already lists exactly the objects that would need a decision.
`classify( )` returns the checks with decisions already filled in, so a
decision dialog only has to flip them.

## Code review fixes

After a whole-branch review, three issues were fixed. The first two have tests
that failed before the fix. The authorization check has none, because A4H25
has no auth exit that would deny it; the allowed path was retested.

- **An exception during import no longer loses the log.** The outcome becomes
  `failed`, the log messages are shown, and the status is reloaded.
- **The guard now decides by the packages of the code that is running**
  (abapGit, abap2UI5 and this repository), instead of by URL.
- **abapGit's startup authorization is checked** before every service call.

## Not tested

- The `failed` outcome (a pull whose log contains errors). It is hard to
  provoke without breaking an object on purpose.
- A network or authentication error during status or pull. The error handling
  is the same `zcx_abapgit_exception` path as the guard, which was tested.
- Large pulls and ICM timeouts. No repository in the system had a large
  remote-only change set that could be pulled safely.

## Leftovers on A4H25

- Package `$AG2UI5_TEST` with `ZIF_ABAPGIT_UNIT_TEST`, and the abapGit
  repository `000000000025` (`abapGit-tests/INTF`). They are kept as the
  happy-path fixture for future end-to-end runs, and can be removed with
  abapGit (Remove / Uninstall).
- Repository `$ABAPGIT2UI5` is on branch `poc/first-slice`.

## Slice 2: pull with decisions (2026-09-30)

Abort mode is replaced by a decision dialog. See
`docs/superpowers/specs/2026-09-30-pull-decisions-design.md`.

End-to-end on the `$AG2UI5_TEST` fixture, after a local change to
`ZIF_ABAPGIT_UNIT_TEST` and a new local-only class `ZCL_AG2UI5_E2E_LOCAL`:

| Step | Result |
|---|---|
| Preview | The class is under "Delete" and the interface under "Overwrite", both unselected |
| Pull with an item missing from the list | Outcome `changed`, nothing imported |
| Pull with a stale group (the interface was ticked as "Import" but is now "Overwrite") | Outcome `changed`, nothing imported |
| Pull with nothing selected | Outcome `nothing`; the class and the local edit stay, and "Last pull" does not move |
| Pull with everything selected | The class is deleted and the interface restored; the preview afterwards is `nothing` |
| Browser: dialog, "Nothing selected", tick a box, "Pull selected" | The dialog closes, "Pulled" is shown and the status reads "Local and remote match" |
| Browser: Pull again, then Back | "Already up to date", and "Last pull" in the list is updated |
| Short dumps | None |

The browser steps ran while the screen was locked. Chrome could still run
JavaScript but did not draw the page or process clicks, so the controls' events
were fired through UI5 (`firePress`, `fireSelect`). That covers the round trips
and bindings, but not the physical click.

A whole-branch review found one critical issue. Only *new* objects were
detected between preview and pull. A tick given to an "Import" could therefore
turn into a delete or an overwrite if the remote or the system changed in
between. `pull` now compares the fresh preview with the submitted one by
object **and group** (`merge_decisions`), and the server decides what can be
ticked. The review also led to two further changes:

- An object in a foreign package keeps that note even when it lands in a more
  dangerous group.
- The service refuses a pull with nothing selected, as abapGit does.

All three have tests that failed first. ABAP Unit is now 37/37.

**Observation from the end-to-end runs.** In one run, a class that was
re-created through ADT right after being deleted did not appear in the preview.
It was gone after the pull anyway. This is abapGit's own behavior, not a
deletion by the dialog:

- abapGit hides TADIR entries whose object does not "exist" yet
  (`zcl_abapgit_tadir->check_exists`).
- When it deserializes a local package, it removes such orphaned TADIR rows
  (`remove_obsolete_tadir` in `zcl_abapgit_object_devc`).

A clean repeat showed the class under "Delete", and it was deleted only when it
was ticked.

## Slice 3: transport request picker (2026-09-30)

The fixture is a transportable package, `ZAG2UI5_TR_TEST` (software component
HOME, change recording on). It holds abapGit repository `000000000026`
(`abapGit-tests/DTEL`) and uses request `A4HK900148`.

| Step | Result |
|---|---|
| Preview | Outcome `ready` with request type `K`; DEVC and DTEL under "Import" |
| List of requests | The user's two modifiable workbench requests |
| Pull with a request that is not the user's (`A4HK999999`) | Refused: "not one of your modifiable requests" |
| Pull with `A4HK900148` | Pulled; `ZAGT_TEST_DTEL` is recorded on the request; the preview afterwards is `nothing` |
| Browser, on `ZABAP_PROCESSING_CENTER` (dialog only, no pull) | A "Transport request" select with both requests, the newest preselected; Cancel closes it |
| Short dumps | None |

A review led to four fixes, each with a test where one is possible:

- **Requests where the user only has a task are offered**, as in abapGit's
  `TRINT_ORDER_CHOICE`. That is the usual team setup.
- **Only requests of the current client are offered** (E070C).
- **A request abapGit already determined is used as is**, with no choice
  offered. It comes from the repository setting or the user exit.
- **"Request required, but no type" blocks** with a clear message.

ABAP Unit is 44/44. The end-to-end test was repeated after the fixes. A local
change to `ZAGT_TEST_DTEL` appears under "Overwrite", and pulling it on
`A4HK900148` restores the remote text.

Creating a request from the dialog is still not supported.

## Slice 4: inline diff view (2026-10-01)

See `docs/superpowers/specs/2026-10-01-diff-view-design.md`.

- `get_diff` on A4H25, after a local comment was added to
  `ZIF_ABAPGIT_UNIT_TEST`:
  - The `.abap` file gives 9 lines, and the comment is the only `LOCAL` line
    (local line 8).
  - The `.xml` file gives no difference.
- ABAP Unit is 51/51. `compact` and `map_diff` are fully unit-tested.
- The browser test was not possible: overnight the SAP session in Chrome
  expired, and Chrome waits for a login that the agent must not enter. The
  page was checked with both linters and with a headless render that uses the
  real diff result (`docs/screenshots/diff.png`).
- Open point: the code column is not in a monospace font yet. That is planned
  together with side by side.
