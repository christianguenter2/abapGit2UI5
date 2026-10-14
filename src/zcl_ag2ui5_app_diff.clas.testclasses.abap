CLASS ltcl_semantic DEFINITION DEFERRED.
CLASS ltcl_object_links DEFINITION DEFERRED.
CLASS ltcl_patch DEFINITION DEFERRED.
CLASS ltcl_columns DEFINITION DEFERRED.
CLASS ltcl_settings DEFINITION DEFERRED.
CLASS ltcl_header DEFINITION DEFERRED.
CLASS ltcl_login DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_diff DEFINITION LOCAL FRIENDS ltcl_semantic ltcl_patch ltcl_columns ltcl_settings ltcl_header ltcl_object_links
                                                   ltcl_login.

"! abap2UI5 client for one event with its arguments
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mt_routes TYPE string_table.
    DATA mv_route TYPE string.
    DATA mo_left_to TYPE REF TO z2ui5_if_app.
    DATA mv_event TYPE string.
    DATA mt_args TYPE string_table.
    DATA mv_left TYPE abap_bool.
    DATA mv_view TYPE string.
    DATA mv_init TYPE abap_bool.
    DATA mv_navigated TYPE abap_bool.
    DATA mv_error TYPE string.
    DATA mv_toast TYPE string.
    DATA mo_called TYPE REF TO z2ui5_if_app.
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
    result = xsdbool( mv_init = abap_false AND mv_navigated = abap_false ).
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_call.
    mo_called = app.
  ENDMETHOD.

  METHOD z2ui5_if_client~get.
    result = ms_get.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event_arg.
    result = VALUE #( mt_args[ v ] OPTIONAL ).
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave.
    mo_left_to = app.
    mv_left = abap_true.
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
  "! the view is built but not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
ENDCLASS.


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


CLASS ltcl_patch DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_diff.
    DATA mo_client TYPE REF TO ltd_client.

    METHODS setup.
    METHODS teardown.
    METHODS fire
      IMPORTING
        iv_event TYPE string
        it_args  TYPE string_table OPTIONAL.
    METHODS picked_rows
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS pick_ticks_both_halves FOR TESTING.
    METHODS unpick_clears_both_halves FOR TESTING.
    METHODS pick_all_and_none FOR TESTING.
    METHODS picks_survive_toggle FOR TESTING.
    METHODS apply_hands_back FOR TESTING.
    METHODS back_discards FOR TESTING.
    METHODS earlier_picks_shown FOR TESTING.
    METHODS unknown_id_ignored FOR TESTING.
    METHODS no_apply_without_diff FOR TESTING.
ENDCLASS.


