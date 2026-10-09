CLASS ltcl_routes DEFINITION DEFERRED.
CLASS ltcl_offline DEFINITION DEFERRED.
CLASS ltcl_delete DEFINITION DEFERRED.
CLASS ltcl_favorites DEFINITION DEFERRED.
CLASS ltcl_logos DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_repos DEFINITION LOCAL FRIENDS ltcl_routes ltcl_offline ltcl_delete ltcl_favorites ltcl_logos.

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
    DATA mv_reject TYPE abap_bool.
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
    IF mv_reject = abap_true.
      RETURN.
    ENDIF.
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
    DATA mt_routes TYPE string_table.
    DATA mv_route TYPE string.
    DATA mv_nav_mode TYPE string.
    DATA mv_app_state TYPE string.
    DATA mv_listener TYPE string.
    DATA mv_leave_data TYPE string.
    DATA mv_has_caller TYPE abap_bool.
    DATA mo_left_to TYPE REF TO z2ui5_if_app.
    DATA mv_start TYPE abap_bool.
    DATA mv_init TYPE abap_bool.
    DATA mv_event TYPE string.
    DATA mo_called TYPE REF TO z2ui5_if_app.
    DATA ms_get TYPE z2ui5_if_client=>ty_s_get.
    DATA mv_toast TYPE string.
    DATA mv_arg TYPE string.
    DATA mv_arg2 TYPE string.
    DATA mv_popup TYPE string.
    DATA mv_closed TYPE abap_bool.
    DATA mv_popover TYPE string.
    DATA mv_anchor TYPE string.
    DATA mv_error TYPE string.
    "! The last set_session_stateful( ) value; `-` when it was never called
    DATA mv_stateful TYPE string VALUE `-`.
    DATA mv_follow TYPE string.
    DATA mv_view TYPE string.
    DATA mt_follow_args TYPE string_table.
ENDCLASS.

CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~check_on_init.
    result = mv_init.
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave.
    mo_left_to = app.
    IF r_data IS SUPPLIED.
      mv_leave_data = r_data.
    ENDIF.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_app_prev_stack.
    result = mv_has_caller.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_navigated.
    result = xsdbool( mv_start = abap_true OR mv_init = abap_true ).
  ENDMETHOD.

  METHOD z2ui5_if_client~set_session_stateful.
    mv_stateful = val.
  ENDMETHOD.

  METHOD z2ui5_if_client~follow_up_action.
    IF val = z2ui5_if_client~cs_event-hash_replace
      OR val = z2ui5_if_client~cs_event-hash_set
      OR val = z2ui5_if_client~cs_event-hash_attach_changed
      OR val = z2ui5_if_client~cs_event-hash_routing
      OR val = z2ui5_if_client~cs_event-app_state_set_active.
      INSERT val INTO TABLE mt_routes.
      CASE val.
        WHEN z2ui5_if_client~cs_event-hash_routing.
          mv_nav_mode = VALUE #( t_arg[ 1 ] OPTIONAL ).
        WHEN z2ui5_if_client~cs_event-app_state_set_active.
          mv_app_state = VALUE #( t_arg[ 1 ] OPTIONAL ).
        WHEN z2ui5_if_client~cs_event-hash_attach_changed.
          mv_listener = VALUE #( t_arg[ 1 ] OPTIONAL ).
      ENDCASE.
      IF val = z2ui5_if_client~cs_event-hash_replace.
        mv_route = VALUE #( t_arg[ 1 ] OPTIONAL ).
      ENDIF.
      RETURN.
    ENDIF.

    " only the timer is checked; the search field focus comes after it
    IF val = z2ui5_if_client~cs_event-start_timer.
      mv_follow = val.
      mt_follow_args = t_arg.
    ENDIF.
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
  METHOD z2ui5_if_client~message_box_display.
    mv_error = text.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_display.
    mv_popup = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_destroy.
    mv_closed = abap_true.
  ENDMETHOD.
  METHOD z2ui5_if_client~popover_display.
    mv_popover = xml.
    mv_anchor = by_id.
  ENDMETHOD.
  METHOD z2ui5_if_client~popover_destroy.
    CLEAR: mv_popover, mv_anchor.
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
    result = COND #( WHEN v = 2 THEN mv_arg2 ELSE mv_arg ).
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
  METHOD zif_ag2ui5_repo_service~logoff ##NEEDED.
  ENDMETHOD.
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


