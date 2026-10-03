CLASS ltcl_app DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_new_repo DEFINITION LOCAL FRIENDS ltcl_app.

"! abap2UI5 client: either the start (navigated) or one event
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_start TYPE abap_bool.
    DATA mv_event TYPE string.
    DATA mv_view TYPE string.
    DATA mv_toast TYPE string.
    DATA mv_left TYPE abap_bool.
    DATA mo_left_to TYPE REF TO z2ui5_if_app.
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
  METHOD z2ui5_if_client~view_display.
    mv_view = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_toast_display.
    mv_toast = text.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_leave.
    mv_left = abap_true.
    mo_left_to = app.
  ENDMETHOD.
  "! bindings and events are not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
ENDCLASS.


"! Service that answers create_repo with a preset result, or raises
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA ms_result TYPE zif_ag2ui5_repo_service=>ty_new_repo_result.
    DATA mv_fail TYPE abap_bool.
    DATA ms_received TYPE zif_ag2ui5_repo_service=>ty_new_repo.
ENDCLASS.

CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~create_repo.
    ms_received = is_repo.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Not authorized` ).
    ENDIF.
    rs_result = ms_result.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_app DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_new_repo.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.

    METHODS setup.
    METHODS fire
      IMPORTING
        iv_event TYPE string.

    METHODS defaults_as_abapgit FOR TESTING.
    METHODS online_created_opens_status FOR TESTING.
    METHODS offline_created_back_to_list FOR TESTING.
    METHODS errors_to_fields FOR TESTING.
    METHODS errors_cleared_on_retry FOR TESTING.
    METHODS exception_to_message FOR TESTING.
    METHODS back_leaves FOR TESTING.
    METHODS back_never_overflows FOR TESTING.
ENDCLASS.


CLASS ltcl_app IMPLEMENTATION.

  METHOD setup.
    mo_client  = NEW #( ).
    mo_service = NEW #( ).
    mo_app = zcl_ag2ui5_app_new_repo=>create( ).
    mo_app->mi_service = mo_service.
    mo_app->ms_repo-url     = `https://github.com/abapGit-tests/DTEL.git`.
    mo_app->ms_repo-package = `$AG2UI5_NEW`.
  ENDMETHOD.

  METHOD fire.
    mo_client->mv_event = iv_event.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.

  METHOD defaults_as_abapgit.
    DATA(lo_app) = zcl_ag2ui5_app_new_repo=>create( ).
    cl_abap_unit_assert=>assert_equals( exp = `ONLINE` act = lo_app->ms_repo-kind ).
    cl_abap_unit_assert=>assert_equals( exp = `PREFIX` act = lo_app->ms_repo-folder_logic ).
    cl_abap_unit_assert=>assert_initial( lo_app->ms_repo-abap_lang_vers ).
    cl_abap_unit_assert=>assert_false( lo_app->ms_repo-ign_subpackages ).
    cl_abap_unit_assert=>assert_false( lo_app->ms_repo-main_lang_only ).
  ENDMETHOD.

  METHOD online_created_opens_status.
    mo_service->ms_result = VALUE #( outcome = zif_ag2ui5_repo_service=>c_outcome-created key = `000000000042` ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = `$AG2UI5_NEW` act = mo_service->ms_received-package ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    " this page is left for the status page, so Back there returns to the list
    cl_abap_unit_assert=>assert_true( xsdbool( mo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_status ) ).
  ENDMETHOD.

  METHOD offline_created_back_to_list.
    mo_app->ms_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
    mo_app->ms_repo-name = `offline repo`.
    mo_service->ms_result = VALUE #( outcome = zif_ag2ui5_repo_service=>c_outcome-created key = `000000000043` ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_not_bound( mo_client->mo_left_to ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_toast exp = `*offline repo*` ).
  ENDMETHOD.

  METHOD errors_to_fields.
    mo_service->ms_result = VALUE #(
      outcome = zif_ag2ui5_repo_service=>c_outcome-invalid
      errors  = VALUE #( ( field = `url`     text = `Bad URL` )
                         ( field = `package` text = `Package in use` )
                         ( field = ``        text = `Not authorized` ) ) ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = `Bad URL` act = mo_app->ms_error_text-url ).
    cl_abap_unit_assert=>assert_equals( exp = `Package in use` act = mo_app->ms_error_text-package ).
    cl_abap_unit_assert=>assert_equals( exp = `Not authorized` act = mo_app->mv_message ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
    " the form keeps what the user typed
    cl_abap_unit_assert=>assert_equals( exp = `$AG2UI5_NEW` act = mo_app->ms_repo-package ).
  ENDMETHOD.

  METHOD errors_cleared_on_retry.
    mo_app->ms_error_text-url = `old`.
    mo_app->ms_error_text-name = `old`.
    mo_app->mv_message = `old`.
    mo_service->ms_result = VALUE #(
      outcome = zif_ag2ui5_repo_service=>c_outcome-invalid
      errors  = VALUE #( ( field = `package` text = `Package in use` ) ) ).
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_error_text-url ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_error_text-name ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_message ).
    cl_abap_unit_assert=>assert_equals( exp = `Package in use` act = mo_app->ms_error_text-package ).
  ENDMETHOD.

  METHOD exception_to_message.
    mo_service->mv_fail = abap_true.
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = `Not authorized` act = mo_app->mv_message ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
  ENDMETHOD.

  METHOD back_leaves.
    fire( `BACK` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_not_bound( mo_client->mo_left_to ).
  ENDMETHOD.

  METHOD back_never_overflows.
    " on a narrow screen the header controls must not push out the back
    " button: they sit in an overflow toolbar, the back button stays
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    FIND REGEX `<customHeader>\s*<OverflowToolbar[^>]*>\s*<Button[^>]*sap-icon://nav-back[^>]*[^/>]>\s*`
            && `<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
    FIND REGEX `<Button text="Create"[^>]*[^/>]>\s*<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
  ENDMETHOD.

ENDCLASS.