CLASS ltcl_patch IMPLEMENTATION.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD setup.
    " not the tester's own settings
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    " same, added (N2), removed (O2), changed old + new (N3)
    mo_client = NEW #( ).
    mo_app = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `zcl_a.clas.abap`
                                          iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` iv_patch = abap_true ).
    mo_app->client = mo_client.
    mo_app->mv_fingerprint = `fp`.
    mo_app->mt_all = VALUE #(
      ( local_num = `1` remote_num = `1` text = `same`        kind = `SAME` )
      ( local_num = `2`                  text = `added`       kind = `LOCAL`  patch_id = `N2` )
      (                 remote_num = `2` text = `removed`     kind = `REMOTE` patch_id = `O2` )
      (                 remote_num = `3` text = `changed old` kind = `REMOTE` patch_id = `N3` )
      ( local_num = `3`                  text = `changed new` kind = `LOCAL`  patch_id = `N3` ) ).
    mo_app->rows_build( ).
  ENDMETHOD.

  METHOD fire.
    mo_client->mv_event = iv_event.
    mo_client->mt_args  = it_args.
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.

  METHOD picked_rows.
    " one character per shown row: X picked, - not, . nothing to pick
    LOOP AT mo_app->mt_rows INTO DATA(ls_row).
      rv_text = rv_text && COND #( WHEN ls_row-pickable = abap_false THEN `.`
                                   WHEN ls_row-picked = abap_true THEN `X` ELSE `-` ).
    ENDLOOP.
  ENDMETHOD.

  METHOD pick_ticks_both_halves.
    fire( iv_event = `PICK` it_args = VALUE #( ( `N3` ) ( `X` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = picked_rows( ) exp = `.--XX` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_pick_text exp = `1 of 3 lines picked` ).
  ENDMETHOD.

  METHOD unpick_clears_both_halves.
    fire( iv_event = `PICK` it_args = VALUE #( ( `N3` ) ( `X` ) ) ).
    fire( iv_event = `PICK` it_args = VALUE #( ( `N3` ) ( `` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = picked_rows( ) exp = `.----` ).
  ENDMETHOD.

  METHOD pick_all_and_none.
    fire( `PICK_ALL` ).
    cl_abap_unit_assert=>assert_equals( act = picked_rows( ) exp = `.XXXX` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mv_pick_text exp = `3 of 3 lines picked` ).

    fire( `PICK_NONE` ).
    cl_abap_unit_assert=>assert_equals( act = picked_rows( ) exp = `.----` ).
  ENDMETHOD.

  METHOD picks_survive_toggle.
    " Show all / Changes only rebuilds the rows from mt_all
    fire( iv_event = `PICK` it_args = VALUE #( ( `O2` ) ( `X` ) ) ).
    fire( `TOGGLE` ).
    fire( `TOGGLE` ).

    cl_abap_unit_assert=>assert_equals( act = picked_rows( ) exp = `.-X--` ).
  ENDMETHOD.

  METHOD apply_hands_back.
    fire( iv_event = `PICK` it_args = VALUE #( ( `N3` ) ( `X` ) ) ).
    fire( iv_event = `PICK` it_args = VALUE #( ( `N2` ) ( `X` ) ) ).
    fire( `APPLY` ).

    DATA(ls_patch) = mo_app->get_patch( ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_true( ls_patch-applied ).
    cl_abap_unit_assert=>assert_equals( act = ls_patch-ids exp = VALUE string_table( ( `N2` ) ( `N3` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_patch-total exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_patch-fingerprint exp = `fp` ).
    cl_abap_unit_assert=>assert_equals( act = ls_patch-filename exp = `zcl_a.clas.abap` ).
  ENDMETHOD.

  METHOD back_discards.
    fire( iv_event = `PICK` it_args = VALUE #( ( `N3` ) ( `X` ) ) ).
    fire( `BACK` ).

    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
    cl_abap_unit_assert=>assert_false( mo_app->get_patch( )-applied ).
  ENDMETHOD.

  METHOD earlier_picks_shown.
    mo_app = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `zcl_a.clas.abap`
                                          iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` iv_patch = abap_true
                                          it_picked = VALUE #( ( `O2` ) ) ).
    mo_app->client = mo_client.
    mo_app->mt_all = VALUE #(
      (                 remote_num = `2` text = `removed` kind = `REMOTE` patch_id = `O2` ) ).
    mo_app->rows_build( ).

    cl_abap_unit_assert=>assert_equals( act = picked_rows( ) exp = `X` ).
  ENDMETHOD.

  METHOD no_apply_without_diff.
    " the diff did not load: Apply must not hand back "no lines"
    CLEAR: mo_app->mv_fingerprint, mo_app->mt_all.
    fire( `APPLY` ).

    cl_abap_unit_assert=>assert_false( mo_app->get_patch( )-applied ).
  ENDMETHOD.

  METHOD unknown_id_ignored.
    " the ID comes from the browser; one that is not in the diff is dropped
    fire( iv_event = `PICK` it_args = VALUE #( ( `N99` ) ( `X` ) ) ).
    fire( `APPLY` ).

    cl_abap_unit_assert=>assert_initial( mo_app->get_patch( )-ids ).
  ENDMETHOD.

ENDCLASS.


"! Side by side as in abapGit: the system left, Git right, in both directions
CLASS ltcl_columns DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS app
      IMPORTING
        iv_remote_is_new TYPE abap_bool
      RETURNING
        VALUE(ro_app)    TYPE REF TO zcl_ag2ui5_app_diff.
    METHODS teardown.

    METHODS push_system_left FOR TESTING.
    METHODS pull_system_left FOR TESTING.
ENDCLASS.


CLASS ltcl_columns IMPLEMENTATION.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD app.
    " not the tester's own settings
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    " one line changed: the system has "local", Git has "remote"
    ro_app = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `zcl_a.clas.abap`
                                          iv_obj_type = `CLAS` iv_obj_name = `ZCL_A`
                                          iv_remote_is_new = iv_remote_is_new ).
    ro_app->mt_all = VALUE #(
      ( local_num = `1` remote_num = `1` text = `same`   kind = `SAME` )
      (                 remote_num = `2` text = `remote` kind = `REMOTE` )
      ( local_num = `2`                  text = `local`  kind = `LOCAL` ) ).
    ro_app->rows_build( ).
  ENDMETHOD.

  METHOD push_system_left.
    DATA(lo_app) = app( abap_false ).
    cl_abap_unit_assert=>assert_equals( exp = `System (new)` act = lo_app->ms_head-system_label ).
    cl_abap_unit_assert=>assert_equals( exp = `Git (old)`    act = lo_app->ms_head-git_label ).
    READ TABLE lo_app->mt_sbs INTO DATA(ls_row) INDEX 2.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*local*`  act = ls_row-system_html ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*remote*` act = ls_row-git_html ).
    cl_abap_unit_assert=>assert_equals( exp = `+`       act = ls_row-system_marker ).
    cl_abap_unit_assert=>assert_equals( exp = `Success` act = ls_row-system_state ).
    cl_abap_unit_assert=>assert_equals( exp = `-`       act = ls_row-git_marker ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`   act = ls_row-git_state ).
    cl_abap_unit_assert=>assert_equals( exp = `2`       act = ls_row-system_num ).
  ENDMETHOD.

  METHOD pull_system_left.
    DATA(lo_app) = app( abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = `System (old)` act = lo_app->ms_head-system_label ).
    cl_abap_unit_assert=>assert_equals( exp = `Git (new)`    act = lo_app->ms_head-git_label ).
    READ TABLE lo_app->mt_sbs INTO DATA(ls_row) INDEX 2.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*local*`  act = ls_row-system_html ).
    cl_abap_unit_assert=>assert_char_cp( exp = `*remote*` act = ls_row-git_html ).
    cl_abap_unit_assert=>assert_equals( exp = `-`       act = ls_row-system_marker ).
    cl_abap_unit_assert=>assert_equals( exp = `Error`   act = ls_row-system_state ).
    cl_abap_unit_assert=>assert_equals( exp = `+`       act = ls_row-git_marker ).
    cl_abap_unit_assert=>assert_equals( exp = `Success` act = ls_row-git_state ).
    cl_abap_unit_assert=>assert_equals( exp = `2`       act = ls_row-git_num ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_settings TYPE REF TO ltd_settings.

    METHODS setup.
    METHODS teardown.
    METHODS create
      IMPORTING
        iv_patch      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_diff.
    METHODS fire
      IMPORTING
        io_app   TYPE REF TO zcl_ag2ui5_app_diff
        iv_event TYPE string.

    METHODS create_reads_settings FOR TESTING.
    METHODS patch_ignores_layout FOR TESTING.
    METHODS patch_layout_event_not_saved FOR TESTING.
    METHODS layout_event_saves FOR TESTING.
    METHODS toggle_event_saves FOR TESTING.
ENDCLASS.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_settings = NEW #( ).
    mo_settings->mt_preset = VALUE #(
      ( key = zif_ag2ui5_settings=>c_key-diff_layout   value = `SBS` )
      ( key = zif_ag2ui5_settings=>c_key-diff_show_all value = `X` ) ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD create.
    ro_app = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `zcl_a.clas.abap`
                                          iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` iv_patch = iv_patch ).
  ENDMETHOD.

  METHOD fire.
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = iv_event.
    io_app->z2ui5_if_app~main( lo_client ).
  ENDMETHOD.

  METHOD create_reads_settings.
    DATA(lo_app) = create( ).
    cl_abap_unit_assert=>assert_equals( exp = `SBS` act = lo_app->mv_layout ).
    cl_abap_unit_assert=>assert_true( lo_app->mv_show_all ).
  ENDMETHOD.

  METHOD patch_ignores_layout.
    " patch mode is always inline, and must not overwrite the stored layout
    DATA(lo_app) = create( abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = `INLINE` act = lo_app->mv_layout ).
    fire( io_app = lo_app iv_event = `TOGGLE` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `?` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-diff_layout ) ).
  ENDMETHOD.

  METHOD patch_layout_event_not_saved.
    " patch mode shows no layout switch; a crafted LAYOUT event must not
    " overwrite the stored side by side with the inline it shows
    DATA(lo_app) = create( abap_true ).
    fire( io_app = lo_app iv_event = `LAYOUT` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `?` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-diff_layout ) ).
  ENDMETHOD.

  METHOD layout_event_saves.
    DATA(lo_app) = create( ).
    lo_app->mv_layout = `INLINE`.
    fire( io_app = lo_app iv_event = `LAYOUT` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `INLINE` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-diff_layout ) ).
  ENDMETHOD.

  METHOD toggle_event_saves.
    " the stored X is read, TOGGLE flips it and saves the new state
    DATA(lo_app) = create( ).
    fire( io_app = lo_app iv_event = `TOGGLE` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-diff_show_all ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_header DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS back_never_overflows FOR TESTING.
    METHODS apply_never_overflows FOR TESTING.
    METHODS assert_back
      IMPORTING
        iv_patch TYPE abap_bool.
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
    assert_back( abap_false ).
    assert_back( abap_true ).
  ENDMETHOD.

  METHOD apply_never_overflows.
    " Apply never moves into the menu
    DATA(lo_app) = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `zcl_a.clas.abap`
                                                iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` iv_patch = abap_true ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->client = lo_client.
    lo_app->mv_fingerprint = `fp`.
    lo_app->view_display( ).
    FIND REGEX `<Button text="Apply"[^>]*[^/>]>\s*<layoutData>\s*<OverflowToolbarLayoutData[^>]*priority="NeverOverflow"`
      IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
  ENDMETHOD.

  METHOD assert_back.
    DATA(lo_app) = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `zcl_a.clas.abap`
                                                iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` iv_patch = iv_patch ).
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
    DATA(lo_app) = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/`
      iv_filename = `zcl_a.clas.abap` iv_obj_type = `CLAS` iv_obj_name = `ZCL_A`
      iv_object_link = `adt://A4H/example` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->client = lo_client.
    lo_app->view_display( ).
    " The link must belong to ObjectAttribute customContent, not its siblings.
    FIND REGEX `<ObjectAttribute title="Object">\s*<customContent>\s*<Link`
      IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
    CLEAR lo_app->ms_head-object_link.
    lo_app->view_display( ).
    FIND REGEX `<ObjectAttribute title="Object" text="[^"]*"/>`
      IN lo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lo_client->mv_view ).
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_semantic DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_diff.
    DATA mo_client TYPE REF TO ltd_client.
    METHODS setup.
    METHODS teardown.
    METHODS filters_both_sides FOR TESTING.
    METHODS filters_one_side FOR TESTING.
    METHODS rejects_forged_range FOR TESTING.
    METHODS full_diff_restores FOR TESTING.
    METHODS patch_keeps_full_source FOR TESTING.
    METHODS view_has_summary FOR TESTING.
