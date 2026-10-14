# Single-file fetch for diffs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A single-file diff (Diff page, Pick lines, repository Diff panel)
fetches only that file from Git by its SHA1 instead of the whole repository.

**Architecture:** Status and Stage rows carry the file's remote SHA1. The
apps keep it in PROTECTED data and hand it to `get_diff`, which fetches the
one blob through a small, replaceable blob source, checks it, caches it for
the request and falls back to the full fetch when the server refuses.

**Tech Stack:** ABAP 7.50, abapGit developer version
(`zcl_abapgit_git_transport`, `zcl_abapgit_hash`), abap2UI5 1.146.0,
ABAP Unit, abaplint (`npm run check`).

**Spec:** `docs/superpowers/specs/2026-10-14-single-file-fetch-design.md`

## Global Constraints

- ABAP 7.50 syntax (abaplint `v750`); own objects `ZCL_AG2UI5_*` /
  `ZIF_AG2UI5_*` in package `$ABAPGIT2UI5`.
- Only `ZCL_AG2UI5_REPO_SERVICE` talks to abapGit; the apps get plain data.
- Public app attributes go to the browser: the SHA1 the diff uses never
  comes from public (posted) data.
- Offline repositories and uploaded ZIPs keep today's path.
- Commit/push (`commit_push`, `apply_patch`, fingerprint) keep the full fetch.
- Status's object overview keeps the full fetch (it passes no SHA1).
- A known, empty SHA1 (file only in the system) fetches nothing.
- Match the surrounding code: `"!` doc comments on members, short `"`
  comments only where the reason is not obvious.

## Review Focus

- A SHA1 that is not 40 hex characters (empty, upper case, path-like) must
  never reach the Git request: upper case is lowered, anything else falls
  back to the full fetch (Task 3, `invalid_hash_skips_request`).
- A Git file of 0 bytes is a real remote file, not "not in Git"
  (Task 3, `empty_blob_is_found`).
- A login error from the single fetch opens the login once, not after a
  second full fetch (Task 3, `login_error_no_fallback`).
- An offline repository with `iv_remote_known = X` still reads its ZIP
  (Task 3, `offline_ignores_known`).
- A row posted back by the browser cannot change which hash is fetched
  (Task 5, `diff_uses_server_hash` / `patch_uses_server_hash`).

---

### Task 1: Blob source

**Files:**
- Create: `src/zif_ag2ui5_blob_source.intf.abap`, `src/zif_ag2ui5_blob_source.intf.xml`
- Create: `src/zcl_ag2ui5_blob_source.clas.abap`, `src/zcl_ag2ui5_blob_source.clas.xml`

**Interfaces:**
- Produces: `zif_ag2ui5_blob_source~fetch( iv_url TYPE string iv_sha1 TYPE zif_abapgit_git_definitions=>ty_sha1 ) RETURNING rt_objects TYPE zif_abapgit_definitions=>ty_objects_tt RAISING zcx_abapgit_exception`; default implementation `zcl_ag2ui5_blob_source`.

- [ ] **Step 1: Write the interface**

```abap
"! Reads single Git objects by hash, without fetching the whole repository
INTERFACE zif_ag2ui5_blob_source
  PUBLIC.

  "! The objects the Git server sends for one wanted hash
  METHODS fetch
    IMPORTING
      iv_url            TYPE string
      iv_sha1           TYPE zif_abapgit_git_definitions=>ty_sha1
    RETURNING
      VALUE(rt_objects) TYPE zif_abapgit_definitions=>ty_objects_tt
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
```

`zif_ag2ui5_blob_source.intf.xml`: copy `src/zif_ag2ui5_settings.intf.xml`,
with `CLSNAME` `ZIF_AG2UI5_BLOB_SOURCE` and `DESCRIPT`
`abapGit2UI5 - Single Git objects`.

- [ ] **Step 2: Write the class**

```abap
"! Fetches one object with abapGit's upload-pack request ("want <hash>").
"! Smart HTTP servers (GitHub, GitLab, Bitbucket, Forgejo, plain Git) answer
"! it for any object they hold; others refuse and the caller falls back
CLASS zcl_ag2ui5_blob_source DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_blob_source.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_blob_source IMPLEMENTATION.

  METHOD zif_ag2ui5_blob_source~fetch.

    zcl_abapgit_git_transport=>upload_pack_by_commit(
      EXPORTING iv_url     = iv_url
                iv_hash    = iv_sha1
      IMPORTING et_objects = rt_objects ).

  ENDMETHOD.

ENDCLASS.
```

`zcl_ag2ui5_blob_source.clas.xml`: copy `src/zcl_ag2ui5_object_filter.clas.xml`
with `CLSNAME` `ZCL_AG2UI5_BLOB_SOURCE`, `DESCRIPT`
`abapGit2UI5 - Single Git objects`, and without `<CLSCCINCL>` (no local
definitions).

- [ ] **Step 3: Lint**

Run: `npm run check:abap` — Expected: `0 issue(s) found`.

- [ ] **Step 4: Create both on A4H25**

