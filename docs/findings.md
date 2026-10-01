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
- A review led to four fixes:
  - **Control characters:** abapGit marks a missing final newline with a form
    feed, and abap2UI5 does not escape it in the JSON, which would have blanked
    the page. It now shows as "(no newline at end of file)", CR as `[CR]`, and
    other control characters as `?`.
  - **Changed blocks:** a run of changed lines reads as a block (all remote
    lines, then all local), as in git.
  - **Only the file's object is fetched**, through an object filter, as
    abapGit's diff page does. A diff in `$ABAPGIT` (about 640 objects) takes
    1.2 s.
  - **A missing file** raises "File not found" instead of showing an empty
    file.

  ABAP Unit is 53/53.
- Open points:
  - The code column is not in a monospace font yet, and long lines are cut off.
  - The colour of the remote side is still undecided (see below).

  Both are planned together with side by side.
- abap2UI5 upstream: `escape_string` in `z2ui5_cl_ajson` escapes no control
  characters other than tab, CR and LF. This is worth an issue, because it
  affects every app.

## Slice 5: side-by-side diff and direction (2026-10-01)

- **Direction as in abapGit:** when only the remote changed, the remote is the
  "new" side, in green with `+`. Otherwise the system is new. The header says
  which way the diff reads.
- **"Inline | Side by side"** switch. Side by side pairs a changed block line
  by line. On narrow screens the new side moves below the old one (UI5 popin).
- **Code is monospace** through `sap.m.FormattedText` with `<code>`. It is
  escaped in ABAP, keeps its indentation as `&nbsp;`, wraps long lines, and
  UI5 additionally sanitizes it. Tables grow by 500 rows at a time.
- ABAP Unit is 60/60 (direction, swapped mapping, pairing, code HTML).
- The screenshots use the real diff of `zabapgit.tran.xml` from A4H25. The
  console output of `sapcli abap run` escapes `&` a second time; that is an
  artifact of the screenshot data path, not of the app.
- A review led to two fixes, both with tests that failed first:
  - **Header counts follow the direction:** "+N in Git, -M in this system", or
    the other way round. The side-by-side column titles now name the side
    ("Git (old)" / "System (new)").
  - **Blanks inside a line are kept:** every second blank of a run becomes
    `&nbsp;`, so aligned columns survive, whitespace-only changes stay
    visible, and long lines still wrap. Tabs become four blanks.

  ABAP Unit is 63/63.
- Deployment: abapgit-agent aborted a pull with a `SYSTEM_EDIT` conflict on
  `ZCL_AG2UI5_APP_DIFF`, its known habit of flagging its own earlier imports.
  The two changed classes were therefore deployed through MCP as surgical
  edits. abapGit's status of `$ABAPGIT2UI5` against the branch afterwards
  shows no object differences.
- Browser test: still waiting for a login in Chrome.
- Not addressed yet (minor):
  - Files where **both** sides changed carry no warning.
  - Both row tables are built on every round trip.
  - abapGit keeps local left and remote right in its split view, while this
    app puts old left and new right. The column titles now say which is
    which.

## Slice 6: stage, commit, push (2026-10-01)

See `docs/superpowers/specs/2026-10-01-stage-commit-push-design.md`.

- ABAP Unit: service 69/69, app 4/4. The app tests run the push handler with
  doubles for the abap2UI5 client and the service. They check that the token
  is gone from the app object after a successful push, after an error, when
  nothing is selected, and when the committer is missing.