ENDCLASS.

CLASS ltcl_semantic IMPLEMENTATION.
  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_app = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `test.clas.abap`
      iv_obj_type = `CLAS` iv_obj_name = `ZCL_TEST` ).
    mo_client = NEW #( ).
    mo_app->client = mo_client.
    mo_app->mv_show_all = abap_true.
    mo_app->mt_all = VALUE #(
      ( text = `outside` local_num = `1` remote_num = `1` kind = `SAME` )
      ( text = `METHOD run.` local_num = `2` remote_num = `2` kind = `SAME` )
      ( text = `old` remote_num = `3` kind = `REMOTE` patch_id = `N3` )
      ( text = `new` local_num = `3` kind = `LOCAL` patch_id = `N3` )
      ( text = `ENDMETHOD.` local_num = `4` remote_num = `4` kind = `SAME` )
      ( text = `outside` local_num = `5` remote_num = `5` kind = `SAME` ) ).
    mo_app->mt_semantic = VALUE #( ( id = `ZCL_TEST/Implementation/RUN` text = `RUN implementation changed`
      local_from = 2 local_to = 4 remote_from = 2 remote_to = 4 ) ).
    mo_app->mt_summary = CORRESPONDING #( mo_app->mt_semantic ).
    mo_app->mv_summary_note = `Method declarations and implementations only.`.
    mo_app->rows_build( ).
  ENDMETHOD.
  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.
  METHOD filters_both_sides.
    mo_client->mv_event = `SEMANTIC`.
    mo_client->mt_args = VALUE #( ( `ZCL_TEST/Implementation/RUN` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-local_num exp = `2` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 2 ]-remote_num exp = `3` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_all ) exp = 6 ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_sbs ) exp = 3 ).
  ENDMETHOD.
  METHOD filters_one_side.
    mo_app->mt_semantic = VALUE #( ( id = `removed` remote_from = 3 remote_to = 3 )
      ( id = `added` local_from = 3 local_to = 3 ) ).
    mo_app->focus_change( `removed` ).
    mo_app->rows_build( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-remote_num exp = `3` ).
    mo_app->focus_change( `added` ).
    mo_app->rows_build( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_rows[ 1 ]-local_num exp = `3` ).
  ENDMETHOD.

  METHOD rejects_forged_range.
    mo_app->mt_summary = VALUE #( ( id = `forged` text = `forged source range` ) ).
    mo_client->mv_event = `SEMANTIC`.
    mo_client->mt_args = VALUE #( ( `forged` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_focus ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 6 ).
  ENDMETHOD.
  METHOD full_diff_restores.
    mo_app->focus_change( `ZCL_TEST/Implementation/RUN` ).
    mo_client->mv_event = `FULL_DIFF`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_focus ).
    cl_abap_unit_assert=>assert_initial( mo_app->mv_focus_text ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 6 ).
  ENDMETHOD.
  METHOD patch_keeps_full_source.
    mo_app->mv_patch = abap_true.
    mo_client->mv_event = `SEMANTIC`.
    mo_client->mt_args = VALUE #( ( `ZCL_TEST/Implementation/RUN` ) ).
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_initial( mo_app->ms_focus ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_rows ) exp = 6 ).
    mo_client->mv_event = `PICK_ALL`.
    mo_app->on_event( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_picked ) exp = 1 ).
  ENDMETHOD.
  METHOD view_has_summary.
    mo_app->focus_change( `ZCL_TEST/Implementation/RUN` ).
    mo_app->view_display( ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view exp = `*Structural changes*` ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_view exp = `*Show complete diff*` ).
    mo_app->mv_patch = abap_true.
    mo_app->view_display( ).
    cl_abap_unit_assert=>assert_false( xsdbool( mo_client->mv_view CS `Structural changes` ) ).
  ENDMETHOD.
