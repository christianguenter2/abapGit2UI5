# Create branch: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new branch from the "Switch branch" dialog, at the head of the branch the repository follows now, and follow it.

**Architecture:** Three side-effect-free methods on the service normalize and
check the name; `create_branch` then calls abapGit's
`zif_abapgit_repo_online~create_branch`, which pushes the new ref and
switches to it. The status page's branch dialog gets a "New branch…" entry
that shows a name field and turns "Switch" into "Create". No credentials:
abapGit's exit supplies them.

**Tech Stack:** ABAP on A4H25, abapGit developer version, abap2UI5 1.146.0, abaplint + abap2ui5lint (`npm run check`).

**Spec:** `docs/superpowers/specs/2026-10-01-create-branch-design.md`

## Global Constraints

- Only `ZCL_AG2UI5_REPO_SERVICE` talks to abapGit; apps hold plain data;
  only bound data is PUBLIC.
- Every service method starts with `assert_authorized( )` and
  `silence_progress( )`. No abapGit popups.
- The name from the browser is normalized, checked against Git's rules and
  against a fresh branch list before anything reaches abapGit.
- After abapGit's `create_branch`: `COMMIT WORK AND WAIT`.
- No credential fields; the login manager is not touched.
- Deploy over ADT (`.sapcli/a4h25 class write … --activate`,
  `interface write …`), because abapgit-agent blocks pulls with false
  `SYSTEM_EDIT` conflicts; compare with `get_status( '000000000020' )`
  afterwards (only `.abapgit.xml` may differ).
- The real creation of a branch on GitHub is Chris's step, or needs his OK.

## Review Focus

1. **A name that only differs in case** from an existing branch (`Main` next
   to `main`): Git allows it, but it confuses. Expected: accepted, since Git
   and abapGit accept it. Pinned in Task 1 (`case_differs_is_new`).
2. **A name typed with `refs/heads/`:** must not become
   `refs/heads/refs/heads/x`. Pinned in Task 1 (`branch_name_keeps_prefix`).
3. **Blanks at either end** (`" x "`): expected `refs/heads/x`, not
   `refs/heads/-x-`. Pinned in Task 1 (`branch_name_trims`).
4. **The 401 when the exit gives no credentials:** a message box with the
   remote's text, the dialog stays open, nothing is switched. Checked in
   Task 4 only if Chris wants to see it; the code path is the existing
   `CATCH` of the dialog.
5. **Picking "New branch…" and then an existing branch again:** the name
   field hides, the button reads "Switch", and Switch switches. Checked in
   the browser in Task 4.

---

### Task 1: branch_name, assert_branch_name, assert_new_branch (side-effect free)

**Files:**
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (PUBLIC SECTION, methods)
- Test: `src/zcl_ag2ui5_repo_service.clas.testclasses.abap` (class `ltcl_branches`)

**Interfaces:**
- Produces:
  - `branch_name( iv_name TYPE string ) RETURNING rv_branch TYPE string`
  - `assert_branch_name( iv_branch TYPE string ) RAISING zcx_abapgit_exception` (takes the full `refs/heads/...` name)
  - `assert_new_branch( iv_branch TYPE string it_branches TYPE zif_ag2ui5_repo_service=>ty_branches ) RAISING zcx_abapgit_exception`

- [ ] **Step 1: Stubs** in the PUBLIC SECTION after `assert_branch`:

```abap
    "! The full name of a new branch, as abapGit makes it: blanks at the
    "! ends removed, inner blanks as -, refs/heads/ added unless present
    CLASS-METHODS branch_name
      IMPORTING
        iv_name          TYPE string
      RETURNING
        VALUE(rv_branch) TYPE string.

    "! Raises unless the name after refs/heads/ follows Git's rules for a ref
    CLASS-METHODS assert_branch_name
      IMPORTING
        iv_branch TYPE string
      RAISING
        zcx_abapgit_exception.

    "! Raises if the branch is already on the remote
    CLASS-METHODS assert_new_branch
      IMPORTING
        iv_branch   TYPE string
        it_branches TYPE zif_ag2ui5_repo_service=>ty_branches
      RAISING
        zcx_abapgit_exception.
```