abapgit-mcp: `write_objects` with the four files, `package` `$ABAPGIT2UI5`,
first `dry_run: true`, then without. Both objects `active`, no errors.
Then smoke test in the scratchpad (`.sapcli/a4h25 abap run <file>`):

```abap
DATA(lt_objects) = NEW zcl_ag2ui5_blob_source( )->zif_ag2ui5_blob_source~fetch(
  iv_url  = `https://github.com/abapGit/abapGit.git`
  iv_sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
out->write( |{ lines( lt_objects ) } { lt_objects[ 1 ]-type }| ).
```

Expected: `1 blob`.

- [ ] **Step 5: Commit**

```bash
git add src/zif_ag2ui5_blob_source.* src/zcl_ag2ui5_blob_source.*
git commit -m "Add a source for single Git objects"
```

---

### Task 2: Rows carry the remote SHA1

**Files:**
- Modify: `src/zif_ag2ui5_repo_service.intf.abap` (`ty_status_row`, `ty_stage_item`)
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (new `remote_sha1`, `get_status`, `get_stage`)
- Test: `src/zcl_ag2ui5_repo_service.clas.testclasses.abap`

**Interfaces:**
- Produces: field `remote_sha1 TYPE string` in `ty_status_row` and
  `ty_stage_item`; `CLASS-METHODS remote_sha1 IMPORTING it_remote TYPE zif_abapgit_git_definitions=>ty_files_tt iv_path TYPE string iv_filename TYPE string RETURNING VALUE(rv_sha1) TYPE string` (public, lower case, empty when not found).

- [ ] **Step 1: Write the failing test** (new class at the end of the test include)

```abap
CLASS ltcl_remote_sha1 DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS found_lower_case FOR TESTING.
    METHODS missing_is_empty FOR TESTING.
ENDCLASS.

