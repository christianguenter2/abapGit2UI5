# PoC findings

## Staging parity with conventional abapGit (2026-10-06)

On `$UMLAUT` / `feature/test1234`, the ABAP source differed only in Git
(`" patch test 1`), while its XML differed locally. Classic staging offered
both files and removal of remote-only `x.md`; this frontend excluded the
source and remote-only file and refused all selected remote changes at push.

Stage loading, fresh push validation and ignore previews now use abapGit's
stage logic. The pure mapper retains native ignore rules and metadata/move
guards. Explicit selections can commit SAP contents over remote changes,
with a notice on each affected row. Patch fingerprints and fresh candidate
validation remain; no file is selected by default.

Deployed the service and staging app, including their existing test includes,
via ADT. All four readbacks match. Native suites passed service 181/181,
stage 24/24 and diff 25/25 (230/230). `npm run check` passes with no errors or
warnings and the existing unresolved MessageStrip hint. Regression coverage
includes authoritative stage candidates, remote edits/additions/deletions,
metadata removal, permitted explicit overwrites and the row notice.

Live service and Chrome staging show the same three candidates as classic
abapGit. **Pick lines** shows the comment as a selectable deletion; a native
patch check recreates the SAP source exactly. An ignore preview includes the
ABAP source. No fixture object, branch, ignore rule or remote commit changed;
no push ran. Back from Pick lines leaves all candidates unselected.

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

- ABAP Unit: service 86/86, diff app 9/9 (new test include), stage app 12/12.
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
- **Real partial push (Chris, 2026-10-01):** `$UMLAUT`, one of the two
  picked comments in `ZCL_TEST_UMLAUT`. It works.
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

- **Review** (a fresh reviewer, whole branch): no critical findings. Three
  important ones, each fixed with a test that failed first:
  - "No lines" after an earlier patch left the row ticked, so the push
    committed the whole file. The same happened with Apply after a failed
    load. Now the tick from before the first patch is restored, and Apply
    needs a loaded diff.
  - abapGit's diff appends a form feed to a last line without newline when
    only the other side has one. The patch is built from those texts, so an
    unpicked change put the form feed into Git. abapGit's own patch page has
    the same bug (worth an upstream issue). `apply_patch` now removes it.
  - A removal with only some lines picked passed the "moved without removing
    the old path" check. It no longer counts as the removal.
- Minor points from the review, open:
  - Reopening Pick lines on a changed file carries old IDs over without a
    notice.
  - A `changed` outcome drops all picks without saying so.
  - "Select none" keeps patches, and "Select all" brings them back.
  - The "Pick lines" column has no header for screen readers.
  - `check_on_navigated` could use `IS INSTANCE OF`, and has no app test of
    its own.

## Slice 8: switch branch (2026-10-01)

See `docs/superpowers/specs/2026-10-01-switch-branch-design.md`. A bounded
slice: existing branches only, no new branch.

- ABAP Unit: service 92/92 (6 new tests for `branch_rows` and
  `assert_branch`), diff app 9/9, stage app 12/12.
- Smoke test: `list_branches` gives the 9 branches of `$ABAPGIT2UI5`
  (`main` default, the current one marked) and `main`/`Test` of `$UMLAUT`.
  An unknown branch is refused.
- Browser test on `$ABAPGIT2UI5`: the dialog lists the branches with
  `main (default)` first and the current one preselected. Switching to
  `patch` showed its head `f8c649d` and the 5 files that differ; switching
  back gave `aa49879` and only `.abapgit.xml`, as before.
- Chris tested switching branches himself (2026-10-01): it works.
- The first switch in the browser ended with abap2UI5's "Network error:
  Failed to fetch". Nothing was switched, and there was no dump; the repeat
  went through. Not reproduced.
- The status app still has no test include. Its new code is view wiring and
  one service call each.
- Deployment: abapgit-agent flagged the service class and the interface with
  `SYSTEM_EDIT` too (after the ADT writes, and its own import). All sources
  went over ADT; `get_status` showed only `.abapgit.xml` differing.

## Slice 9: status lists all files (2026-10-01)

See `docs/superpowers/specs/2026-10-01-all-files-design.md`. A bounded
slice, one row per file; a per-object view with a switch comes later.

- ABAP Unit: service 93/93 (`status_rows` replaces `filter_status`;
  `change_highlight`), diff app 9/9, stage app 12/12.
- Browser: `$UMLAUT` shows 4 files, one marked; "Changes only" shows that
  one, "All files" the 4 again, without a new fetch. `$ABAPGIT2UI5` shows
  21 files.
