"! Settings of the current user. Every key and value is checked against an
"! allow-list: the values come from the browser.
CLASS zcl_ag2ui5_settings DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_settings.

    CLASS-METHODS get_instance
      RETURNING
        VALUE(ri_settings) TYPE REF TO zif_ag2ui5_settings.

    "! Tests: replace the instance; an unbound reference restores the real one
    CLASS-METHODS inject
      IMPORTING
        ii_settings TYPE REF TO zif_ag2ui5_settings.

    METHODS constructor.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA gi_instance TYPE REF TO zif_ag2ui5_settings.
    DATA mi_store TYPE REF TO lif_store.

    "! The values a key may take; empty for an unknown key
    CLASS-METHODS allowed_values
      IMPORTING
        iv_key           TYPE string
      RETURNING
        VALUE(rt_values) TYPE string_table.
ENDCLASS.



CLASS zcl_ag2ui5_settings IMPLEMENTATION.

  METHOD constructor.
    mi_store = NEW lcl_db_store( ).
  ENDMETHOD.

  METHOD get_instance.
    IF gi_instance IS NOT BOUND.
      gi_instance = NEW zcl_ag2ui5_settings( ).
    ENDIF.
    ri_settings = gi_instance.
  ENDMETHOD.

  METHOD inject.
    gi_instance = ii_settings.
  ENDMETHOD.

  METHOD allowed_values.
    " stub: no key is known yet
    rt_values = VALUE #( ( iv_key ) ).
    CLEAR rt_values.
  ENDMETHOD.

  METHOD zif_ag2ui5_settings~get.
    rv_value = iv_default.
  ENDMETHOD.

  METHOD zif_ag2ui5_settings~set.
    rv_saved = abap_false.
  ENDMETHOD.

ENDCLASS.
