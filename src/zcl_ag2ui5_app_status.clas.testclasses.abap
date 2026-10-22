CLASS ltcl_routes DEFINITION DEFERRED.
CLASS ltcl_overview DEFINITION DEFERRED.
CLASS ltcl_object_links DEFINITION DEFERRED.
CLASS ltcl_offline DEFINITION DEFERRED.
CLASS ltcl_branches DEFINITION DEFERRED.
CLASS ltcl_settings DEFINITION DEFERRED.
CLASS ltcl_runs DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_status DEFINITION LOCAL FRIENDS ltcl_routes ltcl_offline ltcl_object_links ltcl_overview ltcl_branches ltcl_settings ltcl_runs.

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
    DATA mt_routes TYPE string_table.
    DATA mv_route TYPE string.
    DATA mv_has_caller TYPE abap_bool.
    DATA mo_left_to TYPE REF TO z2ui5_if_app.
    DATA mv_event TYPE string.
    DATA mv_navigated TYPE abap_bool.
    DATA mv_init TYPE abap_bool.
    DATA mv_view TYPE string.
    "! A test may identify the data object whose binding it wants to verify
    DATA mr_diff_binding TYPE REF TO data.
    DATA mr_busy_binding TYPE REF TO data.
    DATA mr_pull_binding TYPE REF TO data.
    DATA mv_timer_calls TYPE i.
    DATA mv_popup TYPE string.
    DATA mv_error TYPE string.
    DATA mt_box_actions TYPE string_table.
    DATA mv_emphasized_action TYPE string.
    DATA mv_toast TYPE string.
    DATA mv_left TYPE abap_bool.
    DATA mv_leave_data TYPE string.
    DATA mv_destroyed TYPE abap_bool.
    DATA mv_follow TYPE string.
    DATA mt_args TYPE string_table.
    DATA mo_called TYPE REF TO z2ui5_if_app.
    DATA ms_get TYPE z2ui5_if_client=>ty_s_get.
ENDCLASS.

CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~check_app_prev_stack.
    result = mv_has_caller.
  ENDMETHOD.

  METHOD z2ui5_if_client~get.
    result = ms_get.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_init.
    result = mv_init.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_navigated.
    result = xsdbool( mv_navigated = abap_true OR mv_init = abap_true ).
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
    mt_box_actions = actions.
    mv_emphasized_action = emphasizedaction.
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
    IF val = z2ui5_if_client~cs_event-start_timer.
      mv_timer_calls = mv_timer_calls + 1.
    ENDIF.
    IF val = z2ui5_if_client~cs_event-hash_replace
      OR val = z2ui5_if_client~cs_event-hash_set
      OR val = z2ui5_if_client~cs_event-hash_attach_changed
      OR val = z2ui5_if_client~cs_event-hash_routing
      OR val = z2ui5_if_client~cs_event-app_state_set_active.
      INSERT val INTO TABLE mt_routes.
      IF val = z2ui5_if_client~cs_event-hash_replace.
        mv_route = VALUE #( t_arg[ 1 ] OPTIONAL ).
      ENDIF.
      RETURN.
    ENDIF.

    mv_follow = val.
    mt_args = t_arg.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_leave.
    mo_left_to = app.
    mv_left = abap_true.
    IF r_data IS SUPPLIED.
      mv_leave_data = r_data.
    ENDIF.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_call.
    mo_called = app.
  ENDMETHOD.
  METHOD z2ui5_if_client~get_event_arg.
    result = VALUE #( mt_args[ v ] OPTIONAL ).
  ENDMETHOD.
  METHOD z2ui5_if_client~_bind.
    DATA(lr_value) = REF #( val ).
    IF mr_busy_binding IS BOUND AND lr_value = mr_busy_binding.
      result = `{/MV_BUSY}`.
    ENDIF.
    IF mr_pull_binding IS BOUND AND lr_value = mr_pull_binding.
      result = `{/MV_CAN_PULL}`.
    ENDIF.
    IF mr_diff_binding IS BOUND AND lr_value = mr_diff_binding.
      result = COND #( WHEN path = abap_true THEN `/MV_CAN_DIFF` ELSE `{/MV_CAN_DIFF}` ).
    ENDIF.
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
    METHODS sort_event_saves FOR TESTING.
    METHODS sort_toggles_changes_first FOR TESTING.
    METHODS sort_refuses_unknown FOR TESTING.
    METHODS sort_marks_current FOR TESTING.
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

  METHOD sort_event_saves.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = `SORT`.
    lo_client->mt_args = VALUE #( ( `FILE` ) ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `FILE` act = lo_app->mv_sort ).
    cl_abap_unit_assert=>assert_equals(
      exp = `FILE` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_sort ) ).
  ENDMETHOD.

  METHOD sort_toggles_changes_first.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = `SORT`.
    lo_client->mt_args = VALUE #( ( `CHANGES_FIRST` ) ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_false( lo_app->mv_changes_first ).
    cl_abap_unit_assert=>assert_equals(
      exp = `` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_changes_first ) ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_true( lo_app->mv_changes_first ).
  ENDMETHOD.

  METHOD sort_refuses_unknown.
    " the argument comes from the browser
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = `SORT`.
    lo_client->mt_args = VALUE #( ( `DROP TABLE` ) ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `OBJECT` act = lo_app->mv_sort ).
    cl_abap_unit_assert=>assert_initial( mo_settings->mt_saved ).
  ENDMETHOD.

  METHOD sort_marks_current.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = `SORT`.
    lo_client->mt_args = VALUE #( ( `FILE` ) ).
    lo_app->z2ui5_if_app~main( lo_client ).
    FIND REGEX `<MenuItem[^>]*text="File"[^>]*icon="sap-icon://accept"` IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
    FIND REGEX `<MenuItem[^>]*text="Object"[^>]*icon="sap-icon://accept"` IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 4 msg = lo_client->mv_view ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_header DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS back_never_overflows FOR TESTING.
    METHODS header_holds_actions_only FOR TESTING.
    METHODS table_holds_view_controls FOR TESTING.
    METHODS branch_shown_once FOR TESTING.
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

  METHOD header_holds_actions_only.
    " how the list looks belongs to the table, the page header acts
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_navigated = abap_true.
    lo_app->z2ui5_if_app~main( lo_client ).
    FIND REGEX `<customHeader>.*</customHeader>` IN lo_client->mv_view MATCH OFFSET DATA(lv_off) MATCH LENGTH DATA(lv_len).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
    DATA(lv_header) = substring( val = lo_client->mv_view off = lv_off len = lv_len ).
    cl_abap_unit_assert=>assert_char_np( act = lv_header exp = `*SegmentedButton*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_header exp = `*<Select*<core:Item key="refs/heads/*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_header exp = `*ToggleButton*` ).
    " the branch button names the branch; its tooltip says what it opens
    FIND REGEX `<Button[^>]*tooltip="Branches and tags"[^>]*icon="sap-icon://split"|<Button[^>]*icon="sap-icon://split"[^>]*tooltip="Branches and tags"`
      IN lv_header.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_header ).
  ENDMETHOD.

  METHOD branch_shown_once.
    " the branch button is the one place for the branch: no header line
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_navigated = abap_true.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_char_np( act = lo_client->mv_view exp = `*title="Branch"*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lo_client->mv_view exp = `*title="Remote commit"*` ).
  ENDMETHOD.

  METHOD table_holds_view_controls.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_navigated = abap_true.
    lo_app->z2ui5_if_app~main( lo_client ).
    FIND REGEX `<Table[^>]*>\s*<headerToolbar>\s*<OverflowToolbar[^>]*>.*SegmentedButton.*<MenuButton[^>]*sap-icon://sort.*</headerToolbar>`
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
    DATA mv_status_calls TYPE i.
    DATA mv_run_id TYPE string.
    DATA mv_status_run TYPE string.
    DATA mv_state_calls TYPE i.
    DATA mv_state_key TYPE string.
    DATA mv_state_run TYPE string.
    DATA ms_state TYPE zif_ag2ui5_repo_service=>ty_run_state.
    "! get_status raises this text when set
    DATA mv_status_error TYPE string.
    DATA mv_start_error TYPE string.
    DATA mv_preview_zip TYPE xstring.
    DATA mv_pull_zip TYPE xstring.
    DATA mv_export TYPE xstring.
    DATA mv_export_calls TYPE i.
    DATA mt_items TYPE zif_ag2ui5_repo_service=>ty_decision_items.
    DATA mv_transport TYPE string.
    DATA mv_ack TYPE abap_bool.
    DATA mt_repos TYPE zif_ag2ui5_repo_service=>ty_repos.
    DATA mv_label_saves TYPE i.
    DATA mv_saved_labels TYPE string.
    DATA mv_expected_labels TYPE string.
    DATA mv_label_error TYPE string.
ENDCLASS.

CLASS ltd_offline_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~list_repos.
    rt_repos = mt_repos.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~save_labels.
    mv_label_saves = mv_label_saves + 1.
    IF mv_label_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_label_error ).
    ENDIF.
    mv_saved_labels = iv_labels.
    mv_expected_labels = iv_expected.
    rt_labels = zcl_ag2ui5_repo_service=>repo_labels( iv_labels ).
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~get_diff.
    mv_diff_calls = mv_diff_calls + 1.
    mv_diff_zip = iv_zip.
    IF mv_diff_fail = abap_true.
      zcx_abapgit_exception=>raise( `Test load failure` ).
    ENDIF.
    rs_diff = ms_diff.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~get_status.
    mv_status_calls = mv_status_calls + 1.
    mv_status_run = iv_run_id.
    IF mv_status_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_status_error ).
    ENDIF.
    mv_status_zip = iv_zip.
    rs_status = ms_status.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~start_status.
    IF mv_start_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_start_error ).
    ENDIF.
    rs_start-run_id = mv_run_id.
    rs_start-head = ms_status.
    CLEAR rs_start-head-rows.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~run_state.
    mv_state_calls = mv_state_calls + 1.
    mv_state_key = iv_key.
    mv_state_run = iv_run_id.
    rs_state = ms_state.
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
    METHODS header_labels FOR TESTING.
    METHODS header_package_link FOR TESTING.
    METHODS labels_edit_save FOR TESTING.
    METHODS labels_edit_cancel FOR TESTING.
    METHODS labels_edit_errors FOR TESTING.
    METHODS labels_edit_stale FOR TESTING.
    METHODS labels_save_without_open FOR TESTING.
    METHODS offline_controls FOR TESTING.
    METHODS online_controls FOR TESTING.
    METHODS clean_online_can_manage_rules FOR TESTING.
    METHODS upload_preview FOR TESTING RAISING zcx_abapgit_exception.
    METHODS upload_waits_for_run FOR TESTING RAISING zcx_abapgit_exception.
    METHODS upload_run_error_no_preview FOR TESTING RAISING zcx_abapgit_exception.
    METHODS refresh_drops_pending_upload FOR TESTING RAISING zcx_abapgit_exception.
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

  METHOD header_labels.
    mo_service->ms_status-labels = VALUE #( ( text = `ui5` color = `purple` ) ).
    mo_client->mv_init = abap_true.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-labels exp = mo_service->ms_status-labels ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view exp = `*ag2ui5RepoTags*` ).
    mo_client->mv_init = abap_false.
    mo_client->mv_navigated = abap_false.
    mo_client->mt_args = VALUE #( ( `unknown` ) ).
    fire( `HEADER_LABEL` ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
    mo_client->mt_args = VALUE #( ( `ui5` ) ).
    mo_app->mv_zip = '00FF'.
    fire( `HEADER_LABEL` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_leave_data exp = `LABEL_FILTER:ui5` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_zip ).
  ENDMETHOD.

  METHOD header_package_link.
    mo_service->ms_status-package_link = `adt://A4H/sap/bc/adt/packages/%24test_offline`.
    mo_client->mv_init = abap_true.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-package_link exp = mo_service->ms_status-package_link ).
    " the repository name is the title; the package is the first attribute and links to ADT
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view
      exp = `*<ObjectHeader title=*><attributes><ObjectAttribute title="Package"><customContent><Link *href=*enabled=*` ).
    cl_abap_unit_assert=>assert_false( xsdbool( mo_client->mv_view CS `titleActive` ) ).
  ENDMETHOD.

  METHOD labels_edit_save.
    mo_service->mt_repos = VALUE #(
      ( key = `29` labels = VALUE #( ( text = `core` color = `blue` ) ) )
      ( key = `30` labels = VALUE #( ( text = `core` ) ( text = `tools` ) ) ) ).
    mo_app->mv_zip = '00FF'.
    fire( `LABELS_EDIT` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_label_choices ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_label_selected exp = VALUE string_table( ( `core` ) ) ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_popup exp = `*MultiComboBox*` ).
    mo_app->mv_label_new = ` new label `.
    fire( `LABELS_ADD` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_label_error ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mo_app->mt_label_selected[ table_line = `new label` ] ) ) ).
    mo_app->mt_label_selected = VALUE #( ( `new label` ) ( `tools` ) ).
    fire( `LABELS_SAVE` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_saved_labels exp = `new label, tools` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_expected_labels exp = `core` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->ms_head-labels ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_zip exp = CONV xstring( '00FF' ) ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_destroyed ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_label_choices ).
  ENDMETHOD.

  METHOD labels_edit_cancel.
    mo_service->mt_repos = VALUE #( ( key = `29` labels = VALUE #( ( text = `core` ) ) ) ).
    fire( `LABELS_EDIT` ).
    mo_app->mv_label_new = `discard`.
    fire( `LABELS_ADD` ).
    fire( `LABELS_CANCEL` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_label_saves ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_label_selected ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_labels_open ).
  ENDMETHOD.

  METHOD labels_edit_errors.
    mo_service->mt_repos = VALUE #( ( key = `29` ) ).
    fire( `LABELS_EDIT` ).
    mo_app->mv_label_new = `bad<label`.
    fire( `LABELS_ADD` ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mv_label_error ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_label_selected ).
    fire( `LABELS_SAVE` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_label_saves ).
    CLEAR mo_app->mv_label_new.
    mo_app->mt_label_selected = VALUE #( ( `forged,extra` ) ).
    fire( `LABELS_SAVE` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_label_saves ).
    mo_app->mt_label_selected = VALUE #( ).
    fire( `LABELS_SAVE` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_label_saves exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_head-labels ).
  ENDMETHOD.

  METHOD labels_edit_stale.
    mo_service->mt_repos = VALUE #( ( key = `29` ) ).
    mo_service->mv_label_error = `Labels changed since this dialog was opened`.
    fire( `LABELS_EDIT` ).
    fire( `LABELS_SAVE` ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_labels_open ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_label_error exp = mo_service->mv_label_error ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_destroyed ).
  ENDMETHOD.

  METHOD labels_save_without_open.
    fire( `LABELS_SAVE` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_label_saves ).
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
    " the branch button shows the branch name; Branches is its tooltip
    FIND REGEX `<Button visible="false"[^>]*tooltip="Branches and tags"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
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
    " the branch button shows the branch name; Branches is its tooltip
    FIND REGEX `<Button visible="true"[^>]*tooltip="Branches and tags"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
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

  METHOD upload_waits_for_run.
    " the last poll redraws the view, which closes an open dialog: the
    " preview opens only after it
    mo_service->mv_run_id = `R1`.
    DATA(lv_zip) = archive( ).
    mo_app->mv_upload = `data:application/zip;base64,` && cl_http_utility=>encode_x_base64( lv_zip ).
    fire( `ZIP_UPLOAD` ).
    cl_abap_unit_assert=>assert_equals( exp = lv_zip act = mo_app->mv_zip ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_preview_zip ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).

    mo_service->ms_state-state = zif_ag2ui5_repo_service=>c_run_state-running.
    fire( `RUN_POLL:R1` ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).

    CLEAR mo_client->mv_view.
    mo_service->ms_state-state = zif_ag2ui5_repo_service=>c_run_state-done.
    fire( `RUN_POLL:R1` ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_view ).
    cl_abap_unit_assert=>assert_equals( exp = lv_zip act = mo_service->mv_status_zip ).
    cl_abap_unit_assert=>assert_equals( exp = lv_zip act = mo_service->mv_preview_zip ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mv_popup CS `Pull selected` ) ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_pull_pending ).
  ENDMETHOD.

  METHOD upload_run_error_no_preview.
    mo_service->mv_run_id = `R1`.
    mo_app->mv_upload = `data:application/zip;base64,` && cl_http_utility=>encode_x_base64( archive( ) ).
    fire( `ZIP_UPLOAD` ).
    mo_service->ms_state-state = zif_ag2ui5_repo_service=>c_run_state-error.
    mo_service->ms_state-message = `Serialization failed`.
    fire( `RUN_POLL:R1` ).
    cl_abap_unit_assert=>assert_equals( exp = `Serialization failed` act = mo_client->mv_error ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_preview_zip ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_pull_pending ).
  ENDMETHOD.

  METHOD refresh_drops_pending_upload.
    mo_service->mv_run_id = `R1`.
    mo_app->mv_upload = `data:application/zip;base64,` && cl_http_utility=>encode_x_base64( archive( ) ).
    fire( `ZIP_UPLOAD` ).
    fire( `REFRESH` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_pull_pending ).
    mo_service->ms_state-state = zif_ag2ui5_repo_service=>c_run_state-done.
    fire( `RUN_POLL:R1` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_preview_zip ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).
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
    METHODS diff_uses_server_hash FOR TESTING.
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
    METHODS changed_by_in_objects_only FOR TESTING.
    METHODS open_all_files FOR TESTING.
    METHODS diff_and_return FOR TESTING.
    METHODS close_clears FOR TESTING.
    METHODS unknown_key FOR TESTING.
    METHODS offline_without_zip FOR TESTING.
    METHODS semantic_navigation FOR TESTING.
    METHODS semantic_load_failure FOR TESTING.
    METHODS return_after_push_reloads FOR TESTING.
    METHODS return_without_push_keeps FOR TESTING.
    METHODS return_after_push_shows_text FOR TESTING.
    METHODS login_error_opens_login FOR TESTING.
    METHODS other_error_message FOR TESTING.
    METHODS logged_in_reloads FOR TESTING.
    METHODS wrong_login_reopens FOR TESTING.
    METHODS repo_diff_passes_changed FOR TESTING.
    METHODS diff_off_offline_without_zip FOR TESTING.
    METHODS diff_disabled_without_changes FOR TESTING.
    METHODS refresh_follows_changes FOR TESTING.
    METHODS diff_button_binding FOR TESTING.
