CLASS ltcl_push DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_stage DEFINITION LOCAL FRIENDS ltcl_push.

"! abap2UI5 client for one event round trip
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_event TYPE string.
    DATA mv_message TYPE string.
ENDCLASS.


CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~check_on_init.
    result = abap_false.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_navigated.
    result = abap_false.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_event.
    result = abap_true.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_toast_display.
    mv_message = text.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_box_display.
    mv_message = text.
  ENDMETHOD.
ENDCLASS.


"! Service that records the token it got, and fails on request
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mv_received_token TYPE string.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.


CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~commit_push.
    mv_received_token = iv_token.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `HTTP 401 Unauthorized` ).
    ENDIF.
    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-pushed.
    rs_result-commit  = `abc1234`.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_stage ##NEEDED.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_push DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_stage.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.

    METHODS setup.
    METHODS token_cleared_after_push FOR TESTING.
    METHODS token_cleared_after_error FOR TESTING.
    METHODS token_cleared_without_select FOR TESTING.

ENDCLASS.


CLASS ltcl_push IMPLEMENTATION.

  METHOD setup.
    mo_client  = NEW #( ).
    mo_service = NEW #( ).
    mo_client->mv_event = `PUSH`.

    mo_app = zcl_ag2ui5_app_stage=>create( iv_key = `000000000001` iv_title = `test` ).
    mo_app->mi_service = mo_service.
    mo_app->mt_rows = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` action = `ADD` selected = abap_true ) ).
    mo_app->ms_commit-title = `Test`.
    mo_app->mv_user  = `someone`.
    mo_app->mv_token = `secret-token`.
  ENDMETHOD.

  METHOD token_cleared_after_push.
    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_received_token
                                        exp = `secret-token` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_message
                                         exp = `Pushed abc1234*` ).
  ENDMETHOD.

  METHOD token_cleared_after_error.
    mo_service->mv_fail = abap_true.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message
                                        exp = `HTTP 401 Unauthorized` ).
  ENDMETHOD.

  METHOD token_cleared_without_select.
    " even when the push does not start, the token must not stay
    mo_app->mt_rows[ 1 ]-selected = abap_false.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
    cl_abap_unit_assert=>assert_initial( mo_service->mv_received_token ).
  ENDMETHOD.

ENDCLASS.
