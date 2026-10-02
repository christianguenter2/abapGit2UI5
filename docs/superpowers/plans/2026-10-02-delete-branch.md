# Delete branch: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete a branch on the remote from the status page's branch dialog, never the default branch or the one the repository follows.

**Architecture:** `branch_rows` carries each branch's commit. A
side-effect-free `assert_deletable` guards the service's `delete_branch`,
which takes the name from the browser, checks it against a fresh branch list
and sends that list's commit to `zcl_abapgit_git_porcelain=>delete_branch`.
The dialog (renamed "Branches") shows "Delete" only for deletable branches
and asks through a confirm message box.

**Tech Stack:** ABAP on A4H25, abapGit developer version, abap2UI5 1.146.0, `npm run check`.

**Spec:** `docs/superpowers/specs/2026-10-02-delete-branch-design.md`

## Global Constraints

- Only `ZCL_AG2UI5_REPO_SERVICE` talks to abapGit; only bound data is PUBLIC.
- Every service method starts with `assert_authorized( )` and
  `silence_progress( )`.
- The name from the browser is checked against a fresh branch list; the
  commit sent to the remote comes from that list, never from the browser.
- Protected: the default branch and the branch the repository follows.
- No credentials in the app; abapGit's exit supplies them.
- Deploy over ADT (`.sapcli/a4h25 class write … --activate`, `interface
  write …`), then compare with `get_status( '000000000020' )`.
- Real deletions only on `$UMLAUT`, only of branches created for the test.
  `feature/test1234` stays.

## Review Focus

1. **The browser holds a stale list** (someone deleted or moved the branch
   elsewhere): the server's fresh list decides; a gone branch gives "not on
   the remote", a moved one is deleted at its new commit, and the toast
   shows that commit. Pinned by `assert_deletable` refusing an unknown name
   (Task 1); the moved case by code (fresh sha1 only).
2. **A forged request for the current or default branch** while the button
   is hidden: refused on the server. Pinned in Task 1.
3. **Cancel in the confirmation:** nothing is sent. Checked in the browser
   (Task 4).
4. **The deleted branch was the one picked:** after reloading, the Select
   picks the current branch again and "Delete" hides. Checked in the browser.
5. **The `HEAD` entry** of the remote list must never become deletable:
   `branch_rows` already drops it; `assert_deletable` refuses what is not
   listed.

---

### Task 1: sha1 in branch_rows, assert_deletable (side-effect free)

**Files:** `src/zif_ag2ui5_repo_service.intf.abap`,
`src/zcl_ag2ui5_repo_service.clas.abap`,
`src/zcl_ag2ui5_repo_service.clas.testclasses.abap` (`ltcl_branches`)

**Interfaces:**
- Produces: `ty_branch-sha1 TYPE string`;
  `assert_deletable( iv_branch TYPE string it_branches TYPE zif_ag2ui5_repo_service=>ty_branches ) RAISING zcx_abapgit_exception`.

- [ ] **Step 1:** `ty_branch` gets, after `current`:

```abap
      "! The commit the branch points to
      sha1    TYPE string,
```

Stub after `assert_new_branch` (definition and empty implementation):

```abap
    "! Raises unless the branch is listed and is neither the remote's
    "! default nor the one the repository follows
    CLASS-METHODS assert_deletable
      IMPORTING
        iv_branch   TYPE string
        it_branches TYPE zif_ag2ui5_repo_service=>ty_branches
      RAISING
        zcx_abapgit_exception.
```

- [ ] **Step 2: Failing tests.** In `remote_list( )`, give each entry a
  `sha1` (`zeta` `'1111111'`, `HEAD` and `main` `'2222222'`, `alpha`
  `'3333333'`). Update `default_and_current_marked`'s two expected rows with
  `sha1 = '2222222'` and `sha1 = '1111111'`. New methods:

```abap
    METHODS sha1_carried FOR TESTING.
    METHODS other_branch_deletable FOR TESTING RAISING cx_static_check.
    METHODS default_not_deletable FOR TESTING.
    METHODS current_not_deletable FOR TESTING.
    METHODS unknown_not_deletable FOR TESTING.
```

