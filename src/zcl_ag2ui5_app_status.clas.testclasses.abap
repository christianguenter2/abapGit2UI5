CLASS ltcl_overview DEFINITION DEFERRED.
CLASS ltcl_object_links DEFINITION DEFERRED.
CLASS ltcl_offline DEFINITION DEFERRED.
CLASS ltcl_branches DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_status DEFINITION LOCAL FRIENDS ltcl_offline ltcl_object_links ltcl_overview ltcl_branches.

"! Settings double: preset values, and every set( ) call recorded
CLASS ltd_settings DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_settings.
    TYPES:
      BEGIN OF ty_pair,
        key   TYPE string,
        value TYPE string,
      END OF ty_pair,
      ty_pairs TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY.
    DATA mt_preset TYPE ty_pairs.
    DATA mt_saved TYPE ty_pairs.
    METHODS saved
      IMPORTING
        iv_key          TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.

CLASS ltd_settings IMPLEMENTATION.

  METHOD zif_ag2ui5_settings~get.
    READ TABLE mt_preset INTO DATA(ls_pair) WITH KEY key = iv_key.
    rv_value = COND #( WHEN sy-subrc = 0 THEN ls_pair-value ELSE iv_default ).
  ENDMETHOD.

  METHOD zif_ag2ui5_settings~set.
    INSERT VALUE #( key = iv_key value = iv_value ) INTO TABLE mt_saved.
    rv_saved = abap_true.
  ENDMETHOD.

  METHOD saved.
    " the last value saved for the key; `?` if none was saved
    rv_value = `?`.
    LOOP AT mt_saved INTO DATA(ls_pair) WHERE key = iv_key.
      rv_value = ls_pair-value.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_event TYPE string.
    DATA mv_navigated TYPE abap_bool.
    DATA mv_init TYPE abap_bool.
    DATA mv_view TYPE string.
    DATA mv_popup TYPE string.
    DATA mv_error TYPE string.
    DATA mv_toast TYPE string.
    DATA mv_left TYPE abap_bool.
    DATA mv_destroyed TYPE abap_bool.
    DATA mv_follow TYPE string.
    DATA mt_args TYPE string_table.
    DATA mo_called TYPE REF TO z2ui5_if_app.
    DATA ms_get TYPE z2ui5_if_client=>ty_s_get.
ENDCLASS.

CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~get.
    result = ms_get.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_init.
    result = mv_init.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_navigated.
    result = mv_navigated.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_event.
    result = xsdbool( mv_navigated = abap_false ).
  ENDMETHOD.
  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.
  METHOD z2ui5_if_client~view_display.
    mv_view = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_box_display.
    mv_error = text.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_toast_display.
    mv_toast = text.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_display.
    mv_popup = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_destroy.
    mv_destroyed = abap_true.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_model_update ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~follow_up_action.
    mv_follow = val.
    mt_args = t_arg.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_leave.
    mv_left = abap_true.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_call.
    mo_called = app.
  ENDMETHOD.
  METHOD z2ui5_if_client~get_event_arg.
    result = VALUE #( mt_args[ v ] OPTIONAL ).
  ENDMETHOD.
  "! bindings and events are not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_settings TYPE REF TO ltd_settings.

    METHODS setup.
    METHODS teardown.
    METHODS create_reads_settings FOR TESTING.
    METHODS create_without_settings FOR TESTING.
    METHODS view_event_saves FOR TESTING.
