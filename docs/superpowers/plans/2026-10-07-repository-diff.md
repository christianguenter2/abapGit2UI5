# Repository Diff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A page that shows every changed file of a repository as collapsible diff panels, opened from the status page.

**Architecture:** New abap2UI5 app `ZCL_AG2UI5_APP_REPO_DIFF`. It receives the changed status rows, keeps them PROTECTED, and loads each file's diff on demand through the existing `get_diff`. One bound table of files with nested line tables renders the panels through a template. The status page gets a Diff button in its table toolbar.

**Tech Stack:** ABAP on A4H25, abap2UI5 1.146.0 (view builder, `_bind`, `_event`), ABAP Unit, abaplint + abap2ui5lint (`npm run check`), abapgit-mcp `write_objects` to create the new class.

**Spec:** `docs/superpowers/specs/2026-10-07-repository-diff-design.md`

## Global Constraints

- No new service method; files load through `zif_ag2ui5_repo_service~get_diff`.
- First 3 files load on start; Expand all stops at 25 expanded files.
- Event arguments are indexes into the PROTECTED file table; anything else is ignored.
- Only bound data is PUBLIC (AGENTS.md); keys, ZIP and raw lines stay PROTECTED.
- Nothing is written; no line picking.
- Page header is an `OverflowToolbar` in `customHeader` with a NeverOverflow Back button (AGENTS.md).
- A boolean event argument arrives as `X` or space; tests send the same (AGENTS.md). Accept `true` too.
- New class with test include is created via abapgit-mcp `write_objects` (dry run first) in `$ABAPGIT2UI5`; existing classes over ADT (`.sapcli/a4h25 class write ... --activate`).
- Work in the worktree `/home/chris/Projects/GIT/abapGit2UI5-repo-diff` (branch `feature/repo-diff`); never switch branches in the shared checkout. Link `node_modules` from `../abapGit2UI5` for `npm run check`, remove the link afterwards.

## Review Focus

1. A file whose `get_diff` raises must not stop the others; its panel shows the text — test `failing_file_isolated`.
2. Collapsing an already collapsed panel or expanding a loaded one must not reload or duplicate rows — test `expand_twice_loads_once`.
3. Panel header data comes from the browser (two-way binding of the public file table); Open must use the PROTECTED source row, not the posted one — test `open_uses_server_row`.
4. Layout switch with collapsed panels must not load them — test `layout_keeps_collapsed`.
5. An offline repository without ZIP must not open the page — status test `diff_disabled_offline_without_zip`.

---

### Task 1: `ZCL_AG2UI5_APP_REPO_DIFF` model: files, loading, expand/collapse, summary, layout, Open

**Files:**
- Create: `src/zcl_ag2ui5_app_repo_diff.clas.abap`, `src/zcl_ag2ui5_app_repo_diff.clas.testclasses.abap`, `src/zcl_ag2ui5_app_repo_diff.clas.xml`

**Interfaces:**
- Consumes: `zif_ag2ui5_repo_service~get_diff( iv_key iv_path iv_filename iv_remote_is_new iv_zip ) -> ty_diff`; `zcl_ag2ui5_repo_service=>compact / code_html / tinted_html / to_side_by_side / remote_is_new`; `zcl_ag2ui5_app_diff=>create( ... )`.
- Produces: `zcl_ag2ui5_app_repo_diff=>create( iv_key TYPE string iv_title TYPE string iv_zip TYPE xstring OPTIONAL it_files TYPE zif_ag2ui5_repo_service=>ty_status_rows ) RETURNING ro_app`; public `mt_files TYPE ty_files` (component `file` = path && filename); public `mi_service` for tests (as in the other apps: check `zcl_ag2ui5_app_diff` for the service attribute name and copy the same pattern).

- [ ] **Step 1: Write the class XML and a stub class** (`create` returns an object; every other method empty), so the test include can exist. XML:

