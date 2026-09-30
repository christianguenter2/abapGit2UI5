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