ENDCLASS.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_settings = NEW #( ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD create_reads_settings.
    " a stored blank for "changes on top" is off, not the default on
    mo_settings->mt_preset = VALUE #(
      ( key = zif_ag2ui5_settings=>c_key-status_view          value = `CHANGES` )
      ( key = zif_ag2ui5_settings=>c_key-status_sort          value = `FILE` )
      ( key = zif_ag2ui5_settings=>c_key-status_changes_first value = `` ) ).
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    cl_abap_unit_assert=>assert_equals( exp = `CHANGES` act = lo_app->mv_view ).
    cl_abap_unit_assert=>assert_equals( exp = `FILE` act = lo_app->mv_sort ).
    cl_abap_unit_assert=>assert_false( lo_app->mv_changes_first ).
  ENDMETHOD.

  METHOD create_without_settings.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    cl_abap_unit_assert=>assert_equals( exp = `ALL` act = lo_app->mv_view ).
    cl_abap_unit_assert=>assert_equals( exp = `OBJECT` act = lo_app->mv_sort ).
    cl_abap_unit_assert=>assert_true( lo_app->mv_changes_first ).
  ENDMETHOD.

  METHOD view_event_saves.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->mv_view = `CHANGES`.
    lo_app->mv_sort = `TYPE`.
    lo_app->mv_changes_first = abap_false.
    lo_client->mv_event = `VIEW`.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals(
      exp = `CHANGES` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_view ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `TYPE` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_sort ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_changes_first ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_header DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS back_never_overflows FOR TESTING.
ENDCLASS.

CLASS ltcl_header IMPLEMENTATION.

  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD back_never_overflows.
    " on a narrow screen the header controls must not push out the back
    " button: they sit in an overflow toolbar, the back button stays
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_navigated = abap_true.
    lo_app->z2ui5_if_app~main( lo_client ).
    FIND REGEX `<customHeader>\s*<OverflowToolbar[^>]*>\s*<Button[^>]*sap-icon://nav-back[^>]*[^/>]>\s*`
            && `<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
    " Pull never moves into the menu
    FIND REGEX `<Button[^>]*type="Emphasized"[^>]*[^/>]>\s*<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
  ENDMETHOD.

ENDCLASS.


CLASS ltd_offline_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA ms_status TYPE zif_ag2ui5_repo_service=>ty_status.
    DATA ms_diff TYPE zif_ag2ui5_repo_service=>ty_diff.
    DATA mv_diff_zip TYPE xstring.
    DATA mv_diff_calls TYPE i.
    DATA mv_diff_fail TYPE abap_bool.
    DATA ms_preview TYPE zif_ag2ui5_repo_service=>ty_preview.
    DATA ms_result TYPE zif_ag2ui5_repo_service=>ty_pull_result.
    DATA mv_status_zip TYPE xstring.
    DATA mv_preview_zip TYPE xstring.
    DATA mv_pull_zip TYPE xstring.
    DATA mv_export TYPE xstring.
    DATA mv_export_calls TYPE i.
    DATA mt_items TYPE zif_ag2ui5_repo_service=>ty_decision_items.
    DATA mv_transport TYPE string.
    DATA mv_ack TYPE abap_bool.
ENDCLASS.

CLASS ltd_offline_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~get_diff.
    mv_diff_calls = mv_diff_calls + 1.
    mv_diff_zip = iv_zip.
    IF mv_diff_fail = abap_true.
      zcx_abapgit_exception=>raise( `Test load failure` ).
    ENDIF.
    rs_diff = ms_diff.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~get_status.
    mv_status_zip = iv_zip.
    rs_status = ms_status.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~preview_pull.
    mv_preview_zip = iv_zip.
    rs_preview = ms_preview.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~pull.
    mv_pull_zip = iv_zip.
    mt_items = it_items.
    mv_transport = iv_transport.
    mv_ack = iv_acknowledged.
    rs_result = ms_result.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~export_zip.
    mv_export_calls = mv_export_calls + 1.
    rv_zip = mv_export.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_offline DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_status.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_offline_service.
    METHODS setup.
    METHODS teardown.
    METHODS fire IMPORTING iv_event TYPE string.
    METHODS archive RETURNING VALUE(rv_zip) TYPE xstring RAISING zcx_abapgit_exception.
    METHODS start_loads_offline FOR TESTING.
    METHODS offline_controls FOR TESTING.
    METHODS online_controls FOR TESTING.
    METHODS clean_online_can_manage_rules FOR TESTING.
    METHODS upload_preview FOR TESTING RAISING zcx_abapgit_exception.
    METHODS invalid_keeps_previous FOR TESTING.
    METHODS cancel_keeps_previous FOR TESTING.
    METHODS decisions_cancel_keeps_zip FOR TESTING.
    METHODS pull_uses_zip_and_decisions FOR TESTING.
    METHODS nothing_selected_no_pull FOR TESTING.
    METHODS mark_all_selectable_groups FOR TESTING.
    METHODS unmark_all_groups FOR TESTING.
    METHODS mark_preserves_other_state FOR TESTING.
    METHODS mark_empty_is_noop FOR TESTING.
    METHODS mark_controls_in_popup FOR TESTING.
    METHODS refresh_uses_zip FOR TESTING.
    METHODS export_binary_download FOR TESTING.
    METHODS online_export_ignored FOR TESTING.
    METHODS back_clears_zip FOR TESTING.
    METHODS offline_stage_ignored FOR TESTING.
    METHODS diff_uses_zip FOR TESTING.
ENDCLASS.

CLASS ltcl_offline IMPLEMENTATION.
  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_app = zcl_ag2ui5_app_status=>create( `29` ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app->mi_service = mo_service.
    mo_app->mv_offline = abap_true.
    mo_service->ms_status = VALUE #( name = `offline` package = `$TEST_OFFLINE` offline = abap_true ).
    mo_service->ms_preview = VALUE #( outcome = zif_ag2ui5_repo_service=>c_outcome-ready
      items = VALUE #( ( obj_type = `CLAS` obj_name = `ZTEST` group = zif_ag2ui5_repo_service=>c_group-import
                         selected = abap_true selectable = abap_true ) ) ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD fire.
    mo_client->mv_event = iv_event.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.

  METHOD archive.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = `.abapgit.xml` content = zcl_abapgit_dot_abapgit=>build_default( )->serialize( ) ).
    lo_zip->add( name = `src/ztest.bin` content = CONV xstring( '00FF0C80' ) ).
    rv_zip = lo_zip->save( ).
  ENDMETHOD.

  METHOD start_loads_offline.
    mo_service->ms_status-rows = VALUE #( ( path = `/src/` filename = `ztest.abap` lstate = `M` ) ).
    mo_client->mv_init = abap_true.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_offline ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_stage ).
    cl_abap_unit_assert=>assert_equals( exp = `Inactive` act = mo_app->mv_row_type ).
    cl_abap_unit_assert=>assert_equals( exp = `Import ZIP` act = mo_app->mv_pull_text ).
    cl_abap_unit_assert=>assert_equals( exp = `ZIP` act = mo_app->mv_remote_label ).
  ENDMETHOD.

  METHOD offline_controls.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_view CS `visible="true" text="Export ZIP"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_view CS `visible="false" text="Branches"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_view CS `visible="false" text="Stage"` ) ).
  ENDMETHOD.

  METHOD clean_online_can_manage_rules.
    mo_service->ms_status-offline = abap_false.
    mo_service->ms_status-rows = VALUE #( ( path = `/src/` filename = `ztest.abap` changed = abap_false ) ).
    mo_client->mv_init = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_stage ).
  ENDMETHOD.

  METHOD online_controls.
    mo_app->mv_offline = abap_false.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_view CS `visible="false" text="Export ZIP"` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_view CS `visible="true" text="Branches"` ) ).
  ENDMETHOD.

  METHOD upload_preview.
    DATA(lv_zip) = archive( ).
    mo_app->mv_upload = `data:application/zip;base64,` && cl_http_utility=>encode_x_base64( lv_zip ).
    fire( `ZIP_UPLOAD` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_upload ).
    cl_abap_unit_assert=>assert_equals( exp = lv_zip act = mo_app->mv_zip ).
    cl_abap_unit_assert=>assert_equals( exp = lv_zip act = mo_service->mv_preview_zip ).
    cl_abap_unit_assert=>assert_equals( exp = lv_zip act = mo_service->mv_status_zip ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_app->ms_decisions-import ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_popup CS `Pull selected` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Import ZIP` act = mo_app->mv_pull_text ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_stage ).
    cl_abap_unit_assert=>assert_equals( exp = `Navigation` act = mo_app->mv_row_type ).
  ENDMETHOD.

  METHOD invalid_keeps_previous.
    mo_app->mv_zip = '0102'.
    mo_app->mv_upload = `data:application/zip;base64,AQIDBA==`.
    fire( `ZIP_UPLOAD` ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( '0102' ) act = mo_app->mv_zip ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_upload ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_preview_zip ).
  ENDMETHOD.

  METHOD cancel_keeps_previous.
    mo_app->mv_zip = '0102'.
    fire( `PULL` ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_popup CS `z2ui5:FileUploader` ) ).
    mo_app->mv_upload = `discarded`.
    fire( `ZIP_CANCEL` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_upload ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( '0102' ) act = mo_app->mv_zip ).
  ENDMETHOD.

  METHOD decisions_cancel_keeps_zip.
    mo_app->mv_zip = '0102'.
    mo_app->ms_decisions-import = mo_service->ms_preview-items.
    fire( `PULL_CANCEL` ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_decisions ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( '0102' ) act = mo_app->mv_zip ).
  ENDMETHOD.

  METHOD pull_uses_zip_and_decisions.
    mo_app->mv_zip = '0102'.
    mo_app->ms_decisions-import = mo_service->ms_preview-items.
    mo_app->mv_transport = `TESTK900001`.
    mo_app->mv_acknowledged = abap_true.
    fire( `PULL_SELECTED` ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( '0102' ) act = mo_service->mv_pull_zip ).
    cl_abap_unit_assert=>assert_equals( exp = mo_service->ms_preview-items act = mo_service->mt_items ).
    cl_abap_unit_assert=>assert_equals( exp = `TESTK900001` act = mo_service->mv_transport ).
    cl_abap_unit_assert=>assert_true( mo_service->mv_ack ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_decisions ).
  ENDMETHOD.

  METHOD nothing_selected_no_pull.
    mo_app->mv_zip = '0102'.
    mo_app->ms_decisions-import = mo_service->ms_preview-items.
    mo_app->ms_decisions-import[ 1 ]-selected = abap_false.
    fire( `PULL_SELECTED` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_pull_zip ).
    cl_abap_unit_assert=>assert_equals( exp = `Nothing selected` act = mo_client->mv_toast ).
  ENDMETHOD.

  METHOD mark_all_selectable_groups.
    DATA(lt_rows) = VALUE zif_ag2ui5_repo_service=>ty_decision_items(
      ( obj_name = `SELECTABLE` selectable = abap_true )
      ( obj_name = `DISABLED` )
      ( obj_name = `FORGED_TICK` selected = abap_true ) ).
    mo_app->ms_decisions = VALUE #( data_loss = lt_rows delete = lt_rows overwrite = lt_rows
      package = lt_rows import = lt_rows skipped = lt_rows ).
    fire( `PULL_MARK_ALL` ).
    DO 6 TIMES.
      ASSIGN COMPONENT sy-index OF STRUCTURE mo_app->ms_decisions TO FIELD-SYMBOL(<lt_rows>).
      cl_abap_unit_assert=>assert_subrc( ).
      DATA(lt_actual) = CONV zif_ag2ui5_repo_service=>ty_decision_items( <lt_rows> ).
      cl_abap_unit_assert=>assert_equals( exp = xsdbool( sy-index <> 6 ) act = lt_actual[ 1 ]-selected ).
      cl_abap_unit_assert=>assert_false( lt_actual[ 2 ]-selected ).
      cl_abap_unit_assert=>assert_false( lt_actual[ 3 ]-selected ).
    ENDDO.
    cl_abap_unit_assert=>assert_initial( mo_service->mt_items ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_destroyed ).
  ENDMETHOD.

  METHOD unmark_all_groups.
    DATA(lt_rows) = VALUE zif_ag2ui5_repo_service=>ty_decision_items(
      ( obj_name = `SELECTABLE` selected = abap_true selectable = abap_true )
      ( obj_name = `DISABLED` selected = abap_true ) ).
    mo_app->ms_decisions = VALUE #( data_loss = lt_rows delete = lt_rows overwrite = lt_rows
      package = lt_rows import = lt_rows skipped = lt_rows ).
    fire( `PULL_UNMARK_ALL` ).
    DO 6 TIMES.
      ASSIGN COMPONENT sy-index OF STRUCTURE mo_app->ms_decisions TO FIELD-SYMBOL(<lt_rows>).
      cl_abap_unit_assert=>assert_subrc( ).
      DATA(lt_actual) = CONV zif_ag2ui5_repo_service=>ty_decision_items( <lt_rows> ).
      cl_abap_unit_assert=>assert_false( lt_actual[ 1 ]-selected ).
      cl_abap_unit_assert=>assert_false( lt_actual[ 2 ]-selected ).
    ENDDO.
    cl_abap_unit_assert=>assert_initial( mo_service->mt_items ).
  ENDMETHOD.

  METHOD mark_preserves_other_state.
    mo_app->ms_decisions-import = mo_service->ms_preview-items.
    mo_app->mv_transport = `A4HK900148`.
    mo_app->mv_customizing = `CUSTOMIZING`.
    mo_app->mv_ack_text = `Requirements warning`.
    mo_app->mv_acknowledged = abap_true.
    mo_app->mv_zip = '00FF80'.
    fire( `PULL_MARK_ALL` ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_acknowledged ).
    mo_app->mv_acknowledged = abap_false.
    fire( `PULL_UNMARK_ALL` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_acknowledged ).
    cl_abap_unit_assert=>assert_equals( exp = `Requirements warning` act = mo_app->mv_ack_text ).
    cl_abap_unit_assert=>assert_equals( exp = `A4HK900148` act = mo_app->mv_transport ).
    cl_abap_unit_assert=>assert_equals( exp = `CUSTOMIZING` act = mo_app->mv_customizing ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( '00FF80' ) act = mo_app->mv_zip ).
    cl_abap_unit_assert=>assert_initial( mo_service->mt_items ).
  ENDMETHOD.

  METHOD mark_empty_is_noop.
    fire( `PULL_MARK_ALL` ).
    fire( `PULL_UNMARK_ALL` ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_decisions ).
    cl_abap_unit_assert=>assert_initial( mo_service->mt_items ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).
  ENDMETHOD.

  METHOD mark_controls_in_popup.
    mo_app->client = mo_client.
    mo_app->popup_decisions_display( ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_popup CS `Mark all` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_popup CS `Unmark all` ) ).
  ENDMETHOD.

  METHOD refresh_uses_zip.
    mo_app->mv_zip = '0102'.
    fire( `REFRESH` ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( '0102' ) act = mo_service->mv_status_zip ).
    cl_abap_unit_assert=>assert_equals( exp = `ZIP` act = mo_app->mv_remote_label ).
  ENDMETHOD.

  METHOD export_binary_download.
    mo_service->mv_export = '00FF0C80'.
    fire( `EXPORT_ZIP` ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_client=>cs_event-download_b64_file act = mo_client->mv_follow ).
    cl_abap_unit_assert=>assert_equals( exp = `data:application/zip;base64,AP8MgA==` act = mo_client->mt_args[ 1 ] ).
    cl_abap_unit_assert=>assert_equals( exp = `repository.zip` act = mo_client->mt_args[ 2 ] ).
  ENDMETHOD.

  METHOD online_export_ignored.
    mo_app->mv_offline = abap_false.
    fire( `EXPORT_ZIP` ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = mo_service->mv_export_calls ).
  ENDMETHOD.

  METHOD back_clears_zip.
    mo_app->mv_zip = '0102'.
    mo_app->mv_upload = `discarded`.
    fire( `BACK` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_zip ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_upload ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
  ENDMETHOD.

  METHOD offline_stage_ignored.
    fire( `STAGE` ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
  ENDMETHOD.

  METHOD diff_uses_zip.
    mo_app->mv_zip = '0102'.
    mo_app->mt_rows = VALUE #( ( path = `/src/` filename = `ztest.abap` obj_type = `CLAS` obj_name = `ZTEST` rstate = `M` ) ).
    mo_client->mt_args = VALUE #( ( `/src/` ) ( `ztest.abap` ) ).
    fire( `DIFF` ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( exp = `ZIP (new)` act = lo_diff->ms_head-git_label ).
    cl_abap_unit_assert=>assert_equals( exp = `ZIP` act = lo_diff->ms_head-remote_label ).
    cl_abap_unit_assert=>assert_false( xsdbool( lo_diff->ms_head-legend CS `Git` ) ).
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_object_links DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS link_handoff FOR TESTING.
ENDCLASS.

CLASS ltcl_object_links IMPLEMENTATION.
  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
  ENDMETHOD.
  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.
  METHOD link_handoff.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->client = lo_client.
    lo_app->mt_status = VALUE #( ( obj_type = `CLAS` obj_name = `ZCL_A`
      path = `/src/` filename = `zcl_a.clas.abap` object_link = `adt://A4H/example` ) ).
    lo_app->rows_build( ).
    cl_abap_unit_assert=>assert_equals( act = lo_app->mt_rows[ 1 ]-object_link exp = `adt://A4H/example` ).
    lo_client->mv_event = `DIFF`.
    lo_client->mt_args = VALUE #( ( `/src/` ) ( `zcl_a.clas.abap` ) ).
    lo_app->on_event( ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( lo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-object_link exp = `adt://A4H/example` ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_overview DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_status.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_settings TYPE REF TO ltd_settings.
    METHODS setup.
    METHODS teardown.
    METHODS defaults_and_saved FOR TESTING.
    METHODS switch_saves FOR TESTING.
    METHODS counts_before_filter FOR TESTING.
    METHODS open_all_files FOR TESTING.
    METHODS diff_and_return FOR TESTING.
    METHODS close_clears FOR TESTING.
    METHODS unknown_key FOR TESTING.
    METHODS offline_without_zip FOR TESTING.
    METHODS semantic_navigation FOR TESTING.
    METHODS semantic_load_failure FOR TESTING.
    METHODS return_after_push_reloads FOR TESTING.
    METHODS return_without_push_keeps FOR TESTING.
ENDCLASS.

CLASS ltcl_overview IMPLEMENTATION.
  METHOD return_after_push_reloads.
    " a push may have moved the repository to a new branch
    CAST ltd_offline_service( mo_app->mi_service )->ms_status-branch_display = `feature-x`.
    mo_app->ms_head-branch_display = `main`.
    mo_client->ms_get-r_event_data = NEW string( `PUSHED` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-branch_display exp = `feature-x` ).
  ENDMETHOD.

  METHOD return_without_push_keeps.
    CAST ltd_offline_service( mo_app->mi_service )->ms_status-branch_display = `feature-x`.
    mo_app->ms_head-branch_display = `main`.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-branch_display exp = `main` ).
  ENDMETHOD.

  METHOD semantic_navigation.
    DATA(lo_service) = CAST ltd_offline_service( mo_app->mi_service ).
    lo_service->ms_diff-semantic-changes = VALUE #( ( id = `ZCL_A/Declaration/RUN`
      text = `ZCL_A=>RUN: declaration changed` path = `/src/` filename = `a.abap` ) ).
    mo_app->mv_zip = CONV xstring( 'CAFE' ).
    mo_client->mv_event = `OBJECT`.
    mo_client->mt_args = VALUE #( ( `CLAS` ) ( `ZCL_A` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_equals( act = lo_service->mv_diff_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lo_service->mv_diff_zip exp = mo_app->mv_zip ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_object_summary ) exp = 1 ).
    " Forged public entries do not authorize navigation.
    mo_app->mt_object_summary = VALUE #( ( id = `forged` path = `/src/` filename = `a.abap` ) ).
    mo_client->mv_event = `SEMANTIC`.
    mo_client->mt_args = VALUE #( ( `/src/` ) ( `a.abap` ) ( `forged` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
    mo_client->mt_args = VALUE #( ( `/src/` ) ( `a.abap` ) ( `ZCL_A/Declaration/RUN` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_bound( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_files_open ).
    mo_client->mv_event = `FILES_CLOSE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_semantic ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_object_summary ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_object_summary_note ).
  ENDMETHOD.

  METHOD semantic_load_failure.
    DATA(lo_service) = CAST ltd_offline_service( mo_app->mi_service ).
    lo_service->mv_diff_fail = abap_true.
    mo_client->mv_event = `OBJECT`.
    mo_client->mt_args = VALUE #( ( `CLAS` ) ( `ZCL_A` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_files_open ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_object_files ) exp = 3 ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_app->mv_object_summary_note exp = `Some source could not be loaded*` ).
  ENDMETHOD.

  METHOD setup.
    mo_settings = NEW #( ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
    mo_app = zcl_ag2ui5_app_status=>create( `1` ).
    mo_client = NEW #( ).
    mo_app->client = mo_client.
    mo_app->mi_service = NEW ltd_offline_service( ).
    mo_app->mt_status = VALUE #(
      ( obj_type = `CLAS` obj_name = `ZCL_A` path = `/src/` filename = `a.abap`
        lstate = `M` changed = abap_true object_link = `adt://A4H/a` )
      ( obj_type = `CLAS` obj_name = `ZCL_A` path = `/src/` filename = `a.xml` )
      ( obj_type = `CLAS` obj_name = `ZCL_A` path = `/other/` filename = `a.xml`
        rstate = `A` changed = abap_true object_link = `adt://A4H/a` )
      ( path = `/` filename = `.abapgit.xml` ) ).
    mo_app->mv_overview = `OBJECTS`.
    mo_app->rows_build( ).
  ENDMETHOD.
  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.
  METHOD defaults_and_saved.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `2` ).
    cl_abap_unit_assert=>assert_equals( act = lo_app->mv_overview exp = `FILES` ).
    mo_settings->mt_preset = VALUE #( ( key = zif_ag2ui5_settings=>c_key-status_overview value = `OBJECTS` ) ).
    lo_app = zcl_ag2ui5_app_status=>create( `2` ).
    cl_abap_unit_assert=>assert_equals( act = lo_app->mv_overview exp = `OBJECTS` ).
  ENDMETHOD.
  METHOD switch_saves.
    mo_client->mv_event = `OVERVIEW`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_equals( exp = `OBJECTS`
      act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_overview ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 2 ).
    mo_app->mv_overview = `FILES`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( exp = `FILES`
      act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_overview ) ).
  ENDMETHOD.
  METHOD counts_before_filter.
    mo_app->mv_view = `CHANGES`.
    mo_app->rows_build( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-files_text exp = `2 of 3 changed` ).
    mo_app->mv_view = `ALL`.
    mo_app->rows_build( ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 2 ]-object_display exp = `Repository files` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_rows[ 2 ]-object_link ).
  ENDMETHOD.
  METHOD open_all_files.
    mo_app->mv_view = `CHANGES`.
    mo_app->rows_build( ).
    mo_client->mv_event = `OBJECT`.
    mo_client->mt_args = VALUE #( ( `CLAS` ) ( `ZCL_A` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_files_open ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_object_files ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_files_title exp = `Files - ZCL_A` ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_popup ).
    " Metadata has its own navigable group; it never becomes an invented object.
    mo_app->mv_view = `ALL`.
    mo_app->rows_build( ).
    mo_client->mt_args = VALUE #( ( `` ) ( `` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_object_files ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_object_files[ 1 ]-filename exp = `.abapgit.xml` ).
  ENDMETHOD.
  METHOD diff_and_return.
    mo_client->mv_event = `OBJECT`.
    mo_client->mt_args = VALUE #( ( `CLAS` ) ( `ZCL_A` ) ).
    mo_app->on_event( ).
    mo_client->mv_event = `DIFF`.
    mo_client->mt_args = VALUE #( ( `/other/` ) ( `a.xml` ) ).
    mo_app->on_event( ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-file exp = `/other/a.xml` ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-object_link exp = `adt://A4H/a` ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-direction exp = `Changes in Git, compared with this system` ).
    CLEAR mo_client->mv_popup.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_popup ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_files_open ).
  ENDMETHOD.
  METHOD close_clears.
    mo_app->mv_zip = CONV xstring( 'CAFE' ).
    mo_client->mv_event = `OBJECT`.
    mo_client->mt_args = VALUE #( ( `CLAS` ) ( `ZCL_A` ) ).
    mo_app->on_event( ).
    mo_client->mv_event = `FILES_CLOSE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_files_open ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_object_files ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_files_title ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_destroyed ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_zip exp = CONV xstring( 'CAFE' ) ).
  ENDMETHOD.
  METHOD unknown_key.
    mo_client->mv_event = `OBJECT`.
    mo_client->mt_args = VALUE #( ( `CLAS` ) ( `ZCL_UNKNOWN` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_files_open ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_object_files ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).
  ENDMETHOD.
  METHOD offline_without_zip.
    mo_app->mv_offline = abap_true.
    mo_app->mv_row_type = `Inactive`.
    mo_client->mv_event = `OBJECT`.
    mo_client->mt_args = VALUE #( ( `CLAS` ) ( `ZCL_A` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_files_open ).
    mo_client->mv_event = `DIFF`.
    mo_client->mt_args = VALUE #( ( `/src/` ) ( `a.abap` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
  ENDMETHOD.
ENDCLASS.


"! Branches of a remote: main is the default, zeta is followed, alpha is free
CLASS ltd_branch_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mv_switched TYPE string.
    DATA mv_created TYPE string.
    DATA mv_deleted TYPE string.
    DATA mv_deleted_sha1 TYPE string.
ENDCLASS.

CLASS ltd_branch_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~list_branches.
    rt_branches = VALUE #(
      ( name = `refs/heads/main`  display = `main`  default = abap_true sha1 = `1111111aaaa` )
      ( name = `refs/heads/alpha` display = `alpha` sha1 = `3333333bbbb` link = `https://example.com/tree/alpha` )
      ( name = `refs/heads/zeta`  display = `zeta`  current = abap_true sha1 = `2222222cccc` ) ).
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~switch_branch.
    mv_switched = iv_branch.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~create_branch.
    mv_created = iv_name.
    rv_branch = |refs/heads/{ iv_name }|.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~delete_branch.
    mv_deleted = iv_branch.
    mv_deleted_sha1 = iv_sha1.
    rv_sha1 = iv_sha1.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~get_status ##NEEDED.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_branches DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_status.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_branch_service.
    METHODS setup.
    METHODS teardown.
    METHODS fire IMPORTING iv_event TYPE string iv_arg TYPE string OPTIONAL.
    METHODS rows_and_actions FOR TESTING.
    METHODS list_not_dropdown FOR TESTING.
    METHODS switch_from_row FOR TESTING.
    METHODS switch_refuses_unlisted FOR TESTING.
    METHODS delete_from_row FOR TESTING.
    METHODS delete_refuses_protected FOR TESTING.
    METHODS new_and_back FOR TESTING.
    METHODS create_in_new_mode FOR TESTING.
