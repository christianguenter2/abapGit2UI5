"! In-memory store: what was written, and for which user
CLASS ltd_memory_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES lif_store.
    TYPES:
      BEGIN OF ty_row,
        user  TYPE syuname,
        key   TYPE string,
        value TYPE string,
      END OF ty_row.
    DATA mt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_memory_store IMPLEMENTATION.

  METHOD lif_store~read.
    CLEAR: ev_found, ev_value.
    READ TABLE mt_rows INTO DATA(ls_row) WITH KEY user = iv_user key = iv_key.
    IF sy-subrc = 0.
      ev_found = abap_true.
      ev_value = ls_row-value.
    ENDIF.
  ENDMETHOD.

  METHOD lif_store~write.
    DELETE mt_rows WHERE user = iv_user AND key = iv_key.
    INSERT VALUE #( user = iv_user key = iv_key value = iv_value ) INTO TABLE mt_rows.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_ag2ui5_settings.
    DATA mo_store TYPE REF TO ltd_memory_store.
    DATA mi_cut TYPE REF TO zif_ag2ui5_settings.

    METHODS setup.
    METHODS no_row_gives_default FOR TESTING.
    METHODS set_then_get FOR TESTING.
    METHODS blank_boolean_is_stored FOR TESTING.
    METHODS set_refuses_value FOR TESTING.
    METHODS set_refuses_unknown_key FOR TESTING.
    METHODS set_refuses_long_value FOR TESTING.
    METHODS get_ignores_stale_value FOR TESTING.
    METHODS row_carries_current_user FOR TESTING.
    METHODS every_key_has_values FOR TESTING.
    METHODS overview_allow_list FOR TESTING.
ENDCLASS.

CLASS zcl_ag2ui5_settings DEFINITION LOCAL FRIENDS ltcl_settings.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    mo_store = NEW #( ).
    mo_cut->mi_store = mo_store.
    mi_cut = mo_cut.
  ENDMETHOD.

  METHOD no_row_gives_default.
    cl_abap_unit_assert=>assert_equals(
      exp = `LIST`
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_default = `LIST` ) ).
  ENDMETHOD.

  METHOD set_then_get.
    cl_abap_unit_assert=>assert_true(
      mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_value = `TILES` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `TILES`
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_default = `LIST` ) ).
  ENDMETHOD.

  METHOD blank_boolean_is_stored.
    " a stored blank is "off", not "nothing stored"
    cl_abap_unit_assert=>assert_true(
      mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-status_changes_first iv_value = `` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = ``
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-status_changes_first iv_default = `X` ) ).
  ENDMETHOD.

  METHOD set_refuses_value.
    cl_abap_unit_assert=>assert_false(
      mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_value = `TILES2` ) ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_rows ).
  ENDMETHOD.

  METHOD set_refuses_unknown_key.
    cl_abap_unit_assert=>assert_false( mi_cut->set( iv_key = `NO_SUCH_KEY` iv_value = `X` ) ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_rows ).
  ENDMETHOD.

  METHOD set_refuses_long_value.
    cl_abap_unit_assert=>assert_false(
      mi_cut->set( iv_key   = zif_ag2ui5_settings=>c_key-status_sort
                   iv_value = repeat( val = `A` occ = 50 ) ) ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_rows ).
  ENDMETHOD.

  METHOD get_ignores_stale_value.
    " an option removed later, or a row edited by hand
    INSERT VALUE #( user = sy-uname key = zif_ag2ui5_settings=>c_key-diff_layout value = `GONE` )
      INTO TABLE mo_store->mt_rows.
    cl_abap_unit_assert=>assert_equals(
      exp = `INLINE`
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-diff_layout iv_default = `INLINE` ) ).
  ENDMETHOD.

  METHOD row_carries_current_user.
    mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-status_view iv_value = `CHANGES` ).
    READ TABLE mo_store->mt_rows INTO DATA(ls_row) INDEX 1.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = sy-uname act = ls_row-user ).
  ENDMETHOD.

  METHOD every_key_has_values.
    " a key added to the interface but not to the allow-list could never be saved
    DATA(lt_keys) = VALUE string_table(
      ( zif_ag2ui5_settings=>c_key-repos_layout )
      ( zif_ag2ui5_settings=>c_key-status_view )
      ( zif_ag2ui5_settings=>c_key-status_overview )
      ( zif_ag2ui5_settings=>c_key-status_sort )
      ( zif_ag2ui5_settings=>c_key-status_changes_first )
      ( zif_ag2ui5_settings=>c_key-diff_layout )
      ( zif_ag2ui5_settings=>c_key-diff_show_all ) ).
    LOOP AT lt_keys INTO DATA(lv_key).
      cl_abap_unit_assert=>assert_not_initial( act = zcl_ag2ui5_settings=>allowed_values( lv_key )
                                               msg = lv_key ).
    ENDLOOP.
  ENDMETHOD.

  METHOD overview_allow_list.
    cl_abap_unit_assert=>assert_true( mi_cut->set(
      iv_key = zif_ag2ui5_settings=>c_key-status_overview iv_value = `OBJECTS` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `OBJECTS` act = mi_cut->get(
      iv_key = zif_ag2ui5_settings=>c_key-status_overview iv_default = `FILES` ) ).
    cl_abap_unit_assert=>assert_false( mi_cut->set(
      iv_key = zif_ag2ui5_settings=>c_key-status_overview iv_value = `OBJECT` ) ).
    cl_abap_unit_assert=>assert_true( mi_cut->set(
      iv_key = zif_ag2ui5_settings=>c_key-status_overview iv_value = `FILES` ) ).
  ENDMETHOD.

ENDCLASS.