CLASS ltcl_remote_sha1 IMPLEMENTATION.
  METHOD found_lower_case.
    DATA(lt_remote) = VALUE zif_abapgit_git_definitions=>ty_files_tt(
      ( path = `/src/` filename = `zcl_a.clas.abap` sha1 = `84D35DD847B3DC2361F9EEA4CF2BDC76A8D1B349` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>remote_sha1( it_remote = lt_remote iv_path = `/src/` iv_filename = `zcl_a.clas.abap` )
      exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
  ENDMETHOD.
  METHOD missing_is_empty.
    DATA(lt_remote) = VALUE zif_abapgit_git_definitions=>ty_files_tt(
      ( path = `/src/` filename = `zcl_a.clas.abap` sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ) ).
    cl_abap_unit_assert=>assert_initial(
      zcl_ag2ui5_repo_service=>remote_sha1( it_remote = lt_remote iv_path = `/src/` iv_filename = `zcl_b.clas.abap` ) ).
  ENDMETHOD.
ENDCLASS.
```

- [ ] **Step 2: Lint shows it fails**

Run: `npm run check:abap` — Expected: error, `remote_sha1` not found.

- [ ] **Step 3: Implement**

Interface, in `ty_status_row` after `changed_by` and in `ty_stage_item`
after `changed_by`:

```abap
      "! SHA1 of the file in Git; empty when it is not in Git or the
      "! repository is offline
      remote_sha1 TYPE string,
```

Service, PUBLIC SECTION next to `remote_is_new`:

```abap
    "! The file's SHA1 in a remote file list, lower case; empty when the
    "! file is not in Git
    CLASS-METHODS remote_sha1
      IMPORTING
        it_remote      TYPE zif_abapgit_git_definitions=>ty_files_tt
        iv_path        TYPE string
        iv_filename    TYPE string
      RETURNING
        VALUE(rv_sha1) TYPE string.
```

```abap
  METHOD remote_sha1.
    READ TABLE it_remote INTO DATA(ls_file)
      WITH KEY file_path COMPONENTS path = iv_path filename = iv_filename.
    IF sy-subrc = 0.
      rv_sha1 = to_lower( ls_file-sha1 ).
    ENDIF.
  ENDMETHOD.
```

`get_status`: before the existing `LOOP AT rs_status-rows ASSIGNING
FIELD-SYMBOL(<ls_row>)`, read the list `calculate( )` has already fetched,
and fill the field inside that loop:

```abap
    " calculate( ) fetched the remote files already: no second request
    DATA lt_remote TYPE zif_abapgit_git_definitions=>ty_files_tt.
    IF rs_status-offline = abap_false.
      lt_remote = li_repo->get_files_remote( ).
    ENDIF.
```

```abap
      <ls_row>-remote_sha1 = remote_sha1( it_remote = lt_remote iv_path = <ls_row>-path
                                          iv_filename = <ls_row>-filename ).
```

`get_stage`: inside the existing `LOOP AT rs_stage-items ASSIGNING
FIELD-SYMBOL(<ls_row>)` (the object link loop):

```abap
      <ls_row>-remote_sha1 = remote_sha1( it_remote = ls_files-remote iv_path = <ls_row>-path
                                          iv_filename = <ls_row>-filename ).
```

- [ ] **Step 4: Lint passes**

Run: `npm run check` — Expected: abaplint 0 issues, abap2UI5 linter 0 errors.

- [ ] **Step 5: Commit**

```bash
git add src/zif_ag2ui5_repo_service.intf.abap src/zcl_ag2ui5_repo_service.clas.abap src/zcl_ag2ui5_repo_service.clas.testclasses.abap
git commit -m "Give Status and Stage rows the file's SHA1 in Git"
```

---

### Task 3: `get_diff` fetches a single file

**Files:**
- Modify: `src/zif_ag2ui5_repo_service.intf.abap` (`get_diff`)
- Modify: `src/zcl_ag2ui5_repo_service.clas.abap` (`get_diff`, `read_file_pair`, new `remote_file`, `checked_blob`, `blob_source`, `request_start`, static data)
- Test: `src/zcl_ag2ui5_repo_service.clas.testclasses.abap`

**Interfaces:**
- Consumes: `zif_ag2ui5_blob_source` (Task 1), `remote_sha1` field (Task 2).
- Produces: `get_diff( ... iv_remote_sha1 TYPE string OPTIONAL iv_remote_known TYPE abap_bool DEFAULT abap_false )`.

- [ ] **Step 1: Write the failing tests**

Near the other `LOCAL FRIENDS` declarations:

```abap
CLASS ltcl_remote_file DEFINITION DEFERRED.
CLASS zcl_ag2ui5_repo_service DEFINITION LOCAL FRIENDS ltcl_remote_file.
```

Doubles and tests at the end of the include:

```abap
"! An online or offline repository that counts full fetches
CLASS ltd_remote_repo DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo PARTIALLY IMPLEMENTED.
    INTERFACES zif_abapgit_repo_online PARTIALLY IMPLEMENTED.
    DATA mv_offline TYPE abap_bool.
    DATA mv_full_fetches TYPE i.
    DATA mt_remote TYPE zif_abapgit_git_definitions=>ty_files_tt.
ENDCLASS.

CLASS ltd_remote_repo IMPLEMENTATION.
  METHOD zif_abapgit_repo~is_offline.
    rv_offline = mv_offline.
  ENDMETHOD.
  METHOD zif_abapgit_repo_online~get_url.
    rv_url = `https://example.org/repo.git`.
  ENDMETHOD.
  METHOD zif_abapgit_repo~get_files_remote.
    mv_full_fetches = mv_full_fetches + 1.
    rt_files = mt_remote.
  ENDMETHOD.
ENDCLASS.

"! Returns given objects or raises a given text, and counts requests
CLASS ltd_blob_source DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_blob_source.
    DATA mt_objects TYPE zif_abapgit_definitions=>ty_objects_tt.
    DATA mv_error TYPE string.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_blob_source IMPLEMENTATION.
  METHOD zif_ag2ui5_blob_source~fetch.
    mv_calls = mv_calls + 1.
    IF mv_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_error ).
    ENDIF.
    rt_objects = mt_objects.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_remote_file DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_repo TYPE REF TO ltd_remote_repo.
    DATA mo_source TYPE REF TO ltd_blob_source.
    DATA mv_data TYPE xstring.
    DATA mv_sha1 TYPE string.
    METHODS setup RAISING zcx_abapgit_exception.
    METHODS teardown.
    METHODS read
      IMPORTING iv_sha1  TYPE string OPTIONAL
                iv_known TYPE abap_bool DEFAULT abap_true
      EXPORTING ev_data  TYPE xstring
                ev_found TYPE abap_bool
      RAISING   zcx_abapgit_exception.
    METHODS known_hash_fetches_blob FOR TESTING RAISING zcx_abapgit_exception.
    METHODS second_read_cached FOR TESTING RAISING zcx_abapgit_exception.
    METHODS wrong_content_falls_back FOR TESTING RAISING zcx_abapgit_exception.
    METHODS refused_falls_back FOR TESTING RAISING zcx_abapgit_exception.
    METHODS login_error_no_fallback FOR TESTING RAISING zcx_abapgit_exception.
    METHODS known_empty_not_in_git FOR TESTING RAISING zcx_abapgit_exception.
    METHODS unknown_uses_full_fetch FOR TESTING RAISING zcx_abapgit_exception.
    METHODS offline_ignores_known FOR TESTING RAISING zcx_abapgit_exception.
    METHODS invalid_hash_skips_request FOR TESTING RAISING zcx_abapgit_exception.
    METHODS upper_case_hash_lowered FOR TESTING RAISING zcx_abapgit_exception.
    METHODS empty_blob_is_found FOR TESTING RAISING zcx_abapgit_exception.
    METHODS two_objects_refused FOR TESTING.
    METHODS commit_object_refused FOR TESTING.
ENDCLASS.

CLASS ltcl_remote_file IMPLEMENTATION.
  METHOD setup.
    mv_data = zcl_abapgit_convert=>string_to_xstring_utf8( |hello\n| ).
    mv_sha1 = to_lower( zcl_abapgit_hash=>sha1_blob( mv_data ) ).
    mo_repo = NEW #( ).
    mo_repo->mt_remote = VALUE #( ( path = `/src/` filename = `a.abap`
      data = zcl_abapgit_convert=>string_to_xstring_utf8( |full\n| ) ) ).
    mo_source = NEW #( ).
    mo_source->mt_objects = VALUE #( ( sha1 = mv_sha1 type = zif_abapgit_git_definitions=>c_type-blob data = mv_data ) ).
    zcl_ag2ui5_repo_service=>gi_blob_source = mo_source.
    CLEAR zcl_ag2ui5_repo_service=>gt_blobs.
  ENDMETHOD.

  METHOD teardown.
    CLEAR: zcl_ag2ui5_repo_service=>gi_blob_source, zcl_ag2ui5_repo_service=>gt_blobs.
  ENDMETHOD.

  METHOD read.
    NEW zcl_ag2ui5_repo_service( )->remote_file(
      EXPORTING ii_repo         = mo_repo
                ii_filter       = NEW zcl_ag2ui5_object_filter( )
                iv_path         = `/src/`
                iv_filename     = `a.abap`
                iv_remote_sha1  = iv_sha1
                iv_remote_known = iv_known
      IMPORTING ev_data         = ev_data
                ev_found        = ev_found ).
  ENDMETHOD.

  METHOD known_hash_fetches_blob.
    read( EXPORTING iv_sha1 = mv_sha1 IMPORTING ev_data = DATA(lv_data) ev_found = DATA(lv_found) ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = mv_data ).
    cl_abap_unit_assert=>assert_true( lv_found ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_full_fetches exp = 0 ).
  ENDMETHOD.

  METHOD second_read_cached.
    read( iv_sha1 = mv_sha1 ).
    read( iv_sha1 = mv_sha1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_source->mv_calls exp = 1 ).
  ENDMETHOD.

  METHOD wrong_content_falls_back.
    mo_source->mt_objects[ 1 ]-data = zcl_abapgit_convert=>string_to_xstring_utf8( |other\n| ).
    read( EXPORTING iv_sha1 = mv_sha1 IMPORTING ev_data = DATA(lv_data) ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = mo_repo->mt_remote[ 1 ]-data ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_full_fetches exp = 1 ).
  ENDMETHOD.

  METHOD refused_falls_back.
    mo_source->mv_error = `ERR upload-pack: not our ref`.
    read( EXPORTING iv_sha1 = mv_sha1 IMPORTING ev_data = DATA(lv_data) ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = mo_repo->mt_remote[ 1 ]-data ).
  ENDMETHOD.

  METHOD login_error_no_fallback.
    mo_source->mv_error = `Unauthorized access. Check your credentials`.
    TRY.
        read( iv_sha1 = mv_sha1 ).
        cl_abap_unit_assert=>fail( `login error expected` ).
      CATCH zcx_abapgit_exception.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_full_fetches exp = 0 ).
  ENDMETHOD.

  METHOD known_empty_not_in_git.
    read( IMPORTING ev_found = DATA(lv_found) ).
    cl_abap_unit_assert=>assert_false( lv_found ).
    cl_abap_unit_assert=>assert_equals( act = mo_source->mv_calls + mo_repo->mv_full_fetches exp = 0 ).
  ENDMETHOD.

  METHOD unknown_uses_full_fetch.
    read( EXPORTING iv_sha1 = mv_sha1 iv_known = abap_false IMPORTING ev_found = DATA(lv_found) ).
    cl_abap_unit_assert=>assert_true( lv_found ).
    cl_abap_unit_assert=>assert_equals( act = mo_source->mv_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_full_fetches exp = 1 ).
  ENDMETHOD.

  METHOD offline_ignores_known.
    mo_repo->mv_offline = abap_true.
    read( EXPORTING iv_sha1 = mv_sha1 IMPORTING ev_data = DATA(lv_data) ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = mo_repo->mt_remote[ 1 ]-data ).
    cl_abap_unit_assert=>assert_equals( act = mo_source->mv_calls exp = 0 ).
  ENDMETHOD.

  METHOD invalid_hash_skips_request.
    read( iv_sha1 = `../../etc` ).
    cl_abap_unit_assert=>assert_equals( act = mo_source->mv_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_full_fetches exp = 1 ).
  ENDMETHOD.

  METHOD upper_case_hash_lowered.
    read( EXPORTING iv_sha1 = to_upper( mv_sha1 ) IMPORTING ev_data = DATA(lv_data) ).
    cl_abap_unit_assert=>assert_equals( act = lv_data exp = mv_data ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_full_fetches exp = 0 ).
  ENDMETHOD.

  METHOD empty_blob_is_found.
    CLEAR mv_data.
    mv_sha1 = to_lower( zcl_abapgit_hash=>sha1_blob( mv_data ) ).
    mo_source->mt_objects = VALUE #( ( sha1 = mv_sha1 type = zif_abapgit_git_definitions=>c_type-blob ) ).
    read( EXPORTING iv_sha1 = mv_sha1 IMPORTING ev_data = DATA(lv_data) ev_found = DATA(lv_found) ).
    cl_abap_unit_assert=>assert_true( lv_found ).
    cl_abap_unit_assert=>assert_initial( lv_data ).
    cl_abap_unit_assert=>assert_equals( act = mo_repo->mv_full_fetches exp = 0 ).
  ENDMETHOD.

  METHOD two_objects_refused.
    INSERT mo_source->mt_objects[ 1 ] INTO TABLE mo_source->mt_objects.
    TRY.
        zcl_ag2ui5_repo_service=>checked_blob( it_objects = mo_source->mt_objects iv_sha1 = mv_sha1 ).
        cl_abap_unit_assert=>fail( `two objects must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD commit_object_refused.
    mo_source->mt_objects[ 1 ]-type = zif_abapgit_git_definitions=>c_type-commit.
    TRY.
        zcl_ag2ui5_repo_service=>checked_blob( it_objects = mo_source->mt_objects iv_sha1 = mv_sha1 ).
        cl_abap_unit_assert=>fail( `a commit object must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
```

- [ ] **Step 2: Lint shows it fails**

Run: `npm run check:abap` — Expected: errors for `remote_file`,
`checked_blob`, `gi_blob_source`, `gt_blobs`.

- [ ] **Step 3: Implement**

Interface `get_diff`, after `iv_remote_is_new`:

```abap
      "! The file's SHA1 in Git from a status or stage row
      iv_remote_sha1   TYPE string OPTIONAL
      "! The caller knows the remote side from such a row: the file is
      "! fetched alone, and an empty iv_remote_sha1 means "not in Git"
      iv_remote_known  TYPE abap_bool DEFAULT abap_false
```

Service PUBLIC SECTION next to `remote_sha1`:

```abap
    "! The one blob Git sent for iv_sha1, checked against the hash
    CLASS-METHODS checked_blob
      IMPORTING
        it_objects     TYPE zif_abapgit_definitions=>ty_objects_tt
        iv_sha1        TYPE string
      RETURNING
        VALUE(rv_data) TYPE xstring
      RAISING
        zcx_abapgit_exception.
```

PRIVATE SECTION:

```abap
    TYPES:
      BEGIN OF ty_blob,
        sha1 TYPE string,
        data TYPE xstring,
      END OF ty_blob,
      ty_blobs TYPE HASHED TABLE OF ty_blob WITH UNIQUE KEY sha1.
    "! Single files fetched in this request, cleared by request_start( )
    CLASS-DATA gt_blobs TYPE ty_blobs.
    "! Tests replace it
    CLASS-DATA gi_blob_source TYPE REF TO zif_ag2ui5_blob_source.

    CLASS-METHODS blob_source
      RETURNING
        VALUE(ri_source) TYPE REF TO zif_ag2ui5_blob_source.

    "! The file's remote side: fetched alone when a row gave its SHA1,
    "! otherwise (and when the server refuses) from the whole repository
    METHODS remote_file
      IMPORTING
        ii_repo         TYPE REF TO zif_abapgit_repo
        ii_filter       TYPE REF TO zif_abapgit_object_filter
        iv_path         TYPE string
        iv_filename     TYPE string
        iv_remote_sha1  TYPE string
        iv_remote_known TYPE abap_bool
      EXPORTING
        ev_data         TYPE xstring
        ev_found        TYPE abap_bool
      RAISING
        zcx_abapgit_exception.
```

Add `iv_remote_sha1 TYPE string OPTIONAL` and `iv_remote_known TYPE
abap_bool DEFAULT abap_false` to `read_file_pair`'s definition, and pass
them from `get_diff`:

```abap
    read_file_pair( EXPORTING ii_repo          = li_repo
                              iv_path          = iv_path
                              iv_filename      = iv_filename
                              iv_remote_sha1   = iv_remote_sha1
                              iv_remote_known  = iv_remote_known
                    IMPORTING ev_local         = DATA(lv_local)
                              ev_remote        = DATA(lv_remote) ).
```

`read_file_pair`: replace the remote loop with

```abap
    remote_file( EXPORTING ii_repo         = ii_repo
                           ii_filter       = li_filter
                           iv_path         = iv_path
                           iv_filename     = iv_filename
                           iv_remote_sha1  = iv_remote_sha1
                           iv_remote_known = iv_remote_known
                 IMPORTING ev_data         = ev_remote
                           ev_found        = DATA(lv_remote_found) ).
    IF lv_remote_found = abap_true.
      lv_found = abap_true.
    ENDIF.
```

New methods:

```abap
  METHOD remote_file.

    CLEAR: ev_data, ev_found.

    IF iv_remote_known = abap_true AND ii_repo->is_offline( ) = abap_false.
      IF iv_remote_sha1 IS INITIAL.
        " the row says the file is only in the system
        RETURN.
      ENDIF.
      DATA(lv_sha1) = to_lower( iv_remote_sha1 ).
      IF strlen( lv_sha1 ) = 40 AND lv_sha1 CO `0123456789abcdef`.
        READ TABLE gt_blobs INTO DATA(ls_blob) WITH TABLE KEY sha1 = lv_sha1.
        IF sy-subrc = 0.
          ev_data  = ls_blob-data.
          ev_found = abap_true.
          RETURN.
        ENDIF.
        TRY.
            ev_data = checked_blob(
              it_objects = blob_source( )->fetch( iv_url  = CAST zif_abapgit_repo_online( ii_repo )->get_url( )
                                                  iv_sha1 = CONV #( lv_sha1 ) )
              iv_sha1    = lv_sha1 ).
            INSERT VALUE #( sha1 = lv_sha1 data = ev_data ) INTO TABLE gt_blobs.
            ev_found = abap_true.
            RETURN.
          CATCH zcx_abapgit_exception INTO DATA(lx_error).
            " the full fetch would ask for the same credentials
            IF login_required( lx_error ) = abap_true.
              RAISE EXCEPTION lx_error.
            ENDIF.
            " a server that refuses single objects: the whole repository
        ENDTRY.
      ENDIF.
    ENDIF.

    LOOP AT ii_repo->get_files_remote( iv_ignore_files = abap_true
                                       ii_obj_filter   = ii_filter ) INTO DATA(ls_remote)
        USING KEY file_path WHERE path = iv_path AND filename = iv_filename.
      ev_data  = ls_remote-data.
      ev_found = abap_true.
      EXIT.
    ENDLOOP.

  ENDMETHOD.

  METHOD checked_blob.

    IF lines( it_objects ) <> 1.
      zcx_abapgit_exception=>raise( |Git sent { lines( it_objects ) } objects for { iv_sha1 }| ).
    ENDIF.
    DATA(ls_object) = it_objects[ 1 ].
    IF ls_object-type <> zif_abapgit_git_definitions=>c_type-blob
        OR to_lower( zcl_abapgit_hash=>sha1_blob( ls_object-data ) ) <> to_lower( iv_sha1 ).
      zcx_abapgit_exception=>raise( |Git sent another object for { iv_sha1 }| ).
    ENDIF.
    rv_data = ls_object-data.

  ENDMETHOD.

  METHOD blob_source.
    IF gi_blob_source IS NOT BOUND.
      gi_blob_source = NEW zcl_ag2ui5_blob_source( ).
    ENDIF.
    ri_source = gi_blob_source.
  ENDMETHOD.
```

`request_start`:

```abap
  METHOD request_start.
    zcl_abapgit_repo_srv=>get_instance( )->init( ).
    CLEAR gt_blobs.
  ENDMETHOD.
```

- [ ] **Step 4: Lint passes**

Run: `npm run check` — Expected: 0 issues.

- [ ] **Step 5: Deploy and run the service suite**

```sh
cd /home/chris/Projects/GIT/abapGit
./.sapcli/a4h25 interface write ZIF_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zif_ag2ui5_repo_service.intf.abap --activate
./.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.abap --activate
./.sapcli/a4h25 class write ZCL_AG2UI5_REPO_SERVICE /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_repo_service.clas.testclasses.abap
```

Back up the three sources (`class read` / `interface read`) into the
scratchpad first and check they equal `main`. Expected: 265/265 (250 + 2 + 13).

- [ ] **Step 6: Commit**

```bash
git add src/zif_ag2ui5_repo_service.intf.abap src/zcl_ag2ui5_repo_service.clas.abap src/zcl_ag2ui5_repo_service.clas.testclasses.abap
git commit -m "Fetch a single file for a diff when its SHA1 is known"
```

---

### Task 4: Diff page passes the SHA1

**Files:**
- Modify: `src/zcl_ag2ui5_app_diff.clas.abap` (`create`, PROTECTED data, `get_remote`, `load_diff`)
- Test: `src/zcl_ag2ui5_app_diff.clas.testclasses.abap`

**Interfaces:**
- Consumes: `get_diff( iv_remote_sha1, iv_remote_known )` (Task 3).
- Produces: `create( ... iv_remote_sha1 TYPE string OPTIONAL iv_remote_known TYPE abap_bool DEFAULT abap_false )`;
  public `TYPES: BEGIN OF ty_remote, sha1 TYPE string, known TYPE abap_bool, END OF ty_remote.` and
  `METHODS get_remote RETURNING VALUE(rs_remote) TYPE ty_remote` (Task 5's tests read it).

- [ ] **Step 1: Write the failing test**

In `ltd_login_service` add `DATA mv_got_sha1 TYPE string. DATA mv_got_known TYPE abap_bool.`
and at the start of its `get_diff`:

```abap
    mv_got_sha1  = iv_remote_sha1.
    mv_got_known = iv_remote_known.
```

In `ltcl_login` add `METHODS remote_hash_reaches_service FOR TESTING.`:

```abap
  METHOD remote_hash_reaches_service.
    mo_app = zcl_ag2ui5_app_diff=>create( iv_key = `000000000001` iv_path = `/src/` iv_filename = `a.abap`
                                          iv_remote_sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349`
                                          iv_remote_known = abap_true ).
    mo_app->mi_service = mo_service.
    start( ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_got_sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
    cl_abap_unit_assert=>assert_true( mo_service->mv_got_known ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->get_remote( )-sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
  ENDMETHOD.
```

(`start( )` is the class's helper that runs `main` on init; if it creates
its own app, set `mo_app` the same way it does and assign `mi_service`
before `main`.)

- [ ] **Step 2: Lint shows it fails** — `npm run check:abap`: unknown parameters.

- [ ] **Step 3: Implement**

PUBLIC SECTION: the `ty_remote` type, `get_remote`, and the two `create`
parameters after `it_picked`:

```abap
        "! The file's SHA1 in Git, from the caller's server-side row
        iv_remote_sha1  TYPE string OPTIONAL
        "! The caller knows the remote side (see get_diff)
        iv_remote_known TYPE abap_bool DEFAULT abap_false
```

PROTECTED SECTION: `DATA ms_remote TYPE ty_remote.`

`create`: `ro_app->ms_remote = VALUE #( sha1 = iv_remote_sha1 known = iv_remote_known ).`

`get_remote`: `rs_remote = ms_remote.`

`load_diff`: add to the `get_diff` call

```abap
          iv_remote_sha1   = ms_remote-sha1
          iv_remote_known  = ms_remote-known
```

- [ ] **Step 4: Lint passes** — `npm run check`.

- [ ] **Step 5: Deploy, run, commit**

```sh
./.sapcli/a4h25 class write ZCL_AG2UI5_APP_DIFF <main> --activate
./.sapcli/a4h25 class write ZCL_AG2UI5_APP_DIFF <testclasses> --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_app_diff.clas.testclasses.abap
```

(back up both first). Expected: all pass, one more than before.

```bash
git add src/zcl_ag2ui5_app_diff.clas.abap src/zcl_ag2ui5_app_diff.clas.testclasses.abap
git commit -m "Hand the file's SHA1 from the diff page to the service"
```

---

### Task 5: Stage, Status and repository Diff pass the server's SHA1

**Files:**
- Modify: `src/zcl_ag2ui5_app_stage.clas.abap` (PROTECTED `mt_remote`, `load_stage`, `DIFF`, `PATCH`)
- Modify: `src/zcl_ag2ui5_app_status.clas.abap` (`DIFF`, `SEMANTIC`)
- Modify: `src/zcl_ag2ui5_app_repo_diff.clas.abap` (`open`, panel `get_diff`)
- Test: the three `.clas.testclasses.abap`

**Interfaces:**
- Consumes: `remote_sha1` in rows (Task 2), `zcl_ag2ui5_app_diff=>create( iv_remote_sha1, iv_remote_known )` and `get_remote( )` (Task 4), `get_diff( iv_remote_sha1, iv_remote_known )` (Task 3).

- [ ] **Step 1: Write the failing tests**

Stage (`ltcl_patch`):

```abap
    METHODS patch_uses_server_hash FOR TESTING.
    METHODS load_keeps_hashes FOR TESTING.
```

```abap
  METHOD patch_uses_server_hash.
    mo_app->mt_remote = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap`
                                   sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ) ).
    mo_client->mv_event = `PATCH`.
    mo_client->mv_arg1 = `/src/`.
    mo_client->mv_arg2 = `zcl_a.clas.abap`.
    mo_app->z2ui5_if_app~main( mo_client ).
    DATA(ls_remote) = CAST zcl_ag2ui5_app_diff( mo_client->mv_called )->get_remote( ).
    cl_abap_unit_assert=>assert_equals( act = ls_remote-sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
    cl_abap_unit_assert=>assert_true( ls_remote-known ).
  ENDMETHOD.

  METHOD load_keeps_hashes.
    mo_service->ms_stage-items = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` action = `ADD` lstate = `M`
                                             remote_sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` )
                                           ( path = `/src/` filename = `zcl_b.clas.abap` action = `ADD` lstate = `A` ) ).
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_remote ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_remote[ path = `/src/` filename = `zcl_b.clas.abap` ]-sha1 ).
  ENDMETHOD.
