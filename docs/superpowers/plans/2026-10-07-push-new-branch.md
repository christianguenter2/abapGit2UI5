# Commit and Push to a New Branch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Stage app can commit the selected changes to a new branch, created at the checked head, as abapGit's commit page does.

**Architecture:** `ty_commit` gets `new_branch`; a pure class-method `push_branch( )` normalizes and checks it against a fresh branch list; `commit_push` creates the branch after all existing checks and before the exit/push. The Stage app gets an optional input and a bound placeholder showing the followed branch.

**Tech Stack:** ABAP (abapGit developer version, abap2UI5 1.146.0), ABAP Unit on A4H25, abaplint + abap2ui5lint (`npm run check`).

**Spec:** `docs/superpowers/specs/2026-10-07-push-new-branch-design.md`

## Global Constraints

- New branch only; pushing to another existing branch is out of scope.
- Nothing is written (no branch, no push) while a name check or an existing staging check fails.
- The branch starts at the head the selection was checked against (`iv_from`).
- Order after the checks: `create_branch`, exit `validate_before_push`, push, `COMMIT WORK AND WAIT`, exit `validate_after_push`.
- Credentials are set before the first remote call and cleared on every way out.
- Empty `new_branch`: behavior unchanged; `ty_push_result-branch` still filled.
- Only bound data may be public in the app (`AGENTS.md`).
- Deploy over ADT (`class write` / `interface write`), never a pull with `ignore` mode without Chris's OK.
- The live push needs Chris's OK first (abapGit's exit supplies his real credentials); never touch `feature/test1234`.

## Review Focus

1. Blank or whitespace-only input means "no new branch", not "Enter a name" — test `push_branch_blank_is_none`.
2. A name equal to the followed branch (e.g. `main` while on main) is refused as existing — test `push_branch_current_refused`.
3. Branch names may contain `{` / `}` (Git allows them); the placeholder must not break the XML view's binding syntax — bound attribute, test `placeholder_bound`.
4. Push failure after the branch was created must say the branch exists and is followed — wrapped message in `commit_push` (no unit seam; checked in review and live).
5. After success the new-branch input is cleared, so a second push does not try to create the same branch again — test `new_branch_cleared_after_push`.

---

### Task 1: Service: `push_branch`, result and stage fields, `commit_push` wiring

**Files:**
- Modify: `src/zif_ag2ui5_repo_service.intf.abap` (`ty_commit` ~314, `ty_push_result` ~322, `ty_stage` ~297)
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (declarations next to `assert_new_branch` ~206; `get_stage` ~1709; `commit_push` ~1741)
- Test: `src/zcl_ag2ui5_repo_service.clas.testclasses.abap` (`ltcl_branches` ~1745)

**Interfaces:**
- Produces: `ty_commit-new_branch TYPE string`; `ty_push_result-branch TYPE string` (display name, without `refs/heads/`); `ty_stage-branch TYPE string` (display name of the followed branch);
  `CLASS-METHODS push_branch IMPORTING iv_new_branch TYPE string it_branches TYPE zif_ag2ui5_repo_service=>ty_branches RETURNING VALUE(rv_branch) TYPE string RAISING zcx_abapgit_exception` — empty for blank input, else the full `refs/heads/...` name.

- [ ] **Step 1: Write the failing tests** in `ltcl_branches` (declarations after `case_differs_is_new`):

```abap
    METHODS push_branch_blank_is_none FOR TESTING RAISING cx_static_check.
    METHODS push_branch_normalized FOR TESTING RAISING cx_static_check.
    METHODS push_branch_invalid_refused FOR TESTING.
    METHODS push_branch_current_refused FOR TESTING.
```

```abap
  METHOD push_branch_blank_is_none.
    cl_abap_unit_assert=>assert_initial(
      zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = `   ` it_branches = rows( ) ) ).
  ENDMETHOD.

  METHOD push_branch_normalized.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = ` feature x ` it_branches = rows( ) )
      exp = `refs/heads/feature-x` ).
  ENDMETHOD.

  METHOD push_branch_invalid_refused.
    TRY.
        zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = `a..b` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `An invalid name must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD push_branch_current_refused.
    " rows( ) follows zeta; pushing "to a new branch" zeta must not pass
    TRY.
        zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = `zeta` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `The followed branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
```

- [ ] **Step 2: Run to verify RED.** Write the test include over ADT, then run:

```sh
cd /home/chris/Projects/GIT/abapGit
.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap --type testclasses --activate
```
Expected: activation fails with a syntax error that `PUSH_BRANCH` is unknown (that is the RED for a missing method in ABAP).

- [ ] **Step 3: Implement.** Interface fields:

```abap
    BEGIN OF ty_commit,
      title TYPE string,
      body  TYPE string,
      name  TYPE string,
      email TYPE string,
      "! Optional: create this branch at the checked head and push there
      new_branch TYPE string,
    END OF ty_commit.
```
```abap
    BEGIN OF ty_push_result,
      outcome TYPE ty_outcome,
      "! The remote head after the push, 7 characters
      commit  TYPE string,
      "! The branch pushed to, without refs/heads/
      branch  TYPE string,
    END OF ty_push_result.
```
`ty_stage`: add after `email`:
```abap
      "! The branch the repository follows, without refs/heads/
      branch TYPE string,
```