```xml
<?xml version="1.0" encoding="utf-8"?>
<abapGit version="v1.0.0" serializer="LCL_OBJECT_CLAS" serializer_version="v1.0.0">
 <asx:abap xmlns:asx="http://www.sap.com/abapxml" version="1.0">
  <asx:values>
   <VSEOCLASS>
    <CLSNAME>ZCL_AG2UI5_APP_REPO_DIFF</CLSNAME>
    <LANGU>E</LANGU>
    <DESCRIPT>abapGit2UI5 - Diff of all changed files</DESCRIPT>
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
(Copy the BOM-less form of `zcl_ag2ui5_app_diff.clas.xml`.)

The stub's definition is the final PUBLIC/PROTECTED definition from Step 4 with empty method bodies.

- [ ] **Step 2: Write the tests** (`zcl_ag2ui5_app_repo_diff.clas.testclasses.abap`): a client double (copy `ltd_client` from `zcl_ag2ui5_app_diff.clas.testclasses.abap`, add `mo_called TYPE REF TO z2ui5_if_app` set in `nav_app_call`, `mv_toast` in `message_toast_display`) and a service double:

```abap
"! get_diff double: path /bin/ is binary, /fail/ raises, others give
"! one changed line (local) per call
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mt_calls TYPE string_table.
ENDCLASS.

CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~get_diff.
    INSERT |{ iv_path }{ iv_filename }| INTO TABLE mt_calls.
    IF iv_path = `/fail/`.
      zcx_abapgit_exception=>raise( `Cannot read file` ).
    ENDIF.
    IF iv_path = `/bin/`.
      rs_diff-binary = abap_true.
      RETURN.
    ENDIF.
    rs_diff-remote_is_new = iv_remote_is_new.
    rs_diff-lines = VALUE #(
      ( local_num = `1` remote_num = `1` text = `same` kind = zif_ag2ui5_repo_service=>c_line_kind-same )
      ( local_num = `2` text = `new` kind = zif_ag2ui5_repo_service=>c_line_kind-local ) ).
    rs_diff-local_count = 1.
  ENDMETHOD.