```abap
  METHOD sha1_carried.
    cl_abap_unit_assert=>assert_equals( act = rows( )[ name = `refs/heads/alpha` ]-sha1 exp = `3333333` ).
  ENDMETHOD.

  METHOD other_branch_deletable.
    zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = `refs/heads/alpha` it_branches = rows( ) ).
  ENDMETHOD.

  METHOD default_not_deletable.
    TRY.
        zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = `refs/heads/main` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `The default branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD current_not_deletable.
    TRY.
        zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = `refs/heads/zeta` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `The current branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD unknown_not_deletable.
    " the name comes from the browser; HEAD is never listed
    LOOP AT VALUE string_table( ( `refs/heads/gone` ) ( `HEAD` ) ( `` ) ) INTO DATA(lv_name).
      TRY.
          zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = lv_name it_branches = rows( ) ).
          cl_abap_unit_assert=>fail( |{ lv_name } must be refused| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
```

- [ ] **Step 3:** Write interface, class and test include over ADT; run the
  service tests. Expected: `sha1_carried`, `default_and_current_marked`,
  the three refusals fail; `other_branch_deletable` passes on the stub.
  106 + 5 = 111 tests.

- [ ] **Step 4: Implement.** In `branch_rows`'s `INSERT VALUE #( … )` add
  `sha1 = ls_branch-sha1`. Then:

```abap
  METHOD assert_deletable.

    READ TABLE it_branches INTO DATA(ls_branch) WITH KEY name = iv_branch.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Branch { iv_branch } is not on the remote| ).
    ENDIF.
    IF ls_branch-default = abap_true.
      zcx_abapgit_exception=>raise( |{ ls_branch-display } is the default branch and cannot be deleted| ).
    ENDIF.
    IF ls_branch-current = abap_true.
      zcx_abapgit_exception=>raise( |{ ls_branch-display } is the branch this repository follows - switch first| ).
    ENDIF.

  ENDMETHOD.
```

- [ ] **Step 5:** Write the class over ADT, run: 111/111. `npm run check`.
  Commit "Service: branch commits, assert_deletable".

---

### Task 2: service delete_branch

**Files:** `src/zif_ag2ui5_repo_service.intf.abap`, `src/zcl_ag2ui5_repo_service.clas.abap`

**Interfaces:**
- Produces: `zif_ag2ui5_repo_service~delete_branch( iv_key TYPE string iv_branch TYPE string ) RETURNING VALUE(rv_sha1) TYPE string RAISING zcx_abapgit_exception`.

- [ ] **Step 1: Interface** after `create_branch`:

```abap
  "! Deletes a branch on the remote; not the default one, not the one the
  "! repository follows. Returns the commit it pointed to
  METHODS delete_branch
    IMPORTING
      iv_key         TYPE string
      iv_branch      TYPE string
    RETURNING
      VALUE(rv_sha1) TYPE string
    RAISING
      zcx_abapgit_exception.
```

- [ ] **Step 2: Implementation** after `create_branch`:

```abap
  METHOD zif_ag2ui5_repo_service~delete_branch.

    assert_authorized( ).
    silence_progress( ).

    " the name comes from the browser; the commit comes from a fresh list
    DATA(lt_branches) = zif_ag2ui5_repo_service~list_branches( iv_key ).
    assert_deletable( iv_branch   = iv_branch
                      it_branches = lt_branches ).
    DATA(ls_branch) = lt_branches[ name = iv_branch ].

    zcl_abapgit_git_porcelain=>delete_branch(
      iv_url    = get_online_repo( iv_key )->get_url( )
      is_branch = VALUE #( name = ls_branch-name sha1 = ls_branch-sha1 display_name = ls_branch-display ) ).
    rv_sha1 = ls_branch-sha1.

  ENDMETHOD.
```

- [ ] **Step 3:** Deploy (interface, class), run the service tests
  (111/111), commit "Service: delete a branch".
- [ ] **Step 4: Smoke test, deleting nothing:** `delete_branch` on
  `$UMLAUT` for `refs/heads/main` (default), the current branch, and
  `refs/heads/gone` must each raise.

---

### Task 3: the dialog, "Branches"

**Files:** `src/zcl_ag2ui5_app_status.clas.abap`

- [ ] **Step 1: Data.** `ty_branch_row` gets `default TYPE abap_bool`,
  `current TYPE abap_bool`, `sha1 TYPE string`; `load_branches` fills them
  from the service rows. New PUBLIC `DATA mv_can_delete TYPE abap_bool.`;
  PROTECTED `DATA mv_delete_branch TYPE string.` (the branch the open
  confirmation is about, set on the server).