- End to end on A4H25, with `$UMLAUT` and its local change in
  `ZCL_TEST_UMLAUT`:
  - The candidates are correct: one ADD.
  - A push with an invalid dummy token is refused cleanly ("Unauthorized
    access. Check your credentials").
  - abapGit's login manager is empty afterwards.
- abapGit stores no committer for the user, so name and e-mail start empty.
  The app now asks for both before pushing.
- A security review found one critical issue, fixed and covered by a test that
  failed first:
  - **The token reached abap2UI5's draft table.** A typed token arrives with
    whatever button is pressed next ("Select all", a diff, Back). abap2UI5
    saves the app state after every event, so the token was stored in
    `Z2UI5_T_01` in plain text, for hours. `on_event( )` now takes it out of
    the attribute first, for every event. The app test runs ALL, NONE, DIFF,
    BACK and PUSH.

  No token had been typed in the browser before the fix: the wrong-token test
  called the service directly, and the browser test left the token field empty.
- The review also led to these fixes in the push:
  - **Credentials first:** they are set before the first fetch. Private
    repositories need them there already, and a 401 is no longer shown as
    "changed".
  - **Cleanup:** the login manager is cleared in `CLEANUP`, so it is cleared
    for every exception.
  - **`COMMIT WORK AND WAIT` after the push**, as abapGit does. abap2UI5 rolls
    back after `main( )`, and push writes the checksums.
  - **abapGit's push exits** `validate_before_push` and `validate_after_push`
    are called.
  - **Refusals, as abapGit's stage page does:** a file that Git changed too
    (shown as "changed in Git too, pull first"), and an object moved to
    another folder without the removal of its old path.
  - **The server works with the fresh state:** the client's rows only say
    which files are selected.

  ABAP Unit: service 73/73, app 5/5.
- Not in scope: reading the status of private repositories. The status and
  staging pages fetch without credentials.
- **Real push (Chris, 2026-10-01):** `$UMLAUT` / `sapgui_java_umlaut` was
  pushed successfully through the staging page. abapGit's user exit supplied
  the credentials. Afterwards the remote is at `900c4e5`, and system and Git
  match.
- **Draft table after the push:** `Z2UI5_T_01.DATA` is plain text (STRG,
  XML). 14 of its 62 drafts contain the staging app with its `MV_TOKEN` field.
  None of them contains a GitHub token pattern (`ghp_`, `github_pat_`) or the
  test marker.
- Deployment: after the MCP edits of slice 5, abapgit-agent blocked every pull
  of the service class (`SYSTEM_EDIT`). With Chris's OK for this one case,
  `ignore` mode was used once; after that, pulls run normally again.

## Slice 7: patch, staging single lines (2026-10-01)

See `docs/superpowers/specs/2026-10-01-patch-design.md`.

- ABAP Unit: service 84/84, diff app 8/8 (new test include), stage app 11/11.
- **Smoke test on A4H25**, `$UMLAUT` with two local comments in
  `ZCL_TEST_UMLAUT`:
  - The diff has two patch IDs (`N23`, `N27`).
  - Picking the first gives Git's 29 lines plus that one comment (30 lines),
    with state `M`. The fingerprint equals `get_diff`'s.
  - The umlauts stay intact (U+00FC). The `Ã¼` in the sapcli console comes
    from the console only.
- **Browser test** (through UI5, the screen was locked), without typing into
  the token field: Pick lines, tick, "Show all" and "Changes only", Apply,
  open again, Back. Every step behaves as specified. The row shows
  `modify - 1 of 2 lines`.
- **The browser found a bug the unit tests missed:** abap2UI5 sends booleans
  in event arguments as `abap_bool` (`X`/space). `PICK` compared with
  `` `true` ``, so every tick arrived as "unpicked", and the tests sent
  `` `true` `` too. The tests now send what abap2UI5 sends (red first). The
  checkbox passes `${$parameters>/selected}`, the event's own value.
- **Draft table:** 124 drafts, 19 with the staging app, none with a token
  pattern.
- Not run: the stale-fingerprint path of `commit_push` end to end. With a
  dummy token the first fetch is refused (nothing pushed, head unchanged).
  Without a token, abapGit's exit supplies real credentials. A bug in copying
  the patch IDs would then push the whole file, so that run waits for
  Chris's OK. It is covered by code reading and the `apply_patch` tests.
- Deviation from the spec: "Pick lines" is on every row, because the staging
  page does not know which files are binary. For a binary file the diff page
  shows no Apply.
- **Deployment:** abapgit-agent blocked the diff app with `SYSTEM_EDIT`
  although the system source equalled Git. With Chris's OK, `ignore` mode was
  used once, to create the new test include. The next pull was blocked again
  (it flags its own import), so later changes of that class went over ADT
  with `sapcli class write`, which also writes an existing test include
  (`--type testclasses`). `get_status` showed only `.abapgit.xml` differing.

## Open points (as of 2026-10-01)

Next slices, in the order agreed with Chris:

1. **Ignore and `.gitignore`** on the staging page.
2. **Pushing to another branch, or a new one.**
3. **Creating a transport request** from the pull dialog. Today the user is
   pointed to SE09.

Minor points left open by the reviews:

- Diff:
  - There is no warning when **both** sides changed (abapGit shows
    "Attention").
  - Both row tables (inline and side by side) are built on every round trip;
    only the visible one should be.
  - A gap of a single line reads "... 1 unchanged lines ...". Runs of 2 or
    more should be the only ones folded.
- Pull dialog:
  - Cancel closes on the client, so the dialog data stays in the model until
    the next preview.
  - A dialog with only "Skipped" rows cannot be pulled.
  - A pull that changes only repository files shows an empty dialog.
- Transport:
  - The request text is shown only in the logon language.
  - The newest request is preselected, not the user's default request.
- Stage:
  - Ignored files from `.abapgit.xml` are offered as candidates.
  - The status and staging pages read private repositories without
    credentials, so they work there only through the abapGit user exit.
- abap2UI5 upstream (worth an issue): `escape_string` in `z2ui5_cl_ajson`
  escapes no control characters other than tab, CR and LF.
