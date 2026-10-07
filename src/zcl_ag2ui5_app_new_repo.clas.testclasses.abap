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
    "! what the page handed over when it left
    DATA mv_left_data TYPE string.
    DATA mv_popup TYPE string.
    DATA mv_popup_closed TYPE abap_bool.
    DATA mo_called TYPE REF TO z2ui5_if_app.
    DATA ms_get TYPE z2ui5_if_client=>ty_s_get.
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
  METHOD z2ui5_if_client~popup_display.
    mv_popup = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_destroy.
    mv_popup_closed = abap_true.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_call.
    mo_called = app.
  ENDMETHOD.
  METHOD z2ui5_if_client~get.
    result = ms_get.
  ENDMETHOD.
  METHOD z2ui5_if_client~nav_app_leave.
    mv_left = abap_true.
    mo_left_to = app.
    IF r_data IS SUPPLIED.
      mv_left_data = r_data.
    ENDIF.
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
    "! create_repo raises this text instead of "Not authorized" when set
    DATA mv_fail_text TYPE string.
    DATA ms_received TYPE zif_ag2ui5_repo_service=>ty_new_repo.
    DATA ms_package_result TYPE zif_ag2ui5_repo_service=>ty_package_result.
    DATA ms_package_received TYPE zif_ag2ui5_repo_service=>ty_new_package.
ENDCLASS.

CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~package_defaults.
    rs_package = VALUE #( package = to_upper( iv_package ) description = `New package`
      software_component = `LOCAL` super_package = `$TMP` abap_lang_vers = iv_abap_lang_vers ).
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~list_transports.
    rt_transports = VALUE #( ( trkorr = `A4HK900148` text = `Test request` ) ).
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~create_package.
    ms_package_received = is_package.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Package permission denied` ).
    ENDIF.
    rs_result = ms_package_result.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~create_repo.
    ms_received = is_repo.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( COND #( WHEN mv_fail_text IS NOT INITIAL THEN mv_fail_text ELSE `Not authorized` ) ).
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
    METHODS package_cancel_keeps_form FOR TESTING.
    METHODS package_created_keeps_form FOR TESTING.
    METHODS package_errors_and_retry FOR TESTING.
    METHODS package_exception_keeps_inputs FOR TESTING.
    METHODS login_error_opens_login FOR TESTING.
    METHODS logged_in_keeps_form FOR TESTING.
    METHODS other_error_message FOR TESTING.
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
    " a toast sent while leaving is lost: the list shows what is handed over
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_left_data exp = `*offline repo*` ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_toast ).
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

  METHOD package_cancel_keeps_form.
    DATA(ls_before) = mo_app->ms_repo.
    fire( `PACKAGE_OPEN` ).
    cl_abap_unit_assert=>assert_equals( exp = ls_before-package act = mo_app->ms_package-package ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*Create package*` act = mo_client->mv_popup ).
    mo_app->ms_package-package = `$OTHER`.
    fire( `PACKAGE_CANCEL` ).
    cl_abap_unit_assert=>assert_equals( exp = ls_before act = mo_app->ms_repo ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_package ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_popup_closed ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
  ENDMETHOD.

  METHOD package_created_keeps_form.
    mo_app->ms_repo-labels = `keep labels`.
    mo_app->ms_repo-branch = `feature/test`.
    DATA(ls_expected) = mo_app->ms_repo.
    ls_expected-package = `$NEW_PACKAGE`.
    fire( `PACKAGE_OPEN` ).
    mo_app->ms_package-package = `$new_package`.
    mo_app->ms_error_text-package = `old error`.
    mo_service->ms_package_result = VALUE #( outcome = `CREATED` package = `$NEW_PACKAGE` ).
    fire( `PACKAGE_CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = ls_expected act = mo_app->ms_repo ).
    cl_abap_unit_assert=>assert_equals( exp = `$new_package` act = mo_service->ms_package_received-package ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_error_text-package ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_popup_closed ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_left ).
  ENDMETHOD.

  METHOD package_errors_and_retry.
    fire( `PACKAGE_OPEN` ).
    mo_service->ms_package_result = VALUE #( outcome = `INVALID`
      errors = VALUE #( ( field = `description` text = `Enter a description` ) ( text = `Denied` ) ) ).
    DATA(ls_before) = mo_app->ms_package.
    fire( `PACKAGE_CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = ls_before act = mo_app->ms_package ).
    cl_abap_unit_assert=>assert_equals( exp = `Enter a description` act = mo_app->ms_package_error-description ).
    cl_abap_unit_assert=>assert_equals( exp = `Denied` act = mo_app->mv_package_message ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_popup_closed ).
    mo_service->ms_package_result-errors = VALUE #( ( field = `transport` text = `Choose a request` ) ).
    fire( `PACKAGE_CREATE` ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_package_error-description ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_package_message ).
    cl_abap_unit_assert=>assert_equals( exp = `Choose a request` act = mo_app->ms_package_error-transport ).
  ENDMETHOD.

  METHOD package_exception_keeps_inputs.
    fire( `PACKAGE_OPEN` ).
    DATA(ls_before) = mo_app->ms_package.
    mo_service->mv_fail = abap_true.
    fire( `PACKAGE_CREATE` ).
    cl_abap_unit_assert=>assert_equals( exp = ls_before act = mo_app->ms_package ).
    cl_abap_unit_assert=>assert_equals( exp = `Package permission denied` act = mo_app->mv_package_message ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_popup_closed ).
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

  METHOD login_error_opens_login.
    " a private repository and no credentials from the user exit
    mo_service->mv_fail = abap_true.
    mo_service->mv_fail_text = `Unauthorized access. Check your credentials`.
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_bound( CAST zcl_ag2ui5_app_login( mo_client->mo_called ) ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_message ).
  ENDMETHOD.

  METHOD other_error_message.
    mo_service->mv_fail = abap_true.
    fire( `CREATE` ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_message exp = `Not authorized` ).
  ENDMETHOD.

  METHOD logged_in_keeps_form.
    mo_client->ms_get-r_event_data = NEW string( `LOGGED_IN:github.com` ).
    mo_client->mv_start = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_repo-url exp = `https://github.com/abapGit-tests/DTEL.git` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_toast
                                        exp = `Logged in to github.com - repeat the action if it did not run` ).
  ENDMETHOD.
ENDCLASS.