Class declaration after `assert_new_branch`:
```abap
    "! The full name of the new branch for a push, or empty when none was
    "! entered. Normalized as branch_name( ), then checked as create_branch
    CLASS-METHODS push_branch
      IMPORTING
        iv_new_branch    TYPE string
        it_branches      TYPE zif_ag2ui5_repo_service=>ty_branches
      RETURNING
        VALUE(rv_branch) TYPE string
      RAISING
        zcx_abapgit_exception.
```
Implementation after `assert_new_branch`:
```abap
  METHOD push_branch.

    IF condense( iv_new_branch ) IS INITIAL.
      RETURN.
    ENDIF.
    rv_branch = branch_name( iv_new_branch ).
    assert_branch_name( rv_branch ).
    assert_new_branch( iv_branch = rv_branch it_branches = it_branches ).

  ENDMETHOD.
```

`get_stage`, after `refresh`:
```abap
    rs_stage-branch = replace( val = li_repo->get_selected_branch( ) regex = `^refs/heads/` with = `` ).
```

`commit_push`, inside the TRY directly after the `set_basic` IF block (the list needs the credentials for a private repository):
```abap
        " the name comes from the browser: checked against a fresh list
        " before anything is written
        DATA(lv_new_branch) = COND string(
          WHEN is_commit-new_branch IS NOT INITIAL
          THEN push_branch( iv_new_branch = is_commit-new_branch
                            it_branches   = zif_ag2ui5_repo_service~list_branches( iv_key ) ) ).
```
After `refresh( iv_drop_cache = abap_true )`:
```abap
        " the head the selection is checked against; a new branch starts here
        DATA(lv_head) = li_repo->get_current_remote( ).
```
Before the exit `validate_before_push` call (after `ls_comment`):
```abap
        IF lv_new_branch IS NOT INITIAL.
          " as abapGit's commit page: the repository follows the new branch
          li_repo->create_branch( iv_name = lv_new_branch iv_from = lv_head ).
        ENDIF.
```
Wrap exit + push + commit + exit so a failure after the branch exists says so:
```abap
        TRY.
            zcl_abapgit_exit=>get_instance( )->validate_before_push( is_comment     = ls_comment
                                                                     io_stage       = lo_stage
                                                                     ii_repo_online = li_repo ).
            li_repo->push( is_comment = ls_comment
                           io_stage   = lo_stage ).
          CATCH zcx_abapgit_exception INTO DATA(lx_push).
            IF lv_new_branch IS INITIAL.
              RAISE EXCEPTION lx_push.
            ENDIF.
            " the remote has the branch: keep abapGit's record of following it,
            " abap2UI5 would roll it back after main( )
            COMMIT WORK AND WAIT.
            zcx_abapgit_exception=>raise(
              |Branch { substring( val = lv_new_branch off = 11 ) } was created and is now followed, | &&
              |but nothing was pushed: { lx_push->get_text( ) }| ).
        ENDTRY.
        " push( ) writes the new checksums; abap2UI5 rolls back after main( )
        COMMIT WORK AND WAIT.
        zcl_abapgit_exit=>get_instance( )->validate_after_push( li_repo ).
```
After `rs_result-commit = ...`:
```abap
        rs_result-branch = replace( val = li_repo->get_selected_branch( ) regex = `^refs/heads/` with = `` ).
```

- [ ] **Step 4: Deploy and run GREEN.**

```sh
cd /home/chris/Projects/GIT/abapGit
.sapcli/a4h25 interface write ZIF_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zif_ag2ui5_repo_service.intf.abap --activate
.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.abap --activate
.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap
cd /home/chris/Projects/GIT/abapGit2UI5 && npm run check
```
Expected: service 185/185 (181 + 4); `npm run check` clean.

- [ ] **Step 5: Commit**

```sh
git add src/zif_ag2ui5_repo_service.intf.abap src/zcl_ag2ui5_repo_service.clas.abap src/zcl_ag2ui5_repo_service.clas.testclasses.abap
git commit -m "Service: commit and push to a new branch"
```

---

### Task 2: Stage app: "New branch" input, placeholder, toast

**Files:**
- Modify: `src/zcl_ag2ui5_app_stage.clas.abap` (public attributes ~43; `load_stage` ~540; form ~320; `push` ~599-615)
- Test: `src/zcl_ag2ui5_app_stage.clas.testclasses.abap` (`ltd_service` ~93, `ltcl_push` ~141)

**Interfaces:**
- Consumes: `ty_commit-new_branch`, `ty_push_result-branch`, `ty_stage-branch` from Task 1.
- Produces: public bound attribute `mv_branch_hint TYPE string`.

- [ ] **Step 1: Write the failing tests.** `ltd_service`: add `DATA ms_received_commit TYPE zif_ag2ui5_repo_service=>ty_commit.`; in its `commit_push` add `ms_received_commit = is_commit.` and `rs_result-branch = COND #( WHEN is_commit-new_branch IS NOT INITIAL THEN is_commit-new_branch ELSE `main` ).`
`ltcl_push` declarations:

