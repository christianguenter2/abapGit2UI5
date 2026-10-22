CLASS ltcl_ignore DEFINITION DEFERRED.
CLASS ltcl_object_links DEFINITION DEFERRED.
CLASS ltcl_push DEFINITION DEFERRED.
CLASS ltcl_patch DEFINITION DEFERRED.
CLASS ltcl_header DEFINITION DEFERRED.
CLASS ltcl_filter DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_stage DEFINITION LOCAL FRIENDS ltcl_ignore ltcl_push ltcl_patch ltcl_header ltcl_object_links
  ltcl_filter.

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
    DATA mt_routes TYPE string_table.
    DATA mv_route TYPE string.
    DATA mo_left_to TYPE REF TO z2ui5_if_app.
    DATA mv_event TYPE string.
    DATA mv_message TYPE string.
    DATA mv_details TYPE string.
    DATA mv_called TYPE REF TO z2ui5_if_app.
    DATA mv_view TYPE string.
    DATA mv_popup TYPE string.
    DATA mv_closed TYPE abap_bool.
    DATA mv_arg1 TYPE string VALUE `/src/`.
    DATA mv_arg2 TYPE string VALUE `zcl_a.clas.abap`.
    DATA mv_left_data TYPE string.
    DATA mv_navigated TYPE abap_bool.
    DATA mo_prev TYPE REF TO z2ui5_if_app.
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

  METHOD z2ui5_if_client~get.
    result = ms_get.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_app_prev.
    result = COND #( WHEN mo_prev IS BOUND THEN mo_prev ELSE zcl_ag2ui5_app_login=>create( ) ).
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_init.
    result = abap_false.
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

  METHOD z2ui5_if_client~message_toast_display.
    mv_message = text.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_box_display.
    mv_message = text.
    mv_details = details.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event_arg.
    result = SWITCH #( v WHEN 1 THEN mv_arg1 ELSE mv_arg2 ).
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_call.
    mv_called = app.
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave.
    mo_left_to = app.
    IF r_data IS SUPPLIED.
      mv_left_data = r_data.
    ENDIF.
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


"! Service that counts the pushes, and fails on request
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mv_push_calls TYPE i.
    DATA mv_fail TYPE abap_bool.
    DATA mt_received_items TYPE zif_ag2ui5_repo_service=>ty_stage_items.
    DATA ms_stage TYPE zif_ag2ui5_repo_service=>ty_stage.
    DATA ms_preview TYPE zif_ag2ui5_repo_service=>ty_ignore_preview.
    DATA ms_saved TYPE zif_ag2ui5_repo_service=>ty_ignore_preview.
    DATA mv_preview_rule TYPE string.
    DATA mv_preview_remove TYPE abap_bool.
    DATA mv_save_fail TYPE abap_bool.
    DATA ms_received_commit TYPE zif_ag2ui5_repo_service=>ty_commit.
    "! commit_push raises this text instead of HTTP 401 when set
    DATA mv_fail_text TYPE string.
    DATA mv_stage_calls TYPE i.
    "! commit_push answers "changed" when set
    DATA mv_changed TYPE abap_bool.
    "! commit_push raises with this previous error when set
    DATA mv_fail_previous TYPE string.
ENDCLASS.


CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~commit_push.
    mv_push_calls = mv_push_calls + 1.
    mt_received_items = it_items.
    ms_received_commit = is_commit.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( COND #( WHEN mv_fail_text IS NOT INITIAL THEN mv_fail_text ELSE `HTTP 401 Unauthorized` ) ).
    ENDIF.
    IF mv_fail_previous IS NOT INITIAL.
      TRY.
          zcx_abapgit_exception=>raise( mv_fail_previous ).
        CATCH zcx_abapgit_exception INTO DATA(lx_previous).
          zcx_abapgit_exception=>raise( iv_text = `Branch x was created and is now followed, but nothing was pushed.`
                                        ix_previous = lx_previous ).
      ENDTRY.
    ENDIF.
    IF mv_changed = abap_true.
      rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-changed.
      RETURN.
    ENDIF.
    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-pushed.
    rs_result-commit  = `abc1234`.
    rs_result-branch  = COND #( WHEN is_commit-new_branch IS NOT INITIAL THEN is_commit-new_branch ELSE `main` ).
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_stage.
    mv_stage_calls = mv_stage_calls + 1.
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
    METHODS pushes_once FOR TESTING.
    METHODS error_shown FOR TESTING.
    METHODS no_push_without_select FOR TESTING.
    METHODS committer_required FOR TESTING.
    METHODS no_token_fields FOR TESTING.
    METHODS new_branch_passed FOR TESTING.
    METHODS new_branch_cleared_after_push FOR TESTING.
    METHODS toast_names_branch FOR TESTING.
    METHODS placeholder_bound FOR TESTING.
    METHODS failed_push_follows_new_branch FOR TESTING.
    METHODS failed_push_keeps_unused_name FOR TESTING.
    METHODS back_after_push_reports FOR TESTING.
    METHODS leave_when_nothing_left FOR TESTING.
    METHODS stay_when_changes_left FOR TESTING.
    METHODS stay_after_failed_push FOR TESTING.
    METHODS login_error_opens_login FOR TESTING.
    METHODS other_error_message FOR TESTING.
    METHODS changed_by_shown FOR TESTING.
    METHODS logged_in_reloads FOR TESTING.
    METHODS logged_in_keeps_selection FOR TESTING.

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
    mo_app->ms_commit-name  = `Someone`.
    mo_app->ms_commit-email = `someone@example.com`.
    " another change is left after the push: the page stays
    mo_service->ms_stage-items = VALUE #( ( path = `/src/` filename = `zcl_b.clas.abap` action = `ADD` ) ).
  ENDMETHOD.

  METHOD pushes_once.
    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_push_calls exp = 1 ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_message
                                         exp = `Pushed abc1234*` ).
  ENDMETHOD.

  METHOD error_shown.
    mo_service->mv_fail = abap_true.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message
                                        exp = `HTTP 401 Unauthorized` ).
  ENDMETHOD.

  METHOD no_push_without_select.
    mo_app->mt_rows[ 1 ]-selected = abap_false.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_push_calls exp = 0 ).
  ENDMETHOD.

  METHOD committer_required.
    " abapGit needs a committer; without one the push must not start
    CLEAR mo_app->ms_commit-email.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_push_calls exp = 0 ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_message
                                         exp = `*committer*` ).
  ENDMETHOD.

  METHOD no_token_fields.
    " credentials come from the user exit or the session login, never from this page
    mo_app->client = mo_client.
    mo_app->view_display( ).
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_view exp = `*Password*` ).
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_view exp = `*Git user*` ).
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

  METHOD failed_push_follows_new_branch.
    " the branch was created, the push failed: a retry must go to that
    " branch, not try to create it again, and the selection stays
    mo_service->mv_fail = abap_true.
    mo_service->ms_stage-branch = `feature-x`.
    mo_app->ms_commit-new_branch = `feature x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_commit-new_branch ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_branch_hint exp = `Leave empty to push to feature-x` ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `HTTP 401 Unauthorized` ).
  ENDMETHOD.

  METHOD failed_push_keeps_unused_name.
    " refused before anything was written: the name stays for correction
    mo_service->mv_fail = abap_true.
    mo_service->ms_stage-branch = `main`.
    mo_app->ms_commit-new_branch = `feature/x`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_commit-new_branch exp = `feature/x` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_branch_hint exp = `Leave empty to push to main` ).
  ENDMETHOD.

  METHOD leave_when_nothing_left.
    " nothing to stage any more: back to the repository, with the message
    CLEAR mo_service->ms_stage-items.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_left_data exp = `PUSHED:Pushed abc1234 to main` ).
  ENDMETHOD.

  METHOD stay_when_changes_left.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_left_data ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `Pushed abc1234 to main` ).
  ENDMETHOD.

  METHOD login_error_opens_login.
    mo_service->mv_fail = abap_true.
    mo_service->mv_fail_text = `Unauthorized access. Check your credentials`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_bound( CAST zcl_ag2ui5_app_login( mo_client->mv_called ) ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_message ).
  ENDMETHOD.

  METHOD changed_by_shown.
    " the Stage page shows who changed each file, from abapGit's transport owner
    mo_service->ms_stage-items = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` action = `ADD`
                                             lstate = `M` changed_by = `ALICE` ) ).
    mo_app->client = mo_client.
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-changed_by exp = `ALICE` ).
    mo_app->view_display( ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view exp = `*{CHANGED_BY}*` ).
  ENDMETHOD.

  METHOD other_error_message.
    mo_service->mv_fail = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `HTTP 401 Unauthorized` ).
  ENDMETHOD.

  METHOD logged_in_reloads.
    " the first load failed for want of credentials: read the list now
    CLEAR mo_app->mt_rows.
    mo_client->ms_get-r_event_data = NEW string( `LOGGED_IN:github.com` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_stage_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message
                                        exp = `Logged in to github.com - repeat the action if it did not run` ).
  ENDMETHOD.

  METHOD logged_in_keeps_selection.
    " a push failed for want of credentials: the selection is kept for the retry
    mo_client->ms_get-r_event_data = NEW string( `LOGGED_IN:github.com` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_stage_calls exp = 0 ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 1 ]-selected ).
  ENDMETHOD.

  METHOD stay_after_failed_push.
    CLEAR mo_service->ms_stage-items.
    mo_service->mv_fail = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_left_data ).
  ENDMETHOD.

  METHOD back_after_push_reports.
    " the status page shows the followed branch: it must reload after a push
    mo_app->z2ui5_if_app~main( mo_client ).
    mo_client->mv_event = `BACK`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_left_data exp = `PUSHED` ).
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
    METHODS changed_push_says_picks_reset FOR TESTING.
    METHODS wrapped_error_shows_details FOR TESTING.
    METHODS pick_opens_patch_mode FOR TESTING.
    METHODS remote_change_notice FOR TESTING.
    METHODS patch_uses_server_hash FOR TESTING.
    METHODS load_keeps_hashes FOR TESTING.
    METHODS pick_all_uses_server_files FOR TESTING.
    METHODS pick_all_passes_earlier FOR TESTING.
    METHODS pick_all_needs_files FOR TESTING.
    METHODS pick_all_keeps_service_order FOR TESTING.
    METHODS pick_all_passes_shown_files FOR TESTING.
    METHODS pick_all_nothing_shown FOR TESTING.
    METHODS pick_all_button_follows_reload FOR TESTING.
    METHODS take_picks_per_file FOR TESTING.
    METHODS take_picks_without_apply FOR TESTING.
    METHODS pick_all_back_keeps_state FOR TESTING.
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

  METHOD changed_push_says_picks_reset.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    mo_service->mv_changed = abap_true.
    mo_client->mv_event = `PUSH`.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_initial( mo_app->mt_patches ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_message exp = `*Picked lines were reset*` ).
  ENDMETHOD.

  METHOD wrapped_error_shows_details.
    mo_app->mt_rows[ 1 ]-selected = abap_true.
    mo_service->mv_fail_previous = `Push rejected by the remote hook`.
    mo_client->mv_event = `PUSH`.

    mo_app->z2ui5_if_app~main( mo_client ).

    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_message exp = `*nothing was pushed.` ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_details exp = `Push rejected by the remote hook` ).
  ENDMETHOD.

  METHOD pick_opens_patch_mode.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    mo_client->mv_event = `PATCH`.

    mo_app->z2ui5_if_app~main( mo_client ).

    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_char_cp( act = lo_diff->ms_head-title exp = `Pick lines - *` ).
  ENDMETHOD.

  METHOD patch_uses_server_hash.
    mo_app->mt_remote = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap`
                                   sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ) ).
    mo_client->mv_event = `PATCH`.
    mo_client->mv_arg1 = `/src/`.
    mo_client->mv_arg2 = `zcl_a.clas.abap`.
    mo_app->z2ui5_if_app~main( mo_client ).
    DATA(ls_remote) = CAST zcl_ag2ui5_app_diff( mo_client->mv_called )->get_remote( ).
    cl_abap_unit_assert=>assert_equals( act = ls_remote-sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
    cl_abap_unit_assert=>assert_true( ls_remote-known ).
  ENDMETHOD.

  METHOD load_keeps_hashes.
    mo_service->ms_stage-items = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` action = `ADD` lstate = `M`
                                             remote_sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` )
                                           ( path = `/src/` filename = `zcl_b.clas.abap` action = `ADD` lstate = `A` ) ).
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_remote ) exp = 2 ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_remote[ path = `/src/` filename = `zcl_b.clas.abap` ]-sha1 ).
  ENDMETHOD.

  METHOD pick_all_uses_server_files.
    mo_service->ms_stage-items = VALUE #(
      ( path = `/src/` filename = `zcl_a.clas.abap` obj_type = `CLAS` obj_name = `ZCL_A`
        object_link = `adt://A4H/example` lstate = `M` rstate = `A` remote_sha1 = `server-hash` changed_by = `ALICE` )
      ( path = `/other/` filename = `zcl_b.clas.abap` lstate = `D` changed_by = `BOB` ) ).
    mo_app->load_stage( ).
    " posted rows cannot change the files, metadata or hashes handed to Diff
    mo_app->mt_rows = VALUE #( ( path = `/forged/` filename = `forged.abap` obj_name = `FORGED` ) ).
    mo_client->mv_event = `PATCH_ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_repo_diff( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_diff->mt_files ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 1 ]-file exp = `/src/zcl_a.clas.abap` ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 1 ]-object_text exp = `CLAS ZCL_A` ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 1 ]-object_link exp = `adt://A4H/example` ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->mt_files[ 2 ]-file exp = `/other/zcl_b.clas.abap` ).
    " inspect serialized server state without friendship with the other app
    DATA lv_xml TYPE string.
    CALL TRANSFORMATION id SOURCE app = lo_diff RESULT XML lv_xml.
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<REMOTE_SHA1>server-hash</REMOTE_SHA1>*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<LSTATE>M</LSTATE><RSTATE>A</RSTATE>*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<MV_PICK>X</MV_PICK>*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_xml exp = `*FORGED*` ).
  ENDMETHOD.

  METHOD pick_all_passes_earlier.
    mo_service->ms_stage-items = CORRESPONDING #( mo_app->mt_rows ).
    mo_app->load_stage( ).
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ( `O9` ) ) ) ).
    mo_client->mv_event = `PATCH_ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_repo_diff( mo_client->mv_called ).
    DATA lv_xml TYPE string.
    CALL TRANSFORMATION id SOURCE app = lo_diff RESULT XML lv_xml.
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<MT_PICKED_IN>*<PATH>/src/</PATH>*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<FILENAME>zcl_a.clas.abap</FILENAME>*<IDS>*N2*O9*</IDS>*` ).
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<FINGERPRINT>fp</FINGERPRINT>*` ).
  ENDMETHOD.

  METHOD pick_all_needs_files.
    mo_client->mv_event = `PATCH_ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `No files to pick lines in` ).
  ENDMETHOD.

  METHOD pick_all_keeps_service_order.
    " the service's order, not the path or name order of a key
    mo_service->ms_stage-items = VALUE #(
      ( path = `/src/` filename = `zcl_c.clas.abap` lstate = `M` )
      ( path = `/src/` filename = `zcl_a.clas.abap` lstate = `M` )
      ( path = `/doc/` filename = `readme.md` lstate = `M` )
      ( path = `/src/` filename = `zcl_b.clas.abap` lstate = `M` ) ).
    mo_app->load_stage( ).
    mo_client->mv_event = `PATCH_ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_repo_diff( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals(
      act = VALUE string_table( FOR f IN lo_diff->mt_files ( f-file ) )
      exp = VALUE string_table( ( `/src/zcl_c.clas.abap` ) ( `/src/zcl_a.clas.abap` )
                                ( `/doc/readme.md` ) ( `/src/zcl_b.clas.abap` ) ) ).
  ENDMETHOD.

  METHOD pick_all_passes_shown_files.
    mo_service->ms_stage-items = VALUE #(
      ( path = `/src/` filename = `zcl_a.clas.abap` lstate = `M` changed_by = `BOB` )
      ( path = `/src/` filename = `zcl_b.clas.abap` lstate = `M` changed_by = `ALICE` )
      ( path = `/src/` filename = `zcl_c.clas.abap` lstate = `M` changed_by = `ALICE` ) ).
    mo_app->load_stage( ).
    mo_app->take_picks( VALUE #( applied = abap_true picks = VALUE #(
      ( path = `/src/` filename = `zcl_a.clas.abap` ids = VALUE #( ( `BOBID` ) ) total = 3 fingerprint = `fp-a` )
      ( path = `/src/` filename = `zcl_b.clas.abap` ids = VALUE #( ( `ALICEID` ) ) total = 3 fingerprint = `fp-b` ) ) ) ).
    mo_app->mv_user_filter = `ALICE`.
    mo_client->mv_event = `PATCH_ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_repo_diff( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals(
      act = VALUE string_table( FOR f IN lo_diff->mt_files ( f-file ) )
      exp = VALUE string_table( ( `/src/zcl_b.clas.abap` ) ( `/src/zcl_c.clas.abap` ) ) ).
    " the hidden file and its picks are not handed over, the shown file's picks are
    DATA lv_xml TYPE string.
    CALL TRANSFORMATION id SOURCE app = lo_diff RESULT XML lv_xml.
    cl_abap_unit_assert=>assert_char_cp( act = lv_xml exp = `*<MT_PICKED_IN>*zcl_b.clas.abap*ALICEID*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_xml exp = `*zcl_a.clas.abap*` ).
    cl_abap_unit_assert=>assert_char_np( act = lv_xml exp = `*BOBID*` ).
    " the hidden file keeps its own pick in Stage
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_patches ) exp = 2 ).
  ENDMETHOD.

  METHOD pick_all_nothing_shown.
    mo_service->ms_stage-items = VALUE #(
      ( path = `/src/` filename = `zcl_a.clas.abap` lstate = `M` changed_by = `BOB` ) ).
    mo_app->load_stage( ).
    mo_app->mv_user_filter = `ALICE`.
    mo_client->mv_event = `PATCH_ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_called ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `No files to pick lines in` ).
  ENDMETHOD.

  METHOD pick_all_button_follows_reload.
    " the button state is a bound flag: every reload sets it, not only the first view
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_pick ).
    mo_service->ms_stage-items = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` lstate = `M` ) ).
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_true( mo_app->mv_can_pick ).
    CLEAR mo_service->ms_stage-items.
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_false( mo_app->mv_can_pick ).
  ENDMETHOD.

  METHOD take_picks_per_file.
    APPEND VALUE #( path = `/src/` filename = `all.abap` lstate = `M` ) TO mo_app->mt_rows.
    APPEND VALUE #( path = `/src/` filename = `none.abap` lstate = `M` selected = abap_true ) TO mo_app->mt_rows.
    APPEND VALUE #( path = `/src/` filename = `untouched.abap` lstate = `M` selected = abap_true ) TO mo_app->mt_rows.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    mo_app->take_picks( VALUE #( applied = abap_true picks = VALUE #(
      ( path = `/src/` filename = `all.abap` ids = VALUE #( ( `N1` ) ) total = 3 fingerprint = `all-fp` )
      ( path = `/src/` filename = `none.abap` ids = VALUE #( ( `N1` ) ) total = 3 fingerprint = `none-fp` )
      ( path = `/src/` filename = `untouched.abap` ids = VALUE #( ( `O1` ) ) total = 4 fingerprint = `keep-fp` ) ) ) ).
    DATA(ls_untouched) = mo_app->mt_rows[ 4 ].
    DATA(ls_keep_patch) = mo_app->mt_patches[ filename = `untouched.abap` ].
    mo_app->take_picks( VALUE #( applied = abap_true picks = VALUE #(
      ( path = `/src/` filename = `zcl_a.clas.abap` ids = VALUE #( ( `N2` ) ( `O9` ) ) total = 7 fingerprint = `new-fp` )
      ( path = `/src/` filename = `all.abap` ids = VALUE #( ( `N1` ) ( `N2` ) ) total = 2 )
      ( path = `/src/` filename = `none.abap` total = 3 ) ) ) ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 1 ]-patched ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-change exp = `modify - 2 of 7 lines` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_patches[ filename = `zcl_a.clas.abap` ]-fingerprint exp = `new-fp` ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 2 ]-selected ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_rows[ 2 ]-patched ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 2 ]-change exp = `modify` ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 3 ]-selected ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_rows[ 3 ]-patched ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 3 ]-change exp = `modify` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_patches ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 4 ] exp = ls_untouched ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_patches[ filename = `untouched.abap` ] exp = ls_keep_patch ).
    " no lines restores the tick from before the first single-file patch too
    mo_app->take_picks( VALUE #( applied = abap_true picks = VALUE #(
      ( path = `/src/` filename = `zcl_a.clas.abap` total = 7 ) ) ) ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_rows[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_rows[ 1 ]-patched ).
  ENDMETHOD.

  METHOD take_picks_without_apply.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    DATA(lt_rows) = mo_app->mt_rows.
    DATA(lt_patches) = mo_app->mt_patches.
    mo_app->take_picks( VALUE #( picks = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` total = 7 ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows exp = lt_rows ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_patches exp = lt_patches ).
  ENDMETHOD.

  METHOD pick_all_back_keeps_state.
    mo_app->take_patch( patch( VALUE #( ( `N2` ) ) ) ).
    DATA(lt_rows) = mo_app->mt_rows.
    DATA(lt_patches) = mo_app->mt_patches.
    mo_client->mo_prev = zcl_ag2ui5_app_repo_diff=>create(
      iv_key = `000000000001` iv_title = `test` it_files = VALUE #( ) iv_pick = abap_true ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows exp = lt_rows ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_patches exp = lt_patches ).
    cl_abap_unit_assert=>assert_not_initial( mo_client->mv_view ).
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

CLASS ltcl_route_parent DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS parent_on_roundtrip FOR TESTING.
    METHODS route_edit_fresh_root FOR TESTING.
ENDCLASS.
CLASS ltcl_route_parent IMPLEMENTATION.
  METHOD route_edit_fresh_root.
    DATA(lo_client) = NEW ltd_client( ).
    DATA(lo_app) = zcl_ag2ui5_app_stage=>create( iv_key = `000000000010` iv_title = `test` ).
    lo_client->mv_event = `ROUTE_CHANGED`.
    lo_client->ms_get-s_config-hash = `#/repo/000000000099`.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
    cl_abap_unit_assert=>assert_initial( lo_client->mt_routes ).
  ENDMETHOD.

  METHOD parent_on_roundtrip.
    DATA(lo_client) = NEW ltd_client( ).
    DATA(lo_app) = zcl_ag2ui5_app_stage=>create( iv_key = `000000000010` iv_title = `test` ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals( act = lo_client->mv_route exp = `/repo/000000000010` ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_client->mt_routes ) exp = 4 ).
  ENDMETHOD.
ENDCLASS.


"! The Changed by filter: Select all / none and the push see only the visible rows
CLASS ltcl_filter DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_stage.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.

    METHODS setup.
    METHODS teardown.
    METHODS users_offered FOR TESTING.
    METHODS select_all_filtered FOR TESTING.
    METHODS select_none_filtered FOR TESTING.
    METHODS select_all_without_filter FOR TESTING.
    METHODS push_skips_hidden FOR TESTING.
    METHODS push_needs_visible_selection FOR TESTING.
    METHODS reload_drops_gone_user FOR TESTING.
    METHODS reload_keeps_user FOR TESTING.
    METHODS filter_in_view FOR TESTING.

ENDCLASS.


CLASS ltcl_filter IMPLEMENTATION.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_client  = NEW #( ).
    mo_service = NEW #( ).
    mo_app = zcl_ag2ui5_app_stage=>create( iv_key = `000000000001` iv_title = `test` ).
    mo_app->mi_service = mo_service.
    mo_app->client = mo_client.
    mo_service->ms_stage-items = VALUE #(
      ( path = `/src/` filename = `zcl_a.clas.abap` action = `ADD` lstate = `M` changed_by = `BOB` )
      ( path = `/src/` filename = `zcl_b.clas.abap` action = `ADD` lstate = `M` changed_by = `UNKNOWN` )
      ( path = `/src/` filename = `zcl_c.clas.abap` action = `ADD` lstate = `M` changed_by = `ALICE` )
      ( path = `/src/` filename = `zcl_d.clas.abap` action = `ADD` lstate = `M` changed_by = `BOB` ) ).
    mo_app->load_stage( ).
    mo_app->ms_commit-title = `Test`.
    mo_app->ms_commit-name  = `Someone`.
    mo_app->ms_commit-email = `someone@example.com`.
  ENDMETHOD.

  METHOD users_offered.
    " all users first, then the names sorted, UNKNOWN last, each with its count
    cl_abap_unit_assert=>assert_equals(
      act = mo_app->mt_users
      exp = VALUE zcl_ag2ui5_app_stage=>ty_users( ( key = `` text = `All users (4)` )
                                                  ( key = `ALICE` text = `ALICE (1)` )
                                                  ( key = `BOB` text = `BOB (2)` )
                                                  ( key = `UNKNOWN` text = `UNKNOWN (1)` ) ) ).
  ENDMETHOD.

  METHOD select_all_filtered.
    mo_app->mv_user_filter = `BOB`.
    mo_client->mv_event = `ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_rows[ 2 ]-selected ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_rows[ 3 ]-selected ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 4 ]-selected ).
  ENDMETHOD.

  METHOD select_none_filtered.
    mo_app->select_all( abap_true ).
    mo_app->mv_user_filter = `BOB`.
    mo_client->mv_event = `NONE`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_rows[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_rows[ 2 ]-selected ).
  ENDMETHOD.

  METHOD select_all_without_filter.
    mo_client->mv_event = `ALL`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( mo_app->mt_rows[ selected = abap_false ] ) ) ).
  ENDMETHOD.

  METHOD push_skips_hidden.
    " a file the filter hides is never committed, even when it is ticked
    mo_app->select_all( abap_true ).
    mo_app->mv_user_filter = `ALICE`.
    mo_client->mv_event = `PUSH`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_push_calls exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_received_items ) exp = 4 ).
    LOOP AT mo_service->mt_received_items INTO DATA(ls_item).
      cl_abap_unit_assert=>assert_equals( act = ls_item-selected
                                          exp = xsdbool( ls_item-changed_by = `ALICE` ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD push_needs_visible_selection.
    mo_app->mt_rows[ 1 ]-selected = abap_true.
    mo_app->mv_user_filter = `ALICE`.
    mo_client->mv_event = `PUSH`.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_push_calls exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_message exp = `Select at least one file` ).
  ENDMETHOD.

  METHOD reload_drops_gone_user.
    " after a push nobody may be left under the chosen name: show all again
    mo_app->mv_user_filter = `ALICE`.
    DELETE mo_service->ms_stage-items WHERE changed_by = `ALICE`.
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_user_filter ).
  ENDMETHOD.

  METHOD reload_keeps_user.
    mo_app->mv_user_filter = `BOB`.
    mo_app->load_stage( ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_user_filter exp = `BOB` ).
  ENDMETHOD.

  METHOD filter_in_view.
    mo_app->view_display( ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view exp = `*<Select*` ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view exp = `*{CHANGED_BY}*` ).
  ENDMETHOD.

ENDCLASS.