ENDCLASS.
```
(Check the name of the unchanged line kind in `zif_ag2ui5_repo_service=>c_line_kind` and use it.)

Test class `ltcl_repo_diff` (friend of the app), helper `files( iv_count )` building `iv_count` rows `/src/` + `f<n>.abap` with `lstate = 'M'`, helper `fire( iv_event, iv_arg1, iv_arg2 )`, and:

```abap
  METHOD start_loads_first_three.
    DATA(lo_app) = app( files( 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 3 ).
    cl_abap_unit_assert=>assert_true( lo_app->mt_files[ 3 ]-expanded ).
    cl_abap_unit_assert=>assert_false( lo_app->mt_files[ 4 ]-expanded ).
    cl_abap_unit_assert=>assert_initial( lo_app->mt_files[ 4 ]-lines ).
    cl_abap_unit_assert=>assert_not_initial( lo_app->mt_files[ 1 ]-lines ).
  ENDMETHOD.

  METHOD expand_loads_collapse_clears.
    DATA(lo_app) = app( files( 5 ) ).
    fire( iv_event = `PANEL` iv_arg1 = `4` iv_arg2 = `X` ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mt_files[ 4 ]-lines ).
    fire( iv_event = `PANEL` iv_arg1 = `4` iv_arg2 = `` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 4 ]-lines ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_files[ 4 ]-counts exp = `+1 −0` ).
  ENDMETHOD.

  METHOD expand_twice_loads_once.
    app( files( 2 ) ).
    fire( iv_event = `PANEL` iv_arg1 = `1` iv_arg2 = `X` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_files[ 1 ]-lines ) exp = 2 ).
  ENDMETHOD.

  METHOD expand_all_stops_at_limit.
    app( files( 30 ) ).
    fire( `EXPAND_ALL` ).
    DATA(lv_open) = REDUCE i( INIT n = 0 FOR f IN mo_app->mt_files WHERE ( expanded = abap_true ) NEXT n = n + 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_open exp = 25 ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_toast exp = `*5 files stay collapsed*` ).
    fire( `COLLAPSE_ALL` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 1 ]-lines ).
  ENDMETHOD.

  METHOD forged_index_ignored.
    app( files( 2 ) ).
    LOOP AT VALUE string_table( ( `0` ) ( `3` ) ( `-1` ) ( `x` ) ( `` ) ) INTO DATA(lv_arg).
      fire( iv_event = `PANEL` iv_arg1 = lv_arg iv_arg2 = `X` ).
      fire( iv_event = `OPEN` iv_arg1 = lv_arg ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
  ENDMETHOD.

  METHOD failing_file_isolated.
    app( VALUE #( ( path = `/fail/` filename = `a.abap` lstate = `M` )
                  ( path = `/bin/`  filename = `b.png`  lstate = `M` )
                  ( path = `/src/`  filename = `c.abap` lstate = `M` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_files[ 1 ]-note exp = `Cannot read file` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_files[ 2 ]-note exp = `Binary file - no line diff` ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mt_files[ 3 ]-lines ).
  ENDMETHOD.

  METHOD layout_switch_rebuilds.
    app( files( 4 ) ).
    mo_app->mv_layout = `SBS`.
    fire( `LAYOUT` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 1 ]-lines ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mt_files[ 1 ]-sbs ).
  ENDMETHOD.

  METHOD layout_keeps_collapsed.
    app( files( 4 ) ).
    mo_app->mv_layout = `SBS`.
    fire( `LAYOUT` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 3 ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 4 ]-sbs ).
  ENDMETHOD.

  METHOD open_uses_server_row.
    app( files( 2 ) ).
    " the posted model is not trusted
    mo_app->mt_files[ 2 ]-file = `/evil/x.abap`.
    fire( iv_event = `OPEN` iv_arg1 = `2` ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-file exp = `/src/f2.abap` ).
  ENDMETHOD.

  METHOD summary_counts_loaded.
    app( files( 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-summary exp = `5 files · +3 −0 (2 not loaded)` ).
  ENDMETHOD.

  METHOD back_leaves.
    app( files( 1 ) ).
    fire( `BACK` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
  ENDMETHOD.
```
`app( it_files )` creates the app through `create( iv_key = `1` iv_title = `repo` it_files = it_files )`, sets `mi_service = mo_service`, sets `mo_app`, runs `main( )` with `check_on_init` true (the client double must return `mv_init`), then switches the double to events. Check how `zcl_ag2ui5_app_diff`'s test double answers `check_on_init` / `check_on_event` and mirror it.

Note on `ms_head-file`: verify the field name `file` in `zcl_ag2ui5_app_diff=>ty_head` (it is `path && filename` there); adjust the assertion to what that app fills.

- [ ] **Step 3: Create the class on A4H25 (RED).** With abapgit-mcp: `serialize_object` is not needed (new object). `write_objects` with `dry_run: true`, package `$ABAPGIT2UI5`, files `zcl_ag2ui5_app_repo_diff.clas.abap` (stub), `.clas.testclasses.abap`, `.clas.xml`; check the plan; then without `dry_run`. Then:

```sh
cd /home/chris/Projects/GIT/abapGit
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5-repo-diff/src/zcl_ag2ui5_app_repo_diff.clas.testclasses.abap
```
Expected: FAIL, the assertions fail (stub), no syntax errors.

- [ ] **Step 4: Implement.** Definition:

```abap
"! All changed files of a repository: one collapsible diff panel per file
CLASS zcl_ag2ui5_app_repo_diff DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_line,
        remote_num TYPE string,
        local_num  TYPE string,
        marker     TYPE string,
        code_html  TYPE string,
        highlight  TYPE string,
      END OF ty_line,
      ty_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_sbs_line,
        system_num    TYPE string,
        system_html   TYPE string,
        system_marker TYPE string,
        system_state  TYPE string,
        git_num       TYPE string,
        git_html      TYPE string,
        git_marker    TYPE string,
        git_state     TYPE string,
        highlight     TYPE string,
      END OF ty_sbs_line,
      ty_sbs_lines TYPE STANDARD TABLE OF ty_sbs_line WITH EMPTY KEY.
    TYPES:
      "! One panel; the browser sends INDEX back, nothing else is trusted
      BEGIN OF ty_file,
        index       TYPE i,
        file        TYPE string,
        object_text TYPE string,
        object_link TYPE string,
        state       TYPE string,
        "! +x −y once loaded
        counts      TYPE string,
        expanded    TYPE abap_bool,
        "! Binary file, or the error of the load
        note        TYPE string,
        "! Only the current layout's rows are filled, only while expanded
        lines       TYPE ty_lines,
        sbs         TYPE ty_sbs_lines,
      END OF ty_file,
      ty_files TYPE STANDARD TABLE OF ty_file WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_head,
        title        TYPE string,
        summary      TYPE string,
        remote_label TYPE string,
      END OF ty_head.

    CONSTANTS c_initial TYPE i VALUE 3.
    CONSTANTS c_max_expanded TYPE i VALUE 25.

    DATA ms_head TYPE ty_head.
    DATA mt_files TYPE ty_files.
    "! INLINE or SBS
    DATA mv_layout TYPE string VALUE `INLINE`.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
        iv_title      TYPE string
        iv_zip        TYPE xstring OPTIONAL
        it_files      TYPE zif_ag2ui5_repo_service=>ty_status_rows
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_repo_diff.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF ty_loaded,
        index         TYPE i,
        remote_is_new TYPE abap_bool,
        lines         TYPE zif_ag2ui5_repo_service=>ty_diff_lines,
        new_count     TYPE i,
        old_count     TYPE i,
      END OF ty_loaded,
      ty_loaded_tab TYPE SORTED TABLE OF ty_loaded WITH UNIQUE KEY index.

    DATA client TYPE REF TO z2ui5_if_client.
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.
    DATA mv_key TYPE string.
    DATA mv_zip TYPE xstring.
    "! The files as the status page handed them over; the source of truth
    DATA mt_source TYPE zif_ag2ui5_repo_service=>ty_status_rows.
    "! Every loaded file's lines - serialized with the app, never sent
    DATA mt_loaded TYPE ty_loaded_tab.

    METHODS service RETURNING VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.
    METHODS on_event.
    "! The index from the browser, or 0 when it names no file
    METHODS checked_index IMPORTING iv_arg TYPE string RETURNING VALUE(rv_index) TYPE i.
    METHODS expand IMPORTING iv_index TYPE i.
    METHODS collapse IMPORTING iv_index TYPE i.
    METHODS rows_build IMPORTING iv_index TYPE i.
    METHODS summary_build.
    METHODS view_display.
    CLASS-METHODS state_text
      IMPORTING iv_lstate TYPE string iv_rstate TYPE string
      RETURNING VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
ENDCLASS.
```
(If the other apps hold the service as a PUBLIC `mi_service` used by tests, follow that instead and note it.)

Implementation (key methods):

```abap
  METHOD create.
    ro_app = NEW #( ).
    ro_app->mv_key = iv_key.
    ro_app->mv_zip = iv_zip.
    ro_app->mt_source = it_files.
    ro_app->ms_head-title = |Diff – { iv_title }|.
    ro_app->ms_head-remote_label = COND #( WHEN iv_zip IS NOT INITIAL THEN `ZIP` ELSE `Git` ).
    LOOP AT it_files INTO DATA(ls_file).
      INSERT VALUE #( index       = sy-tabix
                      file        = ls_file-path && ls_file-filename
                      object_text = COND #( WHEN ls_file-obj_type IS NOT INITIAL THEN |{ ls_file-obj_type } { ls_file-obj_name }| )
                      object_link = ls_file-object_link
                      state       = state_text( iv_lstate = ls_file-lstate iv_rstate = ls_file-rstate ) )
        INTO TABLE ro_app->mt_files.
    ENDLOOP.
  ENDMETHOD.

  METHOD service.
    IF mi_service IS NOT BOUND.
      mi_service = NEW zcl_ag2ui5_repo_service( ).
    ENDIF.
    ri_service = mi_service.
  ENDMETHOD.

  METHOD z2ui5_if_app~main.
    me->client = client.
    IF client->check_on_init( ).
      DO nmin( val1 = c_initial val2 = lines( mt_files ) ) TIMES.
        expand( sy-index ).
      ENDDO.
      summary_build( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.
  ENDMETHOD.

  METHOD checked_index.
    IF iv_arg CO `0123456789` AND iv_arg IS NOT INITIAL AND strlen( iv_arg ) <= 6.
      rv_index = iv_arg.
    ENDIF.
    IF rv_index < 1 OR rv_index > lines( mt_source ).
      rv_index = 0.
    ENDIF.
  ENDMETHOD.

  METHOD expand.
    ASSIGN mt_files[ iv_index ] TO FIELD-SYMBOL(<ls_file>).
    <ls_file>-expanded = abap_true.
    IF NOT line_exists( mt_loaded[ index = iv_index ] ) AND <ls_file>-note IS INITIAL.
      DATA(ls_source) = mt_source[ iv_index ].
      DATA(lv_remote_is_new) = zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = ls_source-lstate
                                                                      iv_rstate = ls_source-rstate ).
      TRY.
          DATA(ls_diff) = service( )->get_diff( iv_key           = mv_key
                                                iv_path          = ls_source-path
                                                iv_filename      = ls_source-filename
                                                iv_remote_is_new = lv_remote_is_new
                                                iv_zip           = mv_zip ).
        CATCH zcx_abapgit_exception INTO DATA(lx_error).
          " one unreadable file does not stop the others
          <ls_file>-note = lx_error->get_text( ).
          RETURN.
      ENDTRY.
      IF ls_diff-binary = abap_true.
        <ls_file>-note = `Binary file - no line diff`.
        RETURN.
      ENDIF.
      DATA(ls_loaded) = VALUE ty_loaded( index = iv_index remote_is_new = ls_diff-remote_is_new lines = ls_diff-lines
        new_count = COND #( WHEN ls_diff-remote_is_new = abap_true THEN ls_diff-remote_count ELSE ls_diff-local_count )
        old_count = COND #( WHEN ls_diff-remote_is_new = abap_true THEN ls_diff-local_count ELSE ls_diff-remote_count ) ).
      INSERT ls_loaded INTO TABLE mt_loaded.
      <ls_file>-counts = |+{ ls_loaded-new_count } −{ ls_loaded-old_count }|.
    ENDIF.
    rows_build( iv_index ).
  ENDMETHOD.

  METHOD collapse.
    ASSIGN mt_files[ iv_index ] TO FIELD-SYMBOL(<ls_file>).
    <ls_file>-expanded = abap_false.
    CLEAR: <ls_file>-lines, <ls_file>-sbs.
  ENDMETHOD.
```
`rows_build( iv_index )`: clears `lines` and `sbs` of that file; returns unless expanded and loaded; takes `compact( loaded-lines )`; fills `lines` for INLINE exactly as `zcl_ag2ui5_app_diff->rows_build` fills `mt_rows` (without patch fields), or `sbs` for SBS exactly as it fills `mt_sbs` — copy those two loops, replacing `mv_remote_is_new` with the loaded file's `remote_is_new`.

`summary_build`: files = `lines( mt_files )`; sum `new_count` / `old_count` over `mt_loaded`; `k` = files without a loaded entry and without a note; text `|{ files } files · +{ new } −{ old }|` plus ` ({ k } not loaded)` when k > 0. Use `file` singular for 1.

`state_text`: `local`/`remote` + `added`/`modified`/`deleted` for `A`/`M`/`D`; both non-initial and equal → `both <word>`; both non-initial and different → `local <x>, remote <y>`.

`on_event`:

```abap
    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
        RETURN.
      WHEN `PANEL`.
        DATA(lv_index) = checked_index( client->get_event_arg( ) ).
        IF lv_index = 0.
          RETURN.
        ENDIF.
        " the event carries the new state: X / true opens, anything else closes
        IF client->get_event_arg( 2 ) = `X` OR client->get_event_arg( 2 ) = `true`.
          expand( lv_index ).
        ELSE.
          collapse( lv_index ).
        ENDIF.
      WHEN `EXPAND_ALL`.
        DATA(lv_open) = REDUCE i( INIT n = 0 FOR f IN mt_files WHERE ( expanded = abap_true ) NEXT n = n + 1 ).
        DATA(lv_skipped) = 0.
        LOOP AT mt_files INTO DATA(ls_file) WHERE expanded = abap_false.
          IF lv_open >= c_max_expanded.
            lv_skipped = lv_skipped + 1.
            CONTINUE.
          ENDIF.
          expand( ls_file-index ).
          lv_open = lv_open + 1.
        ENDLOOP.
        IF lv_skipped > 0.
          client->message_toast_display( |{ lv_skipped } files stay collapsed: at most { c_max_expanded } are open at once| ).
        ENDIF.
      WHEN `COLLAPSE_ALL`.
        LOOP AT mt_files INTO ls_file WHERE expanded = abap_true.
          collapse( ls_file-index ).
        ENDLOOP.
      WHEN `LAYOUT`.
        IF mv_layout <> `SBS`.
          mv_layout = `INLINE`.
        ENDIF.
        LOOP AT mt_files INTO ls_file WHERE expanded = abap_true.
          rows_build( ls_file-index ).
        ENDLOOP.
      WHEN `OPEN`.
        lv_index = checked_index( client->get_event_arg( ) ).
        IF lv_index = 0.
          RETURN.
        ENDIF.
        DATA(ls_source) = mt_source[ lv_index ].
        client->nav_app_call( zcl_ag2ui5_app_diff=>create(
          iv_key           = mv_key
          iv_zip           = mv_zip
          iv_path          = ls_source-path
          iv_filename      = ls_source-filename
          iv_obj_type      = ls_source-obj_type
          iv_obj_name      = ls_source-obj_name
          iv_object_link   = ls_source-object_link
          iv_remote_is_new = zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = ls_source-lstate
                                                                    iv_rstate = ls_source-rstate ) ) ).
        RETURN.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    summary_build( ).
    view_display( ).
```
Note: the expand state of `mt_files` also comes back from the browser through the two-way binding; `expand` / `collapse` set it explicitly from the event argument, so the posted value never decides loading. `EXPAND_ALL` / `COLLAPSE_ALL` read `expanded` after the posted model was applied: acceptable, because they only load or clear files the server itself names by index.

`view_display` (Step 4 of Task 2 fills it; for Task 1 a minimal page with the header is enough so `main` runs).

- [ ] **Step 5: Write and run GREEN.**

```sh
cd /home/chris/Projects/GIT/abapGit
.sapcli/a4h25 class write ZCL_AG2UI5_APP_REPO_DIFF /home/chris/Projects/GIT/abapGit2UI5-repo-diff/src/zcl_ag2ui5_app_repo_diff.clas.abap --activate
.sapcli/a4h25 class write ZCL_AG2UI5_APP_REPO_DIFF /home/chris/Projects/GIT/abapGit2UI5-repo-diff/src/zcl_ag2ui5_app_repo_diff.clas.testclasses.abap --type testclasses --activate
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5-repo-diff/src/zcl_ag2ui5_app_repo_diff.clas.testclasses.abap
```
Expected: `ZCL_AG2UI5_APP_REPO_DIFF: 11/11 passed`.

- [ ] **Step 6: Commit** the three files: `git commit -m "Repository diff: files, loading and panels state"`.

---

### Task 2: Repository diff view

**Files:** Modify `src/zcl_ag2ui5_app_repo_diff.clas.abap` (`view_display`), test include (view test).

- [ ] **Step 1: Failing view test**

```abap
  METHOD view_panels_from_template.
    app( files( 2 ) ).
    DATA(lv_view) = mo_client->mv_view.
    FIND REGEX `<customHeader>\s*<OverflowToolbar[^>]*>\s*<Button[^>]*sap-icon://nav-back` IN lv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_view ).
    FIND REGEX `<Panel[^>]*expanded="\{EXPANDED\}"` IN lv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_view ).
    FIND REGEX `<Table[^>]*items="\{LINES\}"` IN lv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_view ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view exp = `*items="{SBS}"*` ).
  ENDMETHOD.
