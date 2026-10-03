# New Repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** "New repository" on the repository list creates an online or offline abapGit repository from a form, checked on the server, without popups.

**Architecture:** `ZCL_AG2UI5_REPO_SERVICE` gets one method, `create_repo`, that normalizes and checks the form (pure methods `normalize_new_repo` and `new_repo_errors`, then abapGit's checks), collects every error per field, and only then creates the repository. A new page `ZCL_AG2UI5_APP_NEW_REPO` shows the form and puts the errors on their fields. The repository list gets a header button that opens it.

**Tech Stack:** ABAP 7.5x (A4H25), abapGit developer version, abap2UI5 1.146 view builder, ABAP Unit, abaplint and abap2ui5lint (`npm run check`).

**Spec:** `docs/superpowers/specs/2026-10-03-new-repository-design.md`

## Global Constraints

- Only `ZCL_AG2UI5_REPO_SERVICE` talks to abapGit; it returns plain data. Apps keep no abapGit references.
- Never call `zcl_abapgit_services_repo` or `zcl_abapgit_ui_factory=>get_popups`. Every service method starts with `assert_authorized( )` and `silence_progress( )`.
- The self-update guard `assert_pull_allowed` must refuse the target package (no repository in or above abapGit, abap2UI5 or this repository; on A4H25 `$TMP` too).
- No credentials in this slice. An empty remote is refused: "The repository has no commit yet. Push a first commit (for example a README), then try again."
- Checks first, all errors collected; nothing is written while one fails. Then the creation, then `COMMIT WORK AND WAIT`.
- Page headers are an `OverflowToolbar` in `customHeader`; a control with `layoutData` is opened with `ele( )`, never `tag( )`.
- Event arguments and booleans arrive as abap2UI5 sends them (`X` / space).
- Defaults as abapGit: kind ONLINE, folder logic PREFIX, ABAP language version empty (Any), checkboxes off.
- Deploy over ADT; the new app class needs one abapGit pull for its test include. `ignore` mode needs Chris's OK, asked at that point.

## Deviations from the spec (decided while planning)

- **Display name only online.** abapGit's `new_offline` has no display name; the field sits in the online part of the form, and `normalize_new_repo` clears it for offline.
- **Connection check = the branch list request.** abapGit's `check_connection` only builds the HTTP client; the branch list call (needed anyway for the empty-remote and branch checks) connects and raises for HTTP, SSL and login errors.
- **"Switching the kind keeps the shared fields"** happens on the client only (no event). The test is replaced by `normalize_new_repo` clearing the fields of the other kind (Task 1).
- **Offline needs an existing package.** An online repository may name a missing package when its remote has a package file (checked after `new_online`, as abapGit does); an offline repository has no remote, so a missing package is an error on `package`.
- **The repository list's header becomes an overflow toolbar** too: its new "New repository" button would otherwise push the title out on a phone (the rule in `AGENTS.md`).

## Review Focus

1. Package typed in lower case or with blanks (`  $ag2ui5_new `) - expected: normalized to `$AG2UI5_NEW` before any check. Test: Task 1 `normalize_trims_and_upper_cases`.
2. Branch typed short or with blanks (` main `) - expected: `refs/heads/main`, then checked against the remote. Test: Task 1 `normalize_branch_full_name`.
3. Online remote without package file and a missing package - expected: an error, and **no repository left behind**. Code: Task 2 `add_repo` deletes it again; check: Task 5 step 4.
4. Create pressed twice, or a package already used by a repository - expected: the second attempt fails on `package`, no second repository. Check: Task 5 step 3 (abapGit's `validate_package`).
5. An error on a field, then the kind switched or the field fixed - expected: the next Create clears every old error and message first. Test: Task 3 `errors_cleared_on_retry`; and the other kind's fields are cleared on the server: Task 1 `normalize_clears_other_kind`.

---

### Task 1: Form types and the pure checks

**Files:**
- Modify: `src/zif_ag2ui5_repo_service.intf.abap` (constants `c_outcome`, new types, method `create_repo`)
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (two public class methods; a stub `create_repo`)
- Test: `src/zcl_ag2ui5_repo_service.clas.testclasses.abap` (new class `ltcl_new_repo`)

**Interfaces:**
- Produces:
  - `zif_ag2ui5_repo_service=>c_outcome-created` (`CREATED`), `-invalid` (`INVALID`)
  - `zif_ag2ui5_repo_service=>c_repo_kind-online` (`ONLINE`), `-offline` (`OFFLINE`)
  - types `ty_new_repo`, `ty_field_error`, `ty_field_errors`, `ty_new_repo_result`
  - `METHODS create_repo IMPORTING is_repo TYPE ty_new_repo RETURNING VALUE(rs_result) TYPE ty_new_repo_result RAISING zcx_abapgit_exception`
  - `zcl_ag2ui5_repo_service=>normalize_new_repo( is_repo ) RETURNING rs_repo TYPE ty_new_repo`
  - `zcl_ag2ui5_repo_service=>new_repo_errors( is_repo ) RETURNING rt_errors TYPE ty_field_errors`
  - error `field` values are the lower-case component names of `ty_new_repo` (`url`, `branch`, `name`, `package`, `display_name`, `folder_logic`, `labels`, `abap_lang_vers`); empty means no field

- [ ] **Step 1: Add the types to the interface**

In `src/zif_ag2ui5_repo_service.intf.abap`, add to `c_outcome` (before `END OF c_outcome.`):

```abap
      "! The repository was created
      created TYPE ty_outcome VALUE `CREATED`,
      "! A check failed - nothing was created
      invalid TYPE ty_outcome VALUE `INVALID`,
```

After the `ty_branches` type, add:

```abap
  CONSTANTS:
    BEGIN OF c_repo_kind,
      online  TYPE string VALUE `ONLINE`,
      offline TYPE string VALUE `OFFLINE`,
    END OF c_repo_kind.

  "! The form of a new repository, as the browser sends it
  TYPES:
    BEGIN OF ty_new_repo,
      "! c_repo_kind
      kind            TYPE string,
      "! online only
      url             TYPE string,
      "! online only; empty: the remote's default branch
      branch          TYPE string,
      "! offline only
      name            TYPE string,
      package         TYPE string,
      "! online only
      display_name    TYPE string,
      "! PREFIX, FULL or MIXED
      folder_logic    TYPE string,
      "! comma-separated
      labels          TYPE string,
      ign_subpackages TYPE abap_bool,
      main_lang_only  TYPE abap_bool,
      "! empty (any), ignore, standard, keyUser or cloudDevelopment
      abap_lang_vers  TYPE string,
    END OF ty_new_repo.

  TYPES:
    BEGIN OF ty_field_error,
      "! a component of ty_new_repo in lower case; empty: no field
      field TYPE string,
      text  TYPE string,
    END OF ty_field_error,
    ty_field_errors TYPE STANDARD TABLE OF ty_field_error WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_new_repo_result,
      "! c_outcome-created or -invalid
      outcome TYPE ty_outcome,
      "! the new repository's key, when created
      key     TYPE string,
      errors  TYPE ty_field_errors,
    END OF ty_new_repo_result.
```

At the end of the interface (before `ENDINTERFACE.`), add:

```abap
  "! Creates an online or offline repository. Every check runs first and
  "! all errors are returned per field; while one fails nothing is created
  "! and the outcome is invalid. No credentials: a private repository works
  "! only through abapGit's user exit, an empty remote is refused
  METHODS create_repo
    IMPORTING
      is_repo          TYPE ty_new_repo
    RETURNING
      VALUE(rs_result) TYPE ty_new_repo_result
    RAISING
      zcx_abapgit_exception.
```

- [ ] **Step 2: Write the failing tests**

Append to `src/zcl_ag2ui5_repo_service.clas.testclasses.abap`:

```abap
CLASS ltcl_new_repo DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS valid_online
      RETURNING
        VALUE(rs_repo) TYPE zif_ag2ui5_repo_service=>ty_new_repo.
    METHODS fields
      IMPORTING
        it_errors      TYPE zif_ag2ui5_repo_service=>ty_field_errors
      RETURNING
        VALUE(rv_list) TYPE string.

    METHODS normalize_trims_and_upper_cases FOR TESTING.
    METHODS normalize_branch_full_name FOR TESTING.
    METHODS normalize_clears_other_kind FOR TESTING.
    METHODS valid_online_no_errors FOR TESTING.
    METHODS online_needs_url FOR TESTING.
    METHODS offline_needs_name FOR TESTING.
    METHODS package_required FOR TESTING.
    METHODS unknown_kind FOR TESTING.
    METHODS folder_logic_allowed FOR TESTING.
    METHODS language_version_allowed FOR TESTING.
ENDCLASS.


CLASS ltcl_new_repo IMPLEMENTATION.

  METHOD valid_online.
    rs_repo = VALUE #( kind         = zif_ag2ui5_repo_service=>c_repo_kind-online
                       url          = `https://github.com/abapGit-tests/DTEL.git`
                       package      = `$AG2UI5_NEW`
                       folder_logic = `PREFIX` ).
  ENDMETHOD.

  METHOD fields.
    " the fields with an error, in order, for one compact assertion
    LOOP AT it_errors INTO DATA(ls_error).
      rv_list = rv_list && |{ ls_error-field };|.
    ENDLOOP.
  ENDMETHOD.

  METHOD normalize_trims_and_upper_cases.
    " the form comes from the browser: blanks around, a package in lower case
    DATA(ls_repo) = zcl_ag2ui5_repo_service=>normalize_new_repo( VALUE #(
      kind           = ` online `
      url            = `  https://github.com/abapGit-tests/DTEL.git `
      package        = `  $ag2ui5_new `
      display_name   = ` My repo `
      folder_logic   = ` full `
      labels         = ` a,b `
      abap_lang_vers = ` keyUser ` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `ONLINE` act = ls_repo-kind ).
    cl_abap_unit_assert=>assert_equals( exp = `https://github.com/abapGit-tests/DTEL.git` act = ls_repo-url ).
    cl_abap_unit_assert=>assert_equals( exp = `$AG2UI5_NEW` act = ls_repo-package ).
    " inner blanks stay in a name
    cl_abap_unit_assert=>assert_equals( exp = `My repo` act = ls_repo-display_name ).
    cl_abap_unit_assert=>assert_equals( exp = `FULL` act = ls_repo-folder_logic ).
    cl_abap_unit_assert=>assert_equals( exp = `a,b` act = ls_repo-labels ).
    " abapGit's language versions are case-sensitive
    cl_abap_unit_assert=>assert_equals( exp = `keyUser` act = ls_repo-abap_lang_vers ).
  ENDMETHOD.

  METHOD normalize_branch_full_name.
    DATA(ls_repo) = valid_online( ).
    ls_repo-branch = ` main `.
    cl_abap_unit_assert=>assert_equals(
      exp = `refs/heads/main`
      act = zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo )-branch ).
    " empty stays empty: the remote's default branch
    ls_repo-branch = ``.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo )-branch ).
  ENDMETHOD.

  METHOD normalize_clears_other_kind.
    " the browser keeps the fields of the kind the user switched away from
    DATA(ls_repo) = valid_online( ).
    ls_repo-name = `left over`.
    ls_repo = zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo ).
    cl_abap_unit_assert=>assert_initial( ls_repo-name ).

    ls_repo = valid_online( ).
    ls_repo-kind         = zif_ag2ui5_repo_service=>c_repo_kind-offline.
    ls_repo-name         = `offline`.
    ls_repo-branch       = `main`.
    ls_repo-display_name = `shown`.
    ls_repo = zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo ).
    cl_abap_unit_assert=>assert_initial( ls_repo-url ).
    cl_abap_unit_assert=>assert_initial( ls_repo-branch ).
    cl_abap_unit_assert=>assert_initial( ls_repo-display_name ).
    cl_abap_unit_assert=>assert_equals( exp = `offline` act = ls_repo-name ).
  ENDMETHOD.

  METHOD valid_online_no_errors.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_repo_errors( valid_online( ) ) ).
  ENDMETHOD.

  METHOD online_needs_url.
    DATA(ls_repo) = valid_online( ).
    CLEAR ls_repo-url.
    cl_abap_unit_assert=>assert_equals(
      exp = `url;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD offline_needs_name.
    DATA(ls_repo) = valid_online( ).
    ls_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
    CLEAR ls_repo-url.
    cl_abap_unit_assert=>assert_equals(
      exp = `name;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD package_required.
    DATA(ls_repo) = valid_online( ).
    CLEAR ls_repo-package.
    cl_abap_unit_assert=>assert_equals(
      exp = `package;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD unknown_kind.
    " no field: the switch only offers the two kinds
    DATA(ls_repo) = valid_online( ).
    ls_repo-kind = `ZIP`.
    cl_abap_unit_assert=>assert_equals(
      exp = `;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD folder_logic_allowed.
    DATA(ls_repo) = valid_online( ).
    LOOP AT VALUE string_table( ( `PREFIX` ) ( `FULL` ) ( `MIXED` ) ) INTO ls_repo-folder_logic.
      cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ).
    ENDLOOP.
    LOOP AT VALUE string_table( ( `` ) ( `FLAT` ) ) INTO ls_repo-folder_logic.
      cl_abap_unit_assert=>assert_equals(
        exp = `folder_logic;`
        act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD language_version_allowed.
    DATA(ls_repo) = valid_online( ).
    LOOP AT VALUE string_table( ( `` ) ( `ignore` ) ( `standard` ) ( `keyUser` ) ( `cloudDevelopment` ) )
         INTO ls_repo-abap_lang_vers.
      cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ).
    ENDLOOP.
    LOOP AT VALUE string_table( ( `STANDARD` ) ( `undefined` ) ( `cloud` ) ) INTO ls_repo-abap_lang_vers.
      cl_abap_unit_assert=>assert_equals(
        exp = `abap_lang_vers;`
        act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 3: Add the signatures and empty bodies to the class**

In `src/zcl_ag2ui5_repo_service.clas.abap`, PUBLIC SECTION, after `format_timestamp`:

```abap
    "! The form as the checks see it: blanks around values removed, kind,
    "! package and folder logic in upper case, a branch as refs/heads/...,
    "! and the fields of the other kind cleared
    CLASS-METHODS normalize_new_repo
      IMPORTING
        is_repo        TYPE zif_ag2ui5_repo_service=>ty_new_repo
      RETURNING
        VALUE(rs_repo) TYPE zif_ag2ui5_repo_service=>ty_new_repo.

    "! The form's own errors, before anything asks abapGit: required fields
    "! and the allowed values. Expects a normalized form
    CLASS-METHODS new_repo_errors
      IMPORTING
        is_repo          TYPE zif_ag2ui5_repo_service=>ty_new_repo
      RETURNING
        VALUE(rt_errors) TYPE zif_ag2ui5_repo_service=>ty_field_errors.
```

In the IMPLEMENTATION, add empty methods so the class activates:

```abap
  METHOD normalize_new_repo.
    rs_repo = is_repo.
  ENDMETHOD.

  METHOD new_repo_errors ##NEEDED.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~create_repo ##NEEDED.
  ENDMETHOD.
```

The interface also gains `create_repo`: every class implementing `zif_ag2ui5_repo_service` must compile. The test doubles are `PARTIALLY IMPLEMENTED`, so nothing else changes.

- [ ] **Step 4: Deploy and run the tests to see them fail**

```sh
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 interface write ZIF_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zif_ag2ui5_repo_service.intf.abap --activate
./.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.abap --activate
./.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap
```

Expected: `Errors: 0` for each write. The unit run fails these tests of `LTCL_NEW_REPO`: `normalize_trims_and_upper_cases`, `normalize_branch_full_name`, `normalize_clears_other_kind`, `online_needs_url`, `offline_needs_name`, `package_required`, `unknown_kind`, `folder_logic_allowed`, `language_version_allowed`. `valid_online_no_errors` passes already (empty result); the other 113 tests pass.

- [ ] **Step 5: Implement the two methods**

Replace the two stubs in `src/zcl_ag2ui5_repo_service.clas.abap`:

```abap
  METHOD normalize_new_repo.

    rs_repo = is_repo.
    " single values: condense also takes inner blanks, which they never have
    rs_repo-kind         = to_upper( condense( is_repo-kind ) ).
    rs_repo-url          = condense( is_repo-url ).
    rs_repo-package      = to_upper( condense( is_repo-package ) ).
    rs_repo-folder_logic = to_upper( condense( is_repo-folder_logic ) ).
    " abapGit's language versions are case-sensitive (keyUser)
    rs_repo-abap_lang_vers = condense( is_repo-abap_lang_vers ).
    " names keep their inner blanks
    rs_repo-name         = shift_right( shift_left( is_repo-name ) ).
    rs_repo-display_name = shift_right( shift_left( is_repo-display_name ) ).
    rs_repo-labels       = shift_right( shift_left( is_repo-labels ) ).
    rs_repo-branch       = COND #( WHEN condense( is_repo-branch ) IS NOT INITIAL
                                   THEN branch_name( is_repo-branch ) ).

    " the browser keeps what was typed for the other kind
    IF rs_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-online.
      CLEAR rs_repo-name.
    ELSE.
      CLEAR: rs_repo-url, rs_repo-branch, rs_repo-display_name.
    ENDIF.

  ENDMETHOD.

  METHOD new_repo_errors.

    CASE is_repo-kind.
      WHEN zif_ag2ui5_repo_service=>c_repo_kind-online.
        IF is_repo-url IS INITIAL.
          INSERT VALUE #( field = `url` text = `Enter the URL of the Git repository` ) INTO TABLE rt_errors.
        ENDIF.
      WHEN zif_ag2ui5_repo_service=>c_repo_kind-offline.
        IF is_repo-name IS INITIAL.
          INSERT VALUE #( field = `name` text = `Enter a name for the repository` ) INTO TABLE rt_errors.
        ENDIF.
      WHEN OTHERS.
        INSERT VALUE #( text = |Unknown kind of repository "{ is_repo-kind }"| ) INTO TABLE rt_errors.
    ENDCASE.

    IF is_repo-package IS INITIAL.
      INSERT VALUE #( field = `package` text = `Enter a package` ) INTO TABLE rt_errors.
    ENDIF.

    IF is_repo-folder_logic <> zif_abapgit_dot_abapgit=>c_folder_logic-prefix
        AND is_repo-folder_logic <> zif_abapgit_dot_abapgit=>c_folder_logic-full
        AND is_repo-folder_logic <> zif_abapgit_dot_abapgit=>c_folder_logic-mixed.
      INSERT VALUE #( field = `folder_logic` text = `Choose Prefix, Full or Mixed` ) INTO TABLE rt_errors.
    ENDIF.

    " empty is abapGit's "Any"; undefined is its internal name for it
    IF is_repo-abap_lang_vers IS NOT INITIAL
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-ignore
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-standard
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-key_user
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-cloud_development.
      INSERT VALUE #( field = `abap_lang_vers` text = `Choose an ABAP language version` ) INTO TABLE rt_errors.
    ENDIF.

  ENDMETHOD.
```

- [ ] **Step 6: Deploy and run the tests to see them pass**

```sh
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.abap --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap
cd /home/chris/Projects/GIT/abapGit2UI5 && npm run check
```

Expected: `OK ZCL_AG2UI5_REPO_SERVICE: 123/123 passed`; `npm run check` exits 0 (abaplint 0 issues, linter 0 failing files).

- [ ] **Step 7: Commit**

```bash
git add src/zif_ag2ui5_repo_service.intf.abap src/zcl_ag2ui5_repo_service.clas.abap src/zcl_ag2ui5_repo_service.clas.testclasses.abap
git commit -m "New repository: form types and its checks without side effects"
```

---

### Task 2: `create_repo` - abapGit's checks and the creation

**Files:**
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (`create_repo`, private `check_new_repo`, `add_repo`)
- Test: `src/zcl_ag2ui5_repo_service.clas.testclasses.abap` (`ltcl_new_repo`: one more test)

**Interfaces:**
- Consumes: `normalize_new_repo`, `new_repo_errors`, the types of Task 1; existing `assert_authorized`, `silence_progress`, `assert_pull_allowed( iv_package TYPE devclass )`.
- Produces: a working `zif_ag2ui5_repo_service~create_repo`.

- [ ] **Step 1: Write the failing test**

Add to the DEFINITION of `ltcl_new_repo`: `METHODS invalid_form_creates_nothing FOR TESTING.` and to its IMPLEMENTATION:

```abap
  METHOD invalid_form_creates_nothing.
    " no URL, no package: refused before anything reaches abapGit
    DATA(li_service) = CAST zif_ag2ui5_repo_service( NEW zcl_ag2ui5_repo_service( ) ).
    DATA(lv_before) = lines( li_service->list_repos( ) ).
    DATA(ls_result) = li_service->create_repo( VALUE #( kind = ` online ` folder_logic = `PREFIX` ) ).
    cl_abap_unit_assert=>assert_equals( exp = zif_ag2ui5_repo_service=>c_outcome-invalid act = ls_result-outcome ).
    cl_abap_unit_assert=>assert_equals( exp = `url;package;` act = fields( ls_result-errors ) ).
    cl_abap_unit_assert=>assert_initial( ls_result-key ).
    cl_abap_unit_assert=>assert_equals( exp = lv_before act = lines( li_service->list_repos( ) ) ).
  ENDMETHOD.
```

- [ ] **Step 2: Deploy the test and see it fail**

```sh
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap
```

Expected: `123/124 passed`, `INVALID_FORM_CREATES_NOTHING` fails on the outcome (the stub returns nothing).

- [ ] **Step 3: Implement**

PRIVATE SECTION of `zcl_ag2ui5_repo_service`, add:

```abap
    "! abapGit's own checks for a normalized form; adds to ct_errors. A
    "! field that already has an error is not checked again
    METHODS check_new_repo
      IMPORTING
        is_repo   TYPE zif_ag2ui5_repo_service=>ty_new_repo
      CHANGING
        ct_errors TYPE zif_ag2ui5_repo_service=>ty_field_errors.

    "! Creates the checked repository as abapGit's services do, without
    "! their popups. A new online repository that fails its last checks is
    "! deleted again
    METHODS add_repo
      IMPORTING
        is_repo        TYPE zif_ag2ui5_repo_service=>ty_new_repo
      RETURNING
        VALUE(ri_repo) TYPE REF TO zif_abapgit_repo
      RAISING
        zcx_abapgit_exception.
```

Replace the stub `create_repo` and add the two methods:

```abap
  METHOD zif_ag2ui5_repo_service~create_repo.

    assert_authorized( ).
    silence_progress( ).

    " the form comes from the browser: every check runs, all errors are
    " collected, and nothing is written while one fails
    DATA(ls_repo) = normalize_new_repo( is_repo ).
    rs_result-errors = new_repo_errors( ls_repo ).
    IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-create_repo ) = abap_false.
      INSERT VALUE #( text = `You are not authorized to create repositories` ) INTO TABLE rs_result-errors.
    ENDIF.
    check_new_repo( EXPORTING is_repo   = ls_repo
                    CHANGING  ct_errors = rs_result-errors ).
    IF rs_result-errors IS NOT INITIAL.
      rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-invalid.
      RETURN.
    ENDIF.

    DATA(li_repo) = add_repo( ls_repo ).
    " as abapGit: a new repository is one of the user's favorites
    zcl_abapgit_persist_factory=>get_user( )->toggle_favorite( li_repo->get_key( ) ).
    " abap2UI5 rolls back after main( )
    COMMIT WORK AND WAIT.

    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-created.
    rs_result-key     = li_repo->get_key( ).

  ENDMETHOD.

  METHOD check_new_repo.

    DATA lx_error TYPE REF TO zcx_abapgit_exception.

    IF is_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-online AND NOT line_exists( ct_errors[ field = `url` ] ).
      TRY.
          zcl_abapgit_repo_srv=>get_instance( )->validate_url( is_repo-url ).
          NEW zcl_abapgit_git_url( )->validate_url( is_repo-url ).
          " connects: HTTP, SSL and login errors end up on the URL
          DATA(li_branches) = zcl_abapgit_git_factory=>get_git_transport( )->branches( is_repo-url ).
          IF is_repo-branch IS INITIAL AND li_branches->get_head_symref( ) IS INITIAL.
            " abapGit would push a first branch, which needs a login
            INSERT VALUE #( field = `url`
                            text  = `The repository has no commit yet. Push a first commit ` &&
                                    `(for example a README), then try again.` ) INTO TABLE ct_errors.
          ELSEIF is_repo-branch IS NOT INITIAL.
            TRY.
                li_branches->find_by_name( is_repo-branch ).
              CATCH zcx_abapgit_exception.
                INSERT VALUE #( field = `branch`
                                text  = |Branch { is_repo-branch } is not on the remote| ) INTO TABLE ct_errors.
            ENDTRY.
          ENDIF.
        CATCH zcx_abapgit_exception INTO lx_error.
          INSERT VALUE #( field = `url` text = lx_error->get_text( ) ) INTO TABLE ct_errors.
      ENDTRY.
    ENDIF.

    IF NOT line_exists( ct_errors[ field = `package` ] ).
      TRY.
          " name, SAP's own packages, used by another repository, local and
          " transportable mixed
          zcl_abapgit_repo_srv=>get_instance( )->validate_package(
            iv_package    = CONV #( is_repo-package )
            iv_ign_subpkg = is_repo-ign_subpackages ).
          assert_pull_allowed( CONV #( is_repo-package ) ).
          " an online repository may bring its package along; an offline one cannot
          IF is_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline
              AND zcl_abapgit_factory=>get_sap_package( CONV #( is_repo-package ) )->exists( ) = abap_false.
            zcx_abapgit_exception=>raise( |Package { is_repo-package } does not exist| ).
          ENDIF.
        CATCH zcx_abapgit_exception INTO lx_error.
          INSERT VALUE #( field = `package` text = lx_error->get_text( ) ) INTO TABLE ct_errors.
      ENDTRY.
    ENDIF.

    TRY.
        zcl_abapgit_repo_labels=>validate( is_repo-labels ).
      CATCH zcx_abapgit_exception INTO lx_error.
        INSERT VALUE #( field = `labels` text = lx_error->get_text( ) ) INTO TABLE ct_errors.
    ENDTRY.

  ENDMETHOD.

  METHOD add_repo.

    DATA(li_repo_srv) = zcl_abapgit_repo_srv=>get_instance( ).

    IF is_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
      ri_repo = li_repo_srv->new_offline( iv_name           = is_repo-name
                                          iv_package        = CONV #( is_repo-package )
                                          iv_folder_logic   = is_repo-folder_logic
                                          iv_labels         = is_repo-labels
                                          iv_ign_subpkg     = is_repo-ign_subpackages
                                          iv_main_lang_only = is_repo-main_lang_only
                                          iv_abap_lang_vers = is_repo-abap_lang_vers ).
      RETURN.
    ENDIF.

    ri_repo = li_repo_srv->new_online( iv_url            = is_repo-url
                                       iv_branch_name    = is_repo-branch
                                       iv_display_name   = is_repo-display_name
                                       iv_package        = CONV #( is_repo-package )
                                       iv_folder_logic   = is_repo-folder_logic
                                       iv_labels         = is_repo-labels
                                       iv_ign_subpkg     = is_repo-ign_subpackages
                                       iv_main_lang_only = is_repo-main_lang_only
                                       iv_abap_lang_vers = is_repo-abap_lang_vers ).
    TRY.
        " the steps of abapGit's services after new_online
        IF zcl_abapgit_factory=>get_sap_package( CONV #( is_repo-package ) )->exists( ) = abap_false.
          DATA(lt_remote) = ri_repo->get_files_remote( ).
          READ TABLE lt_remote TRANSPORTING NO FIELDS
            WITH KEY file COMPONENTS filename = zcl_abapgit_filename_logic=>c_package_file.
          IF sy-subrc <> 0.
            zcx_abapgit_exception=>raise( |Package { is_repo-package } does not exist and the repository | &&
                                          |contains no package. Choose an existing package.| ).
          ENDIF.
        ENDIF.
        " no leftovers of an earlier repository; also checks the folder logic
        ri_repo->checksums( )->rebuild( ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        li_repo_srv->delete( ri_repo ).
        COMMIT WORK.
        RAISE EXCEPTION lx_error.
    ENDTRY.

  ENDMETHOD.
```

If abaplint or the kernel rejects the `READ TABLE ... WITH KEY file COMPONENTS` form, copy the exact statement from `zcl_abapgit_services_repo=>check_package_exists` in the abapGit worktree (`git -C /home/chris/Projects/GIT/abapGit-small-fixes show upstream/main:src/ui/routing/zcl_abapgit_services_repo.clas.abap`) and ledger it as a ruling.

- [ ] **Step 4: Deploy and run the tests to see them pass**

```sh
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.abap --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap
cd /home/chris/Projects/GIT/abapGit2UI5 && npm run check
```

Expected: `OK ZCL_AG2UI5_REPO_SERVICE: 124/124 passed`; check exits 0.

- [ ] **Step 5: Smoke test against the system (no creation)**

Write `/tmp/claude-1000/-home-chris-Projects-GIT-abapGit2UI5/5ef041a3-2946-404a-8254-7280c083bcec/scratchpad/new_repo_smoke.abap`:

```abap
DATA(li_s) = CAST zif_ag2ui5_repo_service( NEW zcl_ag2ui5_repo_service( ) ).
DATA(lt_cases) = VALUE string_table(
  ( `ONLINE|https://github.com/abapGit-tests/DTEL.git||$TMP` )
  ( `ONLINE|https://github.com/abapGit-tests/DTEL.git||$ABAPGIT` )
  ( `ONLINE|https://github.com/abapGit-tests/DTEL.git|nosuchbranch|$AG2UI5_NEWX` )
  ( `ONLINE|https://example.com/not-git||$AG2UI5_NEWX` )
  ( `OFFLINE|||$AG2UI5_NOPKG` ) ).
LOOP AT lt_cases INTO DATA(lv_case).
  SPLIT lv_case AT `|` INTO DATA(lv_kind) DATA(lv_url) DATA(lv_branch) DATA(lv_package).
  DATA(ls_result) = li_s->create_repo( VALUE #( kind = lv_kind url = lv_url branch = lv_branch
                                                name = `smoke` package = lv_package folder_logic = `PREFIX` ) ).
  out->write( |{ lv_case } -> { ls_result-outcome }| ).
  LOOP AT ls_result-errors INTO DATA(ls_error).
    out->write( |   { ls_error-field }: { ls_error-text }| ).
  ENDLOOP.
