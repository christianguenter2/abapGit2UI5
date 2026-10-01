CLASS ltcl_patch DEFINITION DEFERRED.
CLASS zcl_ag2ui5_app_diff DEFINITION LOCAL FRIENDS ltcl_patch.

"! abap2UI5 client for one event with its arguments
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_event TYPE string.
    DATA mt_args TYPE string_table.
    DATA mv_left TYPE abap_bool.
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

  METHOD z2ui5_if_client~get_event_arg.
    result = VALUE #( mt_args[ v ] OPTIONAL ).
  ENDMETHOD.

  METHOD z2ui5_if_client~nav_app_leave.
    mv_left = abap_true.
  ENDMETHOD.

  METHOD z2ui5_if_client~view_display ##NEEDED.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_box_display ##NEEDED.
  ENDMETHOD.

  METHOD z2ui5_if_client~message_toast_display ##NEEDED.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_patch DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_app TYPE REF TO zcl_ag2ui5_app_diff.
    DATA mo_client TYPE REF TO ltd_client.

    METHODS setup.
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

  METHOD setup.
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