```
Run (write test include + unit): Expected FAIL.

- [ ] **Step 2: Implement `view_display`.** Page with `customHeader` → `OverflowToolbar`: Back (`sap-icon://nav-back`, NeverOverflow), `Title` bound `ms_head-title` (NeverOverflow, shrinkable), `ToolbarSpacer`, `Text` bound `ms_head-summary`, `SegmentedButton` `selectedKey` bound `mv_layout`, `selectionChange` `LAYOUT`, items `INLINE`/`Inline`, `SBS`/`Side by side`; `Button` Expand all (`EXPAND_ALL`), `Button` Collapse all (`COLLAPSE_ALL`). Content: `VBox` `items` = `client->_bind( mt_files )` with template:

```
Panel expandable="true" expanded="{EXPANDED}" width="auto" class="sapUiSmallMarginBottom"
      expand=_event( val = `PANEL` t_arg = ( `${INDEX}` ) ( `${$parameters>/expand}` ) )
  headerToolbar > OverflowToolbar:
    Title text="{FILE}"
    Link text="{OBJECT_TEXT}" href="{OBJECT_LINK}" visible="{= !!${OBJECT_LINK} }"
    Text text="{OBJECT_TEXT}" visible="{= !${OBJECT_LINK} && !!${OBJECT_TEXT} }"
    Text text="{STATE}"
    ToolbarSpacer
    Text text="{COUNTS}"
    Button text="Open" type="Transparent" press=_event( val = `OPEN` arg = `${INDEX}` )
  content:
    Text text="{NOTE}" visible="{= !!${NOTE} }"
    (INLINE) Table items="{LINES}" visible="{= ${LINES}.length > 0 }" with the inline columns of
             zcl_ag2ui5_app_diff->inline_display (Git/ZIP no., Local no., marker, Code; header label
             ms_head-remote_label bound) and cells {REMOTE_NUM} {LOCAL_NUM} {MARKER} FormattedText {CODE_HTML}
    (SBS)    Table items="{SBS}" ... cells as zcl_ag2ui5_app_diff->side_by_side_display, labels `System` / remote_label
```
Only the table of `mv_layout` is rendered. Run `npx abap2ui5lint src/zcl_ag2ui5_app_repo_diff.clas.abap` and fix every warning (inline `_bind` calls, house layout, single `arg`).