- While checking, `ZCL_TEST_UMLAUT` showed as "changed in Git only" after
  Chris's partial push. That is correct: both comments were removed in the
  system afterwards, and Git still has the pushed one. The checksums of a
  partial push are as in abapGit (the pushed content's SHA1).

## Diff colours (2026-10-01)

A small change, approved in chat: the code cell of an added line gets a light
green background (`#e6ffec`), a removed one light red (`#ffebe9`), a folded
gap light grey (`#f6f8fa`), in both views. `tinted_html` wraps the code in a
block `<span>` with that style.

- Checked first in the browser: UI5 1.153's `sap.m.FormattedText` keeps the
  `background-color` style.
- ABAP Unit: service 95/95, diff app 9/9, stage app 12/12.
- Browser: the diff of `zcl_ag2ui5_app_diff.clas.abap` in `$ABAPGIT2UI5`
  shows 18 green, 4 red and 3 grey lines, inline and side by side.
- Only the code cell is coloured; the row keeps its highlight bar. The colours
  are fixed and suit light themes.

## Status sorting (2026-10-01)

A small change, approved in chat: "Sort by" Object (type, name, file; the
default), File (path, file) or Type (type, name), case ignored, and a
"Changes on top" toggle (on by default). It sorts on the server
(`sort_status_rows`), so the growing table loads its rows in order.

- ABAP Unit: service 99/99, diff app 9/9, stage app 12/12.
- The render gate caught a missing `xmlns:core` for the Select's items
  before deployment.
- Browser on `$ABAPGIT2UI5` (21 files): the 4 changed files first, then
  the rest by object; with the toggle off they are mixed in; by file,
  `.abapgit.xml` and `package.devc.xml` come first.

## Slice 10: create a branch (2026-10-02)

See `docs/superpowers/specs/2026-10-01-create-branch-design.md`. In the
"Switch branch" dialog, without credential fields: abapGit's exit supplies
them.

- ABAP Unit: service 106/106 (7 new: normalizing, Git's ref rules, an
  existing name; a name that differs only in case counts as new), diff app
  9/9, stage app 12/12.
- Smoke test on `$UMLAUT`, creating nothing: `main` ("already exists"),
  `a..b` (the rule message) and an empty name are refused.
- Browser: "New branch..." is the last entry; picking it shows "Starts from:
  refs/heads/test at 3522d6f" and the name, the button reads "Create";
  picking a branch again turns it back. `main` and `a..b` give a message
  box, the dialog stays open and keeps the name.
- abaplint allows only 7-bit ASCII, so the entry reads "New branch...".
  `popup_model_update( )` is not needed: abap2UI5 sends a changed model by
  itself (abap2ui5lint `obsolete-model-update`).
- The SAP session expired overnight; Chris logged in again.
- **Real creation (with Chris's OK, 2026-10-02):** on `$UMLAUT`, which
  followed `test` at `3522d6f`:
  - `test/create-branch` was refused by GitHub: "cannot lock ref …
    'refs/heads/test' exists". A ref cannot be a branch and a folder at the
    same time. The message box showed it; nothing was switched.
  - `create-branch-test` was created: the toast "Created and following
    create-branch-test", the header, GitHub at `3522d6f`, and a fresh session
    lists it as current (so the COMMIT works).
  - Afterwards `$UMLAUT` was switched back to `test`. The branch
    `create-branch-test` is still on GitHub.
- Review (a fresh reviewer): no critical findings.
  - The authorization check now runs at the top of `create_branch`, not only
    inside `list_branches` (the spec's step 1).
  - Not changed: after abapGit's "checkout PR" (a switched origin), the
    branch is created on the fork, and switching the origin back forgets it.
    abapGit's own `create_branch` does the same.
  - Open, minor:
    - Git's rules for path components (`a/.b`, `a.lock/b`), `@{`, `@` and
      `HEAD` are not checked; the remote refuses most of them.
    - A name with non-ASCII characters gives a cryptic Git protocol error
      (abapGit's `pkt_string` counts characters, not bytes).
    - A name that collides with an existing branch as a folder (`test` and
      `test/x`) could be refused before the push.
    - `REFS/HEADS/x` counts as a full name (`CP` ignores case).
    - "Starts from" comes from the last status load.
    - If the ref is created but following it fails, the message does not
      name the branch.
    - The name field has no `labelFor`, and Enter does not create.

## Search field focus (2026-10-02)

A small change, approved in chat: the repository list puts the focus into
the search field when it is shown, at the start and on the way back from a
repository (`follow_up_action( cs_event-set_focus )`, the cursor behind the
text). Checked in the browser both ways.

## Slice 11: delete a branch (2026-10-02)

See `docs/superpowers/specs/2026-10-02-delete-branch-design.md`. The header
button and the dialog are now called "Branches".

- ABAP Unit: service 111/111 (5 new: the branch's commit, `assert_deletable`
  refuses the default, the current and an unknown branch), diff app 9/9,
  stage app 12/12.
- Smoke test on `$UMLAUT`, deleting nothing: `main` (default, and current
  at the time) and a branch that does not exist are refused.
- Browser on `$UMLAUT`:
  - "Delete" is hidden for `main` and for the current branch, shown for
    `Test`, `test` and `feature/test1234` (not deleted).
  - `delete-me` was created, the repository switched back to `main`.
  - Delete, then Cancel in the confirmation ("Delete branch delete-me (at
    463690e) on GitHub? abapGit cannot undo this."): nothing sent, the
    branch still on GitHub.
  - Delete, then DELETE: the toast "Deleted delete-me (was at 463690e)", the
    list without it, `main` picked again. On GitHub `delete-me` is gone and
    the other four branches are unchanged.
- The footer has three buttons, so the dialog uses the `buttons` aggregation
  instead of `beginButton`/`endButton`.
- Chris tested deleting himself and deleted some branches of `$UMLAUT`
  (2026-10-02).
- Review (a fresh reviewer): one important finding, fixed with a test that
  failed first. The spec said the commit the browser saw is never used, so a
  branch that somebody pushed to after the confirmation was deleted at the
  newer commit. Now the confirmed commit is passed and must equal the fresh
  one, as abapGit sends the listed commit. A forged value can only make the
  delete fail. On `$UMLAUT`: `moved-test` created, a wrong commit refused
  ("has moved to … - nothing was deleted"), the right one deleted.
  ABAP Unit: service 113/113.
- Open, minor: the success toast cuts the commit without a length guard; a
  refused delete does not reload the list, and "not on the remote" shows the
  full `refs/heads/` name; `BRANCH_DELETE` does not recompute the button
  state on the server (the service refuses anyway); no app tests for the
  confirmation (the status app has no test include).

## Repository URLs as links (2026-10-02)

A small change, approved in chat: the URL in the repository list and in the
status header is an `sap.m.Link` (`href`, `target = _blank`). A click on the
link in the list does not open the repository. Checked in the browser: 22
links in the list, the header link of `$UMLAUT`. The URL comes from abapGit's
repository settings; UI5 checks every `href` against its URL allowlist.

## Status row colours (2026-10-02)

A small change, approved in chat: a changed status row gets a light
background in the colour of its bar (orange `#fff4e5` system, blue `#e8f1ff`
Git only, red `#ffebe9` both). A row's class cannot be bound, so each row
writes its highlight as `data-change` (`CustomData`, `writeToDom`), and a
`<style>` block in the view (`core:HTML`, braces escaped as the linter asks)
colours the cells. Checked in the browser on `$ABAPGIT2UI5`: 21 rows, the
blue and the red one coloured, 19 transparent.

## Changed rows yellow (2026-10-02)

Chris asked for one colour for every change. `change_highlight` now returns
`Indication03` for any change or an inactive object (its test was adapted
first and failed), and the style block colours such a row light yellow
(`#fff8d6`). Horizon has no yellow highlight colour (`Indication03` is
`#b95100`, a dark orange; the indication colours read from the browser), so
the same style block colours the bar `#e9c000`, through UI5's
`sapMLIBHighlight` class. That depends on UI5's DOM: if a later version
renames the class, the bar falls back to `#b95100`. Checked in the browser on
`$ABAPGIT2UI5`: 4 changed rows with yellow bar and background, 17 white.

## Side by side like abapGit (2026-10-02)

- Side by side now keeps the system left and Git right in both directions,
  as abapGit's split view does (LOCAL left, REMOTE right). Before, old was
  left and new right, so the columns swapped between pull and push. The
  colours and markers still follow the direction: the new side is green (+),
  the old side red (-), and the titles say which is which ("System (new)" /
  "Git (old)" on a push). The diff app maps `to_side_by_side`'s old/new
  columns to system/Git; the service is unchanged.
- ABAP Unit: diff app 11/11 (two new tests, one per direction, failed first).

## Repository tiles (2026-10-03)

- A List/Tiles toggle next to the search. Tiles are `sap.f.Card`s in a
  `sap.f.GridContainer` (20rem columns): name and package in the header,
  cloud or disconnected icon for online and offline, then the URL (a link,
  cut off with an ellipsis, full URL in the tooltip), branch and last pull.
  A click on the header opens the repository like a table row.
- Both layouts bind `mt_repos`, so the search filters both. The toggle only
  switches `visible` on the client (expression binding on `mv_layout`); the
  choice stays for the session, also on the way back from the status page,
  but not across logins.
- Checked: `npm run check` with the render gate (UI5 1.71), headless
  screenshots of both layouts, and in the browser on A4H25 (toggle, search
  in tile mode, opening a card, back, list again, no console errors). No
  ABAP Unit test: the change is view and binding only.

## User settings (2026-10-03)

See `docs/superpowers/specs/2026-10-03-user-settings-design.md`.

- Table `ZAG2UI5_SETTING` (user, key, value), `ZIF_AG2UI5_SETTINGS` and
  `ZCL_AG2UI5_SETTINGS`: an allow-list per key, the default for a missing or
  outdated value, `set( )` commits. The three apps read their toggles when
  they start or are created and save them in the toggle's event; in patch
  mode the diff stays inline and stores no layout.
- ABAP Unit on A4H25: settings 9/9, repository list 3/3 (new include),
  status 3/3 (new include), diff 16/16, stage 12/12, service 113/113. Every
  new test failed first on the system (pull with a stub class).
- Deployment: one abapgit-agent pull of the feature branch, 0 conflicts this
  time; then ADT writes. The table was created over ADT and serialized with
  abapGit into `zag2ui5_setting.tabl.xml`; abaplint now allows TABL.
- Found on the way: on the kernel a `PARTIALLY IMPLEMENTED` client double
  raises for `_bind`/`_event`, so the doubles implement both.
- Browser on A4H25 (screen locked, driven through UI5): tiles survive a
  reload; the status toggles carry over to another repository; the diff
  comes back side by side with "Show all"; no console errors. Patch mode is
  covered by the unit test only. The test rows were deleted afterwards (the
  table was empty before).
- Tiles are the default for the repository list (Chris, 2026-10-03); the
  list is one click away and remembered once chosen.

## Header on narrow screens (2026-10-03)

On a narrow screen (already at about 860px) the status page lost its back
button and title: `sap.m.Page` puts `headerContent` into a bar that has no
overflow, so the controls pushed the left side out.

- Status, diff and stage now use an `OverflowToolbar` as `customHeader`: a
  back button and a shrinkable `Title`, both `NeverOverflow`, then the
  controls. Pull (status) and Apply (diff, patch mode) are `NeverOverflow`
  too; everything else moves into the "⋯" menu. Refresh is an
  `OverflowToolbarButton`: icon in the bar, text in the menu.
- Priority `High` did not work here: Pull with `High` was the **first**
  control in the menu while the title shrank. `NeverOverflow` behaves.
- Builder trap: `tag( )` stays on the parent, so `tag( `Button` )->...->ele(
  `layoutData` )` gives the **toolbar** the layout data. A control that gets
  `layoutData` must be opened with `ele( )`. A first test missed it because
  its regex matched across the button's `/>`; the tests now require an
  element that is not self-closing.
- ABAP Unit on A4H25: status 4/4, diff 18/18, stage 13/13 (one header test
  each, diff also Apply), service 113/113, settings 9/9, repository list
  3/3.
- Browser on A4H25 (body narrowed to 390px, the window could not be
  resized): status and diff keep back, title and the main action; Back
  works; the menu shows the rest. The stage page is covered by its unit
  test only.

## New repository (2026-10-03)

See `docs/superpowers/specs/2026-10-03-new-repository-design.md` and the
plan next to it. Slice 1 of 2; slice 2 is offline support (open, import a
ZIP through the pull dialog, export a ZIP).

- "New repository" on the list opens `ZCL_AG2UI5_APP_NEW_REPO`: online
  (URL, branch, display name) or offline (name), package, and a collapsed
  "More settings" panel (folder logic, labels, ignore subpackages, main
  language only, ABAP language version) with abapGit's defaults.
- `create_repo` normalizes the form (`normalize_new_repo`), collects the
  form's own errors (`new_repo_errors`), then abapGit's: `validate_url`, the
  provider check, the branch list (connection, empty remote, branch),
  `validate_package`, the self-update guard, the labels. Only then
  `new_online` / `new_offline`, the favorite and `COMMIT WORK AND WAIT`. A
  new online repository whose package is missing and whose remote has no
  package file is deleted again.
- Decided while planning: the display name only online (`new_offline` has
  none); no separate connection check (the branch list connects); offline
  needs an existing package; the list's header is an overflow toolbar too.
- Found on the system:
  - abapGit refuses a URL that another repository already uses
    (`validate_url`), so `abapGit-tests/DTEL` (repository 026) could not be
    used; `abapGit-tests/DOMA` was.
  - A toast sent in the same round trip as `nav_app_leave` never shows (a
    hook on `MessageToast.show` saw nothing). The page hands the message
    over with `r_data`; the list shows it.
  - `COND #( WHEN condense( x ) IS NOT INITIAL ...)` does not compile on the
    kernel (abaplint accepts it).
- ABAP Unit on A4H25: service 124/124, settings 9/9, stage 13/13, diff
  18/18, status 4/4, repository list 5/5, new repository 8/8. Every new test
  failed first.
- Browser on A4H25 (screen locked, driven through UI5):
  - online `abapGit-tests/DOMA` into the new package `$ag2ui5_new1` (typed in
    lower case): status page of `$AG2UI5_NEW1`, Back to the list, pull
    created the package and the domain;
  - refused on their fields: a used package, `$TMP`, an unknown branch, an
    untrusted certificate (example.com), an offline package in use;
  - `octocat/Hello-World` into a missing package: message strip, no
    repository left behind;
  - offline into `$TEST_OFFLINE`: back to the list with the toast, a greyed
    tile; the toast is not repeated on later returns;
  - 390px: the form keeps Back, title and Create; the list keeps its title
    and both buttons.
- Final review (fresh reviewer): offline creation skipped abapGit's
  checksum rebuild and its delete-on-failure; fixed, both kinds now follow
  abapGit's services (not reproduced first: that needs a package whose
  subpackages break the prefix rule). Minor points left open:
  - a package name longer than 30 characters is cut instead of refused
    (only a crafted request; the field has maxLength 30);
  - the two checkboxes are not normalized to `X` / space;
  - the list converts the handed-over value without checking its type;
  - the branch error shows the full ref;
  - a comment in `normalize_new_repo` says condense "takes" inner blanks;
  - without the create authorization the URL is still checked over the
    network.

## Offline repositories (2026-10-03)

- Both repository list layouts open offline repositories. The status header
  offers Import ZIP and Export ZIP; branches and staging stay online-only.
- Uploads remain binary. The status app keeps the original ZIP in protected
  state and supplies it to status, diff, preview and pull on every request.
  The service restores offline remote files each time, including after an
  export cleared the session cache. Back clears the ZIP; canceling the
  decisions keeps the comparison and clears the dialog's data.
- Import reuses the existing pull checks and decisions, acknowledgment,
  transport selection and self-update guard. Empty/malformed archives,
  missing or invalid root .abapgit.xml, ambiguous paths and duplicate files
  are refused. The original online-only guard remains for Git operations.
- Native tests exposed two issues fixed before completion:
  - abapGit's ZIP loader raises ITAB_DUPLICATE_KEY for filenames duplicated
    after lower-casing. Raw directory entries are now checked before loading.
  - invalid metadata can raise CX_XSLT_RUNTIME_ERROR outside abapGit's
    declared exception; it is now reported as a normal validation error.
- `npm run check`: no errors or warnings, one existing MessageStrip hint;
  eight view documents passed the render gate.
- ABAP Unit on A4H25: service 134/134, status 19/19, repos 6/6, diff 18/18,
  stage 13/13, settings 9/9, new repository 8/8 (207 total).
- All changes activated over ADT using existing classes and test includes;
  all eight changed source files were read back and matched the working tree.
- Browser: opened $TEST_OFFLINE from both its tile and table row; offline controls and ZIP
  column displayed, branches/stage absent; upload dialog opened and canceled;
  Export ZIP in the toolbar overflow downloaded repository.zip. The browser
  automation download event timed out, but the actual 642-byte file existed
  and its two entries and CRCs were verified locally.
- Service smoke test on $TEST_OFFLINE (key 29): exported two files, loaded
  them into status, preview NOTHING. No-ZIP preview and supplying a ZIP to
  an online repository both refused.
- Native import: ZIP containing the original two files plus the new
  ZIF_AG2UI5_OFFLINE_E2E interface previewed exactly one Import decision.
  Pull activated it; its freshly exported ZIP previewed NOTHING. Cleanup
  selected only that newly created interface's Delete decision and pulled
  the original ZIP. The restored fixture previewed NOTHING; no test object
  was retained. The repository's last-pull timestamp moved as expected.
- Final dump check: only three historical dumps dated September 30 to
  October 2, none from the completed offline smoke tests.
- Browser file selection/upload was verified in the follow-up below;
  phone-width layout and large ZIPs were not exercised. Binary decoding, preview/pull handoff, invalid-upload retry,
  cancellation and ZIP download arguments are covered by native app tests.

### File picker follow-up (2026-10-03)

- Reproduced: selecting a file updated the native input but left the visible
  filename unchanged and Upload disabled. The abap2UI5 FileUploader rendered
  an unowned HBox without a DOM root for the wrapper. Inner controls could not
  propagate invalidation through the wrapper's control tree.
- Framework fix is isolated in `/tmp/abap2ui5-file-uploader`, branch
  `fix/file-uploader-rendering`: a hidden HBox aggregation and a wrapper DOM
  root. The main abap2UI5 checkout is unchanged. Fifteen focused uploader tests
  and `npm run verify:full` passed, including generated-code drift and frontend
  checks. No app-code change was needed.
- Activated only Z2UI5_CL_UI5F_UPLOADER_JS and the regenerated
  Z2UI5_CL_UI5F_PRELOAD on A4H25. The deployment hash was generated separately
  in `/tmp/abap2ui5-picker-deploy` from sources preserving the installed
  Server/AppState round-trip timing additions. All other installed frontend
  classes were backed up and compared; none needed deployment.
- Chrome/SAP: selecting a ZIP shows its filename and enables Upload. An
  invalid file reaches server validation, and retrying with the current
  1,332-byte, four-file export gives matching status. A comparison-only ZIP
  changing one class comment opens exactly one overwrite decision for
  ZCL_TEST_OFFLINE; canceled without pulling. The user's class is unchanged.
- abapGit refuses import preview in German when the repository's main
  language is English. Retested successfully with `sap-language=EN`.
  File-URL access was required only for the browser automation's local test
  uploads; it did not fix the uploader rendering defect.

## Object links to ADT (2026-10-04)

See [the design](superpowers/specs/2026-10-04-object-links-design.md) and
[implementation plan](superpowers/plans/2026-10-04-object-links.md).

- Object names link to the local object in status, staging and pull
  decisions; the diff page has an Object attribute with the same link,
  including patch mode. Missing or unresolved objects use normal text.
- The service checks local existence and uses SAP's Workbench object/ADT
  URI mapper. Its authorized calls return plain link strings and cache each
  distinct object, including unsuccessful lookups, within the call. Pure
  mapping and decision helpers remain unchanged. Diff navigation carries
  the already resolved link.
- Native mapper probe: all 13 representative types returned a URI: CLAS,
  INTF, PROG, TABL, DOMA, DTEL, DEVC, TRAN, FUGR, DDLS, MSAG, SHLP, ENHO.
  TRAN and SHLP returned legacy Workbench navigation URIs; opening their
  editors through ADT is not verified.
- ABAP Unit on A4H25: service 138/138, status 20/20, stage 14/14,
  diff 19/19 (191 affected-suite tests). New tests cover existing/missing
  objects, invalid keys, cache keys, navigation handoff and diff placement.
- Service smoke tests: `$UMLAUT` returned 3 linked files of 5 in 542 ms;
  `$ABAPGIT` returned 1,389 linked files of 1,404 in 8,161 ms. Repository
  metadata files have no object link. This repository's staging returned
  9 candidates with 9 links. Offline export/status and a comparison-only
  ZIP edit returned links to `ZCL_TEST_OFFLINE`; its preview had exactly
  one decision. Nothing was imported, committed or pushed by these tests.
- Local lint/render gate passed with no errors or warnings and the existing
  MessageStrip hint. A headless screenshot with an existing and remote-only
  object exposed the faint disabled-link styling; fallback now uses Text.
- Existing objects and test includes were backed up under
  `/tmp/ag2ui5-object-links-backup` and activated through ADT. All nine
  deployed source files matched the working tree on readback; the three
  app suites passed again after the final normal-text fallback change.
- Browser follow-up after Chris signed in: status links on
  `$ABAP-OPENAPI-UI` carry the expected ADT URIs, including legacy object
  types. Clicking the object leaves status in place; clicking its file
  opens the diff. The real browser found that ObjectAttribute accepts only
  Link/Text in customContent: the fallback HBox hid the diff's Object
  attribute. Fixed with a direct Link or the attribute's text; the diff
  link now appears and its native regression test passes.
- External-protocol clicks detach browser automation while leaving the
  page intact. Eclipse is registered as the ADT handler, but the final
  editor opening cannot be confirmed through this browser session.

## Object overview (2026-10-04)

See [the design](superpowers/specs/2026-10-04-object-overview-design.md) and
[implementation plan](superpowers/plans/2026-10-04-object-overview.md).

- Status now has independent Files / Objects and All / Changes only
  switches. Files remains the default; `STATUS_OVERVIEW` is allow-listed
  and remembered per SAP user. File sorting stays available in Files.
- A pure service helper groups complete object type/name keys, counts all
  files before filtering, combines nonempty states (differing states become
  mixed), and retains inactive/changed flags and ADT links. Incomplete keys
  share Repository files. No extra abapGit fetch is needed.
- Object rows open a full-path file dialog, including unchanged files.
  Files open the existing diff with their own direction and ADT link;
  returning reopens the dialog. Close clears its bound data. Offline
  browsing works without a ZIP, while file diff remains disabled.
- Native ABAP Unit on A4H25: service 144/144, settings 10/10, status
  28/28, diff 19/19, stage 14/14, repositories 6/6, new repository 8/8:
  **229/229 passed**. New tests cover grouping, counts, mixed/inactive
  states, incomplete keys, ordering, settings, filtering, duplicate
  filenames in different paths, navigation, closing and offline guards.
- Local lint/render gate passes with no errors or warnings and only the
  existing MessageStrip hint. Existing SAP objects were backed up under
  `/tmp/ag2ui5-object-overview-backup`; all eight deployed sources/test
  includes match the working tree on readback.
- Chrome/SAP confirmed Files / Objects, changed/total counts, changes-only
  filtering, all three files of ZCL_AG2UI5_APP_STATUS (two changed), correct
  diff direction/link, Back reopening the file dialog, Close, and metadata
  drilldown. Opening an offline repository retained the saved Objects
  preference and allowed its files to be browsed without enabling diff.
  The compact browser viewport exposed a cramped filename
  column; the file dialog now gives filenames 55% of its width.

## Staging ignore rules (2026-10-04)

See [the design](superpowers/specs/2026-10-04-stage-ignore-design.md) and
[implementation plan](superpowers/plans/2026-10-04-stage-ignore.md).

- Staging and fresh push validation now use abapGit's native ignore matcher,
  including starting-folder exclusions and ordered negation rules. Root
  `.abapgit.xml` cannot be removed. The matcher lives only in the service;
  app state contains plain data.
- Per-file Ignore opens an exact path that can be edited into a pattern.
  Preview lists affected staging files before Save. Ignore rules lists
  existing rules and previews their removal. Saving persists the local
  `.abapgit.xml` configuration and commits the SAP persistence, so the rule
  change can be staged/shared normally; it never pushes or deletes the
  ignored remote file. Saving reloads selections and patches while retaining
  commit text and committer details. Online staging stays reachable without
  local changes so rule management remains available.
- Every save recomputes the preview against fresh rules and files. A stale
  or forged preview is refused before writing. Removal uses an unregistered
  repository copy to serialize files hidden by the old rule; previewing
  never calls a settings setter or persists the simulated configuration.
- abapGit does not read conventional `.gitignore` files. This slice uses its
  `.abapgit.xml` rules instead, including `*`/`+` syntax, to keep behavior
  consistent between clients. Conventional Git pattern interpretation is
  still outside this slice.
- ABAP Unit on A4H25: service 153/153, staging 23/23, status 29/29,
  settings 10/10, diff 19/19, repositories 6/6, new repository 8/8:
  **248/248 passed**. New coverage includes exclusions, negations, namespace
  escapes, metadata protection, invalid/duplicate/missing rules, affected
  files, stale previews, cancellation, removal, committer preservation and
  token clearing on every new event.
- Lint/render passes with no errors or warnings and only the existing
  MessageStrip hint. Seven deployed sources/test includes match the working
  tree on readback. Backups are under `/tmp/ag2ui5-stage-ignore-backup`.
- Reversible `$UMLAUT` smoke test: one temporary source comment supplied a
  staging candidate. A forged preview was refused, saving its exact ignore
  hid the source and made `.abapgit.xml` a candidate, removal preview listed
  the returning source, and removal restored it. No fixture remote push.
- Chrome/SAP confirmed clean-repository Stage access, Ignore, preview/Save,
  configuration staging, rule listing/removal, returning-file preview, and
  pattern editing. Live testing exposed an Input change event consuming the
  first Preview click; valueLiveUpdate and root-bound expressions now hide
  stale results and disable Save immediately without that extra round trip.
  A new unit test also caught reload overwriting an entered email; each
  committer field is now defaulted independently. The final compact-viewport
  dialog renders correctly. All temporary fixture changes were restored.

## Create package from New repository (2026-10-05)

- The package field now has **Create package...**. Its dialog prepopulates
  the entered name and local/transportable defaults. Cancel retains the form;
  success fills the normalized package name, clears its old error and retains
  every other repository field. Errors retain dialog inputs and clear on retry.
- The service returns plain data, rejects oversized fields before SAP type
  conversion, checks startup/create authorization, refuses existing packages,
  checks the parent/component/hierarchy and self-update protection, and checks
  the selected transport against a fresh workbench request list. SAP enforces
  package naming, components, layers and development authorizations.
- abapGit's package create API leaves dialog suppression unset. We use SAP
  factory/create and save directly inside the service, with suppression on both
  and the checked transport passed explicitly. Success commits; a failed save
  discards the new package in memory and rolls back.
- Native SAP smoke tests created `$AG2UI5_CPKG_TEST` and
  `ZAG2UI5_CPKG_TEST` (request `A4HK900148`). A separate request confirmed their
  TDEVC persistence, correct LOCAL/HOME component and change recording.
  Duplicate creation and forged transport were refused. The new local package
  worked with both online (`abapGit-tests/CLAS`) and offline repository
  registration. Temporary registrations and both empty packages were removed.
  No objects were imported and no fixture remote was changed.
- **260/260 native tests passed:** service 161, settings 10, stage 23, diff 19,
  status 29, repository list 6, new repository 12. Lint/render checks pass with
  the existing status MessageStrip hint. Desktop (1280x900) and phone (390x844)
  screenshots of the form and dialog were inspected using the UI5 renderer.
- Sources deployed via ADT; all five production/test source readbacks match
  the local files byte for byte.
- Live Chrome/SAP verified Cancel and form preservation, required-description
  retry, duplicate rejection, and the missing-workbench-request error. Local
  and transportable creation passed using request `A4HK900148`; online
  registration opened the status page with the original display name, and
  offline registration returned to the repository list. Both temporary
  registrations and empty packages were removed and their absence checked.
  Cloud defaults are covered by tests; actual cloud package creation and
  authorization-denial paths were not exercised on A4H25.

## Remove and uninstall repositories (2026-10-05)

- Both layouts offer Remove and Uninstall, online and offline. Remove explains
  that SAP objects remain. Uninstall lists the object/type/package scope, warns
  about table data and irreversible deletion, requires the exact package name,
  and starts a required workbench transport unselected.
- Only the service calls non-UI `delete` / `purge`. It reloads persisted metadata
  and compares a fresh preview before deleting. Malformed/overlong keys, changed
  identity or scope, missing confirmation and forged transports are refused.
  Uninstall checks authorization, write protection and language; its hierarchy
  guard protects running code. Fresh persistence prevents deleting another
  registered repository in the scanned scope.
- Partial failures return abapGit's log and retain registration. The dialog
  blocks repeat submission after failure and asks for a new preview. Deletions
  commit individually inside abapGit; success commits registration removal.
  No remote Git mutation is performed.
- **277/277 native tests passed:** service 171, settings 10, stage 23, diff 19,
  status 29, repository list 13, new repository 12. Lint/render checks pass with
  no errors or warnings and the existing status MessageStrip hint. All five
  deployed production/test source readbacks match local files.
- Chrome verified both layouts, online/offline previews, Remove cancellation and
  success, required-name and missing-transport errors, and selection of test
  request `A4HK900148`. Adding a program after opening an online preview produced
  the changed-scope error; native verification confirmed all objects remained.
  Completed Uninstall deletions were exercised through the native service,
  then the browser list was refreshed to verify registrations disappeared.
- Disposable fixtures: Remove retained `ZAG2UI5_REMOVE_TEST` and its package.
  Native Uninstall deleted local and transportable programs and registrations;
  running-code uninstall, missing confirmation, altered preview and forged
  request were refused. Final online Uninstall cleaned the retained Remove
  fixture and concurrent-change program. No test programs or registrations
  remain. `$AG2UI5_REMOVE_TEST` and `$AG2UI5_UNINST_TEST` were deleted. The empty
  `ZAG2UI5_UNINST_TEST` package remains until transport release: SAP's normal
  package factory also refused deletion. The test request was not released.
- The original Tiles setting and `offline` filter were restored. Screenshot
  `/tmp/ag2ui5-uninstall-preview.png` shows the final dialog on the existing
  offline fixture; that preview was canceled and its objects retained.
  Native authorization denial, cloud execution and a real partial deletion
  failure were not exercised; partial-failure UI behavior is unit-tested.
  A setup snippet initially omitted folder logic and raised an uncaught harness
  exception; setup was corrected to `PREFIX` and resumed after checking identity.

## Pull popup Mark all / Unmark all (2026-10-05)

- Added both actions above the decision groups. Mark all selects enabled rows
  in Data loss, Delete, Overwrite, Package and Import; disabled and unsupported
  rows remain unchecked. Unmark all clears every group. Fresh server-side
  decision validation is unchanged.
- Five new status tests cover all groups, disabled/unsupported rows, empty
  decisions, rendered controls and preservation of transports, acknowledgment
  and offline ZIP data. Neither action starts a pull or closes the popup.
  Native status tests pass 34/34. Lint/render checks pass with no errors or
  warnings and the existing MessageStrip hint.
- Deployed production and test source readbacks match the local files exactly.
  Chrome verified Mark all, Unmark all and Mark all again on the INTF fixture's
  Data loss row, then Cancel. No pull ran; fixture objects and data were retained.
  Other groups and unrelated state are covered by the native tests.
- Screenshot: `/tmp/ag2ui5-pull-mark-all.png`. Testing used a separate Chrome
  tab and left the user's active SAP tab untouched.

## Open points (as of 2026-10-05)

End-of-day handoff: pull Mark all / Unmark all is committed and pushed as
`ff4228a`, deployed on A4H25 and confirmed working by Chris. The status suite
passed 34/34; the latest results across unchanged suites total 282/282.
Lint/render and Chrome toggle/cancel checks passed. No pull was performed
during this verification. No implementation work is pending; choose the next
slice with Chris when resuming.

Done since 2026-10-01: patch (single lines), switch, create and delete
branches, all files on the status page (sorted, changes on top, yellow),
diff colours, search field focus, URLs as links, object links to ADT,
Files / Objects overview, native staging ignore rules and package creation
from New repository, repository Remove / Uninstall and pull Mark all / Unmark all.

Session handoff (2026-10-04): `main` contains object links (`51fcf82`), object
overview (`12b4a37`) and staging ignore rules (`8125509`), all pushed and
deployed through ADT on A4H25. Latest verification: 248/248 SAP unit tests,
lint/render checks and browser workflows passed; temporary `$UMLAUT`
changes were restored. Final editor opening in Eclipse remains unverified.
The 2026-10-05 package-creation slice is deployed, with 260/260 native tests.
Its live Chrome workflows passed, and all SAP smoke fixtures were removed.
Remove / Uninstall is deployed with 277/277 native tests and Chrome checks.
The empty transportable lifecycle test package awaits release of `A4HK900148`;
its programs and registration are gone. Do not release that request as cleanup.
Pushing to another branch has not been started.

Next slices:

Potential distinguishing features are collected in
[Feature ideas](feature-ideas.md): named change sets, semantic ABAP diff,
pull impact preview, recovery checkpoints and a repository cockpit. These
are candidates for discussion, not committed slices.

1. **Creating a transport request** from the pull dialog. Today the user is
   pointed to SE09.
2. **Conventional `.gitignore` interpretation**, if desired beyond abapGit's
   native `.abapgit.xml` rules.

Upstream work (abapGit, abap2UI5, abapgit-agent): see
`docs/upstream-notes.md`, which has the agreed order. The abapGit form-feed
fix in PR #7922 was merged on 2026-10-02, as recorded there.

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
  - The status and staging pages read private repositories without
    credentials, so they work there only through the abapGit user exit.
- Per slice, the minor points of the reviews are listed in their sections
  above (patch, branches, delete).


## Structural method review (2026-10-06)

See [the design](superpowers/specs/2026-10-06-semantic-diff-design.md) and
[implementation plan](superpowers/plans/2026-10-06-semantic-diff.md).

- Classes/interfaces expose method declaration and implementation summaries
  in the object file dialog and file diff, with added/removed/changed actions
  in the file's existing comparison direction. Declaration comparison covers
  parameters, static/instance status, visibility and other signature tokens.
  Each link opens the corresponding method range on both sides; Show complete
  diff restores the file. Layout and changes-only preferences are preserved.
- SAP's scanner supplies tokens and source locations, without include loading
  or TRMAC expansion. A native temporary probe confirmed chained declarations
  are separate statements with prefix tokens and correct line numbers. STOKESX
  stores token strings without a fixed-length truncation. Token comparison
  excludes comments/formatting; those changes stay in the raw diff. Local
  owners/test methods are included. Renames are separate removal/addition.
  Incomplete scopes fall back to raw review; XML metadata and unsupported
  object types retain their existing raw diff.
- Summary loading is on demand when an object is opened. Existing get_diff
  restores offline ZIP data and returns plain summaries; no new abapGit object
  references are kept by apps. Failed source loading retains the file list and
  explains how to retry. Diff ranges and navigation identity come from protected
  data; forged public summary entries cannot supply a source range. Patch mode
  stays on the full file and omits summary filtering.
- Added 17 native tests: service 9, diff app 6, status app 2. These cover chained
  and multiline declarations, types, visibility/static changes, implementations,
  additions/removals, direction/ranges, local owners, literals, formatting,
  comments, incomplete scopes, macros, range filtering on both/one side, forged
  events, restoring the file, patch preservation, ZIP forwarding and load errors.
  **Native affected suites passed 241/241:** service 180/180, diff app 25/25,
  status app 36/36. Combined with the unchanged suites' previously recorded
  results, the latest suite results total 299/299.
- Local npm check passes: ABAP lint and all 13 UI5 render documents, no errors
  or warnings and the existing MessageStrip hint. Desktop 1280x900 and phone
  390x844 scratch renders use the actual view builders with illustrative data
  and only the applicable conditional branches. Visual review caught truncated
  summary labels on phones; entries now wrap and the source-range label sits
  above its restore button. Both layouts were inspected. Preview files and
  models are under /tmp/ag2ui5-semantic-*, rather than committed screenshots.
- Deployment to A4H25 was explicitly approved by Chris after automatic
  approval review initially refused activation without deployment permission.
  All seven existing interface/production/test sources activated through ADT,
  with no errors. Backups: /tmp/ag2ui5-semantic-backup. All seven source
  readbacks match the local files after newline normalization; readbacks:
  /tmp/ag2ui5-semantic-readback. Latest SAP short dumps predate this slice.
- Live Chrome/SAP verified on $ABAPGIT2UI5's deployed changes: object summaries,
  added/changed declarations and implementations, navigation into FOCUS_CHANGE
  and the changed CREATE declaration, both layouts, full-range/changes-only
  toggles, Show complete diff, Back reopening the dialog, growing the list from
  20 to 24 summaries, local test-class SETUP navigation, and Close. A selected
  implementation showed precisely its 12 source lines; restoring the complete
  file showed 158 diff rows. The original Files overview, side-by-side layout
  and changes-only preference were restored. No fixture object, registration,
  remote branch or commit was changed; no import/push ran.
- Live screenshot: /tmp/ag2ui5-semantic-live-declaration.jpg. A temporary Chrome
  viewport override changed the DOM size but its screenshot retained the
  desktop layout, so phone visual coverage is the inspected headless render.
  The override was reset. Browser checks used a separate agent-created tab.
  Chris accepted the slice and authorized its commit after verification.


## 2026-10-07 — short branch labels and remote links

- Repository rows, tiles and status headers bind separate short branch labels
  and remote links. Service refs and branch selection keys retain their full
  values. The new-branch starting-point text is shortened too.
- The branch dialog has an Open branch link for its selected existing branch;
  New branch mode and unsupported remotes hide it. All remote links open in a
  new tab. GitHub, GitLab.com and Bitbucket Cloud routes are supported;
  unknown hosts remain short labels without a link.
- Pure helpers strip only a leading `refs/heads/`, trim repository URL suffixes
  and URL-encode the branch as one path component. Five new native unit cases
  cover nested branches, reserved characters, provider routes, missing data,
  non-head refs, unknown hosts and misleading authorities.
- `npm run check` passed: ABAP lint 0 issues, UI5 property/render gates 13
  documents, 0 errors/warnings and the existing MessageStrip hint.
  `git diff --check` passed. Native ABAP Unit has not run and no SAP activation
  or deployment was performed for this slice.
- Inspected headless desktop 1280x900 and phone 390x844 screenshots for tiles,
  list, status and the branch dialog. Short labels and links are visible in
  each layout; the selector keeps its normal Switch/Cancel behavior. These
  illustrative renders retain the linter's known conditional-branch artifacts
  elsewhere in the status page. Screenshots/models: `/tmp/ag2ui5-branch-links*`.
- Concurrent push-new-branch edits were observed in shared service/interface
  files during the work and were preserved; this slice does not implement
  that separate feature.


### A4H25 activation — 2026-10-07

- Chris explicitly requested activation. Deployed the branch-link interface,
  service, existing service test include and repository/status apps via ADT.
  Activation completed with 0 errors; SAP reported documentation/type/regex
  warnings in the existing objects.
- Automatic approval review initially rejected activation because shared files
  might contain concurrent push-new-branch work. Complete snapshot-vs-HEAD
  diffs showed only the branch-link changes; the deployment service/interface
  contained no push_branch method or new_branch commit field. Review then
  accepted activation. No Git push or repository pull was needed.
- Native affected suites passed **235/235**: service **186/186**, repository
  app **13/13**, status app **36/36**; no failed or skipped test classes.
- All five source readbacks match the deployment snapshot after newline
  normalization. Backups `/tmp/ag2ui5-branch-links-backup`; deployed snapshot
  `/tmp/ag2ui5-branch-links-deploy`; readbacks `/tmp/ag2ui5-branch-links-readback`.
  The predeployment service test backup also retains four unrelated draft
  push_branch tests that were absent from local HEAD and the service source.

## Commit to a new branch (2026-10-07)

Spec `docs/superpowers/specs/2026-10-07-push-new-branch-design.md`, plan
`docs/superpowers/plans/2026-10-07-push-new-branch.md`.

- The Stage app's commit form has an optional **New branch** input. Its
  placeholder names the followed branch (bound: Git allows braces in names).
  The success toast names the branch pushed to; the input is cleared with the
  commit text.
- `commit_push` checks the name with `push_branch( )` (normalize, Git ref
  rules, not on a fresh branch list) before anything is written, runs the
  existing staging checks, and only then creates the branch at the head the
  selection was checked against (`iv_from`). Exit, push and commit follow in
  abapGit's order, so a push exit sees the new branch. Blank input keeps the
  old behavior.
- A failure after the branch was created commits abapGit's record of
  following it and says so in the message; nothing was pushed then.
- Only new branches, as in abapGit: pushing to another existing branch would
  need staging against that branch's tree.
- Built on `feature/branch-links` (`7c2a680`); display names use its
  `branch_display( )`.
- Final review fixes: after a failed push that already created the branch,
  the Stage app reads the followed branch again, updates the placeholder and
  clears the input when it names that branch, so a retry pushes there; the
  selection stays. Back after a successful push hands `PUSHED` to the status
  page, which reloads its header and files.
- Native suites 319/319 (service 190, stage 31, diff 25, settings 10,
  status 38, repositories 13, new repository 12). `npm run check` 0 errors.
  Source readbacks match Git. No new short dumps.
- Live on `$UMLAUT` (Chris's OK): New branch `feature/test1234` was refused
  ("already exists") with nothing written. Committing only
  `zcl_test_umlaut.clas.xml` with New branch `ag2ui5-push-test-20261007`
  showed "Pushed 408af62 to ag2ui5-push-test-20261007"; `git ls-remote` had
  the branch at `408af62` and `feature/test1234` unchanged at `a7730ef`. Back
  reloaded the status header (branch and remote commit). Then the app switched
  back to `feature/test1234` and deleted the throwaway branch (gone remotely).
  The class source is unchanged; staging still lists the same three files, the
  XML now also as remote-modified (abapGit recorded the pushed checksum).
- Seen live: entering the followed branch's own name is refused, and the
  input is then cleared (the follow-up read finds that branch followed), so a
  retry pushes to it. Harmless, but the field could keep the name instead.
- Deferred minors from the review: the wrapped push error drops
  `ix_previous` and can be cut at 200 characters; whitespace-only input still
  lists the remote branches; `placeholder_bound` checks the attribute, not
  the binding; AGENTS.md does not name `push_branch` yet;
  `assert_branch_name` misses `@{`, `a/.b` and `a.lock/b` (the remote refuses
  them).

## Branches popup as a list (2026-10-07)

- The Branches popup lists every branch of the remote instead of a dropdown:
  name with "(default)" / "(followed)" as the link to the branch on the
  remote (plain text where there is no link), commit, and per row
  **Switch** (not on the followed branch) and **Delete** (not on the default
  or the followed branch). The footer has **New branch** and **Close**; New
  branch shows the name field with its starting point and **Create** / **Back**.
  The fake "New branch..." entry, the picked-branch state and the separate
  Open links are gone. On narrow screens the commit folds under the name
  (popin).
- The row's branch name comes from the browser: the app accepts it only when
  it is listed and the row allows the action; the service checks it again
  against a fresh list (unchanged). A stray DELETE confirmation without an
  open one is ignored (it used to reach the service with an empty name).
- Status app 46/46 (8 new branch-popup tests); all suites 327/327.
  `npm run check` 0 errors. Readbacks match. Chrome on `$UMLAUT`: list, row
  buttons, New branch mode and Back, Close. Live with Chris's OK: New branch
  `ag2ui5-branch-list-test-20261007` from `testFromMain` at `aa97183`
  ("Created and following ..."), row Switch back to `testFromMain`
  ("Following testFromMain now"), row Delete of the throwaway branch after
  the confirmation ("Deleted ... (was at aa97183)"); `git ls-remote` shows it
  gone and the other branches unchanged. The phone layout was not checked
  live (the window could not be resized).


## 2026-10-07 — favorite repositories

- Implemented the approved shared-favorites design: stars in repository rows
  and tiles; a remembered Favorites only toggle; favorites-first package/name/key
  ordering; search combined with filtering; and a shared empty state with Show
  all repositories. Online and offline repositories use the same controls.
- Favorites remain in abapGit's current-user persistence. list_repos reads its
  keys once. set_favorite validates the raw key and X/blank state before any
  fixed-length conversion, reloads registration and writes only when the desired
  state differs. Existing automatic favorites on registration are unchanged.
  No new table was introduced. REPOS_FAVORITES_ONLY is an allow-listed frontend
  setting; its default is All, independent of classic abapGit's list filter.
- The setter accepts a string state at the boundary to prevent an overlong
  browser value being truncated into a valid abap_bool. Single-space false event
  values are accepted and normalized for the frontend filter. Failure restores
  the server's previous rows; a successful star remains confirmed if a subsequent
  list refresh fails. App state retains no abapGit or settings persistence object.
- Added 24 focused tests: service 9 (mutation, repeat/noop, key/state validation,
  missing registration, authorization, current-user isolation, persistence failure,
  unrelated favorites); repository app 14 (sorting/search/filter, initial/default
  and persisted preference, navigation isolation, failure recovery, last-favorite
  removal, empty matches, Show all, refresh); settings 1 (allow-list/default/user).
  Service mutation tests isolate authorization/registration with test seams and
  inject a persistence double, restored in teardown. Native results are below.
- npm check passes: ABAP lint 0 issues; UI5 property/render gates cover all 13
  documents with 0 errors/warnings and the existing MessageStrip hint. Diff
  whitespace checks pass. Inspected 1280x900 and 390x844 renders for tiles, list
  and empty results, including long names and both star states. Phone review
  moved Package/Actions into pop-ins, replaced the cramped Favorite heading with
  an icon and gave the filter low overflow priority while retaining the page title.
  Render artifacts/models are `/tmp/ag2ui5-favorites-*`.
- Before deployment, backed up all eight affected A4H25 interface/class/test
  sources; every live backup matches Git HEAD. Backups: `/tmp/ag2ui5-favorites/backup`.
  Automatic approval review rejected activation: the user's implementation approval
  was not accepted as explicit live-deployment authorization. No SAP source was
  written. An activation/native-test approval request is pending; no Git commit,
  merge or push has been performed for this feature.

- Chris subsequently explicitly approved deployment and requested commit, push,
  then pull into A4H25. The deployment approval request is resolved; native
  execution and source readback results will be recorded after the pull.

- Deployment completed: feature commit `156e572` and native test-seam fix
  `dda330c` are pushed on main. The normal pull aborted on SYSTEM_EDIT flags;
  fresh SAP sources matched the pre-feature commit. Chris approved ignore mode
  for this deployment. The first import exposed SAP visibility checks that
  abaplint did not catch: injected code executes in production seam context and
  cannot access private test flags. Moved the two flags into the test class's
  PUBLIC section. The scoped service retry succeeded with no failed objects.
- All eight affected SAP sources match the deployment snapshot. A4H25 ABAP
  Unit passed 237/237: service 199, repository app 27, settings 11; no failures,
  skips or warnings. npm check remains clean after the visibility fix.
- Live Chrome: removed `$UMLAUT` from favorites without navigating, enabled
  Favorites only and confirmed the fixture disappeared; reloaded and confirmed
  the filter and favorite state persisted. Restored All and the original starred
  fixture, inspected list stars, then restored the original Tiles layout. The
  browser search keyboard action timed out, so combined-search/empty behavior
  is covered by unit tests and headless renders rather than a live search check.

## Status page toolbar (2026-10-07)

- The page header holds only actions: Back, title, Refresh, the branch
  button, Stage (or Export ZIP) and Pull. The branch button shows the followed
  branch's short name (bound, so braces in a name cannot break the view) with
  the tooltip Branches, and opens the branch list.
- The view controls moved into the table's own header toolbar: Files /
  Objects, All / Changes only and one sort menu button. The menu ticks the
  current choice: Object, File and Type (files view only) and Changes on top.
  It replaces the Sort by label, its dropdown and the Changes on top toggle.
  The SORT event accepts only those keys; the choice is saved as before.
  `mv_sort` and `mv_changes_first` are no longer bound and became PROTECTED.
- Status app 52/52 (6 new tests: header holds actions only, table toolbar
  holds the view controls, sort saves, toggles, refuses unknown keys, ticks
  the current choice); all suites 357/357 after the favorites test seam fix
  (`dda330c`). `npm run check` 0 errors. Readbacks match.
- Chrome on `$UMLAUT`: header and table toolbar as described; sort by File
  with and without Changes on top reorders the rows; the objects view offers
  only Changes on top; the branch button shows `main` and opens the list.
  Chris's settings were restored to Object with Changes on top.


## 2026-10-07 — compact repository tiles

- Moved the existing favorite toggle into sap.f.cards.Header.toolbar, placing
  it at the top right beside the name/package. UI5's header tap handler excludes
  toolbar interactions, so the star remains separate from repository navigation.
- Removed the standalone star row and content top margin, and reduced the bottom
  margin while retaining horizontal alignment and repository metadata/actions.
- npm check: ABAP lint 0 issues; UI5 properties/render gates 0 errors/warnings,
  all 13 documents rendered, existing MessageStrip hint only. Desktop 1280x900
  and phone 390x844 scratch renders were inspected with a long name and online/
  offline repositories, both favorite states. Artifacts: /tmp/ag2ui5-compact-tiles-*.
  Implemented locally; not yet activated on A4H25.

## Branch shown once on the status page (2026-10-07)

- The "Branch:" line under the URL is gone: the toolbar button with the
  followed branch's name is the one place that shows and changes the branch.
  The link to the branch on the remote stays in the Branches popup, where
  every name is a link. The header keeps URL and remote commit.
- Status app 53/53 (new test: no Branch line, Remote commit kept).
  `npm run check` 0 errors. Readbacks match.


## 2026-10-07 — favorite confirmation toasts

- Successful star changes show “Repository added to favorites” or “Repository
  removed from favorites”, using the service-confirmed state. A failed save
  returns with its error and no success toast; a confirmed save keeps its toast
  even if the subsequent list refresh fails.
- Extended four existing app tests to assert these outcomes. npm check passes:
  ABAP lint 0 issues, UI5 properties/render 0 errors/warnings across 13 documents,
  existing MessageStrip hint only. Native tests have not been rerun; this
  follow-up is implemented locally and not yet activated on A4H25.

- Toast follow-up committed and pushed as `6eb1833`. The scoped abort-mode
  A4H25 pull imported nothing due to one SYSTEM_EDIT conflict. Live production
  source matched `723fef8` (compact tiles) and the test include matched `156e572`;
  no uncommitted source changes were present. Activated both through the documented
  ADT fallback, without overriding pull conflicts. Both readbacks match Git.
  Repository app ABAP Unit passed 27/27 with no failures/skips/test warnings.
  Activation had two existing warnings (ABAP Doc and STRING/CLIKE).

## Repository diff (2026-10-07)

Spec `docs/superpowers/specs/2026-10-07-repository-diff-design.md`, plan
`docs/superpowers/plans/2026-10-07-repository-diff.md`.

- New app `ZCL_AG2UI5_APP_REPO_DIFF`: every changed file of the status as a
  collapsible panel (file, object link, state, +/- counts, Open), in file
  order. The first 3 load on start; a panel loads through the existing
  `get_diff` when expanded and drops its rows when collapsed; Expand all opens
  at most 25. Inline / side by side for all panels; binary files and load
  errors show their text in their own panel. The header summarizes
  `n files, +x -y (k not loaded)`.
- The status table toolbar has **Diff** (disabled without changes, and for an
  offline repository without ZIP); it passes all changed rows, independent of
  filter and sort.
- Panels come from one bound file table with nested line tables (template
  binding); abap2UI5 sends the nested tables as expected. Chrome showed long
  files cut at 100 rows (the JSON model's size limit applies to a
  non-growing table); the panel tables now grow (500 rows, then More).
- The class was created through abapgit-mcp `write_objects` (empty shell with
  a placeholder test include), then the real sources were written over ADT.
- Final review fixes: the draft keeps only compacted lines, and only for
  open panels (collapsing drops them, opening again reloads); a single expand
  is capped at 25 open panels too; every access to the posted file table is
  guarded. Expand, collapse, Expand all and Collapse all no longer send a new
  view (it scrolled the page to the top; abap2UI5 pushes the model anyway);
  only the layout switch does.
- Deferred minors from the review: a failed load keeps its error until the
  page is opened again (no retry); the summary counts failed files neither as
  loaded nor as not loaded; `expand( sy-index )` passes a system field by
  reference; the page ignores the saved diff layout; `get_diff` recomputes
  the method summary and, offline, decodes the ZIP for every file; toast says
  "1 files"; test gaps (collapse twice, re-expand failed/binary, `false`
  argument, navigation back after Open); panels are not refreshed after
  coming back from Open.
- Native suites 379/379 (repository diff 18, status 56). `npm run check` 0
  errors. Readbacks match. The only new short dump is the expected RED run of
  the status test before the Diff event existed. Chrome on `$UMLAUT` and
  `$ABAPGIT2UI5` (read only): panels, collapse/expand, side by side, Open and
  Back, Expand all, 607-line file with More.

## Back to the repository after the last commit (2026-10-07)

- After a successful push the Stage page reloads its candidates. When none
  are left it returns to the status page by itself and hands over
  `PUSHED:Pushed <commit> to <branch>`; the status page reloads and shows that
  message (a toast sent with `nav_app_leave` would be lost). With changes
  left, or after a failed push, Stage stays as before. Stage stays reachable
  without changes, so ignore rules can still be managed.
- Stage 34/34 (3 new), status 57/57 (1 new); all suites 383/383.
  `npm run check` 0 errors. Readbacks match. Chrome: Stage and Back unchanged.
  No live push was made.


## 2026-10-07 — README refresh

- Corrected stale branch selector/Open branch instructions and the limitation
  claiming push to another branch was unsupported. Documented the current
  branch list, shared favorites/filter/toasts, compact tiles and post-push return.
- Moved ZIP usage into Supported workflows; expanded Development to all eight
  ABAP Unit suites and explained dependency downloads and local render checks.
- Refreshed repository list/status screenshots and added compact tiles using
  fresh read-only A4H25 service data. Inspected all three 1280x600 renders.
  Scratch copies resolve the screenshot tool's helper/conditional limitations;
  production code and SAP data/settings were unchanged. Existing Diff/Pull/Stage
  images are retained. README local links and diff whitespace checks pass.

## Own ICF node (2026-10-07)

- `/sap/bc/zabapgit2ui5` with handler `ZCL_AG2UI5_HTTP` (calls
  `z2ui5_cl_http_handler=>run`) and a session timeout of 30 minutes
  (`ICF_TIME`). It prepares stateful sessions that keep Git credentials in
  memory: A4H25 has `rdisp/plugin_auto_logout = 0` and no timeout on the
  `/sap/bc` path, so a stateful session would otherwise never end.
- Spike (deleted afterwards): statics survive round trips and
  `nav_app_call`/`nav_app_leave` only after `set_session_stateful( )`; they are
  gone after switching back and after a page reload; a reloaded page leaves
  the old stateful session on the server.
- Created through abapgit-mcp. Two findings: abapgit-mcp collapsed the
  padding inside SICF file names (fixed in abapGitMCP-backend), and abapGit
  writes `ICF_TIME` as `00:30:00`; the timeout was set once through
  `cl_icf_tree=>change_node`, then the Git file was taken from abapGit's own
  serialization. Chrome: repository list and round trips through the new node.
