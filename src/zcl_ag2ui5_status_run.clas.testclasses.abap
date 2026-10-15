CLASS ltd_local_repo DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo PARTIALLY IMPLEMENTED.
    DATA mv_fail TYPE abap_bool.
    DATA mv_refreshed TYPE abap_bool.
ENDCLASS.
CLASS ltd_local_repo IMPLEMENTATION.
  METHOD zif_abapgit_repo~refresh.
    mv_refreshed = iv_drop_cache.
  ENDMETHOD.
  METHOD zif_abapgit_repo~get_files_local.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Local serialization failed` ).
    ENDIF.
    rt_files = VALUE #( ( file-path = `/src/` file-filename = `local.abap` file-data = '0102' ) ).
  ENDMETHOD.
ENDCLASS.
CLASS ltd_local_repo_srv DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo_srv PARTIALLY IMPLEMENTED.
    DATA mo_repo TYPE REF TO ltd_local_repo.
ENDCLASS.
CLASS ltd_local_repo_srv IMPLEMENTATION.
  METHOD zif_abapgit_repo_srv~get.
    ri_repo = mo_repo.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_starter DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_run_starter.
    DATA mv_started TYPE abap_bool VALUE abap_true.
    DATA mv_id TYPE sysuuid_c32.
    DATA mv_key TYPE string.
ENDCLASS.

CLASS ltd_starter IMPLEMENTATION.
  METHOD zif_ag2ui5_run_starter~start.
    mv_id = iv_run_id.
    mv_key = iv_key.
    rv_started = mv_started.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_status_run DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CONSTANTS c_id TYPE string VALUE `AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA`.
    CONSTANTS c_key TYPE string VALUE `000000000025`.
    CLASS-DATA gi_environment TYPE REF TO if_osql_test_environment.
    DATA mo_starter TYPE REF TO ltd_starter.
    DATA ms_row TYPE zag2ui5_run.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS save.
    METHODS serialize_stores_local_files FOR TESTING RAISING zcx_abapgit_exception.
    METHODS serialize_records_error FOR TESTING.
    METHODS serialize_refuses_foreign_row FOR TESTING.
    METHODS create_refuses_invalid_key FOR TESTING.
    METHODS take_files_refuses_unknown FOR TESTING.
    METHODS create_writes_running_row FOR TESTING RAISING zcx_abapgit_exception.
    METHODS start_failure_returns_no_run FOR TESTING RAISING zcx_abapgit_exception.
    METHODS create_cleans_old_rows FOR TESTING RAISING zcx_abapgit_exception.
    METHODS unknown_id_is_gone FOR TESTING RAISING zcx_abapgit_exception.
    METHODS foreign_user_is_gone FOR TESTING RAISING zcx_abapgit_exception.
    METHODS foreign_key_is_gone FOR TESTING RAISING zcx_abapgit_exception.
    METHODS state_reports_progress FOR TESTING RAISING zcx_abapgit_exception.
    METHODS error_row_reports_message FOR TESTING RAISING zcx_abapgit_exception.
    METHODS take_files_returns_and_deletes FOR TESTING RAISING zcx_abapgit_exception.
    METHODS take_files_refuses_running FOR TESTING RAISING zcx_abapgit_exception.
    METHODS take_refuses_foreign_user FOR TESTING RAISING zcx_abapgit_exception.
    METHODS take_refuses_foreign_key FOR TESTING RAISING zcx_abapgit_exception.
    METHODS take_files_refuses_error FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.

CLASS ltcl_status_run IMPLEMENTATION.
  METHOD class_setup.
    gi_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZAG2UI5_RUN' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    gi_environment->destroy( ).
  ENDMETHOD.
  METHOD setup.
    gi_environment->clear_doubles( ).
    mo_starter = NEW #( ).
    zcl_ag2ui5_status_run=>inject( mo_starter ).
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    ms_row = VALUE #( run_id = c_id uname = sy-uname repo_key = c_key state = 'R'
                      created = lv_now changed = lv_now ).
  ENDMETHOD.
  METHOD teardown.
    zcl_ag2ui5_status_run=>inject( NEW zcl_ag2ui5_run_starter( ) ).
    zcl_abapgit_repo_srv=>inject_instance( VALUE #( ) ).
    zcl_abapgit_progress=>set_instance( NEW zcl_ag2ui5_progress_silent( ) ).
    gi_environment->clear_doubles( ).
  ENDMETHOD.
  METHOD save.
    DATA lt_rows TYPE STANDARD TABLE OF zag2ui5_run WITH DEFAULT KEY.
    APPEND ms_row TO lt_rows.
    gi_environment->insert_test_data( lt_rows ).
  ENDMETHOD.
  METHOD serialize_stores_local_files.
    save( ).
    DATA(lo_srv) = NEW ltd_local_repo_srv( ).
    lo_srv->mo_repo = NEW #( ).
    zcl_abapgit_repo_srv=>inject_instance( lo_srv ).
    zcl_ag2ui5_status_run=>serialize( iv_run_id = CONV #( c_id ) iv_key = c_key ).
    cl_abap_unit_assert=>assert_true( lo_srv->mo_repo->mv_refreshed ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = c_key )-state exp = `D` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>take_files( iv_run_id = c_id iv_key = c_key )
      exp = lo_srv->mo_repo->zif_abapgit_repo~get_files_local( ) ).
  ENDMETHOD.
  METHOD serialize_records_error.
    save( ).
    DATA(lo_srv) = NEW ltd_local_repo_srv( ).
    lo_srv->mo_repo = NEW #( ).
    lo_srv->mo_repo->mv_fail = abap_true.
    zcl_abapgit_repo_srv=>inject_instance( lo_srv ).
    zcl_ag2ui5_status_run=>serialize( iv_run_id = CONV #( c_id ) iv_key = c_key ).
    DATA(ls_state) = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = c_key ).
    cl_abap_unit_assert=>assert_equals( act = ls_state-state exp = `E` ).
    cl_abap_unit_assert=>assert_equals( act = ls_state-message exp = `Local serialization failed` ).
  ENDMETHOD.
  METHOD serialize_refuses_foreign_row.
    ms_row-uname = 'OTHER_USER'.
    save( ).
    DATA(lo_srv) = NEW ltd_local_repo_srv( ).
    lo_srv->mo_repo = NEW #( ).
    zcl_abapgit_repo_srv=>inject_instance( lo_srv ).
    zcl_ag2ui5_status_run=>serialize( iv_run_id = CONV #( c_id ) iv_key = c_key ).
    cl_abap_unit_assert=>assert_false( lo_srv->mo_repo->mv_refreshed ).
    SELECT SINGLE state FROM zag2ui5_run WHERE run_id = @c_id INTO @DATA(lv_state).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = lv_state exp = 'R' ).
  ENDMETHOD.
  METHOD create_refuses_invalid_key.
    LOOP AT VALUE string_table( ( `` ) ( `0000000000259` ) ( `invalid` ) ) INTO DATA(lv_key).
      cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_status_run=>create( lv_key ) ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_initial( mo_starter->mv_id ).
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 0 ).
  ENDMETHOD.
  METHOD take_files_refuses_unknown.
    TRY.
        zcl_ag2ui5_status_run=>take_files( iv_run_id = c_id iv_key = c_key ).
        cl_abap_unit_assert=>fail( `Unknown runs must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
  METHOD create_writes_running_row.
    DATA(lv_id) = zcl_ag2ui5_status_run=>create( c_key ).
    SELECT SINGLE run_id, uname, repo_key, state, created, changed FROM zag2ui5_run WHERE run_id = @lv_id INTO @DATA(ls_row).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_not_initial( lv_id ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-uname exp = sy-uname ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-repo_key exp = c_key ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-state exp = 'R' ).
    cl_abap_unit_assert=>assert_not_initial( ls_row-created ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-created exp = ls_row-changed ).
    cl_abap_unit_assert=>assert_equals( act = mo_starter->mv_id exp = lv_id ).
    cl_abap_unit_assert=>assert_equals( act = mo_starter->mv_key exp = c_key ).
  ENDMETHOD.
  METHOD start_failure_returns_no_run.
    mo_starter->mv_started = abap_false.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_status_run=>create( c_key ) ).
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 0 ).
  ENDMETHOD.
  METHOD create_cleans_old_rows.
    GET TIME STAMP FIELD ms_row-created.
    ms_row-created = cl_abap_tstmp=>subtractsecs( tstmp = ms_row-created secs = 7200 ).
    save( ).
    ms_row-run_id = 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'.
    ms_row-uname = 'OTHER_USER'.
    save( ).
    DATA(lv_id) = zcl_ag2ui5_status_run=>create( c_key ).
    cl_abap_unit_assert=>assert_not_initial( lv_id ).
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = c_key )-state exp = `G` ).
    SELECT SINGLE uname FROM zag2ui5_run WHERE run_id = @ms_row-run_id INTO @DATA(lv_owner).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = lv_owner exp = 'OTHER_USER' ).
  ENDMETHOD.
  METHOD unknown_id_is_gone.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = c_key )-state exp = `G` ).
  ENDMETHOD.
  METHOD foreign_user_is_gone.
    ms_row-uname = 'OTHER_USER'.
    save( ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = c_key )-state exp = `G` ).
  ENDMETHOD.
  METHOD foreign_key_is_gone.
    save( ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = `000000000099` )-state exp = `G` ).
  ENDMETHOD.
  METHOD state_reports_progress.
    ms_row-done_count = 340.
    ms_row-total_count = 1419.
    ms_row-changed = cl_abap_tstmp=>subtractsecs( tstmp = ms_row-changed secs = 30 ).
    save( ).
    DATA(ls_state) = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = c_key ).
    cl_abap_unit_assert=>assert_equals( act = ls_state-state exp = `R` ).
    cl_abap_unit_assert=>assert_equals( act = ls_state-done exp = 340 ).
    cl_abap_unit_assert=>assert_equals( act = ls_state-total exp = 1419 ).
    cl_abap_unit_assert=>assert_number_between( number = ls_state-idle_seconds lower = 29 upper = 40 ).
  ENDMETHOD.
  METHOD error_row_reports_message.
    ms_row-state = 'E'.
    ms_row-message = `Serialization failed`.
    save( ).
    DATA(ls_state) = zcl_ag2ui5_status_run=>state( iv_run_id = c_id iv_key = c_key ).
    cl_abap_unit_assert=>assert_equals( act = ls_state-state exp = `E` ).
    cl_abap_unit_assert=>assert_equals( act = ls_state-message exp = ms_row-message ).
  ENDMETHOD.
  METHOD take_files_returns_and_deletes.
    DATA(lt_files) = VALUE zif_abapgit_definitions=>ty_files_item_tt(
      ( file-path = `/src/` file-filename = `a.abap` file-data = '010203' )
      ( file-path = `/` file-filename = `.abapgit.xml` file-data = 'FF00' ) ).
    ms_row-state = 'D'.
    EXPORT files = lt_files TO DATA BUFFER ms_row-files COMPRESSION ON.
    save( ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>take_files( iv_run_id = c_id iv_key = c_key ) exp = lt_files ).
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 0 ).
  ENDMETHOD.
  METHOD take_files_refuses_running.
    save( ).
    TRY.
        zcl_ag2ui5_status_run=>take_files( iv_run_id = c_id iv_key = c_key ).
        cl_abap_unit_assert=>fail( `An unavailable result must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 ).
  ENDMETHOD.
  METHOD take_refuses_foreign_user.
    ms_row-state = 'D'.
    ms_row-uname = 'OTHER_USER'.
    save( ).
    TRY.
        zcl_ag2ui5_status_run=>take_files( iv_run_id = c_id iv_key = c_key ).
        cl_abap_unit_assert=>fail( `An unavailable result must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 ).
  ENDMETHOD.
  METHOD take_refuses_foreign_key.
    ms_row-state = 'D'.
    ms_row-repo_key = '000000000099'.
    save( ).
    TRY.
        zcl_ag2ui5_status_run=>take_files( iv_run_id = c_id iv_key = c_key ).
        cl_abap_unit_assert=>fail( `An unavailable result must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 ).
  ENDMETHOD.
  METHOD take_files_refuses_error.
    ms_row-state = 'E'.
    save( ).
    TRY.
        zcl_ag2ui5_status_run=>take_files( iv_run_id = c_id iv_key = c_key ).
        cl_abap_unit_assert=>fail( `An unavailable result must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
    SELECT COUNT( * ) FROM zag2ui5_run INTO @DATA(lv_count).
    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 ).
  ENDMETHOD.
ENDCLASS.