ENDLOOP.
```

Run: `cd /home/chris/Projects/GIT/abapGit && ./.sapcli/a4h25 abap run <that file>`

Expected: every case `INVALID`, with errors: `$TMP` and `$ABAPGIT` on `package` (guard or "already used"), `nosuchbranch` on `branch`, the example.com URL on `url`, the offline one on `package` ("does not exist"). Nothing created: the repository list of the system is unchanged.

- [ ] **Step 6: Commit**

```bash
git add src/zcl_ag2ui5_repo_service.clas.abap src/zcl_ag2ui5_repo_service.clas.testclasses.abap
git commit -m "New repository: abapGit's checks and the creation, without popups"
```

---

### Task 3: The page `ZCL_AG2UI5_APP_NEW_REPO`

**Files:**
- Create: `src/zcl_ag2ui5_app_new_repo.clas.abap`
- Create: `src/zcl_ag2ui5_app_new_repo.clas.xml`
- Create: `src/zcl_ag2ui5_app_new_repo.clas.testclasses.abap`

**Interfaces:**
- Consumes: `zif_ag2ui5_repo_service~create_repo`, `ty_new_repo`, `ty_new_repo_result`, `c_outcome-created/-invalid`, `c_repo_kind`; `zcl_ag2ui5_app_status=>create( iv_key TYPE string )`.
- Produces: `zcl_ag2ui5_app_new_repo=>create( ) RETURNING VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_new_repo` (Task 4 calls it).

- [ ] **Step 1: Create the class files with a stub and the tests**

`src/zcl_ag2ui5_app_new_repo.clas.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_CLAS" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <VSEOCLASS>
    <CLSNAME>ZCL_AG2UI5_APP_NEW_REPO</CLSNAME>
    <LANGU>E</LANGU>
    <DESCRIPT>abapGit2UI5 - New repository app</DESCRIPT>
    <STATE>1</STATE>
    <CLSCCINCL>X</CLSCCINCL>
    <FIXPT>X</FIXPT>
    <UNICODE>X</UNICODE>
    <WITH_UNIT_TESTS>X</WITH_UNIT_TESTS>
   </VSEOCLASS>
  </asx:values>
 </asx:abap>