ENDCLASS.


"! get_diff raises a given text, or returns one line
CLASS ltd_login_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mv_error TYPE string.
    DATA mv_calls TYPE i.
    DATA mv_got_sha1 TYPE string.
    DATA mv_got_known TYPE abap_bool.
ENDCLASS.

CLASS ltd_login_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~get_diff.
    mv_got_sha1 = iv_remote_sha1.
    mv_got_known = iv_remote_known.
    mv_calls = mv_calls + 1.
    IF mv_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_error ).
    ENDIF.
    rs_diff-lines = VALUE #( ( local_num = `1` remote_num = `1` text = `x` kind = zif_ag2ui5_repo_service=>c_line_kind-same ) ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_login DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_diff.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_login_service.
    METHODS setup.
    METHODS teardown.
    METHODS start.
    METHODS login_error_opens_login FOR TESTING.
    METHODS other_error_message FOR TESTING.
    METHODS logged_in_reloads FOR TESTING.
    METHODS remote_hash_reaches_service FOR TESTING.
ENDCLASS.

CLASS ltcl_login IMPLEMENTATION.
  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
    mo_app = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `a.abap`
                                          iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` ).
    mo_app->mi_service = mo_service.
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD start.
    mo_client->mv_init = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    mo_client->mv_init = abap_false.
  ENDMETHOD.

  METHOD login_error_opens_login.
    mo_service->mv_error = `Unauthorized access. Check your credentials`.
    start( ).
    cl_abap_unit_assert=>assert_bound( CAST zcl_ag2ui5_app_login( mo_client->mo_called ) ).
    cl_abap_unit_assert=>assert_initial( mo_client->mv_error ).
  ENDMETHOD.

  METHOD other_error_message.
    mo_service->mv_error = `Boom`.
    start( ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_error exp = `Boom` ).
  ENDMETHOD.

  METHOD logged_in_reloads.
    mo_service->mv_error = `Unauthorized access. Check your credentials`.
    start( ).
    CLEAR mo_service->mv_error.
    mo_client->ms_get-r_event_data = NEW string( `LOGGED_IN:github.com` ).
    mo_client->mv_navigated = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_calls exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = mo_client->mv_toast
                                        exp = `Logged in to github.com - repeat the action if it did not run` ).
  ENDMETHOD.
  METHOD remote_hash_reaches_service.
    mo_app = zcl_ag2ui5_app_diff=>create( iv_key = `000000000001` iv_path = `/src/` iv_filename = `a.abap`
                                          iv_obj_type = `CLAS` iv_obj_name = `ZCL_A`
                                          iv_remote_sha1 = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349`
                                          iv_remote_known = abap_true ).
    mo_app->mi_service = mo_service.
    start( ).
    cl_abap_unit_assert=>assert_equals( act = mo_service->mv_got_sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
    cl_abap_unit_assert=>assert_true( mo_service->mv_got_known ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->get_remote( )-sha1 exp = `84d35dd847b3dc2361f9eea4cf2bdc76a8d1b349` ).
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
    DATA(lo_app) = zcl_ag2ui5_app_diff=>create( iv_key = `000000000010` iv_path = `/src/` iv_filename = `a.abap` iv_obj_type = `CLAS` iv_obj_name = `ZTEST` ).
    lo_client->mv_event = `ROUTE_CHANGED`.
    lo_client->ms_get-s_config-hash = `#/repo/000000000099`.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_true( xsdbool( lo_client->mo_left_to IS INSTANCE OF zcl_ag2ui5_app_repos ) ).
    cl_abap_unit_assert=>assert_initial( lo_client->mt_routes ).
  ENDMETHOD.

  METHOD parent_on_roundtrip.
    DATA(lo_client) = NEW ltd_client( ).
    DATA(lo_app) = zcl_ag2ui5_app_diff=>create( iv_key = `000000000010` iv_path = `/src/` iv_filename = `a.abap` iv_obj_type = `CLAS` iv_obj_name = `ZTEST` ).
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals( act = lo_client->mv_route exp = `/repo/000000000010` ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_client->mt_routes ) exp = 4 ).
  ENDMETHOD.
ENDCLASS.
