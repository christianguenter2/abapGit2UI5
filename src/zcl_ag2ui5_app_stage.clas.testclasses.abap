CLASS ltcl_ignore DEFINITION DEFERRED.
CLASS ltcl_object_links DEFINITION DEFERRED.
CLASS ltcl_push DEFINITION DEFERRED.
CLASS ltcl_patch DEFINITION DEFERRED.
CLASS ltcl_header DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_stage DEFINITION LOCAL FRIENDS ltcl_ignore ltcl_push ltcl_patch ltcl_header ltcl_object_links.

"! Settings double: always the default, nothing stored - so a diff app the
"! stage app creates does not read the tester's own settings
CLASS ltd_settings DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_settings.
ENDCLASS.

CLASS ltd_settings IMPLEMENTATION.
  METHOD zif_ag2ui5_settings~get.
    rv_value = iv_default.
  ENDMETHOD.
  METHOD zif_ag2ui5_settings~set.
    rv_saved = abap_true.
  ENDMETHOD.
ENDCLASS.

"! abap2UI5 client for one event round trip
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_event TYPE string.
    DATA mv_message TYPE string.
    DATA mv_called TYPE REF TO z2ui5_if_app.
    DATA mv_view TYPE string.
    DATA mv_popup TYPE string.
    DATA mv_closed TYPE abap_bool.
    DATA mv_arg1 TYPE string VALUE `/src/`.
    DATA mv_arg2 TYPE string VALUE `zcl_a.clas.abap`.
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

  METHOD z2ui5_if_client~get_event_arg.
    result = SWITCH #( v WHEN 1 THEN mv_arg1 ELSE mv_arg2 ).
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_call.
    mv_called = app.
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave ##NEEDED.
  ENDMETHOD.

  METHOD z2ui5_if_client~popup_display.
    mv_popup = val.
  ENDMETHOD.
  METHOD z2ui5_if_client~popup_destroy.
    mv_closed = abap_true.
  ENDMETHOD.
  METHOD z2ui5_if_client~view_display.
    mv_view = val.
  ENDMETHOD.
  "! bindings and events are not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
ENDCLASS.


"! Service that records the token it got, and fails on request
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mv_received_token TYPE string.
    DATA mv_fail TYPE abap_bool.
    DATA mt_received_items TYPE zif_ag2ui5_repo_service=>ty_stage_items.
    DATA ms_stage TYPE zif_ag2ui5_repo_service=>ty_stage.
    DATA ms_preview TYPE zif_ag2ui5_repo_service=>ty_ignore_preview.
    DATA ms_saved TYPE zif_ag2ui5_repo_service=>ty_ignore_preview.
    DATA mv_preview_rule TYPE string.
    DATA mv_preview_remove TYPE abap_bool.
    DATA mv_save_fail TYPE abap_bool.
    DATA ms_received_commit TYPE zif_ag2ui5_repo_service=>ty_commit.
ENDCLASS.


CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~commit_push.
    mv_received_token = iv_token.
    mt_received_items = it_items.
    ms_received_commit = is_commit.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `HTTP 401 Unauthorized` ).
    ENDIF.
    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-pushed.
    rs_result-commit  = `abc1234`.
    rs_result-branch  = COND #( WHEN is_commit-new_branch IS NOT INITIAL THEN is_commit-new_branch ELSE `main` ).
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_stage.
    rs_stage = ms_stage.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~preview_ignore.
    mv_preview_rule = iv_rule.
    mv_preview_remove = iv_remove.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Preview failed` ).
    ENDIF.
    rs_preview = ms_preview.
    rs_preview-rule = iv_rule.
    rs_preview-remove = iv_remove.
  ENDMETHOD.
  METHOD zif_ag2ui5_repo_service~save_ignore.
    IF mv_save_fail = abap_true.
      zcx_abapgit_exception=>raise( `Preview is stale` ).
    ENDIF.
    ms_saved = is_preview.
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
    METHODS teardown.
    METHODS token_cleared_after_push FOR TESTING.
    METHODS token_cleared_after_error FOR TESTING.
    METHODS token_cleared_without_select FOR TESTING.
    METHODS committer_required FOR TESTING.
    METHODS token_cleared_on_other_events FOR TESTING.
    METHODS new_branch_passed FOR TESTING.
    METHODS new_branch_cleared_after_push FOR TESTING.
    METHODS toast_names_branch FOR TESTING.
    METHODS placeholder_bound FOR TESTING.

ENDCLASS.


CLASS ltcl_push IMPLEMENTATION.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_client  = NEW #( ).
    mo_service = NEW #( ).
    mo_client->mv_event = `PUSH`.

    mo_app = zcl_ag2ui5_app_stage=>create( iv_key = `000000000001` iv_title = `test` ).
    mo_app->mi_service = mo_service.
    mo_app->mt_rows = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` action = `ADD` selected = abap_true ) ).
    mo_app->ms_commit-title = `Test`.
    mo_app->mv_user  = `someone`.
    mo_app->mv_token = `secret-token`.
    mo_app->ms_commit-name  = `Someone`.
    mo_app->ms_commit-email = `someone@example.com`.
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

  METHOD committer_required.
    " abapGit needs a committer; without one the push must not start
    CLEAR mo_app->ms_commit-email.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_initial( mo_service->mv_received_token ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_token ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_message
                                         exp = `*committer*` ).
  ENDMETHOD.

  METHOD token_cleared_on_other_events.
    " abap2UI5 saves the draft after every event, and a typed token arrives
    " with whatever button is pressed next
    LOOP AT VALUE string_table( ( `ALL` ) ( `NONE` ) ( `DIFF` ) ( `PATCH` ) ( `BACK` )
      ( `RULES` ) ( `IGNORE` ) ( `RULE_REMOVE` ) ( `IGNORE_PREVIEW` ) ( `IGNORE_SAVE` ) ( `IGNORE_CANCEL` ) ) INTO DATA(lv_event).
      mo_app->mv_token = `secret-token`.
      mo_client->mv_event = lv_event.

      mo_app->z2ui5_if_app~main( mo_client ).

      cl_abap_unit_assert=>assert_initial( act = mo_app->mv_token
                                           msg = |Token kept after { lv_event }| ).
    ENDLOOP.
  ENDMETHOD.

  METHOD new_branch_passed.
    mo_app->ms_commit-new_branch = `feature/x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->ms_received_commit-new_branch exp = `feature/x` ).
  ENDMETHOD.

  METHOD new_branch_cleared_after_push.
    " a second push must not try to create the same branch again
    mo_app->ms_commit-new_branch = `feature/x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_commit-new_branch ).
  ENDMETHOD.

  METHOD toast_names_branch.
    mo_app->ms_commit-new_branch = `feature/x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `Pushed abc1234 to feature/x` ).
  ENDMETHOD.

  METHOD placeholder_bound.
    " a branch name may contain { }: the hint reaches the view bound, not inline
    mo_service->ms_stage-branch = `a{b}`.
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_branch_hint exp = `Leave empty to push to a{b}` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_patch DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_stage.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.

    METHODS setup.
    METHODS teardown.
    METHODS patch
      IMPORTING
        it_ids          TYPE string_table
        iv_total        TYPE i DEFAULT 7
      RETURNING
        VALUE(rs_patch) TYPE zcl_ag2ui5_app_diff=>ty_patch.

    METHODS some_lines_select_row FOR TESTING.
    METHODS all_lines_mean_whole_file FOR TESTING.
    METHODS no_lines_reset_row FOR TESTING.
    METHODS no_lines_restore_tick FOR TESTING.
    METHODS back_without_apply_keeps_row FOR TESTING.
    METHODS push_sends_patch FOR TESTING.
    METHODS pick_opens_patch_mode FOR TESTING.
    METHODS remote_change_notice FOR TESTING.
ENDCLASS.


CLASS ltcl_patch IMPLEMENTATION.

  METHOD remote_change_notice.
    cl_abap_unit_assert=>assert_equals(
      act = mo_app->change_text( VALUE #( action = `ADD` lstate = `M` rstate = `M` ) )
      exp = `modify - commit SAP version over Git changes` ).
    cl_abap_unit_assert=>assert_equals(
      act = mo_app->change_text( VALUE #( action = `RM` rstate = `A` ) )
      exp = `delete - commit SAP version over Git changes` ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_client  = NEW #( ).
    mo_service = NEW #( ).
    mo_app = zcl_ag2ui5_app_stage=>create( iv_key = `000000000001` iv_title = `test` ).
    mo_app->client     = mo_client.
    mo_app->mi_service = mo_service.
    mo_app->mt_rows = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` action = `ADD` lstate = `M`
                                 change = `modify` ) ).
    mo_app->ms_commit = VALUE #( title = `Test` name = `Someone` email = `someone@example.com` ).
  ENDMETHOD.

  METHOD patch.
    rs_patch = VALUE #( applied = abap_true path = `/src/` filename = `zcl_a.clas.abap`
                        ids = it_ids total = iv_total fingerprint = `fp` ).
  ENDMETHOD.

  METHOD some_lines_select_row.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ( `N5` ) ( `O9` ) ) ) ).

    DATA(ls_row) = mo_app->mt_rows[ 1 ].
    cl_abap_unit_assert=>assert_true( ls_row-selected ).
    cl_abap_unit_assert=>assert_true( ls_row-patched ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-change exp = `modify - 3 of 7 lines` ).
  ENDMETHOD.

  METHOD all_lines_mean_whole_file.
    mo_app->take_patch( patch( it_ids = VALUE #( ( `N2` ) ( `O3` ) ) iv_total = 2 ) ).

    DATA(ls_row) = mo_app->mt_rows[ 1 ].
    cl_abap_unit_assert=>assert_true( ls_row-selected ).
    cl_abap_unit_assert=>assert_false( ls_row-patched ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-change exp = `modify` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_patches ).
  ENDMETHOD.

  METHOD no_lines_reset_row.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    mo_app->take_patch( patch( VALUE #( ) ) ).

    DATA(ls_row) = mo_app->mt_rows[ 1 ].
    cl_abap_unit_assert=>assert_false( ls_row-patched ).
    cl_abap_unit_assert=>assert_equals( act = ls_row-change exp = `modify` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_patches ).
    " the row was not ticked before the first patch: pushing would commit
    " the whole file the user just took every line out of
    cl_abap_unit_assert=>assert_false( ls_row-selected ).
  ENDMETHOD.

  METHOD no_lines_restore_tick.
    " ticked before the first patch: it stays ticked, as before
    mo_app->mt_rows[ 1 ]-selected = abap_true.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    mo_app->take_patch( patch( VALUE #( ) ) ).

    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 1 ]-selected ).
  ENDMETHOD.

  METHOD back_without_apply_keeps_row.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    DATA(ls_back) = patch( VALUE #( ( `N2` ) ( `N5` ) ) ).
    ls_back-applied = abap_false.

    mo_app->take_patch( ls_back ).

    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-change exp = `modify - 1 of 7 lines` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_patches[ 1 ]-ids exp = VALUE string_table( ( `N2` ) ) ).
  ENDMETHOD.

  METHOD push_sends_patch.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    mo_client->mv_event = `PUSH`.

    mo_app->z2ui5_if_app~main( mo_client ).

    DATA(ls_item) = mo_service->mt_received_items[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_item-patch_ids exp = VALUE string_table( ( `N2` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-fingerprint exp = `fp` ).
  ENDMETHOD.

  METHOD pick_opens_patch_mode.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    mo_client->mv_event = `PATCH`.

    mo_app->z2ui5_if_app~main( mo_client ).

    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_char_cp( act = lo_diff->ms_head-title exp = `Pick lines - *` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_header DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS back_never_overflows FOR TESTING.
ENDCLASS.

CLASS ltcl_header IMPLEMENTATION.

  METHOD back_never_overflows.
    " on a narrow screen the header controls must not push out the back
    " button: they sit in an overflow toolbar, the back button stays
    DATA(lo_app) = zcl_ag2ui5_app_stage=>create( iv_key = `000000000001` iv_title = `test` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->client = lo_client.
    lo_app->view_display( ).
    FIND REGEX `<customHeader>\s*<OverflowToolbar[^>]*>\s*<Button[^>]*sap-icon://nav-back[^>]*[^/>]>\s*`
            && `<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
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
    DATA(lo_app) = zcl_ag2ui5_app_stage=>create( iv_key = `1` iv_title = `test` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->client = lo_client.
    lo_app->mt_rows = VALUE #( ( obj_type = `CLAS` obj_name = `ZCL_A`
      path = `/src/` filename = `zcl_a.clas.abap` object_link = `adt://A4H/example` ) ).
    lo_client->mv_event = `DIFF`.
    lo_app->on_event( ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( lo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-object_link exp = `adt://A4H/example` ).
    lo_client->mv_event = `PATCH`.
    lo_app->on_event( ).
    lo_diff = CAST zcl_ag2ui5_app_diff( lo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-object_link exp = `adt://A4H/example` ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_ignore DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_stage.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.
    METHODS setup.
    METHODS start FOR TESTING.
    METHODS unknown_row FOR TESTING.
    METHODS edit_refuses_save FOR TESTING.
    METHODS preview_error FOR TESTING.
    METHODS save_needs_preview FOR TESTING.
    METHODS save_reloads FOR TESTING.
    METHODS stale_save FOR TESTING.
    METHODS remove_rule FOR TESTING.
    METHODS cancel_clears FOR TESTING.
ENDCLASS.
CLASS ltcl_ignore IMPLEMENTATION.
  METHOD setup.
    mo_app = zcl_ag2ui5_app_stage=>create( iv_key = `1` iv_title = `test` ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app->client = mo_client.
    mo_app->mi_service = mo_service.
    mo_app->mt_rows = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` lstate = `M` ) ).
    mo_service->ms_preview-files = CORRESPONDING #( mo_app->mt_rows ).
  ENDMETHOD.
  METHOD start.
    mo_client->mv_event = `IGNORE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_ignore_rule exp = `/src/zcl_a.clas.abap` ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_ignore_ready ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_popup ).
    mo_client->mv_event = `IGNORE_PREVIEW`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_ignore_ready ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_ignore_files ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_preview_rule exp = `/src/zcl_a.clas.abap` ).
  ENDMETHOD.
  METHOD unknown_row.
    mo_client->mv_arg2 = `forged.abap`.
    mo_client->mv_event = `IGNORE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_popup ).
  ENDMETHOD.
  METHOD edit_refuses_save.
    start( ).
    mo_app->mv_ignore_rule = `/src/other.abap`.
    mo_client->mv_event = `IGNORE_SAVE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_ignore_ready ).
    cl_abap_unit_assert=>assert_initial( mo_service->ms_saved ).
  ENDMETHOD.
  METHOD preview_error.
    start( ).
    mo_service->mv_fail = abap_true.
    mo_client->mv_event = `IGNORE_PREVIEW`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_ignore_ready ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_ignore_files ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `Preview failed` ).
  ENDMETHOD.
  METHOD save_needs_preview.
    mo_client->mv_event = `IGNORE_SAVE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_service->ms_saved ).
    start( ).
    mo_app->mv_ignore_rule = `/src/other.abap`.
    mo_client->mv_event = `IGNORE_SAVE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_service->ms_saved ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_ignore_ready ).
  ENDMETHOD.
  METHOD save_reloads.
    start( ).
    mo_app->ms_commit-title = `Keep my title`.
    mo_app->ms_commit-email = `tester@example.com`.
    mo_app->mt_patches = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` ids = VALUE #( ( `N1` ) ) ) ).
    mo_service->ms_stage-items = VALUE #( ( path = `/` filename = `.abapgit.xml` lstate = `M` ) ).
    mo_client->mv_event = `IGNORE_SAVE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_not_initial( mo_service->ms_saved ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_closed ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_ignore_preview ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_patches ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-filename exp = `.abapgit.xml` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_commit-title exp = `Keep my title` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_commit-email exp = `tester@example.com` ).
  ENDMETHOD.
  METHOD stale_save.
    start( ).
    mo_service->mv_save_fail = abap_true.
    mo_client->mv_event = `IGNORE_SAVE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_ignore_ready ).
    cl_abap_unit_assert=>assert_false( mo_client->mv_closed ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_ignore_files ).
  ENDMETHOD.
  METHOD remove_rule.
    mo_app->mt_ignore_rules = VALUE #( ( rule = `/src/*.abap` ) ).
    mo_client->mv_arg1 = `/src/*.abap`.
    mo_client->mv_event = `RULE_REMOVE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_ignore_remove ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_ignore_editable ).
    mo_client->mv_event = `IGNORE_PREVIEW`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_service->mv_preview_remove ).
    mo_client->mv_event = `IGNORE_SAVE`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_true( mo_service->ms_saved-remove ).
  ENDMETHOD.
  METHOD cancel_clears.
    start( ).
    mo_client->mv_event = `IGNORE_CANCEL`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_ignore_files ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_ignore_preview ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_closed ).
  ENDMETHOD.
ENDCLASS.