ENDCLASS.

CLASS ltcl_branches IMPLEMENTATION.
  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_app = zcl_ag2ui5_app_status=>create( `1` ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app->client = mo_client.
    mo_app->mi_service = mo_service.
    fire( `BRANCHES` ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD fire.
    mo_client->mv_event = iv_event.
    mo_client->mt_args = COND #( WHEN iv_arg IS SUPPLIED THEN VALUE #( ( iv_arg ) ) ).
    mo_app->on_event( ).
  ENDMETHOD.

  METHOD rows_and_actions.
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_branches ) exp = 3 ).
    DATA(ls_main) = mo_app->mt_branches[ name = `refs/heads/main` ].
    DATA(ls_alpha) = mo_app->mt_branches[ name = `refs/heads/alpha` ].
    DATA(ls_zeta) = mo_app->mt_branches[ name = `refs/heads/zeta` ].
    cl_abap_unit_assert=>assert_equals( act = ls_main-text exp = `main (default)` ).
    cl_abap_unit_assert=>assert_equals( act = ls_zeta-text exp = `zeta (followed)` ).
    cl_abap_unit_assert=>assert_equals( act = ls_alpha-commit exp = `3333333` ).
    cl_abap_unit_assert=>assert_true( ls_main-can_switch ).
    cl_abap_unit_assert=>assert_false( ls_main-can_delete ).
    cl_abap_unit_assert=>assert_true( ls_alpha-can_switch ).
    cl_abap_unit_assert=>assert_true( ls_alpha-can_delete ).
    cl_abap_unit_assert=>assert_false( ls_zeta-can_switch ).
    cl_abap_unit_assert=>assert_false( ls_zeta-can_delete ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_new_mode ).
  ENDMETHOD.

  METHOD list_not_dropdown.
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_popup exp = `*<Table*` ).
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_popup exp = `*<Select*` ).
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_popup exp = `*New branch...*` ).
  ENDMETHOD.

  METHOD switch_from_row.
    fire( iv_event = `BRANCH_SWITCH` iv_arg = `refs/heads/alpha` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_switched exp = `refs/heads/alpha` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_destroyed ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_toast exp = `Following alpha now` ).
  ENDMETHOD.

  METHOD switch_refuses_unlisted.
    " the argument comes from the browser
    fire( iv_event = `BRANCH_SWITCH` iv_arg = `refs/heads/forged` ).
    fire( iv_event = `BRANCH_SWITCH` iv_arg = `refs/heads/zeta` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_switched ).
  ENDMETHOD.

  METHOD delete_from_row.
    fire( iv_event = `BRANCH_DELETE` iv_arg = `refs/heads/alpha` ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_error exp = `Delete branch alpha (at 3333333)*` ).
    fire( iv_event = `BRANCH_DELETE_CLOSE` iv_arg = `DELETE` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_deleted exp = `refs/heads/alpha` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_deleted_sha1 exp = `3333333bbbb` ).
  ENDMETHOD.

  METHOD delete_refuses_protected.
    LOOP AT VALUE string_table( ( `refs/heads/main` ) ( `refs/heads/zeta` ) ( `refs/heads/forged` ) ) INTO DATA(lv_name).
      fire( iv_event = `BRANCH_DELETE` iv_arg = lv_name ).
      cl_abap_unit_assert=>assert_initial( act = mo_client->mv_error msg = |{ lv_name } offered for deletion| ).
    ENDLOOP.
    fire( iv_event = `BRANCH_DELETE_CLOSE` iv_arg = `DELETE` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_deleted ).
  ENDMETHOD.

  METHOD new_and_back.
    mo_app->mv_new_name = `old`.
    fire( `BRANCH_NEW` ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_new_mode ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_new_name ).
    fire( `BRANCH_BACK` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_new_mode ).
  ENDMETHOD.

  METHOD create_in_new_mode.
    fire( `BRANCH_NEW` ).
    mo_app->mv_new_name = `feature/x`.
    fire( `BRANCH_CREATE` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_created exp = `feature/x` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_toast exp = `Created and following feature/x` ).
  ENDMETHOD.
ENDCLASS.