</abapGit>
```

(Copy the BOM-prefixed first line exactly as in `src/zcl_ag2ui5_app_repos.clas.xml`.)

`src/zcl_ag2ui5_app_new_repo.clas.abap` (stub: the definition is final, the bodies are empty):

```abap
"! Creates an online or offline abapGit repository from a form
CLASS zcl_ag2ui5_app_new_repo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      "! the error text per field of the form; empty: no error
      BEGIN OF ty_error_texts,
        url            TYPE string,
        branch         TYPE string,
        name           TYPE string,
        package        TYPE string,
        display_name   TYPE string,
        folder_logic   TYPE string,
        labels         TYPE string,
        abap_lang_vers TYPE string,
      END OF ty_error_texts.

    CLASS-METHODS create
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_new_repo.

    DATA ms_repo TYPE zif_ag2ui5_repo_service=>ty_new_repo.
    DATA ms_error_text TYPE ty_error_texts.
    "! an error that belongs to no field
    DATA mv_message TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    "! Set only by unit tests; the real service otherwise
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.

    METHODS view_display.
    METHODS on_event.
    METHODS create_repo.
    METHODS show_errors
      IMPORTING
        it_errors TYPE zif_ag2ui5_repo_service=>ty_field_errors.
    METHODS service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_new_repo IMPLEMENTATION.

  METHOD create.
    ro_app = NEW #( ).
  ENDMETHOD.

  METHOD z2ui5_if_app~main ##NEEDED.
  ENDMETHOD.

  METHOD view_display ##NEEDED.
  ENDMETHOD.

  METHOD on_event ##NEEDED.
  ENDMETHOD.

  METHOD create_repo ##NEEDED.
  ENDMETHOD.

  METHOD show_errors ##NEEDED.
  ENDMETHOD.

  METHOD service.
    ri_service = COND #( WHEN mi_service IS BOUND THEN mi_service ELSE NEW zcl_ag2ui5_repo_service( ) ).
  ENDMETHOD.