```

(If `ltcl_patch`'s setup fills `mv_arg1`/`mv_arg2` differently, use the
names of its `ltd_client`: `get_event_arg` returns `mv_arg1` for 1 and
`mv_arg2` otherwise.)

Status (`ltcl_object_links`):

```abap
    METHODS diff_uses_server_hash FOR TESTING.
```

```abap
  METHOD diff_uses_server_hash.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->client = lo_client.
    lo_app->mt_status = VALUE #( ( obj_type = `CLAS` obj_name = `ZCL_A` path = `/src/` filename = `zcl_a.clas.abap`
                                   remote_sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ) ).
    lo_app->rows_build( ).
    lo_client->mv_event = `DIFF`.
    lo_client->mt_args = VALUE #( ( `/src/` ) ( `zcl_a.clas.abap` ) ).
    lo_app->on_event( ).
    DATA(ls_remote) = CAST zcl_ag2ui5_app_diff( lo_client->mo_called )->get_remote( ).
    cl_abap_unit_assert=>assert_equals( act = ls_remote-sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
    cl_abap_unit_assert=>assert_true( ls_remote-known ).
  ENDMETHOD.
```

Repository Diff: in its `ltd_service` record `iv_remote_sha1` /
`iv_remote_known` of the last `get_diff` call (`DATA mv_got_sha1 TYPE
string. DATA mv_got_known TYPE abap_bool.`), give `files( )`' first row
`remote_sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349``, and add
`METHODS panel_passes_hash FOR TESTING.`:

```abap
  METHOD panel_passes_hash.
    app( files( 1 ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_got_sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
    cl_abap_unit_assert=>assert_true( mo_service->mv_got_known ).
    fire( iv_event = `OPEN` iv_arg1 = `1` ).
    cl_abap_unit_assert=>assert_true( CAST zcl_ag2ui5_app_diff( mo_client->mo_called )->get_remote( )-known ).
  ENDMETHOD.
```

- [ ] **Step 2: Lint shows it fails** — `npm run check:abap`.

- [ ] **Step 3: Implement**

Stage, PROTECTED SECTION:

```abap
    TYPES:
      BEGIN OF ty_remote,
        path     TYPE string,
        filename TYPE string,
        sha1     TYPE string,
      END OF ty_remote,
      ty_remotes TYPE HASHED TABLE OF ty_remote WITH UNIQUE KEY path filename.
    "! Each file's SHA1 in Git from the service - mt_rows comes back from
    "! the browser, so the diff page never takes the hash from there
    DATA mt_remote TYPE ty_remotes.
```

`load_stage`: `CLEAR: mt_rows, mt_patches, mt_remote.` and inside the item loop
`INSERT VALUE #( path = ls_item-path filename = ls_item-filename sha1 = ls_item-remote_sha1 ) INTO TABLE mt_remote.`

`DIFF` and `PATCH`: before `nav_app_call`

```abap
          READ TABLE mt_remote INTO DATA(ls_remote)
            WITH TABLE KEY path = ls_row-path filename = ls_row-filename.
          DATA(lv_known) = xsdbool( sy-subrc = 0 ).
```

and add to both `create` calls
`iv_remote_sha1 = ls_remote-sha1 iv_remote_known = lv_known`. (Declare
`ls_remote` / `lv_known` once at the top of `on_event` with `DATA` to avoid
a second inline declaration; clear `ls_remote` before each `READ`.)

Status, `DIFF` (after the row is found):

```abap
          READ TABLE mt_status INTO DATA(ls_server)
            WITH KEY path = ls_row-path filename = ls_row-filename.
```

pass `iv_remote_sha1 = ls_server-remote_sha1 iv_remote_known = xsdbool( sy-subrc = 0 )`
— compute the flag into a variable right after the `READ`, before the
`create` call. `SEMANTIC` already reads `ls_semantic_file` from `mt_status`:
pass `iv_remote_sha1 = ls_semantic_file-remote_sha1 iv_remote_known = abap_true`.

Repository Diff: `open` and the panel's `get_diff` pass
`iv_remote_sha1 = ls_source-remote_sha1 iv_remote_known = abap_true`
(`mt_source` is PROTECTED and comes from the Status page's `mt_status`).
Status's object overview `get_diff` (around line 931) stays unchanged.

- [ ] **Step 4: Lint passes** — `npm run check`.

- [ ] **Step 5: Deploy, run, commit**

Back up, then write main and test includes of `ZCL_AG2UI5_APP_STAGE`,
`ZCL_AG2UI5_APP_STATUS`, `ZCL_AG2UI5_APP_REPO_DIFF`; run their suites and
the other suites listed in `AGENTS-LOCAL.md` (all must pass).

```bash
git add src/zcl_ag2ui5_app_stage.* src/zcl_ag2ui5_app_status.* src/zcl_ag2ui5_app_repo_diff.*
git commit -m "Open diffs with the SHA1 the server listed"
```

---

### Task 6: Live check, docs

**Files:**
- Modify: `AGENTS.md` (design rule), `docs/findings.md` (if it lists the fetch cost), `AGENTS-LOCAL.md` (local note, Git-ignored)
- Delete at merge: the spec and this plan

- [ ] **Step 1: Readbacks** — every written source read back from A4H25 equals the file.

- [ ] **Step 2: Timing on `$ABAPGIT`** — rerun the scratchpad timing snippet:
`get_diff` for `/src/repo/zcl_abapgit_repo_pull.clas.abap` with and without
`iv_remote_sha1`/`iv_remote_known` after `request_start( )`. Expected: about
1,200 ms without, about 400 ms with.

- [ ] **Step 3: Chrome on `$AG2UI5_TEST`** — local comment in
`ZIF_ABAPGIT_UNIT_TEST`, Stage → Pick lines and Diff show the change;
Status → Diff; repository Diff panel. Optional: an ARC-1 HTTP trace
(`diagnose trace_start`) of the Pick lines click shows no full fetch.
Restore the interface source afterwards.

- [ ] **Step 4: Offline** — Status → Diff on `$TEST_OFFLINE` with its ZIP
still works (no blob request).

- [ ] **Step 5: AGENTS.md** — add after the **Offline ZIPs** bullet:

```markdown
- **Single-file diffs:** Status and Stage rows carry `remote_sha1`. The
  apps keep it server-side (Stage `mt_remote`, Status `mt_status`, Repo
  diff `mt_source`) and pass it to `get_diff` with `iv_remote_known`, which
  fetches only that blob (`ZIF_AG2UI5_BLOB_SOURCE`), checks it with
  `checked_blob` and caches it per request. Refusals fall back to the full
  fetch; login errors do not. Commit/push and the object overview keep the
  full fetch.
```

- [ ] **Step 6: Commit and report**

```bash
git add AGENTS.md docs/
git commit -m "Document single-file diffs"
```

Report results to Chris and ask "merge and push?".
