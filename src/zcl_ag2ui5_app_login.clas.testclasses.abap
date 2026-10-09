CLASS ltcl_login DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_login DEFINITION LOCAL FRIENDS ltcl_login.


CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mt_routes TYPE string_table.
    DATA mv_route TYPE string.
    DATA mo_left_to TYPE REF TO z2ui5_if_app.
    DATA mv_init TYPE abap_bool.
    DATA mv_navigated TYPE abap_bool.
    DATA mv_event TYPE string.
    DATA mv_view TYPE string.
    DATA mv_message TYPE string.
    DATA mv_left TYPE abap_bool.
    DATA mv_left_data TYPE string.
    "! The last set_session_stateful( ) value; `-` when it was never called
    DATA mv_stateful TYPE string VALUE `-`.
    DATA ms_get TYPE z2ui5_if_client=>ty_s_get.
ENDCLASS.


CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~follow_up_action.
    IF val = z2ui5_if_client~cs_event-hash_replace
      OR val = z2ui5_if_client~cs_event-hash_set
      OR val = z2ui5_if_client~cs_event-hash_attach_changed
      OR val = z2ui5_if_client~cs_event-hash_routing
      OR val = z2ui5_if_client~cs_event-app_state_set_active.
      INSERT val INTO TABLE mt_routes.
      IF val = z2ui5_if_client~cs_event-hash_replace.
        mv_route = VALUE #( t_arg[ 1 ] OPTIONAL ).
      ENDIF.
    ENDIF.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_init.
    result = mv_init.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_navigated.
    result = mv_navigated.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_event.
    " as abap2UI5: a round trip without an event name is no event
    result = xsdbool( mv_init = abap_false AND mv_navigated = abap_false AND mv_event IS NOT INITIAL ).
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.

  METHOD z2ui5_if_client~view_display.
    mv_view = val.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_box_display.
    mv_message = text.
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave.
    mo_left_to = app.
    mv_left = abap_true.
    IF r_data IS SUPPLIED.
      mv_left_data = r_data.
    ENDIF.
  ENDMETHOD.

  METHOD z2ui5_if_client~set_session_stateful.
    mv_stateful = val.
  ENDMETHOD.

  METHOD z2ui5_if_client~get.
    result = ms_get.
  ENDMETHOD.

  "! bindings and events are not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.

  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
ENDCLASS.


"! Records the login; fails on request; knows one repository
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mv_calls TYPE i.
    DATA mv_key TYPE string.
    DATA mv_url TYPE string.
    DATA mv_user TYPE string.
    DATA mv_token TYPE string.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.


CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~login.
    mv_calls = mv_calls + 1.
    mv_key = iv_key.
    mv_url = iv_url.
    mv_user = iv_user.
    mv_token = iv_token.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Enter the Git user and the token or password` ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_repos.
    rt_repos = VALUE #( ( key = `000000000042` url = `https://github.com/a/b.git` ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_login DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_login.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.

    METHODS setup.
    METHODS fire
      IMPORTING
        iv_event TYPE string.
    METHODS title_names_host FOR TESTING.
    METHODS title_from_url FOR TESTING.
    METHODS token_cleared_every_event FOR TESTING.
    METHODS route_clears_credentials FOR TESTING.
    METHODS login_calls_service FOR TESTING.
    METHODS cancel_leaves_plain FOR TESTING.
    METHODS empty_input_stays FOR TESTING.
    METHODS service_error_stays FOR TESTING.
    METHODS view_has_password_field FOR TESTING.
    METHODS login_needs_own_node FOR TESTING.
    METHODS login_notes_stateful FOR TESTING.
    METHODS token_cleared_without_event FOR TESTING.
    METHODS other_node_hint_on_open FOR TESTING.
    METHODS user_cleared_on_leave FOR TESTING.
    METHODS teardown.
ENDCLASS.