CLASS ltd_favorites_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mt_repos TYPE zif_ag2ui5_repo_service=>ty_repos.
    DATA mv_key TYPE string.
    DATA mv_state TYPE string.
    DATA mv_calls TYPE i.
    DATA mv_reads TYPE i.
    DATA mv_fail TYPE abap_bool.
    DATA mv_fail_read TYPE abap_bool.
    DATA mv_logoffs TYPE i.
    DATA ms_status TYPE zif_ag2ui5_repo_service=>ty_status.
    DATA mv_status_reads TYPE i.
    DATA mv_status_fail TYPE abap_bool.
ENDCLASS.
CLASS ltd_favorites_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~get_status.
    mv_status_reads = mv_status_reads + 1.
    IF mv_status_fail = abap_true.
      zcx_abapgit_exception=>raise( `Cannot read Status` ).
    ENDIF.
    rs_status = ms_status.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~logoff.
    mv_logoffs = mv_logoffs + 1.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~list_repos.
    mv_reads = mv_reads + 1.
    IF mv_fail_read = abap_true.
      zcx_abapgit_exception=>raise( `Test list refresh failure` ).
    ENDIF.
    rt_repos = mt_repos.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~set_favorite.
    mv_key = iv_key.
    mv_state = iv_favorite.
    mv_calls = mv_calls + 1.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Test persistence failure` ).
    ENDIF.
    LOOP AT mt_repos ASSIGNING FIELD-SYMBOL(<ls_repo>) WHERE key = iv_key.
      <ls_repo>-favorite = xsdbool( iv_favorite = `X` ).
      rv_favorite = <ls_repo>-favorite.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_favorites DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_repos.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_favorites_service.
    DATA mo_settings TYPE REF TO ltd_settings.
    METHODS setup.
    METHODS teardown.
    METHODS event IMPORTING iv_event TYPE string.
    METHODS favorites_first FOR TESTING.
    METHODS search_and_filter FOR TESTING.
    METHODS case_insensitive_search FOR TESTING.
    METHODS labels_and_overflow FOR TESTING.
    METHODS labels_popover FOR TESTING.
    METHODS label_click_filter FOR TESTING.
    METHODS header_label_return FOR TESTING.
    METHODS start_reads_filter FOR TESTING.
    METHODS filter_defaults_to_all FOR TESTING.
    METHODS filter_event_saves FOR TESTING.
    METHODS filter_failure_restores FOR TESTING.
    METHODS star_sets_without_navigation FOR TESTING.
    METHODS star_failure_restores FOR TESTING.
    METHODS confirmed_star_survives_error FOR TESTING.
    METHODS last_favorite_removed FOR TESTING.
    METHODS empty_matching_favorites FOR TESTING.
    METHODS show_all_keeps_search FOR TESTING.
    METHODS refresh_reloads_flags FOR TESTING.
    METHODS list_goes_stateless FOR TESTING.
    METHODS list_without_login_stays FOR TESTING.
ENDCLASS.

CLASS ltcl_favorites IMPLEMENTATION.
  METHOD list_goes_stateless.
    " after a login: abap2UI5 switches back only when this app made the
    " session stateful itself - so on now, off in the next round trip
    zcl_ag2ui5_app_login=>set_stateful( abap_true ).
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_logoffs exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_stateful exp = `X` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_follow exp = mo_client->z2ui5_if_client~cs_event-start_timer ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mt_follow_args[ 1 ] exp = `SESSION_END` ).
    mo_client->mv_start = abap_false.
    mo_client->mv_event = `SESSION_END`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_stateful exp = `` ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_app_login=>is_stateful( ) ).
  ENDMETHOD.

  METHOD list_without_login_stays.
    " no login, no stateful session: nothing to switch
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_logoffs exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_stateful exp = `-` ).
  ENDMETHOD.

  METHOD setup.
    mo_app = NEW #( ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_settings = NEW #( ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
    mo_app->mi_service = mo_service.
    mo_app->client = mo_client.
    mo_service->mt_repos = VALUE #(
      ( key = `1` name = `Ordinary` package = `$A` url = `https://example.com/one` )
      ( key = `3` name = `Later`    package = `$Z` favorite = abap_true offline = abap_true )
      ( key = `2` name = `First`    package = `$B` favorite = abap_true ) ).
    mo_app->load_repos( ).
  ENDMETHOD.
  METHOD teardown.
    zcl_ag2ui5_app_login=>set_stateful( abap_false ).
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.
  METHOD event.
    mo_client->mv_event = iv_event.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.
  METHOD favorites_first.
    cl_abap_unit_assert=>assert_equals( exp = `2` act = mo_app->mt_repos[ 1 ]-key ).
    cl_abap_unit_assert=>assert_equals( exp = `3` act = mo_app->mt_repos[ 2 ]-key ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = mo_app->mt_repos[ 3 ]-key ).
    cl_abap_unit_assert=>assert_equals( exp = `sap-icon://favorite` act = mo_app->mt_repos[ 1 ]-favorite_icon ).
    cl_abap_unit_assert=>assert_equals( exp = `sap-icon://unfavorite` act = mo_app->mt_repos[ 3 ]-favorite_icon ).
    " Tie-breakers make order deterministic, independent of service input.
    DATA(lt_rows) = zcl_ag2ui5_app_repos=>filtered_repos(
      it_rows = VALUE #( ( key = `2` name = `Beta` package = `$SAME` favorite = abap_true )
                        ( key = `3` name = `Alpha` package = `$SAME` favorite = abap_true )
                        ( key = `1` name = `Alpha` package = `$SAME` favorite = abap_true ) )
      iv_search = `` iv_favorites_only = abap_false ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = lt_rows[ 1 ]-key ).
    cl_abap_unit_assert=>assert_equals( exp = `3` act = lt_rows[ 2 ]-key ).
    cl_abap_unit_assert=>assert_equals( exp = `2` act = lt_rows[ 3 ]-key ).
  ENDMETHOD.
  METHOD search_and_filter.
    mo_app->mv_favorites_only = abap_true.
    mo_app->mv_search = `Later`.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_app->mt_repos ) ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_repos[ 1 ]-offline ).
    mo_app->mv_search = `Ordinary`.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_repos ).
  ENDMETHOD.
  METHOD labels_and_overflow.
    mo_service->mt_repos[ 1 ]-labels = VALUE #( ( text = `core` color = `blue` ) ( text = `tools` color = `teal` )
      ( text = `ui5` color = `rose` ) ( text = `hidden-label` color = `purple` ) ).
    mo_app->load_repos( ).
    mo_app->mv_search = `HIDDEN-LABEL`.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_repos ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_repos[ 1 ]-label_more exp = `+1` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_repos[ 1 ]-label_preview ) exp = 3 ).
    mo_app->mv_favorites_only = abap_true.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_repos ).
  ENDMETHOD.
  METHOD header_label_return.
    mo_service->mt_repos[ 1 ]-labels = VALUE #( ( text = `ui5` color = `purple` ) ).
    mo_client->ms_get-r_event_data = NEW string( `LABEL_FILTER:ui5` ).
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_search exp = `ui5` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_repos ) exp = 1 ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_toast ).
  ENDMETHOD.

  METHOD label_click_filter.
    mo_service->mt_repos[ 1 ]-labels = VALUE #( ( text = `core` color = `blue` ) ).
    mo_service->mt_repos[ 2 ]-labels = VALUE #( ( text = `core-tools` color = `teal` ) ).
    mo_service->mt_repos[ 3 ]-name = `core`.
    mo_app->load_repos( ).
    mo_client->mv_arg = `core`.
    event( `LABEL_FILTER` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_search exp = `core` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_repos ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_repos[ 1 ]-key exp = `1` ).
    mo_client->mv_arg = `unknown`.
    event( `LABEL_FILTER` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_label_filter exp = `core` ).
    mo_app->mv_favorites_only = abap_true.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_repos ).
    mo_app->mv_favorites_only = abap_false.
    mo_app->mv_search = ``.
    event( `SEARCH` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_label_filter ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_repos ) exp = 3 ).
  ENDMETHOD.
  METHOD labels_popover.
    mo_service->mt_repos[ 1 ]-labels = VALUE #( ( text = `server-label` color = `blue` ) ).
    mo_app->load_repos( ).
    mo_client->mv_arg = `1`.
    mo_client->mv_arg2 = `label-button`.
    event( `LABELS` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_anchor exp = `label-button` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_labels[ 1 ]-text exp = `server-label` ).
    event( `LABELS_CLOSE` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_labels ).
    mo_client->mv_arg = `unknown`.
    event( `LABELS` ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popover ).
  ENDMETHOD.
  METHOD case_insensitive_search.
    mo_app->mv_search = `first`.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_equals( exp = `2` act = mo_app->mt_repos[ 1 ]-key ).
    mo_app->mv_search = `$z`.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_equals( exp = `3` act = mo_app->mt_repos[ 1 ]-key ).
    mo_app->mv_search = `EXAMPLE.COM`.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = mo_app->mt_repos[ 1 ]-key ).
  ENDMETHOD.
  METHOD start_reads_filter.
    mo_settings->mt_preset = VALUE #( ( key = zif_ag2ui5_settings=>c_key-repos_favorites_only value = `X` ) ).
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_favorites_only ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mo_app->mt_repos ) ).
  ENDMETHOD.
  METHOD filter_defaults_to_all.
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_favorites_only ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( mo_app->mt_repos ) ).
  ENDMETHOD.
  METHOD filter_event_saves.
    mo_client->mv_arg = `X`.
    event( `FAVORITES_FILTER` ).
    cl_abap_unit_assert=>assert_equals( exp = `X` act = mo_settings->saved(
      zif_ag2ui5_settings=>c_key-repos_favorites_only ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( mo_app->mt_repos ) ).
    mo_client->mv_arg = ` `.
    event( `FAVORITES_FILTER` ).
    cl_abap_unit_assert=>assert_equals( exp = `` act = mo_settings->saved(
      zif_ag2ui5_settings=>c_key-repos_favorites_only ) ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( mo_app->mt_repos ) ).
  ENDMETHOD.
  METHOD filter_failure_restores.
    mo_settings->mv_reject = abap_true.
    mo_client->mv_arg = `Xextra`.
    mo_app->mv_favorites_only = abap_true.
    event( `FAVORITES_FILTER` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_favorites_only ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( mo_app->mt_repos ) ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
  ENDMETHOD.
  METHOD star_sets_without_navigation.
    mo_client->mv_arg = `1`.
    mo_client->mv_arg2 = `X`.
    event( `FAVORITE` ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = mo_service->mv_key ).
    cl_abap_unit_assert=>assert_equals( exp = `X` act = mo_service->mv_state ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = mo_app->mt_repos[ 1 ]-key ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_repos[ 1 ]-favorite ).
    cl_abap_unit_assert=>assert_not_bound( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( exp = `TILES` act = mo_app->mv_layout ).
    cl_abap_unit_assert=>assert_equals( exp = `Repository added to favorites` act = mo_client->mv_toast ).
  ENDMETHOD.
  METHOD star_failure_restores.
    mo_service->mv_fail = abap_true.
    mo_client->mv_arg = `1`.
    mo_client->mv_arg2 = `X`.
    " Simulate the browser sending an optimistic changed row.
    mo_app->mt_repos[ 3 ]-favorite = abap_true.
    event( `FAVORITE` ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_repos[ 3 ]-favorite ).
    cl_abap_unit_assert=>assert_equals( exp = `sap-icon://unfavorite` act = mo_app->mt_repos[ 3 ]-favorite_icon ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
    cl_abap_unit_assert=>assert_not_bound( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_toast ).
  ENDMETHOD.
  METHOD confirmed_star_survives_error.
    mo_service->mv_fail_read = abap_true.
    mo_client->mv_arg = `1`.
    mo_client->mv_arg2 = `X`.
    event( `FAVORITE` ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = mo_app->mt_repos[ 1 ]-key ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_repos[ 1 ]-favorite ).
    cl_abap_unit_assert=>assert_equals( exp = `sap-icon://favorite` act = mo_app->mt_repos[ 1 ]-favorite_icon ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
    cl_abap_unit_assert=>assert_equals( exp = `Repository added to favorites` act = mo_client->mv_toast ).
  ENDMETHOD.
  METHOD last_favorite_removed.
    mo_service->mt_repos = VALUE #( ( key = `1` name = `Only` favorite = abap_true ) ).
    mo_app->mv_favorites_only = abap_true.
    mo_app->load_repos( ).
    mo_client->mv_arg = `1`.
    mo_client->mv_arg2 = ``.
    event( `FAVORITE` ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_empty ).
    cl_abap_unit_assert=>assert_equals( exp = `No favorites yet` act = mo_app->mv_empty_text ).
    cl_abap_unit_assert=>assert_equals( exp = `Repository removed from favorites` act = mo_client->mv_toast ).
  ENDMETHOD.
  METHOD empty_matching_favorites.
    mo_app->mv_favorites_only = abap_true.
    mo_app->mv_search = `No match`.
    mo_app->apply_search( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_empty ).
    cl_abap_unit_assert=>assert_equals( exp = `No favorites match your search` act = mo_app->mv_empty_text ).
  ENDMETHOD.
  METHOD show_all_keeps_search.
    mo_app->mv_favorites_only = abap_true.
    mo_app->mv_search = `Ordinary`.
    mo_app->mv_layout = `LIST`.
    event( `SHOW_ALL` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_favorites_only ).
    cl_abap_unit_assert=>assert_equals( exp = `Ordinary` act = mo_app->mv_search ).
    cl_abap_unit_assert=>assert_equals( exp = `LIST` act = mo_app->mv_layout ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_app->mt_repos ) ).
  ENDMETHOD.
  METHOD refresh_reloads_flags.
    mo_service->mt_repos[ 1 ]-favorite = abap_true.
    event( `REFRESH` ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_repos[ 1 ]-favorite ).
    cl_abap_unit_assert=>assert_equals( exp = `1` act = mo_app->mt_repos[ 1 ]-key ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_routes DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_repos.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_favorites_service.
    METHODS setup.
    METHODS teardown.
    METHODS cold_status FOR TESTING.
    METHODS route_edit_resolves_fresh FOR TESTING.
    METHODS listener_and_no_push FOR TESTING.
    METHODS cold_diff FOR TESTING.
    METHODS missing_diff FOR TESTING.
    METHODS offline_diff FOR TESTING.
    METHODS failed_diff FOR TESTING.
    METHODS malformed FOR TESTING.
    METHODS unknown_and_removed FOR TESTING.
    METHODS list_aliases FOR TESTING.
    METHODS handover_ignores_old_hash FOR TESTING.
    METHODS list_failure FOR TESTING.
ENDCLASS.
CLASS ltcl_routes IMPLEMENTATION.
  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_app = NEW #( ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_service->mt_repos = VALUE #( ( key = `000000000010` name = `Fresh` ) ).
    mo_app->mi_service = mo_service.
    mo_client->mv_start = abap_true.
    mo_client->mv_init = abap_true.
  ENDMETHOD.
  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.
  METHOD route_edit_resolves_fresh.
    mo_client->mv_start = abap_false.
    mo_client->mv_init = abap_false.
    mo_client->mv_event = `ROUTE_CHANGED`.
    mo_client->ms_get-s_config-hash = `#/repo/000000000010`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
    DATA(lo_root) = CAST zcl_ag2ui5_app_repos( mo_client->mo_left_to ).
    lo_root->mi_service = mo_service.
    CLEAR mo_client->mo_left_to.
    mo_client->mv_init = abap_true.
    mo_client->mv_start = abap_true.
    CLEAR mo_client->mv_event.
    lo_root->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_status ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_reads exp = 1 ).
  ENDMETHOD.
  METHOD listener_and_no_push.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_nav_mode exp = `DEFAULT` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_app_state exp = ` ` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_listener exp = `ROUTE_CHANGED` ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( mo_client->mt_routes[ table_line = mo_client->z2ui5_if_client~cs_event-hash_attach_changed ] ) ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( mo_client->mt_routes[ table_line = mo_client->z2ui5_if_client~cs_event-hash_set ] ) ) ).
  ENDMETHOD.
  METHOD cold_status.
    mo_client->ms_get-s_config-hash = `#/repo/000000000010`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_status ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_reads exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_logoffs exp = 0 ).
  ENDMETHOD.
  METHOD cold_diff.
    mo_service->ms_status = VALUE #( name = `Fresh` rows = VALUE #(
      ( path = `/fresh/` filename = `new.abap` changed = abap_true lstate = `M` )
      ( path = `/fresh/` filename = `same.xml` changed = abap_false ) ) ).
    mo_client->ms_get-s_config-hash = `#/repo/000000000010/diff`.
    mo_app->z2ui5_if_app~main( mo_client ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_repo_diff( mo_client->mo_left_to ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_diff->mt_files ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 1 ]-file exp = `/fresh/new.abap` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_reads exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_status_reads exp = 1 ).
  ENDMETHOD.
  METHOD missing_diff.
    mo_client->ms_get-s_config-hash = `#/repo/000000000010/diff`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_status ) ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_leave_data ).
  ENDMETHOD.
  METHOD offline_diff.
    mo_service->ms_status = VALUE #( offline = abap_true rows = VALUE #( ( changed = abap_true ) ) ).
    mo_client->ms_get-s_config-hash = `#/repo/000000000010/diff`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_status ) ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_leave_data ).
  ENDMETHOD.
  METHOD failed_diff.
    mo_service->mv_status_fail = abap_true.
    mo_client->ms_get-s_config-hash = `#/repo/000000000010/diff`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_status ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_status_reads exp = 1 ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_leave_data ).
  ENDMETHOD.
  METHOD malformed.
    LOOP AT VALUE string_table( ( `#/repo/1` ) ( `#/repo/0000000000100` )
      ( `#/repo/00000000001x` ) ( `#/repo/000000000010/stage` )
      ( `#/repo/000000000010/diff?index=1` ) ( `#/app/anything` )
      ( |#/repo/000000000010{ cl_abap_char_utilities=>newline }| ) ) INTO DATA(lv_hash).
      mo_client->ms_get-s_config-hash = lv_hash.
      CLEAR mo_client->mv_error.
      mo_app->z2ui5_if_app~main( mo_client ).
      cl_abap_unit_assert=>assert_initial( mo_client->mo_left_to ).
      cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
      cl_abap_unit_assert=>assert_equals( act = mo_client->mv_route exp = `/` ).
    ENDLOOP.
  ENDMETHOD.
  METHOD unknown_and_removed.
    mo_client->ms_get-s_config-hash = `#/repo/000000000099`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_left_to ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_error exp = `Unknown*` ).
    CLEAR mo_service->mt_repos.
    mo_client->ms_get-s_config-hash = `#/repo/000000000010`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_left_to ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_error exp = `Unknown*` ).
  ENDMETHOD.
  METHOD list_aliases.
    LOOP AT VALUE string_table( ( `` ) ( `#` ) ( `#/` ) ) INTO DATA(lv_hash).
      mo_client->ms_get-s_config-hash = lv_hash.
      mo_app->z2ui5_if_app~main( mo_client ).
      cl_abap_unit_assert=>assert_initial( mo_client->mo_left_to ).
      cl_abap_unit_assert=>assert_initial( mo_client->mv_error ).
      cl_abap_unit_assert=>assert_equals( act = mo_client->mv_route exp = `/` ).
    ENDLOOP.
  ENDMETHOD.
  METHOD handover_ignores_old_hash.
    mo_client->ms_get-s_config-hash = `#/repo/000000000010`.
    DATA(lv_message) = `Back from Status`.
    mo_client->ms_get-r_event_data = REF #( lv_message ).
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_left_to ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_logoffs exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_route exp = `/` ).
  ENDMETHOD.
  METHOD list_failure.
    mo_service->mv_fail_read = abap_true.
    mo_client->ms_get-s_config-hash = `#/repo/000000000010`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_left_to ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_error ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_route exp = `/` ).
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_logos DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS logos_are_images FOR TESTING.
    METHODS header_shows_logos FOR TESTING.
