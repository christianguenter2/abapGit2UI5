CLASS ltcl_offline DEFINITION DEFERRED.
CLASS ltcl_delete DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_repos DEFINITION LOCAL FRIENDS ltcl_offline ltcl_delete.

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


"! abap2UI5 client: either the start (navigated) or one event
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_start TYPE abap_bool.
    DATA mv_event TYPE string.
    DATA mo_called TYPE REF TO z2ui5_if_app.
    DATA ms_get TYPE z2ui5_if_client=>ty_s_get.
    DATA mv_toast TYPE string.
    DATA mv_arg TYPE string.
    DATA mv_popup TYPE string.
    DATA mv_closed TYPE abap_bool.
    DATA mv_error TYPE string.
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
  METHOD z2ui5_if_client~view_display ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~follow_up_action ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_box_display.
    mv_error = text.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_display.
    mv_popup = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_destroy.
    mv_closed = abap_true.
  ENDMETHOD.
  "! the view is built but not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_call.
    mo_called = app.
  ENDMETHOD.
  METHOD z2ui5_if_client~get_event_arg.
    result = mv_arg.
  ENDMETHOD.
  METHOD z2ui5_if_client~get.
    result = ms_get.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_toast_display.
    mv_toast = text.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_delete_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA ms_preview TYPE zif_ag2ui5_repo_service=>ty_delete_preview.
    DATA ms_received TYPE zif_ag2ui5_repo_service=>ty_delete_preview.
    DATA ms_result TYPE zif_ag2ui5_repo_service=>ty_delete_result.
    DATA mv_calls TYPE i.
    DATA mv_confirmation TYPE string.
    DATA mv_transport TYPE string.
    DATA mv_raise TYPE abap_bool.
ENDCLASS.

CLASS ltd_delete_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~preview_delete.
    rs_preview = ms_preview.
    rs_preview-key = iv_key.
    rs_preview-action = iv_action.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~delete_repo.
    mv_calls = mv_calls + 1.
    ms_received = is_preview.
    mv_confirmation = iv_confirmation.
    mv_transport = iv_transport.
    IF mv_raise = abap_true.
      zcx_abapgit_exception=>raise( `Test rejection` ).
    ENDIF.
    rs_result = ms_result.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~list_repos ##NEEDED.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~list_transports.
    rt_transports = VALUE #( ( trkorr = `A4HK900148` text = `Test request` ) ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_delete DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_repos.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_delete_service.
    METHODS setup.
    METHODS event IMPORTING iv_event TYPE string.
    METHODS cancel_never_deletes FOR TESTING.
    METHODS uninstall_requires_preview FOR TESTING.
    METHODS remove_success_clears FOR TESTING.
    METHODS transport_starts_unselected FOR TESTING.
    METHODS server_error_retains_dialog FOR TESTING.
    METHODS partial_failure_blocks_retry FOR TESTING.
    METHODS sends_original_scope FOR TESTING.
ENDCLASS.