CLASS ltcl_login IMPLEMENTATION.

  METHOD teardown.
    zcl_ag2ui5_app_login=>set_stateful( abap_false ).
    zcl_ag2ui5_http=>mark_own_node( abap_false ).
  ENDMETHOD.

  METHOD setup.
    " the request came through /sap/bc/zabapgit2ui5, as the handler marks it
    zcl_ag2ui5_http=>mark_own_node( abap_true ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app = zcl_ag2ui5_app_login=>create( iv_key = `000000000042` ).
    mo_app->mi_service = mo_service.
    mo_client->mv_init = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    mo_client->mv_init = abap_false.
  ENDMETHOD.

  METHOD fire.
    mo_client->mv_event = iv_event.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.

  METHOD title_names_host.
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_title exp = `Log in to github.com` ).
  ENDMETHOD.

  METHOD title_from_url.
    DATA(lo_app) = zcl_ag2ui5_app_login=>create( iv_url = `https://git.example.com/x.git` ).
    lo_app->mi_service = mo_service.
    mo_client->mv_init = abap_true.
    lo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = lo_app->mv_title exp = `Log in to git.example.com` ).
  ENDMETHOD.

  METHOD route_clears_credentials.
    mo_app->mv_user = `someone`.
    mo_app->mv_token = `secret-token`.
    fire( `ROUTE_CHANGED` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_user ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_calls exp = 0 ).
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
  ENDMETHOD.
  METHOD token_cleared_every_event.
    " abap2UI5 saves the draft after every event, whatever button was pressed
    LOOP AT VALUE string_table( ( `LOGIN` ) ( `CANCEL` ) ( `OTHER` ) ( `` ) ) INTO DATA(lv_event).
      mo_app->mv_user = `someone`.
      mo_app->mv_token = `secret-token`.
      fire( lv_event ).
      cl_abap_unit_assert=>assert_initial( act = mo_app->mv_token msg = |Token kept after "{ lv_event }"| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD login_calls_service.
    mo_app->mv_user = `someone`.
    mo_app->mv_token = `secret-token`.
    fire( `LOGIN` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_key exp = `000000000042` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_user exp = `someone` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_token exp = `secret-token` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_stateful exp = `X` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_left_data exp = `LOGGED_IN:github.com` ).
  ENDMETHOD.

  METHOD cancel_leaves_plain.
    fire( `CANCEL` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_left_data ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_calls exp = 0 ).
  ENDMETHOD.

  METHOD empty_input_stays.
    mo_app->mv_user = `someone`.
    fire( `LOGIN` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_calls exp = 0 ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_message ).
  ENDMETHOD.

  METHOD service_error_stays.
    mo_service->mv_fail = abap_true.
    mo_app->mv_user = `someone`.
    mo_app->mv_token = `secret-token`.
    fire( `LOGIN` ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_stateful exp = `-` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `Enter the Git user and the token or password` ).
  ENDMETHOD.

  METHOD login_needs_own_node.
    " /sap/bc/z2ui5 never ends an idle session on A4H25: no credentials there.
    " The browser's own idea of the path does not count
    zcl_ag2ui5_http=>mark_own_node( abap_false ).
    mo_client->ms_get-s_config-pathname = `/sap/bc/zabapgit2ui5`.
    mo_app->mv_user = `someone`.
    mo_app->mv_token = `secret-token`.
    fire( `LOGIN` ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_stateful exp = `-` ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_message exp = `*/sap/bc/zabapgit2ui5*` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
  ENDMETHOD.

  METHOD token_cleared_without_event.
    " a round trip without event, and the way back from another page, must
    " not leave a posted token in the state abap2UI5 saves
    mo_app->mv_token = `secret-token`.
    fire( `` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
    mo_app->mv_token = `secret-token`.
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
  ENDMETHOD.

  METHOD other_node_hint_on_open.
    " opened on /sap/bc/z2ui5: say so at once, and offer no Log in
    zcl_ag2ui5_http=>mark_own_node( abap_false ).
    DATA(lo_app) = zcl_ag2ui5_app_login=>create( iv_key = `000000000042` ).
    lo_app->mi_service = mo_service.
    mo_client->mv_init = abap_true.
    lo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_false( lo_app->mv_can_login ).
    cl_abap_unit_assert=>assert_char_cp( act = lo_app->mv_node_hint exp = `*/sap/bc/zabapgit2ui5*` ).
  ENDMETHOD.

  METHOD user_cleared_on_leave.
    " some hosts take a token as the user name: it does not stay in the draft
    mo_app->mv_user = `someone`.
    mo_app->mv_token = `secret-token`.
    fire( `LOGIN` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_user ).
    mo_app->mv_user = `someone`.
    fire( `CANCEL` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_user ).
  ENDMETHOD.

  METHOD login_notes_stateful.
    " the repository list ends the stateful session again
    mo_app->mv_user = `someone`.
    mo_app->mv_token = `secret-token`.
    fire( `LOGIN` ).
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_app_login=>is_stateful( ) ).
  ENDMETHOD.

  METHOD view_has_password_field.
    FIND REGEX `<Input[^>]*type="Password"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_route_parent DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS parent_on_roundtrip FOR TESTING.
    METHODS route_edit_fresh_root FOR TESTING.
ENDCLASS.
CLASS ltcl_route_parent IMPLEMENTATION.
  METHOD route_edit_fresh_root.
    DATA(lo_client) = NEW ltd_client( ).
    DATA(lo_app) = zcl_ag2ui5_app_login=>create( iv_key = `000000000010` ).
    lo_client->mv_event = `ROUTE_CHANGED`.
    lo_client->ms_get-s_config-hash = `#/repo/000000000099`.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
    cl_abap_unit_assert=>assert_initial( lo_client->mt_routes ).
  ENDMETHOD.

  METHOD parent_on_roundtrip.
    DATA(lo_client) = NEW ltd_client( ).
    DATA(lo_app) = zcl_ag2ui5_app_login=>create( iv_key = `000000000010` ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals( act = lo_client->mv_route exp = `/repo/000000000010` ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_client->mt_routes ) exp = 4 ).
  ENDMETHOD.
ENDCLASS.