ENDCLASS.

CLASS ltcl_logos IMPLEMENTATION.

  METHOD logos_are_images.
    " a truncated or mistyped line in the embedded data breaks the image
    DATA(lv_svg) = zcl_ag2ui5_app_repos=>abapgit_logo( ).
    cl_abap_unit_assert=>assert_char_cp( exp = `data:image/svg+xml;base64,*` act = lv_svg ).
    DATA(lv_xml) = cl_abap_codepage=>convert_from(
      cl_http_utility=>decode_x_base64( substring_after( val = lv_svg sub = `,` ) ) ).
    cl_abap_unit_assert=>assert_char_cp( exp = `<svg *</svg>` act = lv_xml ).

    DATA(lv_png) = zcl_ag2ui5_app_repos=>abap2ui5_logo( ).
    cl_abap_unit_assert=>assert_char_cp( exp = `data:image/png;base64,*` act = lv_png ).
    DATA(lv_bytes) = cl_http_utility=>decode_x_base64( substring_after( val = lv_png sub = `,` ) ).
    DATA lv_head TYPE x LENGTH 8.
    DATA lv_tail TYPE x LENGTH 8.
    lv_head = lv_bytes.
    " the PNG ends with its IEND chunk
    DATA(lv_end) = xstrlen( lv_bytes ) - 8.
    lv_tail = lv_bytes+lv_end(8).
    cl_abap_unit_assert=>assert_equals( exp = '89504E470D0A1A0A' act = lv_head ).
    cl_abap_unit_assert=>assert_equals( exp = '49454E44AE426082' act = lv_tail ).
  ENDMETHOD.

  METHOD header_shows_logos.
    DATA(lo_client) = NEW ltd_client( ).
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    lo_client->mv_start = abap_true.
    NEW zcl_ag2ui5_app_repos( )->z2ui5_if_app~main( lo_client ).
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).

    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mv_view CS zcl_ag2ui5_app_repos=>abapgit_logo( ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mv_view CS zcl_ag2ui5_app_repos=>abap2ui5_logo( ) ) ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*text="Repositories"*` act = lo_client->mv_view ).
    " UI5 drops alt of a decorative image
    cl_abap_unit_assert=>assert_char_cp( exp = `*alt="abap2UI5"*decorative="false"*` act = lo_client->mv_view ).
  ENDMETHOD.

ENDCLASS.
