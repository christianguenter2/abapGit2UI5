CLASS ltcl_repo_diff DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_repo_diff DEFINITION LOCAL FRIENDS ltcl_repo_diff.


CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_init TYPE abap_bool.
    DATA mv_event TYPE string.
    DATA mt_args TYPE string_table.
    DATA mv_left TYPE abap_bool.
    DATA mv_view TYPE string.
    DATA mv_toast TYPE string.
    DATA mo_called TYPE REF TO z2ui5_if_app.
ENDCLASS.


CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~check_on_init.
    result = mv_init.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_navigated.
    result = abap_false.
  ENDMETHOD.

  METHOD z2ui5_if_client~check_on_event.
    result = xsdbool( mv_init = abap_false ).
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.

  METHOD z2ui5_if_client~get_event_arg.
    result = VALUE #( mt_args[ v ] OPTIONAL ).
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave.
    mv_left = abap_true.
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_call.
    mo_called = app.
  ENDMETHOD.

  METHOD z2ui5_if_client~view_display.
    mv_view = val.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_box_display ##NEEDED.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_toast_display.
    mv_toast = text.
  ENDMETHOD.

  "! the view is built but bindings are not checked here
  METHOD z2ui5_if_client~_bind ##NEEDED.
  ENDMETHOD.

  METHOD z2ui5_if_client~_event ##NEEDED.
  ENDMETHOD.
ENDCLASS.


"! get_diff double: /bin/ is binary, /fail/ raises, every other file has
"! one unchanged and one local line
CLASS ltd_service DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service PARTIALLY IMPLEMENTED.
    DATA mt_calls TYPE string_table.
ENDCLASS.


CLASS ltd_service IMPLEMENTATION.
  METHOD zif_ag2ui5_repo_service~get_diff.
    INSERT |{ iv_path }{ iv_filename }| INTO TABLE mt_calls.
    IF iv_path = `/fail/`.
      zcx_abapgit_exception=>raise( `Cannot read file` ).
    ENDIF.
    IF iv_path = `/bin/`.
      rs_diff-binary = abap_true.
      RETURN.
    ENDIF.
    rs_diff-remote_is_new = iv_remote_is_new.
    rs_diff-lines = VALUE #(
      ( local_num = `1` remote_num = `1` text = `same` kind = zif_ag2ui5_repo_service=>c_line_kind-same )
      ( local_num = `2` text = `new` kind = zif_ag2ui5_repo_service=>c_line_kind-local ) ).
    rs_diff-local_count = 1.
  ENDMETHOD.
ENDCLASS.


"! The single-file diff reads the user's settings when it is created
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


CLASS ltcl_repo_diff DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_repo_diff.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_service TYPE REF TO ltd_service.

    METHODS setup.
    METHODS teardown.
    "! Starts the page as abap2UI5 does, then switches the client to events
    METHODS app
      IMPORTING
        it_files TYPE zif_ag2ui5_repo_service=>ty_status_rows.
    METHODS files
      IMPORTING
        iv_count        TYPE i
      RETURNING
        VALUE(rt_files) TYPE zif_ag2ui5_repo_service=>ty_status_rows.
    METHODS fire
      IMPORTING
        iv_event TYPE string
        iv_arg1  TYPE string OPTIONAL
        iv_arg2  TYPE string OPTIONAL.

    METHODS start_loads_first_three FOR TESTING.
    METHODS expand_loads_collapse_clears FOR TESTING.
    METHODS expand_twice_loads_once FOR TESTING.
    METHODS expand_all_stops_at_limit FOR TESTING.
    METHODS forged_index_ignored FOR TESTING.
    METHODS failing_file_isolated FOR TESTING.
    METHODS layout_switch_rebuilds FOR TESTING.
    METHODS layout_keeps_collapsed FOR TESTING.
    METHODS open_uses_server_row FOR TESTING.
    METHODS summary_counts_loaded FOR TESTING.
    METHODS state_texts FOR TESTING.
    METHODS back_leaves FOR TESTING.
    METHODS view_panels_from_template FOR TESTING.
    METHODS view_side_by_side FOR TESTING.