ENDCLASS.

CLASS ltcl_overview IMPLEMENTATION.
  METHOD login_error_opens_login.
    " abapGit's user exit has no credentials for the remote: log in, no error box
    CAST ltd_offline_service( mo_app->mi_service )->mv_status_error = `Unauthorized access. Check your credentials`.
    mo_client->mv_event = `REFRESH`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_bound( CAST zcl_ag2ui5_app_login( mo_client->mo_called ) ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_error ).
  ENDMETHOD.

  METHOD other_error_message.
    CAST ltd_offline_service( mo_app->mi_service )->mv_status_error = `Boom`.
    mo_client->mv_event = `REFRESH`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_error exp = `Boom` ).
  ENDMETHOD.

  METHOD wrong_login_reopens.
    " the remote rejected the credentials: abapGit drops them, the reload
    " asks again, and the login page opens again - no silent loop
    DATA(lo_service) = CAST ltd_offline_service( mo_app->mi_service ).
    lo_service->mv_status_error = `Unauthorized access to resource (HTTP 401). Check your credentials`.
    mo_client->ms_get-r_event_data = NEW string( `LOGGED_IN:github.com` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_bound( CAST zcl_ag2ui5_app_login( mo_client->mo_called ) ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_error ).
  ENDMETHOD.

  METHOD logged_in_reloads.
    DATA(lo_service) = CAST ltd_offline_service( mo_app->mi_service ).
    mo_client->ms_get-r_event_data = NEW string( `LOGGED_IN:github.com` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = lo_service->mv_status_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_toast
                                        exp = `Logged in to github.com - repeat the action if it did not run` ).
  ENDMETHOD.

  METHOD repo_diff_passes_changed.
    " every changed file, in file order, whatever the filter shows
    mo_app->mv_offline = abap_false.
    mo_app->mv_view = `CHANGES`.
    mo_client->mv_event = `REPO_DIFF`.
    mo_app->on_event( ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_repo_diff( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_diff->mt_files ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 1 ]-file exp = `/other/a.xml` ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 2 ]-file exp = `/src/a.abap` ).
  ENDMETHOD.

  METHOD diff_off_offline_without_zip.
    DATA(lo_service) = CAST ltd_offline_service( mo_app->mi_service ).
    lo_service->ms_status = VALUE #( offline = abap_true
      rows = VALUE #( ( path = `/src/` filename = `a.abap` lstate = `M` changed = abap_true ) ) ).
    CLEAR mo_app->mv_zip.
    mo_client->mv_event = `REFRESH`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
    mo_client->mv_event = `REPO_DIFF`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
  ENDMETHOD.

  METHOD diff_disabled_without_changes.
    CAST ltd_offline_service( mo_app->mi_service )->ms_status-rows = VALUE #(
      ( path = `/src/` filename = `a.abap` changed = abap_false ) ).
    mo_client->mv_event = `REFRESH`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
    mo_client->mv_event = `REPO_DIFF`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
  ENDMETHOD.

  METHOD diff_button_binding.
    " Compare references, not boolean values: binding another flag must fail.
    mo_client->mr_diff_binding = REF #( mo_app->mv_can_diff ).
    mo_app->view_display( ).
    FIND REGEX `<Button[^>]*text="Diff"[^>]*enabled="\{/MV_CAN_DIFF\}"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
  ENDMETHOD.

  METHOD refresh_follows_changes.
    " Refresh reloads the status without rendering the view again: the button
    " state has to come from the reloaded status, not from the first render
    DATA(lo_service) = CAST ltd_offline_service( mo_app->mi_service ).
    lo_service->ms_status-rows = VALUE #( ( path = `/src/` filename = `a.abap` changed = abap_false ) ).
    mo_client->mv_event = `REFRESH`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
    lo_service->ms_status-rows = VALUE #( ( path = `/src/` filename = `a.abap` lstate = `M` changed = abap_true ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_diff ).
    mo_client->mv_event = `REPO_DIFF`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_bound( mo_client->mo_called ).
    lo_service->ms_status-rows = VALUE #( ( path = `/src/` filename = `a.abap` changed = abap_false ) ).
    mo_client->mv_event = `REFRESH`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
    lo_service->mv_status_error = `Boom`.
    lo_service->ms_status-rows = VALUE #( ( path = `/src/` filename = `a.abap` lstate = `M` changed = abap_true ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
  ENDMETHOD.

  METHOD return_after_push_reloads.
    " a push may have moved the repository to a new branch
    CAST ltd_offline_service( mo_app->mi_service )->ms_status-branch_display = `feature-x`.
    mo_app->ms_head-branch_display = `main`.
    mo_client->ms_get-r_event_data = NEW string( `PUSHED` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-branch_display exp = `feature-x` ).
  ENDMETHOD.

  METHOD return_after_push_shows_text.
    " the stage page left by itself: its toast would be lost on the way
    CAST ltd_offline_service( mo_app->mi_service )->ms_status-branch_display = `feature-x`.
    mo_client->ms_get-r_event_data = NEW string( `PUSHED:Pushed abc1234 to feature-x` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-branch_display exp = `feature-x` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_toast exp = `Pushed abc1234 to feature-x` ).
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
  METHOD changed_by_in_objects_only.
    " the Objects view shows who changed an object; the Files view does not
    mo_app->mt_status = VALUE #(
      ( obj_type = `CLAS` obj_name = `ZCL_A` path = `/src/` filename = `a.abap` rstate = `M` changed_by = `ALICE` ) ).
    mo_app->mv_overview = `OBJECTS`.
    mo_app->rows_build( ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-changed_by exp = `ALICE` ).
    mo_app->view_display( ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view exp = `*{CHANGED_BY}*` ).
    mo_app->mv_overview = `FILES`.
    mo_app->view_display( ).
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_view exp = `*{CHANGED_BY}*` ).
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
    DATA mt_tags TYPE zif_ag2ui5_repo_service=>ty_tags.
    DATA mv_tag TYPE string.
    DATA mv_tag_sha1 TYPE string.
    DATA mv_tag_error TYPE string.
    DATA ms_created_tag TYPE zif_ag2ui5_repo_service=>ty_new_tag.
    DATA ms_expected_tag TYPE zif_ag2ui5_repo_service=>ty_tag_target.
    DATA mv_deleted_tag TYPE string.
    DATA mv_deleted_tag_sha1 TYPE string.
ENDCLASS.

CLASS ltd_branch_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~delete_tag.
    IF mv_tag_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_tag_error ).
    ENDIF.
    mv_deleted_tag = iv_tag.
    mv_deleted_tag_sha1 = iv_ref_sha1.
    DELETE mt_tags WHERE name = iv_tag.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~tag_target.
    IF mv_tag_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_tag_error ).
    ENDIF.
    rs_target = VALUE #( ref = `refs/heads/zeta` sha1 = `2222222cccc` name = `Alice` email = `alice@example.com` ).
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~create_tag.
    IF mv_tag_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_tag_error ).
    ENDIF.
    ms_created_tag = is_tag.
    ms_expected_tag = is_expected.
    rv_tag = |refs/tags/{ is_tag-name }|.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~list_tags.
    IF mv_tag_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_tag_error ).
    ENDIF.
    rt_tags = mt_tags.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~switch_tag.
    mv_tag = iv_tag.
    mv_tag_sha1 = iv_sha1.
  ENDMETHOD.
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
  METHOD zif_ag2ui5_repo_service~get_status.
    rs_status-branch = mv_tag.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~start_status.
    " no run ID: Status loads synchronously through get_status
    rs_start-head-branch = mv_tag.
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
    METHODS tags_lazy_load_and_switch FOR TESTING.
    METHODS tags_empty_and_failure FOR TESTING.
    METHODS tags_reject_bad_event FOR TESTING.
    METHODS new_tag_flow FOR TESTING.
    METHODS new_tag_failure_and_back FOR TESTING.
    METHODS new_tag_event_guards FOR TESTING.
    METHODS tag_delete_confirmation FOR TESTING.
    METHODS noncommit_tag_actions FOR TESTING.
    METHODS tag_delete_guards FOR TESTING.
    METHODS tag_delete_error_and_cancel FOR TESTING.
ENDCLASS.

CLASS ltcl_branches IMPLEMENTATION.
  METHOD noncommit_tag_actions.
    mo_service->mt_tags = VALUE #( ( name = `refs/tags/tree` display = `tree` ref_sha1 = `tagobject` ) ).
    mo_app->mv_ref_tab = `TAGS`.
    fire( `REF_TAB` ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_tags[ 1 ]-can_switch ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_tags[ 1 ]-can_delete ).
    fire( iv_event = `TAG_SWITCH` iv_arg = `refs/tags/tree` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_tag ).
    fire( iv_event = `TAG_DELETE` iv_arg = `refs/tags/tree` ).
    fire( iv_event = `TAG_DELETE_CLOSE` iv_arg = `DELETE` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_deleted_tag_sha1 exp = `tagobject` ).
  ENDMETHOD.
  METHOD tag_delete_confirmation.
    mo_service->mt_tags = VALUE #( ( name = `refs/tags/v1` display = `v1` sha1 = `commit1` ref_sha1 = `tagobj1` ) ).
    mo_app->mv_ref_tab = `TAGS`.
    fire( `REF_TAB` ).
    fire( iv_event = `TAG_DELETE` iv_arg = `refs/tags/v1` ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_error exp = `Delete tag v1 on the remote (commit: commit1)*` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_deleted_tag ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mt_box_actions[ 1 ] exp = `CANCEL` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_emphasized_action exp = `CANCEL` ).
    fire( iv_event = `TAG_DELETE_CLOSE` iv_arg = `DELETE` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_deleted_tag exp = `refs/tags/v1` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_deleted_tag_sha1 exp = `tagobj1` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_tags ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_ref_tab exp = `TAGS` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_tag ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_tag_sha1 ).
    CLEAR mo_service->mv_deleted_tag.
    fire( iv_event = `TAG_DELETE_CLOSE` iv_arg = `DELETE` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_deleted_tag ).
  ENDMETHOD.
  METHOD tag_delete_guards.
    mo_service->mt_tags = VALUE #( ( name = `refs/tags/current` display = `current` current = abap_true ref_sha1 = `obj1` )
      ( name = `refs/tags/free` display = `free` ref_sha1 = `obj2` ) ).
    mo_app->mv_ref_tab = `TAGS`.
    fire( `REF_TAB` ).
    LOOP AT VALUE string_table( ( `refs/tags/current` ) ( `refs/tags/forged` ) ) INTO DATA(lv_tag).
      fire( iv_event = `TAG_DELETE` iv_arg = lv_tag ).
      fire( iv_event = `TAG_DELETE_CLOSE` iv_arg = `DELETE` ).
      cl_abap_unit_assert=>assert_initial( mo_service->mv_deleted_tag ).
    ENDLOOP.
    mo_app->mv_offline = abap_true.
    fire( iv_event = `TAG_DELETE` iv_arg = `refs/tags/free` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_tag ).
    mo_app->mv_offline = abap_false.
    mo_app->mv_new_mode = abap_true.
    fire( iv_event = `TAG_DELETE` iv_arg = `refs/tags/free` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_tag ).
    mo_app->mv_new_mode = abap_false.
    mo_app->mv_ref_tab = `BRANCHES`.
    fire( iv_event = `TAG_DELETE` iv_arg = `refs/tags/free` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_tag ).
  ENDMETHOD.
  METHOD tag_delete_error_and_cancel.
    mo_service->mt_tags = VALUE #( ( name = `refs/tags/v1` display = `v1` ref_sha1 = `tagobj1` ) ).
    mo_app->mv_ref_tab = `TAGS`.
    fire( `REF_TAB` ).
    fire( iv_event = `TAG_DELETE` iv_arg = `refs/tags/v1` ).
    fire( iv_event = `TAG_DELETE_CLOSE` iv_arg = `CANCEL` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_deleted_tag ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_tag_sha1 ).
    fire( iv_event = `TAG_DELETE` iv_arg = `refs/tags/v1` ).
    mo_service->mv_tag_error = `The tag changed`.
    fire( iv_event = `TAG_DELETE_CLOSE` iv_arg = `DELETE` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_deleted_tag ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_tag ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mt_tags ).
  ENDMETHOD.
  METHOD new_tag_flow.
    mo_app->mv_ref_tab = `TAGS`.
    fire( `TAG_NEW` ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_tag_new_mode ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_new_tag-kind exp = `LIGHTWEIGHT` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_new_tag-tagger_email exp = `alice@example.com` ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_app->mv_start_text exp = `*2222222cccc*Local changes are not included*` ).
    mo_app->ms_new_tag-name = `v1`.
    fire( `BRANCH_CREATE` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->ms_created_tag-name exp = `v1` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->ms_expected_tag-sha1 exp = `2222222cccc` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_created ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_new_mode ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_new_tag ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_tag_expected ).
  ENDMETHOD.
  METHOD new_tag_failure_and_back.
    mo_app->mv_ref_tab = `TAGS`.
    fire( `TAG_NEW` ).
    mo_app->ms_new_tag-name = `v1`.
    mo_service->mv_tag_error = `The target changed`.
    fire( `BRANCH_CREATE` ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_new_mode ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_new_tag-name exp = `v1` ).
    cl_abap_unit_assert=>assert_initial( mo_service->ms_created_tag ).
    fire( `BRANCH_BACK` ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_new_tag ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_tag_expected ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_tag_new_mode ).
  ENDMETHOD.
  METHOD new_tag_event_guards.
    fire( `TAG_NEW` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_new_mode ).
    mo_app->mv_ref_tab = `TAGS`.
    mo_app->mv_offline = abap_true.
    fire( `TAG_NEW` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_new_mode ).
    mo_app->mv_offline = abap_false.
    fire( `BRANCH_CREATE` ).
    cl_abap_unit_assert=>assert_initial( mo_service->ms_created_tag ).
    mo_service->mv_tag_error = `Cannot load target`.
    fire( `TAG_NEW` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_new_mode ).
  ENDMETHOD.
  METHOD tags_lazy_load_and_switch.
    cl_abap_unit_assert=>assert_initial( mo_app->mt_tags ).
    mo_service->mt_tags = VALUE #(
      ( name = `refs/tags/v2` display = `v2` sha1 = `1234567abcd` )
      ( name = `refs/tags/v1` display = `v1` sha1 = `7654321abcd` current = abap_true ) ).
    mo_app->mv_ref_tab = `TAGS`.
    fire( `REF_TAB` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_tags ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_tags[ 1 ]-commit exp = `1234567` ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_tags[ 2 ]-can_switch ).
    fire( iv_event = `TAG_SWITCH` iv_arg = `refs/tags/v2` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_tag exp = `refs/tags/v2` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_tag_sha1 exp = `1234567abcd` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_destroyed ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_is_tag ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_stage ).
    fire( `STAGE` ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
  ENDMETHOD.
  METHOD tags_empty_and_failure.
    mo_app->mv_ref_tab = `TAGS`.
    fire( `REF_TAB` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_tags ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_tags_note exp = `The remote has no tags` ).
    mo_service->mv_tag_error = `Remote unavailable`.
    fire( `REF_TAB` ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_app->mv_tags_note exp = `Tags could not be loaded*` ).
  ENDMETHOD.
  METHOD tags_reject_bad_event.
    mo_service->mt_tags = VALUE #( ( name = `refs/tags/v1` sha1 = `1234567` current = abap_true ) ).
    mo_app->mv_ref_tab = `TAGS`.
    fire( `REF_TAB` ).
    fire( iv_event = `TAG_SWITCH` iv_arg = `refs/tags/forged` ).
    fire( iv_event = `TAG_SWITCH` iv_arg = `refs/tags/v1` ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_tag ).
    mo_app->mv_ref_tab = `forged`.
    fire( `REF_TAB` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_ref_tab exp = `BRANCHES` ).
  ENDMETHOD.
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
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_popup exp = `*<Select*<core:Item key="refs/heads/*` ).
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_popup exp = `*New branch...*` ).
    " the name is the link to the branch; no separate Open link
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_popup exp = `*text="Open"*` ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_popup exp = `*<Link*text="{TEXT}"*href="{LINK}"*` ).
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