and empty `METHOD … ENDMETHOD.` for each, after `METHOD assert_branch`.

- [ ] **Step 2: Failing tests** in `ltcl_branches` (definition):

```abap
    METHODS branch_name_normalized FOR TESTING.
    METHODS branch_name_keeps_prefix FOR TESTING.
    METHODS branch_name_trims FOR TESTING.
    METHODS valid_name_accepted FOR TESTING RAISING cx_static_check.
    METHODS invalid_names_refused FOR TESTING.
    METHODS existing_branch_refused FOR TESTING.
    METHODS case_differs_is_new FOR TESTING RAISING cx_static_check.
```

Implementation:

```abap
  METHOD branch_name_normalized.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_name( `feature x` )
                                        exp = `refs/heads/feature-x` ).
  ENDMETHOD.

  METHOD branch_name_keeps_prefix.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_name( `refs/heads/a` )
                                        exp = `refs/heads/a` ).
  ENDMETHOD.

  METHOD branch_name_trims.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_name( `  x  ` )
                                        exp = `refs/heads/x` ).
  ENDMETHOD.

  METHOD valid_name_accepted.
    zcl_ag2ui5_repo_service=>assert_branch_name( `refs/heads/feature/x-1` ).
  ENDMETHOD.

  METHOD invalid_names_refused.
    " the name comes from the browser; the remote would reject these too
    LOOP AT VALUE string_table( ( `refs/heads/` ) ( `refs/heads/a..b` ) ( `refs/heads/a~b` )
                                ( `refs/heads/a:b` ) ( `refs/heads/a^b` ) ( `refs/heads/a?b` )
                                ( `refs/heads/a*b` ) ( `refs/heads/a[b` ) ( `refs/heads/a\b` )
                                ( `refs/heads//a` ) ( `refs/heads/a/` ) ( `refs/heads/.a` )
                                ( `refs/heads/a.` ) ( `refs/heads/a.lock` )
                                ( |refs/heads/a{ cl_abap_char_utilities=>horizontal_tab }b| ) ) INTO DATA(lv_name).
      TRY.
          zcl_ag2ui5_repo_service=>assert_branch_name( lv_name ).
          cl_abap_unit_assert=>fail( |{ lv_name } must be refused| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD existing_branch_refused.
    TRY.
        zcl_ag2ui5_repo_service=>assert_new_branch( iv_branch = `refs/heads/main` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `An existing branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD case_differs_is_new.
    " Git refs are case-sensitive, as abapGit's check
    zcl_ag2ui5_repo_service=>assert_new_branch( iv_branch = `refs/heads/Main` it_branches = rows( ) ).
  ENDMETHOD.
```

(`rows( )` is the existing helper in `ltcl_branches`: `main`, `alpha`, `zeta`.)

- [ ] **Step 3: Deploy and run; confirm failures.**

```sh
A=/home/chris/Projects/GIT/abapGit/.sapcli/a4h25
$A class write ZCL_AG2UI5_REPO_SERVICE src/zcl_ag2ui5_repo_service.clas.abap --activate
$A class write ZCL_AG2UI5_REPO_SERVICE src/zcl_ag2ui5_repo_service.clas.testclasses.abap --type testclasses --activate
cd /home/chris/Projects/GIT/abapGit && .sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap
```

Expected: `branch_name_*` (3), `invalid_names_refused`, `existing_branch_refused` fail; `valid_name_accepted` and `case_differs_is_new` pass on the stubs (they pin "accepted"). 99 + 7 = 106 tests.

- [ ] **Step 4: Implement**

```abap
  METHOD branch_name.

    " as abapGit's normalize_branch_name and complete_heads_branch_name
    rv_branch = condense( val = iv_name del = ` ` from = `` ).
    rv_branch = replace( val = rv_branch sub = ` ` with = `-` occ = 0 ).
    IF rv_branch NP `refs/heads/*`.
      rv_branch = |refs/heads/{ rv_branch }|.
    ENDIF.

  ENDMETHOD.

  METHOD assert_branch_name.

    DATA(lv_short) = COND string( WHEN iv_branch CP `refs/heads/*` THEN substring( val = iv_branch off = 11 ) ).
    IF lv_short IS INITIAL.
      zcx_abapgit_exception=>raise( `Enter a name for the new branch` ).
    ENDIF.
    " Git's rules for a ref name (git check-ref-format)
    FIND REGEX `\.\.|[~^:?*\[\\]|[[:cntrl:]]|^[/.]|[/.]$|//|\.lock$` IN lv_short.
    IF sy-subrc = 0.
      zcx_abapgit_exception=>raise( |{ lv_short } is no valid branch name: no .., ~ ^ : ? * [ \\, | &&
                                    |control characters or //, and it may not start or end with / or . or end with .lock| ).
    ENDIF.

  ENDMETHOD.

  METHOD assert_new_branch.

    IF line_exists( it_branches[ name = iv_branch ] ).
      zcx_abapgit_exception=>raise( |Branch { substring( val = iv_branch off = 11 ) } already exists| ).
    ENDIF.

  ENDMETHOD.
```

`condense( … del = ` ` from = `` )` only strips the ends (`from = ``` keeps
inner blanks), so `branch_name_trims` gives `x`, not `-x-`.

- [ ] **Step 5: Deploy and run; all pass.** Same commands. Expected 106/106.
  Commit "Service: branch name checks"; `npm run check` passes.

---

### Task 2: service create_branch

**Files:**
- Modify: `src/zif_ag2ui5_repo_service.intf.abap`, `src/zcl_ag2ui5_repo_service.clas.abap`

**Interfaces:**
- Consumes: Task 1's three methods; existing `list_branches`.
- Produces: `zif_ag2ui5_repo_service~create_branch( iv_key TYPE string iv_name TYPE string ) RETURNING VALUE(rv_branch) TYPE string RAISING zcx_abapgit_exception`.

- [ ] **Step 1: Interface**, after `switch_branch`:

```abap
  "! Creates a branch at the head of the branch the repository follows, and
  "! follows it. The name is normalized and checked; abapGit's exit supplies
  "! the credentials for the push of the new ref
  METHODS create_branch
    IMPORTING
      iv_key           TYPE string
      iv_name          TYPE string
    RETURNING
      VALUE(rv_branch) TYPE string
    RAISING
      zcx_abapgit_exception.
```

- [ ] **Step 2: Implementation** after `zif_ag2ui5_repo_service~switch_branch`:

```abap
  METHOD zif_ag2ui5_repo_service~create_branch.

    " list_branches checks the authorization and installs the silent
    " progress; the name comes from the browser
    rv_branch = branch_name( iv_name ).
    assert_branch_name( rv_branch ).
    assert_new_branch( iv_branch   = rv_branch
                       it_branches = zif_ag2ui5_repo_service~list_branches( iv_key ) ).

    " abapGit pushes the new ref at the current head and follows it
    get_online_repo( iv_key )->create_branch( rv_branch ).
    " abap2UI5 rolls back after main( )
    COMMIT WORK AND WAIT.

  ENDMETHOD.
```

- [ ] **Step 3: Deploy** (interface first, then class), run the service tests
  (106/106), commit "Service: create a branch".

- [ ] **Step 4: Smoke test without creating anything** (scratchpad snippet,
  `./.sapcli/a4h25 abap run`): `create_branch( iv_key = '000000000010'
  iv_name = 'main' )` must raise "Branch main already exists";
  `iv_name = 'a..b'` must raise the rule message. Print
  `branch_name( ' my feature ' )` → `refs/heads/my-feature`.

---

### Task 3: the dialog

**Files:**
- Modify: `src/zcl_ag2ui5_app_status.clas.abap`

**Interfaces:**
- Consumes: `create_branch` (Task 2), `ms_head-branch`, `ms_head-remote_commit`.

- [ ] **Step 1: Bound data** (PUBLIC, after `mv_branch`):

```abap
    "! New branch… is picked: the name field shows, the button creates
    DATA mv_new_mode     TYPE abap_bool.
    DATA mv_new_name     TYPE string.
    DATA mv_start_text   TYPE string.
    DATA mv_branch_button TYPE string VALUE `Switch`.
```

Constant in the PROTECTED SECTION:

```abap
    CONSTANTS c_new_branch TYPE string VALUE `NEW`.
```

- [ ] **Step 2: `load_branches`** appends the entry and sets the texts,
  after the loop:

```abap
    INSERT VALUE #( name = c_new_branch text = `New branch…` ) INTO TABLE mt_branches.
    mv_start_text = |Starts from: { ms_head-branch } at { ms_head-remote_commit }|.
    CLEAR: mv_new_mode, mv_new_name.
    mv_branch_button = `Switch`.
```

- [ ] **Step 3: `popup_branches_display`**: the Select gets
  `change = client->_event( `BRANCH_PICK` )`; after the Select:

```abap
    box->tag( `Text`
        )->a( n = `text`    v = client->_bind( mv_start_text )
        )->a( n = `visible` v = client->_bind( mv_new_mode )
        )->a( n = `class`   v = `sapUiSmallMarginTop` ).
    box->tag( `Label`
        )->a( n = `text`     v = `Name`
        )->a( n = `required` v = `true`
        )->a( n = `visible`  v = client->_bind( mv_new_mode ) ).
    box->tag( `Input`
        )->a( n = `value`       v = client->_bind( mv_new_name )
        )->a( n = `placeholder` v = `feature/my-change`
        )->a( n = `visible`     v = client->_bind( mv_new_mode ) ).
```

and the begin button's `text` becomes `client->_bind( mv_branch_button )`.

- [ ] **Step 4: Events** in `on_event`:

```abap
      WHEN `BRANCH_PICK`.
        mv_new_mode      = xsdbool( mv_branch = c_new_branch ).
        mv_branch_button = COND #( WHEN mv_new_mode = abap_true THEN `Create` ELSE `Switch` ).
        client->popup_model_update( ).
```

and `switch_branch( )` starts with:

```abap
    IF mv_branch = c_new_branch.
      create_branch( ).
      RETURN.
    ENDIF.
```

New PROTECTED method `create_branch`:

```abap
  METHOD create_branch.

    TRY.
        DATA(lv_branch) = service( )->create_branch( iv_key  = mv_key
                                                     iv_name = mv_new_name ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        " the dialog stays open with the name
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    client->popup_destroy( ).
    client->message_toast_display( |Created and following { substring( val = lv_branch off = 11 ) }| ).
    load_status( ).

  ENDMETHOD.
```

- [ ] **Step 5:** `npm run check` passes. A headless screenshot of the dialog
  (scratch copy with `mv_new_mode = X`), deploy the class over ADT, run all
  three test classes, commit "Status page: create a branch".

---

### Task 4: browser, the real creation, docs, review

- [ ] **Step 1: Browser on `$UMLAUT`, without creating:** open the dialog;
  "New branch…" is last; picking it shows "Starts from: …" and the name,
  the button reads "Create"; picking `main` hides them and reads "Switch".
  Create with the name `main`: message box "Branch main already exists",
  dialog still open. Create with `a..b`: the rule message.
- [ ] **Step 2: Hand over to Chris:** he creates `test/create-branch` on
  `$UMLAUT` (or OKs the agent doing it). Check: GitHub has the branch at
  the old head, the header shows it, the list contains it.
- [ ] **Step 3: Docs:** `findings.md` section, `README.md` feature line,
  `AGENTS.md` bullet under "checked again on the server" and the Branch row
  of the table (`branch_name`, `assert_branch_name`, `assert_new_branch`).
- [ ] **Step 4: Final review** of the branch by a fresh reviewer; fixes
  test first.