ENDCLASS.


CLASS ltcl_repo_diff IMPLEMENTATION.

  METHOD setup.
    zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
    mo_client = NEW #( ).
    mo_service = NEW #( ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD app.
    mo_app = zcl_ag2ui5_app_repo_diff=>create( iv_key = `1` iv_title = `repo` it_files = it_files ).
    mo_app->mi_service = mo_service.
    mo_client->mv_init = abap_true.
    mo_app->z2ui5_if_app~main( mo_client ).
    mo_client->mv_init = abap_false.
  ENDMETHOD.

  METHOD files.
    DO iv_count TIMES.
      INSERT VALUE #( path = `/src/` filename = |f{ sy-index }.abap| lstate = `M` ) INTO TABLE rt_files.
    ENDDO.
  ENDMETHOD.

  METHOD fire.
    mo_client->mv_event = iv_event.
    mo_client->mt_args = VALUE #( ( iv_arg1 ) ( iv_arg2 ) ).
    mo_app->z2ui5_if_app~main( mo_client ).
  ENDMETHOD.

  METHOD start_loads_first_three.
    app( files( 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 3 ).
    cl_abap_unit_assert=>assert_true( mo_app->mt_files[ 3 ]-expanded ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_files[ 4 ]-expanded ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 4 ]-lines ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_files[ 1 ]-lines ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_files[ 1 ]-file exp = `/src/f1.abap` ).
  ENDMETHOD.

  METHOD expand_loads_collapse_clears.
    app( files( 5 ) ).
    fire( iv_event = `PANEL` iv_arg1 = `4` iv_arg2 = `X` ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mt_files[ 4 ]-lines ).
    fire( iv_event = `PANEL` iv_arg1 = `4` iv_arg2 = `` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 4 ]-lines ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_files[ 4 ]-expanded ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_files[ 4 ]-counts exp = `+1 -0` ).
  ENDMETHOD.

  METHOD expand_twice_loads_once.
    app( files( 2 ) ).
    fire( iv_event = `PANEL` iv_arg1 = `1` iv_arg2 = `X` ).
    fire( iv_event = `PANEL` iv_arg1 = `1` iv_arg2 = `true` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_app->mt_files[ 1 ]-lines ) exp = 2 ).
  ENDMETHOD.

  METHOD expand_all_stops_at_limit.
    app( files( 30 ) ).
    fire( `EXPAND_ALL` ).
    DATA(lv_open) = REDUCE i( INIT n = 0 FOR f IN mo_app->mt_files WHERE ( expanded = abap_true ) NEXT n = n + 1 ).
    cl_abap_unit_assert=>assert_equals( act = lv_open exp = 25 ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 25 ).
    cl_abap_unit_assert=>assert_char_cp( act = mo_client->mv_toast exp = `5 files stay collapsed*` ).
    fire( `COLLAPSE_ALL` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 1 ]-lines ).
    cl_abap_unit_assert=>assert_false( mo_app->mt_files[ 1 ]-expanded ).
  ENDMETHOD.

  METHOD forged_index_ignored.
    app( files( 4 ) ).
    LOOP AT VALUE string_table( ( `0` ) ( `5` ) ( `-1` ) ( `x` ) ( `` ) ( `4 ` ) ( `99999999` ) ) INTO DATA(lv_arg).
      fire( iv_event = `PANEL` iv_arg1 = lv_arg iv_arg2 = `X` ).
      fire( iv_event = `OPEN` iv_arg1 = lv_arg ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 3 ).
    cl_abap_unit_assert=>assert_initial( mo_client->mo_called ).
  ENDMETHOD.

  METHOD failing_file_isolated.
    app( VALUE #( ( path = `/fail/` filename = `a.abap` lstate = `M` )
                  ( path = `/bin/`  filename = `b.png`  lstate = `M` )
                  ( path = `/src/`  filename = `c.abap` lstate = `M` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_files[ 1 ]-note exp = `Cannot read file` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->mt_files[ 2 ]-note exp = `Binary file - no line diff` ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mt_files[ 3 ]-lines ).
  ENDMETHOD.

  METHOD layout_switch_rebuilds.
    app( files( 4 ) ).
    mo_app->mv_layout = `SBS`.
    fire( `LAYOUT` ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 1 ]-lines ).
    cl_abap_unit_assert=>assert_not_initial( mo_app->mt_files[ 1 ]-sbs ).
  ENDMETHOD.

  METHOD layout_keeps_collapsed.
    app( files( 4 ) ).
    mo_app->mv_layout = `SBS`.
    fire( `LAYOUT` ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_service->mt_calls ) exp = 3 ).
    cl_abap_unit_assert=>assert_initial( mo_app->mt_files[ 4 ]-sbs ).
  ENDMETHOD.

  METHOD open_uses_server_row.
    app( files( 2 ) ).
    " the posted model is not trusted
    mo_app->mt_files[ 2 ]-file = `/evil/x.abap`.
    fire( iv_event = `OPEN` iv_arg1 = `2` ).
    DATA(lo_diff) = CAST zcl_ag2ui5_app_diff( mo_client->mo_called ).
    cl_abap_unit_assert=>assert_equals( act = lo_diff->ms_head-file exp = `/src/f2.abap` ).
  ENDMETHOD.

  METHOD summary_counts_loaded.
    app( files( 5 ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-summary exp = `5 files, +3 -0 (2 not loaded)` ).
    fire( `EXPAND_ALL` ).
    cl_abap_unit_assert=>assert_equals( act = mo_app->ms_head-summary exp = `5 files, +5 -0` ).
  ENDMETHOD.

  METHOD state_texts.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_app_repo_diff=>state_text( iv_lstate = `M` iv_rstate = `` )
                                        exp = `local modified` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_app_repo_diff=>state_text( iv_lstate = `` iv_rstate = `A` )
                                        exp = `remote added` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_app_repo_diff=>state_text( iv_lstate = `M` iv_rstate = `M` )
                                        exp = `both modified` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_app_repo_diff=>state_text( iv_lstate = `D` iv_rstate = `M` )
                                        exp = `local deleted, remote modified` ).
  ENDMETHOD.

  METHOD view_panels_from_template.
    app( files( 2 ) ).
    DATA(lv_view) = mo_client->mv_view.
    FIND REGEX `<customHeader>\s*<OverflowToolbar[^>]*>\s*<Button[^>]*sap-icon://nav-back` IN lv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_view ).
    FIND REGEX `<Panel[^>]*expanded="\{EXPANDED\}"` IN lv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_view ).
    FIND REGEX `<Table[^>]*items="\{LINES\}"` IN lv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_view ).
    cl_abap_unit_assert=>assert_char_np( act = lv_view exp = `*items="{SBS}"*` ).
    " without growing, UI5 renders only the model's first 100 rows of a long file
    FIND REGEX `<Table[^>]*items="\{LINES\}"[^>]*growing="true"` IN lv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_view ).
  ENDMETHOD.

  METHOD view_side_by_side.
    app( files( 2 ) ).
    mo_app->mv_layout = `SBS`.
    fire( `LAYOUT` ).
    FIND REGEX `<Table[^>]*items="\{SBS\}"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
    cl_abap_unit_assert=>assert_char_np( act = mo_client->mv_view exp = `*items="{LINES}"*` ).
    FIND REGEX `<Table[^>]*items="\{SBS\}"[^>]*growing="true"` IN mo_client->mv_view.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = mo_client->mv_view ).
  ENDMETHOD.

  METHOD back_leaves.
    app( files( 1 ) ).
    fire( `BACK` ).
    cl_abap_unit_assert=>assert_true( mo_client->mv_left ).
  ENDMETHOD.

ENDCLASS.
