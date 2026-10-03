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


"! abap2UI5 client: either the start (navigated) or one event
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_start TYPE abap_bool.
    DATA mv_event TYPE string.
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
  METHOD z2ui5_if_client~view_display ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~follow_up_action ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_box_display ##NEEDED.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_settings TYPE REF TO ltd_settings.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_cut TYPE REF TO zcl_ag2ui5_app_repos.

    METHODS setup.
    METHODS teardown.
    METHODS start_reads_layout FOR TESTING.
    METHODS layout_event_saves FOR TESTING.
ENDCLASS.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_settings = NEW #( ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
    mo_client = NEW #( ).
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD start_reads_layout.
    " the start also lists the repositories of the system; that only reads
    mo_settings->mt_preset = VALUE #( ( key = zif_ag2ui5_settings=>c_key-repos_layout value = `TILES` ) ).
    mo_client->mv_start = abap_true.
    mo_cut->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `TILES` act = mo_cut->mv_layout ).
  ENDMETHOD.

  METHOD layout_event_saves.
    mo_cut->mv_layout = `TILES`.
    mo_client->mv_event = `LAYOUT`.
    mo_cut->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals(
      exp = `TILES`
      act = mo_settings->saved( zif_ag2ui5_settings=>c_key-repos_layout ) ).
  ENDMETHOD.

ENDCLASS.
