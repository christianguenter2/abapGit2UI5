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

    CASE iv_key.
      WHEN zif_ag2ui5_settings=>c_key-repos_layout.
        rt_values = VALUE #( ( `LIST` ) ( `TILES` ) ).
      WHEN zif_ag2ui5_settings=>c_key-status_overview.
        rt_values = VALUE #( ( `FILES` ) ( `OBJECTS` ) ).
      WHEN zif_ag2ui5_settings=>c_key-status_view.
        rt_values = VALUE #( ( `ALL` ) ( `CHANGES` ) ).
      WHEN zif_ag2ui5_settings=>c_key-status_sort.
        rt_values = VALUE #( ( `OBJECT` ) ( `FILE` ) ( `TYPE` ) ).
      WHEN zif_ag2ui5_settings=>c_key-diff_layout.
        rt_values = VALUE #( ( `INLINE` ) ( `SBS` ) ).
      WHEN zif_ag2ui5_settings=>c_key-repos_favorites_only
        OR zif_ag2ui5_settings=>c_key-status_changes_first
        OR zif_ag2ui5_settings=>c_key-diff_show_all.
        rt_values = VALUE #( ( `X` ) ( `` ) ).
    ENDCASE.

  ENDMETHOD.

  METHOD zif_ag2ui5_settings~get.

    DATA lv_found TYPE abap_bool.
    DATA lv_value TYPE string.

    rv_value = iv_default.
    DATA(lt_allowed) = allowed_values( iv_key ).
    IF lt_allowed IS INITIAL.
      RETURN.
    ENDIF.

    mi_store->read( EXPORTING iv_user  = sy-uname
                              iv_key   = iv_key
                    IMPORTING ev_found = lv_found
                              ev_value = lv_value ).
    " a value no longer allowed falls back to the default
    IF lv_found = abap_true AND line_exists( lt_allowed[ table_line = lv_value ] ).
      rv_value = lv_value.
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_settings~set.

    " key and value come from the browser
    DATA(lt_allowed) = allowed_values( iv_key ).
    IF NOT line_exists( lt_allowed[ table_line = iv_value ] ).
      rv_saved = abap_false.
      RETURN.
    ENDIF.

    mi_store->write( iv_user  = sy-uname
                     iv_key   = iv_key
                     iv_value = iv_value ).
    rv_saved = abap_true.

  ENDMETHOD.

ENDCLASS.
