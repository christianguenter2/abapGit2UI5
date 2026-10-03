CLASS lcl_db_store DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_store.
ENDCLASS.

CLASS lcl_db_store IMPLEMENTATION.

  METHOD lif_store~read.

    CLEAR: ev_found, ev_value.
    SELECT SINGLE value FROM zag2ui5_setting
      WHERE uname = @iv_user AND setting = @iv_key
      INTO @DATA(lv_value).
    IF sy-subrc = 0.
      ev_found = abap_true.
      ev_value = lv_value.
    ENDIF.

  ENDMETHOD.

  METHOD lif_store~write.

    DATA(ls_row) = VALUE zag2ui5_setting( uname   = iv_user
                                          setting = iv_key
                                          value   = iv_value ).
    MODIFY zag2ui5_setting FROM @ls_row.
    IF sy-subrc = 0.
      " abap2UI5 rolls back after main( )
      COMMIT WORK.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