CLASS ltcl_routes DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_status.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_offline_service.
    METHODS setup.
    METHODS teardown.
    METHODS route_edit_discards_status FOR TESTING.
    METHODS cold_back FOR TESTING.
    METHODS caller_back FOR TESTING.
    METHODS cold_label_back FOR TESTING.
    METHODS replacement_on_event FOR TESTING.
ENDCLASS.
CLASS ltcl_routes IMPLEMENTATION.
  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_app = zcl_ag2ui5_app_status=>create( iv_key = `000000000010` ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app->mi_service = mo_service.
    mo_service->ms_status = VALUE #( name = `Fresh repository` rows = VALUE #(
      ( path = `/fresh/` filename = `new.abap` changed = abap_true lstate = `M` )
      ( path = `/fresh/` filename = `same.xml` changed = abap_false ) ) ).
  ENDMETHOD.
  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.
  METHOD route_edit_discards_status.
    mo_client->mv_event = `ROUTE_CHANGED`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
    cl_abap_unit_assert=>assert_initial( mo_client->mt_routes ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_status_calls exp = 0 ).
  ENDMETHOD.
  METHOD cold_back.
    mo_client->mv_event = `BACK`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_route exp = `/` ).
  ENDMETHOD.
  METHOD caller_back.
    mo_client->mv_has_caller = abap_true.
    mo_client->mv_event = `BACK`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_left_to ).
  ENDMETHOD.
  METHOD cold_label_back.
    mo_app->ms_head-labels = VALUE #( ( text = `core` ) ).
    mo_client->mt_args = VALUE #( ( `core` ) ).
    mo_client->mv_event = `HEADER_LABEL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_leave_data exp = `LABEL_FILTER:core` ).
  ENDMETHOD.
  METHOD replacement_on_event.
    mo_client->mv_event = `NO_ACTION`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_route exp = `/repo/000000000010` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_client->mt_routes ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_status_calls exp = 0 ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_runs DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_status.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_offline_service.
    METHODS setup.
    METHODS poll IMPORTING iv_state TYPE string.
    METHODS assert_failed.
    METHODS run_shows_head_and_busy FOR TESTING.
    METHODS poll_running_updates_progress FOR TESTING.
    METHODS poll_done_loads_rows FOR TESTING.
    METHODS poll_error_shows_message FOR TESTING.
    METHODS poll_gone_shows_error FOR TESTING.
    METHODS idle_run_times_out FOR TESTING.
    METHODS stale_poll_is_ignored FOR TESTING.
    METHODS start_failure_loads_sync FOR TESTING.
    METHODS login_after_run_opens_login FOR TESTING.
    METHODS refresh_clears_loaded_rows FOR TESTING.
    METHODS start_error_clears_run FOR TESTING.
    METHODS done_fetch_error_stops_poll FOR TESTING.
    METHODS poll_without_run_is_ignored FOR TESTING.
    METHODS start_run IMPORTING iv_event TYPE string OPTIONAL.
    METHODS other_event_keeps_polling FOR TESTING.
    METHODS refused_event_keeps_polling FOR TESTING.
    METHODS return_keeps_polling FOR TESTING.
    METHODS leaving_does_not_poll FOR TESTING.
    METHODS no_run_no_timer FOR TESTING.
    METHODS start_text_needs_commit FOR TESTING.
ENDCLASS.

CLASS ltcl_runs IMPLEMENTATION.
  METHOD setup.
    mo_app = NEW #( ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app->client = mo_client.
    mo_app->mi_service = mo_service.
    mo_app->mv_key = `1`.
    mo_service->mv_run_id = `R1`.
    mo_service->ms_status = VALUE #( name = `Test` package = `$TEST` branch = `refs/heads/main`
      branch_display = `main` url = `https://example.org/repo` remote_commit = `1234567890`
      rows = VALUE #( ( path = `/` filename = `test.abap` changed = abap_true lstate = `M` ) ) ).
  ENDMETHOD.

  METHOD poll.
    mo_service->ms_state-state = iv_state.
    mo_client->mv_event = `RUN_POLL:R1`.
    CLEAR: mo_client->mv_timer_calls, mo_client->mv_follow, mo_client->mt_args, mo_client->mv_view.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.

  METHOD assert_failed.
    cl_abap_unit_assert=>assert_initial( mo_app->mv_run_id ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_busy ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_loaded ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_stage ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_pull ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_rows ).
    cl_abap_unit_assert=>assert_equals( exp = `Status could not be loaded` act = mo_app->mv_no_data ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_view ).
  ENDMETHOD.

  METHOD run_shows_head_and_busy.
    mo_client->mv_init = abap_true.
    mo_client->mr_busy_binding = REF #( mo_app->mv_busy ).
    mo_client->mr_pull_binding = REF #( mo_app->mv_can_pull ).
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `Test` act = mo_app->ms_head-name ).
    cl_abap_unit_assert=>assert_equals( exp = `$TEST` act = mo_app->ms_head-package ).
    cl_abap_unit_assert=>assert_equals( exp = `main` act = mo_app->ms_head-branch_display ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_busy ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_loaded ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_stage ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_rows ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_status_calls ).
    cl_abap_unit_assert=>assert_equals( exp = `Serializing...` act = mo_app->mv_no_data ).
    cl_abap_unit_assert=>assert_equals( exp = z2ui5_if_client=>cs_event-start_timer act = mo_client->mv_follow ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `RUN_POLL:R1` ) ( `1000` ) ( `X` ) ) act = mo_client->mt_args ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*busy="{/MV_BUSY}"*` act = mo_client->mv_view ).
    FIND REGEX `<Button[^>]*enabled="\{/MV_CAN_PULL\}"[^>]*type="Emphasized"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( ).
  ENDMETHOD.

  METHOD poll_running_updates_progress.
    mo_app->load_status( ).
    mo_service->ms_state = VALUE #( done = 340 total = 1419 idle_seconds = 900 ).
    poll( zif_ag2ui5_repo_service=>c_run_state-running ).
    cl_abap_unit_assert=>assert_equals( exp = `Serializing 340 / 1,419` act = mo_app->mv_no_data ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = mo_service->mv_state_key ).
    cl_abap_unit_assert=>assert_equals( exp = `R1` act = mo_service->mv_state_run ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_status_calls ).
  ENDMETHOD.

  METHOD poll_done_loads_rows.
    mo_app->mv_zip = '504B'.
    mo_app->load_status( ).
    poll( zif_ag2ui5_repo_service=>c_run_state-done ).
    cl_abap_unit_assert=>assert_equals( exp = `R1` act = mo_service->mv_status_run ).
    cl_abap_unit_assert=>assert_equals( exp = mo_app->mv_zip act = mo_service->mv_status_zip ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_app->mt_rows ) ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_loaded ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_stage ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_diff ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_busy ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_run_id ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_view ).
  ENDMETHOD.

  METHOD poll_error_shows_message.
    mo_app->load_status( ).
    mo_service->ms_state-message = `Serialization failed`.
    poll( zif_ag2ui5_repo_service=>c_run_state-error ).
    assert_failed( ).
    cl_abap_unit_assert=>assert_equals( exp = `Serialization failed` act = mo_client->mv_error ).
  ENDMETHOD.

  METHOD poll_gone_shows_error.
    mo_app->load_status( ).
    poll( zif_ag2ui5_repo_service=>c_run_state-gone ).
    assert_failed( ).
  ENDMETHOD.

  METHOD idle_run_times_out.
    mo_app->load_status( ).
    mo_service->ms_state-idle_seconds = 901.
    poll( zif_ag2ui5_repo_service=>c_run_state-running ).
    assert_failed( ).
  ENDMETHOD.

  METHOD stale_poll_is_ignored.
    mo_app->load_status( ).
    mo_service->mv_run_id = `R2`.
    mo_client->mv_event = `REFRESH`.
    mo_app->z2ui5_if_app~main( mo_client ).
    poll( zif_ag2ui5_repo_service=>c_run_state-done ).
    cl_abap_unit_assert=>assert_equals( exp = `R2` act = mo_app->mv_run_id ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_state_calls ).
    " the ignored tick still cancelled the timer of run R2
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `RUN_POLL:R2` ) ( `1000` ) ( `X` ) ) act = mo_client->mt_args ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_status_calls ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_busy ).
  ENDMETHOD.

  METHOD start_failure_loads_sync.
    CLEAR mo_service->mv_run_id.
    mo_app->load_status( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_service->mv_status_calls ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_status_run ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_app->mt_rows ) ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_loaded ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_busy ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
  ENDMETHOD.

  METHOD login_after_run_opens_login.
    mo_app->load_status( ).
    mo_service->mv_status_error = `Unauthorized access. Check your credentials`.
    poll( zif_ag2ui5_repo_service=>c_run_state-done ).
    cl_abap_unit_assert=>assert_bound( CAST zcl_ag2ui5_app_login( mo_client->mo_called ) ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_busy ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_run_id ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
  ENDMETHOD.

  METHOD refresh_clears_loaded_rows.
    CLEAR mo_service->mv_run_id.
    mo_app->load_status( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_pull ).
    mo_service->mv_run_id = `R1`.
    mo_client->mv_event = `REFRESH`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_loaded ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_pull ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_stage ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_diff ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_status ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_rows ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_busy ).
  ENDMETHOD.

  METHOD start_error_clears_run.
    mo_app->load_status( ).
    mo_service->mv_start_error = `Start failed`.
    CLEAR mo_client->mv_timer_calls.
    mo_app->load_status( ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_run_id ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_busy ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_stage ).
    cl_abap_unit_assert=>assert_equals( exp = `Start failed` act = mo_client->mv_error ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_pull ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
  ENDMETHOD.

  METHOD done_fetch_error_stops_poll.
    mo_app->load_status( ).
    mo_service->mv_status_error = `Remote fetch failed`.
    poll( zif_ag2ui5_repo_service=>c_run_state-done ).
    assert_failed( ).
    cl_abap_unit_assert=>assert_equals( exp = `Remote fetch failed` act = mo_client->mv_error ).
  ENDMETHOD.

  METHOD poll_without_run_is_ignored.
    poll( zif_ag2ui5_repo_service=>c_run_state-done ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_state_calls ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_status_calls ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
  ENDMETHOD.

  METHOD start_run.
    " opens the page with a run active; the next round trip is iv_event
    mo_client->mv_init = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    mo_client->mv_init = abap_false.
    mo_client->mv_event = iv_event.
    CLEAR: mo_client->mv_timer_calls, mo_client->mv_follow, mo_client->mt_args.
  ENDMETHOD.

  METHOD other_event_keeps_polling.
    mo_service->mt_repos = VALUE #( ( key = `1` ) ).
    start_run( `LABELS_EDIT` ).
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_popup ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `RUN_POLL:R1` ) ( `1000` ) ( `X` ) ) act = mo_client->mt_args ).
    CLEAR: mo_client->mv_timer_calls, mo_client->mt_args.
    mo_client->mv_event = `LABELS_CANCEL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    CLEAR mo_client->mv_timer_calls.
    mo_client->mv_event = `NO_ACTION`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_busy ).
    cl_abap_unit_assert=>assert_equals( exp = `R1` act = mo_app->mv_run_id ).
  ENDMETHOD.

  METHOD refused_event_keeps_polling.
    " Stage is not offered while the status loads: the refusal leaves nothing behind
    start_run( `STAGE` ).
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    CLEAR mo_client->mv_timer_calls.
    mo_client->mv_event = `PULL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
  ENDMETHOD.

  METHOD return_keeps_polling.
    " back from the login app without a login: the run is still going
    start_run( ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    cl_abap_unit_assert=>assert_equals( exp = VALUE string_table( ( `RUN_POLL:R1` ) ( `1000` ) ( `X` ) ) act = mo_client->mt_args ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_view ).
  ENDMETHOD.

  METHOD leaving_does_not_poll.
    start_run( `BACK` ).
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
    " the flag is per round trip: the next one on this page polls again
    mo_client->mv_event = `NO_ACTION`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_client->mv_timer_calls ).
    " a label filter leaves the page too
    CLEAR mo_client->mv_timer_calls.
    mo_app->ms_head-labels = VALUE #( ( text = `core` ) ).
    mo_client->mt_args = VALUE #( ( `core` ) ).
    mo_client->mv_event = `HEADER_LABEL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `LABEL_FILTER:core` act = mo_client->mv_leave_data ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
  ENDMETHOD.

  METHOD no_run_no_timer.
    CLEAR mo_service->mv_run_id.
    start_run( `NO_ACTION` ).
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_timer_calls ).
  ENDMETHOD.

  METHOD start_text_needs_commit.
    " while the run is active the head has no remote commit
    mo_service->ms_status-remote_commit = ``.
    start_run( `BRANCH_BACK` ).
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `Starts from: main` act = mo_app->mv_start_text ).
    mo_service->ms_status-remote_commit = `1234567890`.
    mo_app->load_status( ).
    mo_app->mv_run_id = `R1`.
    poll( zif_ag2ui5_repo_service=>c_run_state-done ).
    mo_client->mv_event = `BRANCH_BACK`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `Starts from: main at 1234567` act = mo_app->mv_start_text ).
  ENDMETHOD.
ENDCLASS.