- [ ] **Step 3: GREEN.** Write class + tests, run unit. Expected 12/12. `npm run check` exit 0.

- [ ] **Step 4: Commit:** `git commit -m "Repository diff: panels view"`.

---

### Task 3: Status page Diff button

**Files:** Modify `src/zcl_ag2ui5_app_status.clas.abap` (table toolbar, `on_event`), its test include.

- [ ] **Step 1: Failing tests** in `ltcl_overview` (has an offline service double and rows; `mo_app->mt_status` has two changed rows `/src/a.abap` and `/other/a.xml` and two unchanged):

```abap
  METHOD repo_diff_passes_changed.
    mo_app->mv_offline = abap_false.
    mo_client->mv_event = `REPO_DIFF`.
    mo_app->on_event( ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_repo_diff( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_diff->mt_files ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 1 ]-file exp = `/other/a.xml` ).
  ENDMETHOD.

  METHOD diff_disabled_offline_without_zip.
    mo_app->mv_offline = abap_true.
    CLEAR mo_app->mv_zip.
    mo_client->mv_event = `REPO_DIFF`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
    mo_app->view_display( ).
    FIND REGEX `<Button[^>]*text="Diff"[^>]*enabled="false"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
  ENDMETHOD.

  METHOD diff_disabled_without_changes.
    mo_app->mv_offline = abap_false.
    LOOP AT mo_app->mt_status ASSIGNING FIELD-SYMBOL(<ls_status>).
      <ls_status>-changed = abap_false.
    ENDLOOP.
    mo_app->view_display( ).
    FIND REGEX `<Button[^>]*text="Diff"[^>]*enabled="false"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
  ENDMETHOD.
```
(File order: `sort_status_rows( iv_by = `FILE` iv_changes_first = abap_true )` sorts by path+filename; check its result for `/other/` vs `/src/` and set the expected first file accordingly.)