ENDCLASS.
```

`src/zcl_ag2ui5_app_new_repo.clas.testclasses.abap`:

```abap
CLASS ltcl_app DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_new_repo DEFINITION LOCAL FRIENDS ltcl_app.

"! abap2UI5 client: either the start (navigated) or one event
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_start TYPE abap_bool.
    DATA mv_event TYPE string.
    DATA mv_view TYPE string.
    DATA mv_toast TYPE string.
    DATA mv_left TYPE abap_bool.
    DATA mo_left_to TYPE REF TO z2ui5_if_app.
ENDCLASS.

CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~check_on_navigated.
    result = mv_start.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_event.
    result = xsdbool( mv_start = abap_false ).
  ENDMETHOD.
  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.
  METHOD z2ui5_if_client~view_display.
    mv_view = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_toast_display.
    mv_toast = text.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_leave.
    mv_left = abap_true.
    mo_left_to = app.
  ENDMETHOD.
  "! bindings and events are not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
ENDCLASS.


"! Service that answers create_repo with a preset result, or raises
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA ms_result TYPE zif_ag2ui5_repo_service=>ty_new_repo_result.
    DATA mv_fail TYPE abap_bool.
    DATA ms_received TYPE zif_ag2ui5_repo_service=>ty_new_repo.
ENDCLASS.

CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~create_repo.
    ms_received = is_repo.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Not authorized` ).
    ENDIF.
    rs_result = ms_result.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_app DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_new_repo.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.

    METHODS setup.
    METHODS fire
      IMPORTING
        iv_event TYPE string.

    METHODS defaults_as_abapgit FOR TESTING.
    METHODS online_created_opens_status FOR TESTING.
    METHODS offline_created_back_to_list FOR TESTING.
    METHODS errors_to_fields FOR TESTING.
    METHODS errors_cleared_on_retry FOR TESTING.
    METHODS exception_to_message FOR TESTING.
    METHODS back_leaves FOR TESTING.
    METHODS back_never_overflows FOR TESTING.
ENDCLASS.


CLASS ltcl_app IMPLEMENTATION.

  METHOD setup.
    mo_client  = NEW #( ).
    mo_service = NEW #( ).
    mo_app = zcl_ag2ui5_app_new_repo=>create( ).
    mo_app->mi_service = mo_service.
    mo_app->ms_repo-url     = `https://github.com/abapGit-tests/DTEL.git`.
    mo_app->ms_repo-package = `$AG2UI5_NEW`.
  ENDMETHOD.

  METHOD fire.
    mo_client->mv_event = iv_event.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.

  METHOD defaults_as_abapgit.
    DATA(lo_app) = zcl_ag2ui5_app_new_repo=>create( ).
    cl_abap_unit_assert=>assert_equals( exp = `ONLINE` act = lo_app->ms_repo-kind ).
    cl_abap_unit_assert=>assert_equals( exp = `PREFIX` act = lo_app->ms_repo-folder_logic ).
    cl_abap_unit_assert=>assert_initial( lo_app->ms_repo-abap_lang_vers ).
    cl_abap_unit_assert=>assert_false( lo_app->ms_repo-ign_subpackages ).
    cl_abap_unit_assert=>assert_false( lo_app->ms_repo-main_lang_only ).
  ENDMETHOD.

  METHOD online_created_opens_status.
    mo_service->ms_result = VALUE #( outcome = zif_ag2ui5_repo_service=>c_outcome-created key = `000000000042` ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = `$AG2UI5_NEW` act = mo_service->ms_received-package ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    " this page is left for the status page, so Back there returns to the list
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_status ) ).
  ENDMETHOD.

  METHOD offline_created_back_to_list.
    mo_app->ms_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
    mo_app->ms_repo-name = `offline repo`.
    mo_service->ms_result = VALUE #( outcome = zif_ag2ui5_repo_service=>c_outcome-created key = `000000000043` ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_not_bound( mo_client->mo_left_to ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_toast exp = `*offline repo*` ).
  ENDMETHOD.

  METHOD errors_to_fields.
    mo_service->ms_result = VALUE #(
      outcome = zif_ag2ui5_repo_service=>c_outcome-invalid
      errors  = VALUE #( ( field = `url`     text = `Bad URL` )
                         ( field = `package` text = `Package in use` )
                         ( field = ``        text = `Not authorized` ) ) ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = `Bad URL` act = mo_app->ms_error_text-url ).
    cl_abap_unit_assert=>assert_equals( exp = `Package in use` act = mo_app->ms_error_text-package ).
    cl_abap_unit_assert=>assert_equals( exp = `Not authorized` act = mo_app->mv_message ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
    " the form keeps what the user typed
    cl_abap_unit_assert=>assert_equals( exp = `$AG2UI5_NEW` act = mo_app->ms_repo-package ).
  ENDMETHOD.

  METHOD errors_cleared_on_retry.
    mo_app->ms_error_text-url = `old`.
    mo_app->ms_error_text-name = `old`.
    mo_app->mv_message = `old`.
    mo_service->ms_result = VALUE #(
      outcome = zif_ag2ui5_repo_service=>c_outcome-invalid
      errors  = VALUE #( ( field = `package` text = `Package in use` ) ) ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_error_text-url ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_error_text-name ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_message ).
    cl_abap_unit_assert=>assert_equals( exp = `Package in use` act = mo_app->ms_error_text-package ).
  ENDMETHOD.

  METHOD exception_to_message.
    mo_service->mv_fail = abap_true.
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = `Not authorized` act = mo_app->mv_message ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
  ENDMETHOD.

  METHOD back_leaves.
    fire( `BACK` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_not_bound( mo_client->mo_left_to ).
  ENDMETHOD.

  METHOD back_never_overflows.
    " on a narrow screen the header controls must not push out the back
    " button: they sit in an overflow toolbar, the back button stays
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    FIND REGEX `<customHeader>\s*<OverflowToolbar[^>]*>\s*<Button[^>]*sap-icon://nav-back[^>]*[^/>]>\s*`
            && `<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
    FIND REGEX `<Button text="Create"[^>]*[^/>]>\s*<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Check, commit and deploy with one pull**

```sh
cd /home/chris/Projects/GIT/abapGit2UI5 && npm run check
git add src/zcl_ag2ui5_app_new_repo.clas.*
git commit -m "New repository app: stub and tests"
/home/chris/Projects/GIT/abapGit/.sapcli/deploy-abapgit2ui5.sh
```

Expected: check exits 0 (the stub's empty methods carry `##NEEDED`). Read the `DEPLOY:` line. If it says "Pull aborted - n conflict(s)", **stop and ask Chris** for `--conflict-mode ignore`; never run it without his OK for this pull.

- [ ] **Step 3: Run the tests to see them fail**

```sh
cd /home/chris/Projects/GIT/abapGit
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_new_repo.clas.testclasses.abap
```

Expected: `FAIL ZCL_AG2UI5_APP_NEW_REPO: 0/8 passed` or close to it - `defaults_as_abapgit` fails (no defaults), the event tests fail (nothing happens), `back_never_overflows` fails (no view).

- [ ] **Step 4: Implement**

Replace the stub bodies in `src/zcl_ag2ui5_app_new_repo.clas.abap`:

```abap
  METHOD create.

    ro_app = NEW #( ).
    " abapGit's defaults
    ro_app->ms_repo-kind         = zif_ag2ui5_repo_service=>c_repo_kind-online.
    ro_app->ms_repo-folder_logic = zif_abapgit_dot_abapgit=>c_folder_logic-prefix.

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `CREATE`.
        create_repo( ).
    ENDCASE.

  ENDMETHOD.

  METHOD create_repo.

    CLEAR: ms_error_text, mv_message.
    TRY.
        DATA(ls_result) = service( )->create_repo( ms_repo ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        mv_message = lx_error->get_text( ).
        RETURN.
    ENDTRY.

    IF ls_result-outcome <> zif_ag2ui5_repo_service=>c_outcome-created.
      show_errors( ls_result-errors ).
      RETURN.
    ENDIF.

    IF ms_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
      " offline repositories open in slice 2; the list shows the new one
      client->message_toast_display( |Offline repository { ms_repo-name } created| ).
      client->nav_app_leave( ).
    ELSE.
      " leave this page for the status page: its Back returns to the list
      client->nav_app_leave( zcl_ag2ui5_app_status=>create( ls_result-key ) ).
    ENDIF.

  ENDMETHOD.

  METHOD show_errors.

    FIELD-SYMBOLS <lv_text> TYPE string.

    LOOP AT it_errors INTO DATA(ls_error).
      UNASSIGN <lv_text>.
      IF ls_error-field IS NOT INITIAL.
        DATA(lv_component) = to_upper( ls_error-field ).
        ASSIGN COMPONENT lv_component OF STRUCTURE ms_error_text TO <lv_text>.
      ENDIF.
      IF <lv_text> IS ASSIGNED.
        <lv_text> = ls_error-text.
      ELSE.
        mv_message = COND #( WHEN mv_message IS INITIAL THEN ls_error-text
                             ELSE |{ mv_message } { ls_error-text }| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    " the header is an overflow toolbar: on a narrow screen the controls
    " move into its menu, the back button and the title stay
    DATA(page) = view->ele( `Page` ).
    DATA(header_content) = page->ele( `customHeader` )->ele( `OverflowToolbar` ).
    header_content->ele( `Button`
        )->a( n = `icon`    v = `sap-icon://nav-back`
        )->a( n = `tooltip` v = `Back`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `press`   v = client->_event( `BACK` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `NeverOverflow` ).
    header_content->ele( `Title`
        )->a( n = `text`  v = `New repository`
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `true` ).
    header_content->tag( `ToolbarSpacer` ).
    header_content->ele( `Button`
        )->a( n = `text`  v = `Create`
        )->a( n = `icon`  v = `sap-icon://add`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `press` v = client->_event( `CREATE` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `NeverOverflow` ).

    DATA(content) = page->ele( `content` ).

    " an error that belongs to no field
    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( mv_message )
        )->a( n = `type`     v = `Error`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin`
        )->a( n = `visible`  v = |\{= !!$\{{ client->_bind( val = mv_message path = abap_true ) }\} \}| ).

    DATA(form) = content->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` v = `true`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->ele( n = `content` ns = `form` ).

    form->tag( `Label`
        )->a( n = `text` v = `Kind` ).
    form->ele( `SegmentedButton`
        )->a( n = `selectedKey` v = client->_bind( ms_repo-kind )
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `ONLINE`
                )->a( n = `text` v = `Online`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `OFFLINE`
                )->a( n = `text` v = `Offline` ).

    " online: URL, branch, display name - the kind switches on the client
    form->tag( `Label`
        )->a( n = `text`     v = `Git repository URL`
        )->a( n = `required` v = `true`
        )->a( n = `visible`  v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-url )
        )->a( n = `placeholder`    v = `https://github.com/...git`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-url path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-url )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Label`
        )->a( n = `text`    v = `Branch`
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-branch )
        )->a( n = `placeholder`    v = `Default branch of the remote`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-branch path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-branch )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).

    " offline: a name
    form->tag( `Label`
        )->a( n = `text`     v = `Name`
        )->a( n = `required` v = `true`
        )->a( n = `visible`  v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'OFFLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-name )
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-name path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-name )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'OFFLINE' \}| ).

    form->tag( `Label`
        )->a( n = `text`     v = `Package`
        )->a( n = `required` v = `true` ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-package )
        )->a( n = `placeholder`    v = `Z... / $...`
        )->a( n = `maxLength`      v = `30`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-package path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-package ) ).

    form->tag( `Label`
        )->a( n = `text`    v = `Display name`
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-display_name )
        )->a( n = `placeholder`    v = `Optional`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-display_name path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-display_name )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).

    " the rarely changed settings, collapsed
    DATA(more) = content->ele( `Panel`
        )->a( n = `headerText` v = `More settings`
        )->a( n = `expandable` v = `true`
        )->a( n = `expanded`   v = `false`
        )->ele( `content`
            )->ele( n = `SimpleForm` ns = `form`
                )->a( n = `editable` v = `true`
                )->a( n = `layout`   v = `ResponsiveGridLayout`
                )->ele( n = `content` ns = `form` ).

    more->tag( `Label`
        )->a( n = `text` v = `Folder logic` ).
    more->ele( `Select`
        )->a( n = `selectedKey`    v = client->_bind( ms_repo-folder_logic )
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-folder_logic path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-folder_logic )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `PREFIX`
                )->a( n = `text` v = `Prefix`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `FULL`
                )->a( n = `text` v = `Full`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `MIXED`
                )->a( n = `text` v = `Mixed` ).

    more->tag( `Label`
        )->a( n = `text` v = `Labels` ).
    more->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-labels )
        )->a( n = `placeholder`    v = `Comma-separated, optional`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-labels path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-labels ) ).

    more->tag( `Label`
        )->a( n = `text` v = `Ignore subpackages` ).
    more->tag( `CheckBox`
        )->a( n = `selected` v = client->_bind( ms_repo-ign_subpackages ) ).

    more->tag( `Label`
        )->a( n = `text` v = `Main language only` ).
    more->tag( `CheckBox`
        )->a( n = `selected` v = client->_bind( ms_repo-main_lang_only ) ).

    more->tag( `Label`
        )->a( n = `text` v = `ABAP language version` ).
    more->ele( `Select`
        )->a( n = `selectedKey`    v = client->_bind( ms_repo-abap_lang_vers )
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-abap_lang_vers path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-abap_lang_vers )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = ``
                )->a( n = `text` v = `Any`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `ignore`
                )->a( n = `text` v = `Ignore`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `standard`
                )->a( n = `text` v = `Standard`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `keyUser`
                )->a( n = `text` v = `For key users`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `cloudDevelopment`
                )->a( n = `text` v = `For cloud development` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.
```

If the linter reports `chain-house-layout`, run `npx abap2ui5lint --fix src/zcl_ag2ui5_app_new_repo.clas.abap` and re-check; if it reports a captured or unresolvable binding, ledger the finding and its fix as a ruling.

- [ ] **Step 5: Deploy and run the tests to see them pass**

```sh
cd /home/chris/Projects/GIT/abapGit2UI5 && npm run check
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 class write ZCL_AG2UI5_APP_NEW_REPO /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_new_repo.clas.abap --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_new_repo.clas.testclasses.abap
```

Expected: check exits 0; `OK ZCL_AG2UI5_APP_NEW_REPO: 8/8 passed`.

- [ ] **Step 6: Commit**

```bash
git add src/zcl_ag2ui5_app_new_repo.clas.abap
git commit -m "New repository app: form, errors on their fields, and the way out"
```

---

### Task 4: The repository list opens the page

**Files:**
- Modify: `src/zcl_ag2ui5_app_repos.clas.abap` (header as overflow toolbar, button, event `NEW`)
- Test: `src/zcl_ag2ui5_app_repos.clas.testclasses.abap`

**Interfaces:**
- Consumes: `zcl_ag2ui5_app_new_repo=>create( )`.

- [ ] **Step 1: Write the failing test**

In `src/zcl_ag2ui5_app_repos.clas.testclasses.abap`, `ltd_client`: add `DATA mo_called TYPE REF TO z2ui5_if_app.` to its PUBLIC SECTION and to the IMPLEMENTATION:

```abap
  METHOD z2ui5_if_client~nav_app_call.
    mo_called = app.
  ENDMETHOD.
```

Append a test class:

```abap
CLASS ltcl_new DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS new_opens_page FOR TESTING.
ENDCLASS.

CLASS ltcl_new IMPLEMENTATION.

  METHOD new_opens_page.
    DATA(lo_app) = NEW zcl_ag2ui5_app_repos( ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = `NEW`.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mo_called IS INSTANCE OF zcl_ag2ui5_app_new_repo ) ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Deploy the test and see it fail**

```sh
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 class write ZCL_AG2UI5_APP_REPOS /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_repos.clas.testclasses.abap --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_repos.clas.testclasses.abap
```

Expected: `3/4 passed`, `LTCL_NEW->NEW_OPENS_PAGE` fails (nothing called).

- [ ] **Step 3: Implement**

In `view_display` of `src/zcl_ag2ui5_app_repos.clas.abap`, replace

```abap
    DATA(page) = view->ele( `Page`
        )->a( n = `title` v = `abapGit - Repositories` ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://refresh`
            )->a( n = `tooltip` v = `Refresh`
            )->a( n = `press`   v = client->_event( `REFRESH` ) ).
```

with

```abap
    " the header is an overflow toolbar: on a narrow screen the buttons move
    " into its menu, the title stays
    DATA(page) = view->ele( `Page` ).
    DATA(header_content) = page->ele( `customHeader` )->ele( `OverflowToolbar` ).
    header_content->ele( `Title`
        )->a( n = `text`  v = `abapGit - Repositories`
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `true` ).
    header_content->tag( `ToolbarSpacer` ).
    header_content->tag( `Button`
        )->a( n = `text`  v = `New repository`
        )->a( n = `icon`  v = `sap-icon://add`
        )->a( n = `press` v = client->_event( `NEW` ) ).
    " icon only in the bar, with its text in the overflow menu
    header_content->tag( `OverflowToolbarButton`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `text`    v = `Refresh`
        )->a( n = `tooltip` v = `Refresh`
        )->a( n = `press`   v = client->_event( `REFRESH` ) ).
```

In `on_event`, add before `ENDCASE.`:

```abap
      WHEN `NEW`.
        client->nav_app_call( zcl_ag2ui5_app_new_repo=>create( ) ).
```

- [ ] **Step 4: Deploy and run the tests to see them pass**

```sh
cd /home/chris/Projects/GIT/abapGit2UI5 && npm run check
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 class write ZCL_AG2UI5_APP_REPOS /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_repos.clas.abap --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_repos.clas.testclasses.abap
```

Expected: check exits 0; `OK ZCL_AG2UI5_APP_REPOS: 4/4 passed`.

- [ ] **Step 5: Commit**

```bash
git add src/zcl_ag2ui5_app_repos.clas.abap src/zcl_ag2ui5_app_repos.clas.testclasses.abap
git commit -m "Repository list: New repository, header as overflow toolbar"
```

---

### Task 5: On the system, docs, cleanup

**Files:**
- Modify: `README.md`, `AGENTS.md`, `docs/findings.md`, `AGENTS-LOCAL.md` (Git-ignored)

- [ ] **Step 1: All suites**

```sh
cd /home/chris/Projects/GIT/abapGit
for f in repo_service settings app_stage app_diff app_status app_repos app_new_repo; do .sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_$f.clas.testclasses.abap; done
.sapcli/venv/bin/python .sapcli/agent.py dump --limit 5
```

Expected: service 124/124, settings 9/9, stage 13/13, diff 18/18, status 4/4, repos 4/4, new repository 8/8; no new dumps.

- [ ] **Step 2: Browser - online repository**

Start https://vhcala4hci25:50001/sap/bc/z2ui5?sap-client=001&app_start=zcl_ag2ui5_app_repos (if the session expired, ask Chris to log in). "New repository" -> Online, URL `https://github.com/abapGit-tests/DTEL.git`, package `$AG2UI5_NEW1` (does not exist; the remote has `package.devc.xml`) -> Create.

Expected: the status page of the new repository; Back leads to the **list** (not to the form), which shows the new tile. Pull on the status page imports the repository's objects into `$AG2UI5_NEW1`. If Back from the status page returns to the form instead, `nav_app_leave( app )` kept this page on the stack: stop, ledger it, and ask in chat before changing the flow.

Note: `abapGit-tests/DTEL` is also repository `000000000026` in `ZAG2UI5_TR_TEST`; a second repository of the same URL in another package is allowed by abapGit.

- [ ] **Step 3: Browser - refusals**

On the form, one after the other, Create with:

- package `$AG2UI5_NEW1` again (now used) -> red on Package ("already used" text from abapGit);
- package `$TMP` -> red on Package (self-update guard);
- URL `https://github.com/abapGit-tests/DTEL` with branch `nosuchbranch` and a new package -> red on Branch;
- URL `https://example.com/x.git` -> red on URL;
- Offline, name `smoke`, package `$AG2UI5_NOPKG` -> red on Package ("does not exist").

Expected: each error on its field, the form keeps its values, no new tile in the list afterwards.

- [ ] **Step 4: Browser - missing package without package file, offline repository**

- Online, URL of a public repository **without** `package.devc.xml` at its root folder (find one with `gh api repos/<owner>/<repo>/contents/src`; if none is at hand, skip and ledger it), package `$AG2UI5_NEW2` (does not exist) -> message strip with "does not exist and the repository contains no package"; the list shows **no** new repository.
- Offline, name `ag2ui5 offline`, package `$AG2UI5_TEST` -> toast, back on the list, a greyed tile "ag2ui5 offline".

- [ ] **Step 5: Phone width**

Narrow the page (`document.body.style.width='390px'` through the JS tool, then reset): the form page keeps Back, title and Create; the list keeps its title, "New repository" and Refresh move into the menu when needed.

- [ ] **Step 6: Clean up the system**

Delete the repositories created in steps 2 and 4 (in abapGit: repository settings -> Remove, which keeps the objects; then delete package `$AG2UI5_NEW1` and its objects with SE80 or `sapcli package delete` - **ask Chris first**, deleting a package is not reversible). Check that the list shows what it showed before step 2.

- [ ] **Step 7: Docs**

- `README.md`: in the feature list, a bullet "New repository: online or offline, checked like abapGit's own dialog; no credentials, no package creation".
- `AGENTS.md`:
  - in "Anything the client sends is checked again", a bullet: "`create_repo` for a new repository: `normalize_new_repo`, `new_repo_errors`, then abapGit's own checks and the self-update guard for the package";
  - in the table, a row `| New repository | \`normalize_new_repo\`, \`new_repo_errors\` |`;
  - the header rule: "(status, diff, stage)" becomes "(every page)";
  - the unit test list: add `ZCL_AG2UI5_APP_NEW_REPO`.
- `docs/findings.md`: a section "## New repository (2026-10-03)" above "Open points": what was built, the deviations above, test counts, the browser results, and whatever the execution ledger records as rulings and deferred minors.
- `AGENTS-LOCAL.md`: test counts; the new test command (`app_new_repo` in the loop).

- [ ] **Step 8: Commit**

```bash
git add README.md AGENTS.md docs/findings.md
git commit -m "Docs: new repository"
```
