CLASS ltcl_progress_run DEFINITION DEFERRED.
CLASS zcl_ag2ui5_progress_run DEFINITION LOCAL FRIENDS ltcl_progress_run.

CLASS ltcl_progress_run DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    CLASS-DATA gi_environment TYPE REF TO if_osql_test_environment.
    DATA mi_progress TYPE REF TO zif_abapgit_progress.
    DATA mo_progress TYPE REF TO zcl_ag2ui5_progress_run.
    DATA ms_row TYPE zag2ui5_run.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.
    METHODS progress_is_throttled FOR TESTING RAISING zcx_abapgit_exception.
    METHODS progress_after_one_second FOR TESTING RAISING zcx_abapgit_exception.
    METHODS foreign_row_is_unchanged FOR TESTING RAISING zcx_abapgit_exception.
    METHODS done_row_is_unchanged FOR TESTING RAISING zcx_abapgit_exception.
    METHODS off_does_nothing FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.

CLASS ltcl_progress_run IMPLEMENTATION.
  METHOD class_setup.
    gi_environment = cl_osql_test_environment=>create( VALUE #( ( 'ZAG2UI5_RUN' ) ) ).
  ENDMETHOD.
  METHOD class_teardown.
    gi_environment->destroy( ).
  ENDMETHOD.
  METHOD setup.
    gi_environment->clear_doubles( ).
    ms_row = VALUE #( run_id = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' uname = sy-uname state = 'R' ).
    DATA lt_rows TYPE STANDARD TABLE OF zag2ui5_run WITH DEFAULT KEY.
    APPEND ms_row TO lt_rows.
    gi_environment->insert_test_data( lt_rows ).
    mo_progress = NEW #( ms_row-run_id ).
    mi_progress = mo_progress.
    mi_progress->set_total( 1419 ).
  ENDMETHOD.
  METHOD teardown.
    gi_environment->clear_doubles( ).
  ENDMETHOD.
  METHOD progress_is_throttled.
    mi_progress->show( iv_current = 340 iv_text = `serialize` ).
    SELECT SINGLE done_count, total_count, changed FROM zag2ui5_run WHERE run_id = @ms_row-run_id INTO @DATA(ls_first).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-done_count exp = 340 ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-total_count exp = 1419 ).
    cl_abap_unit_assert=>assert_not_initial( ls_first-changed ).
    " Pin the last-write time so scheduling cannot make the test cross a second.
    GET TIME STAMP FIELD mo_progress->mv_last_write.
    mi_progress->show( iv_current = 341 iv_text = `serialize` ).
    SELECT SINGLE done_count, total_count, changed FROM zag2ui5_run WHERE run_id = @ms_row-run_id INTO @DATA(ls_second).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = ls_second exp = ls_first ).
  ENDMETHOD.
  METHOD progress_after_one_second.
    mi_progress->show( iv_current = 340 iv_text = `serialize` ).
    mo_progress->mv_last_write = cl_abap_tstmp=>subtractsecs( tstmp = mo_progress->mv_last_write secs = 2 ).
    mi_progress->set_total( 1500 ).
    mi_progress->show( iv_current = 500 iv_text = `serialize` ).
    SELECT SINGLE done_count, total_count, changed FROM zag2ui5_run WHERE run_id = @ms_row-run_id INTO @DATA(ls_row).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-done_count exp = 500 ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-total_count exp = 1500 ).
  ENDMETHOD.
  METHOD foreign_row_is_unchanged.
    UPDATE zag2ui5_run SET uname = 'OTHER_USER' WHERE run_id = @ms_row-run_id.
    cl_abap_unit_assert=>assert_subrc( ).
    mi_progress->show( iv_current = 340 iv_text = `serialize` ).
    SELECT SINGLE done_count FROM zag2ui5_run WHERE run_id = @ms_row-run_id INTO @DATA(lv_done).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_initial( lv_done ).
  ENDMETHOD.
  METHOD done_row_is_unchanged.
    UPDATE zag2ui5_run SET state = 'D' WHERE run_id = @ms_row-run_id.
    cl_abap_unit_assert=>assert_subrc( ).
    mi_progress->show( iv_current = 340 iv_text = `serialize` ).
    SELECT SINGLE done_count FROM zag2ui5_run WHERE run_id = @ms_row-run_id INTO @DATA(lv_done).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_initial( lv_done ).
  ENDMETHOD.
  METHOD off_does_nothing.
    mi_progress->off( ).
    SELECT SINGLE done_count, total_count, changed FROM zag2ui5_run WHERE run_id = @ms_row-run_id INTO @DATA(ls_row).
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-done_count exp = 0 ).
    cl_abap_unit_assert=>assert_initial( ls_row-changed ).
  ENDMETHOD.
ENDCLASS.