CLASS ltcl_delete IMPLEMENTATION.
  METHOD setup.
    mo_app = NEW #( ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app->mi_service = mo_service.
    mo_client->mv_arg = `42`.
    mo_service->ms_preview = VALUE #( name = `Fixture` package = `$FIXTURE`
      objects = VALUE #( ( obj_type = `DEVC` obj_name = `$FIXTURE` package = `$FIXTURE` ) ) ).
  ENDMETHOD.
  METHOD event.
    mo_client->mv_event = iv_event.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.
  METHOD cancel_never_deletes.
    event( `UNINSTALL` ).
    mo_app->mv_delete_confirmation = `$FIXTURE`.
    event( `DELETE_CANCEL` ).
    event( `DELETE_CONFIRM` ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = mo_service->mv_calls ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_delete_preview ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_confirmation ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_closed ).
  ENDMETHOD.
  METHOD uninstall_requires_preview.
    event( `DELETE_CONFIRM` ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = mo_service->mv_calls ).
  ENDMETHOD.
  METHOD remove_success_clears.
    mo_service->ms_result-outcome = zif_ag2ui5_repo_service=>c_outcome-removed.
    event( `REMOVE` ).
    event( `DELETE_CONFIRM` ).
    cl_abap_unit_assert=>assert_equals( exp = `REMOVE` act = mo_service->ms_received-action ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_closed ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_delete_preview ).
    cl_abap_unit_assert=>assert_equals( exp = `Repository registration removed; SAP objects retained`
      act = mo_client->mv_toast ).
  ENDMETHOD.
  METHOD transport_starts_unselected.
    mo_service->ms_preview-transport_required = abap_true.
    event( `UNINSTALL` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_delete_transport ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_delete_transports[ 1 ]-trkorr ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mo_app->mt_delete_transports ) ).
  ENDMETHOD.
  METHOD server_error_retains_dialog.
    mo_service->mv_raise = abap_true.
    event( `UNINSTALL` ).
    event( `DELETE_CONFIRM` ).
    cl_abap_unit_assert=>assert_equals( exp = `Test rejection` act = mo_app->mv_delete_error ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_closed ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_delete_failed ).
    cl_abap_unit_assert=>assert_equals( exp = `42` act = mo_app->ms_delete_preview-key ).
  ENDMETHOD.
  METHOD partial_failure_blocks_retry.
    mo_service->ms_result = VALUE #( outcome = zif_ag2ui5_repo_service=>c_outcome-failed
      messages = VALUE #( ( type = `E` text = `Object is locked` ) ) ).
    event( `UNINSTALL` ).
    event( `DELETE_CONFIRM` ).
    event( `DELETE_CONFIRM` ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_service->mv_calls ).
    cl_abap_unit_assert=>assert_equals( exp = `Object is locked` act = mo_app->mt_delete_messages[ 1 ]-text ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_delete_failed ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_closed ).
  ENDMETHOD.
  METHOD sends_original_scope.
    mo_service->ms_result-outcome = zif_ag2ui5_repo_service=>c_outcome-uninstalled.
    event( `UNINSTALL` ).
    " Bound display rows cannot replace the server preview retained by the app.
    CLEAR mo_app->mt_delete_objects.
    mo_app->mv_delete_confirmation = `$FIXTURE`.
    mo_app->mv_delete_transport = `A4HK900148`.
    event( `DELETE_CONFIRM` ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_service->ms_received-objects ) ).
    cl_abap_unit_assert=>assert_equals( exp = `$FIXTURE` act = mo_service->mv_confirmation ).
    cl_abap_unit_assert=>assert_equals( exp = `A4HK900148` act = mo_service->mv_transport ).
    cl_abap_unit_assert=>assert_equals( exp = `Repository uninstalled` act = mo_client->mv_toast ).
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_offline DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.
  PRIVATE SECTION.
    METHODS offline_opens_status FOR TESTING.
ENDCLASS.

CLASS ltcl_offline IMPLEMENTATION.
  METHOD offline_opens_status.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    DATA(lo_app) = NEW zcl_ag2ui5_app_repos( ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->mt_all = VALUE #( ( key = `29` name = `offline` offline = abap_true ) ).
    lo_client->mv_arg = `29`.
    lo_client->mv_event = `OPEN`.
    lo_app->z2ui5_if_app~main( lo_client ).
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mo_called IS INSTANCE OF zcl_ag2ui5_app_status ) ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_settings TYPE REF TO ltd_settings.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_cut TYPE REF TO zcl_ag2ui5_app_repos.

    METHODS setup.
    METHODS teardown.
    METHODS start_reads_layout FOR TESTING.
    METHODS start_defaults_to_tiles FOR TESTING.
    METHODS layout_event_saves FOR TESTING.
ENDCLASS.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_settings = NEW #( ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
    mo_client = NEW #( ).
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD start_reads_layout.
    " the start also lists the repositories of the system; that only reads
    mo_settings->mt_preset = VALUE #( ( key = zif_ag2ui5_settings=>c_key-repos_layout value = `TILES` ) ).
    mo_client->mv_start = abap_true.
    mo_cut->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `TILES` act = mo_cut->mv_layout ).
  ENDMETHOD.

  METHOD start_defaults_to_tiles.
    " nothing stored: tiles
    mo_client->mv_start = abap_true.
    mo_cut->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `TILES` act = mo_cut->mv_layout ).
  ENDMETHOD.

  METHOD layout_event_saves.
    mo_cut->mv_layout = `TILES`.
    mo_client->mv_event = `LAYOUT`.
    mo_cut->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals(
      exp = `TILES`
      act = mo_settings->saved( zif_ag2ui5_settings=>c_key-repos_layout ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_new DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS new_opens_page FOR TESTING.
    METHODS back_shows_handed_message FOR TESTING.
ENDCLASS.

CLASS ltcl_new IMPLEMENTATION.

  METHOD new_opens_page.
    DATA(lo_app) = NEW zcl_ag2ui5_app_repos( ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = `NEW`.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mo_called IS INSTANCE OF zcl_ag2ui5_app_new_repo ) ).
  ENDMETHOD.

  METHOD back_shows_handed_message.
    " the new repository page hands its message over when it leaves
    DATA(lo_app) = NEW zcl_ag2ui5_app_repos( ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_start = abap_true.
    lo_client->ms_get-r_event_data = NEW string( `Offline repository x created` ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `Offline repository x created` act = lo_client->mv_toast ).
  ENDMETHOD.

ENDCLASS.