- [ ] **Step 2: RED** (write test include, run status unit). Expected: 3 failures.

- [ ] **Step 3: Implement.** In the table toolbar after the second SegmentedButton:

```abap
    table_toolbar->tag( `Button`
        )->a( n = `text`    v = `Diff`
        )->a( n = `icon`    v = `sap-icon://compare`
        )->a( n = `tooltip` v = `All changes of the repository`
        )->a( n = `enabled` b = can_repo_diff( )
        )->a( n = `press`   v = client->_event( `REPO_DIFF` ) ).
```
`can_repo_diff( ) RETURNING rv_can TYPE abap_bool`: `line_exists( mt_status[ changed = abap_true ] ) AND NOT ( mv_offline = abap_true AND mv_zip IS INITIAL )`. In `on_event`:

```abap
      WHEN `REPO_DIFF`.
        IF can_repo_diff( ) = abap_false.
          RETURN.
        ENDIF.
        DATA(lt_changed) = mt_status.
        DELETE lt_changed WHERE changed = abap_false.
        client->nav_app_call( zcl_ag2ui5_app_repo_diff=>create(
          iv_key   = mv_key
          iv_title = ms_head-name
          iv_zip   = mv_zip
          it_files = zcl_ag2ui5_repo_service=>sort_status_rows( it_rows = lt_changed iv_by = `FILE` iv_changes_first = abap_true ) ) ).
```

- [ ] **Step 4: GREEN** — write status class + tests over ADT, run status unit: Expected 56/56. Lint clean.

- [ ] **Step 5: Commit:** `git commit -m "Status page: Diff button for all changes"`.

---

### Task 4: Verification and docs

- [ ] **Step 1:** All suites (repo_service, app_status, app_stage, app_diff, settings, app_repos, app_new_repo, app_repo_diff) — Expected all pass; latest dumps: none new.
- [ ] **Step 2:** Readbacks of the new and changed classes against the worktree files — Expected same.
- [ ] **Step 3:** Chrome on `$UMLAUT` (read only): Diff button → page with panels, first ones expanded, expand/collapse, Expand all, layout switch, Open and Back; screenshot.
- [ ] **Step 4:** `docs/findings.md` section "Repository diff (2026-10-07)"; README feature table/Status paragraph gets the Diff page; `AGENTS.md` "checked again on the server" list gets the repository diff's index checks.
- [ ] **Step 5:** Commit `Docs: repository diff`.