```abap
    METHODS new_branch_passed FOR TESTING.
    METHODS new_branch_cleared_after_push FOR TESTING.
    METHODS toast_names_branch FOR TESTING.
    METHODS placeholder_bound FOR TESTING.
```
```abap
  METHOD new_branch_passed.
    mo_app->ms_commit-new_branch = `feature/x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->ms_received_commit-new_branch exp = `feature/x` ).
  ENDMETHOD.

  METHOD new_branch_cleared_after_push.
    mo_app->ms_commit-new_branch = `feature/x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_commit-new_branch ).
  ENDMETHOD.

  METHOD toast_names_branch.
    mo_app->ms_commit-new_branch = `feature/x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `Pushed abc1234 to feature/x` ).
  ENDMETHOD.

  METHOD placeholder_bound.
    " a branch name may contain { }: the hint must reach the view bound, not inline
    mo_service->ms_stage-branch = `a{b}`.
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_branch_hint exp = `Leave empty to push to a{b}` ).
  ENDMETHOD.
```
(`load_stage` takes no parameters; `ltcl_push` is a local friend, so the test may call it.)

- [ ] **Step 2: Run RED.**

```sh
cd /home/chris/Projects/GIT/abapGit
.sapcli/a4h25 class write ZCL_AG2UI5_APP_STAGE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_stage.clas.testclasses.abap --type testclasses --activate
```
Expected: syntax error, `MV_BRANCH_HINT` unknown.

- [ ] **Step 3: Implement.** Public attribute after `ms_commit`:
```abap
    "! Placeholder of the new-branch input; bound, a branch name may contain braces
    DATA mv_branch_hint TYPE string.
```
`load_stage`, after the committer defaults:
```abap
    mv_branch_hint = |Leave empty to push to { ls_stage-branch }|.
```
Form, after the e-mail input:
```abap
    form->tag( `Label`
        )->a( n = `text` v = `New branch` ).
    form->tag( `Input`
        )->a( n = `value`       v = client->_bind( ms_commit-new_branch )
        )->a( n = `placeholder` v = client->_bind( mv_branch_hint ) ).
```
`push`, success branch:
```abap
        CLEAR: ms_commit-title, ms_commit-body, ms_commit-new_branch.
        client->message_toast_display( |Pushed { ls_result-commit } to { ls_result-branch }| ).
```
Update existing `token_cleared_after_push` expectation stays valid (`Pushed abc1234*`).

- [ ] **Step 4: Deploy and run GREEN.**

```sh
cd /home/chris/Projects/GIT/abapGit
.sapcli/a4h25 class write ZCL_AG2UI5_APP_STAGE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_stage.clas.abap --activate
.sapcli/a4h25 class write ZCL_AG2UI5_APP_STAGE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_stage.clas.testclasses.abap --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_stage.clas.testclasses.abap
cd /home/chris/Projects/GIT/abapGit2UI5 && npm run check
```
Expected: stage 28/28 (24 + 4); check clean (render gate passes with the new Input).

- [ ] **Step 5: Commit**

```sh
git add src/zcl_ag2ui5_app_stage.clas.abap src/zcl_ag2ui5_app_stage.clas.testclasses.abap
git commit -m "Stage app: optional new branch for commit and push"
```

---

### Task 3: Full suites, readbacks, live check, docs

**Files:**
- Modify: `README.md` (feature table row line 26; stage paragraph ~89)
- Modify: `docs/findings.md` (new section for the slice; "Next slices" item 1 done)

- [ ] **Step 1: All suites** (the interface changed; doubles in other test includes must still activate):

```sh
cd /home/chris/Projects/GIT/abapGit
for f in repo_service app_stage app_diff settings app_status app_repos app_new_repo; do .sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_$f.clas.testclasses.abap; done
.sapcli/venv/bin/python .sapcli/agent.py dump --limit 5
```
Expected: all pass (309/309 = 301 + 8); no new dumps.

- [ ] **Step 2: Readbacks.** `class read` / `interface read` the three objects into the scratchpad and `diff` against `src/`. Expected: identical (line ends aside).

- [ ] **Step 3: Live check — ask Chris first.** With his OK, in Chrome on `$UMLAUT` (repo `000000000010`, follows `feature/test1234`): stage one harmless change, enter New branch `ag2ui5-push-test-20261007`, Commit & push. Expected toast `Pushed <sha> to ag2ui5-push-test-20261007`; status clean. Then Branches: switch back to `feature/test1234`, delete `ag2ui5-push-test-20261007`. Also check a refusal without writing: New branch `feature/test1234` → message "already exists", nothing pushed.

- [ ] **Step 4: Docs.** README line 26: `push to the followed branch or to a new one`. Stage paragraph: one sentence "An optional New branch creates that branch at the checked head, follows it and pushes there, as abapGit's commit page does." findings.md: section "Commit to a new branch (2026-10-07)" with results; remove item 1 from "Next slices".

- [ ] **Step 5: Commit**

```sh
git add README.md docs/findings.md
git commit -m "Docs: commit and push to a new branch"
```