- [ ] **Step 2: `can_delete` rule**, computed at the end of `load_branches`
  and in `BRANCH_PICK`:

```abap
    READ TABLE mt_branches INTO DATA(ls_picked) WITH KEY name = mv_branch.
    mv_can_delete = xsdbool( sy-subrc = 0 AND mv_branch <> c_new_branch
                             AND ls_picked-default = abap_false AND ls_picked-current = abap_false ).
```

(Put it in a PROTECTED method `branch_buttons( )` together with
`mv_new_mode` / `mv_branch_button`, and call it from both places.)

- [ ] **Step 3: View.**
  - The header button: text `Branches`, same icon, event `BRANCHES`.
  - The dialog title `Branches`; the intro text "Switch: only the branch the
    repository follows changes. Create and delete act on GitHub."
  - The footer needs three buttons, and `beginButton`/`endButton` hold only
    two: replace both by the `buttons` aggregation,
    `dialog->ele( `buttons` )`, with `Switch`/`Create` (emphasized, as
    now), `Delete` (`type = Reject`,
    `visible = client->_bind( mv_can_delete )`, event `BRANCH_DELETE`) and
    `Cancel` (as now).
- [ ] **Step 4: Events.**

```abap
      WHEN `BRANCH_DELETE`.
        READ TABLE mt_branches INTO DATA(ls_delete) WITH KEY name = mv_branch.
        IF sy-subrc = 0 AND mv_can_delete = abap_true.
          mv_delete_branch = mv_branch.
          client->message_box_display(
            text             = |Delete branch { ls_delete-text } (at { ls_delete-sha1(7) }) on GitHub? abapGit cannot undo this.|
            type             = `confirm`
            actions          = VALUE #( ( `DELETE` ) ( `CANCEL` ) )
            emphasizedaction = `CANCEL`
            onclose          = `BRANCH_DELETE_CLOSE` ).
        ENDIF.
      WHEN `BRANCH_DELETE_CLOSE`.
        IF client->get_event_arg( ) = `DELETE`.
          delete_branch( ).
        ENDIF.
        CLEAR mv_delete_branch.
```

(`ls_delete-sha1(7)` needs a string of at least 7; use
`substring( val = ls_delete-sha1 len = nmin( val1 = 7 val2 = strlen( ls_delete-sha1 ) ) )`.)

PROTECTED `delete_branch( )`:

```abap
  METHOD delete_branch.

    TRY.
        DATA(lv_sha1) = service( )->delete_branch( iv_key    = mv_key
                                                   iv_branch = mv_delete_branch ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    client->message_toast_display(
      |Deleted { substring( val = mv_delete_branch off = 11 ) } (was at { substring( val = lv_sha1 len = 7 ) })| ).
    " the list without the deleted branch, the current one picked again
    load_branches( ).

  ENDMETHOD.
```

- [ ] **Step 5:** `npm run check`, a headless screenshot of the dialog with
  Delete visible, deploy over ADT, the suite, commit
  "Status page: Branches dialog deletes a branch".

---

### Task 4: browser on `$UMLAUT`, docs, review

- [ ] **Step 1:** Open "Branches" on `$UMLAUT`: "Delete" hidden for `main`
  and for the current branch (`test`), shown for `Test` and
  `feature/test1234` (do not delete those).
- [ ] **Step 2:** "New branch..." → `delete-me` → Create (the repository then
  follows `delete-me`). Open "Branches", switch back to `test`. Open again,
  pick `delete-me`, Delete → Cancel: nothing sent (`git ls-remote` still
  lists it). Delete → DELETE: toast, the list without `delete-me`, the
  current branch picked, Delete hidden. `git ls-remote --heads` on the
  repository: `delete-me` gone, `main`, `Test`, `test`, `feature/test1234`
  unchanged.
- [ ] **Step 3: Docs:** `AGENTS.md` (bullet "`assert_deletable` for a branch
  to delete, against a fresh branch list; the commit sent comes from that
  list", Branch row), `README.md` (the "Branches" dialog), `findings.md`.
- [ ] **Step 4:** Final review by a fresh reviewer; fixes test first; then
  merge after Chris's OK.
