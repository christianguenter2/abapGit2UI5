"! Line diff of one file: the system's version against Git's
CLASS zcl_ag2ui5_app_diff DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_head,
        title  TYPE string,
        file   TYPE string,
        counts TYPE string,
      END OF ty_head.

    TYPES:
      BEGIN OF ty_row,
        remote_num TYPE string,
        local_num  TYPE string,
        marker     TYPE string,
        text       TYPE string,
        "! sap.ui.core.MessageType of the row: Success local, Error remote
        highlight  TYPE string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA ms_head        TYPE ty_head.
    "! Only the visible rows travel to the browser
    DATA mt_rows        TYPE ty_rows.
    DATA mv_toggle_text TYPE string.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
        iv_path       TYPE string
        iv_filename   TYPE string
        iv_obj_type   TYPE string
        iv_obj_name   TYPE string
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_diff.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mv_key TYPE string.
    DATA mv_path TYPE string.
    DATA mv_filename TYPE string.
    DATA mv_show_all TYPE abap_bool.
    DATA mv_binary TYPE abap_bool.
    "! Every line of the diff - serialized with the app, never sent to the browser
    DATA mt_all TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    METHODS view_display.
    METHODS on_event.
    METHODS load_diff.
    METHODS rows_build.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_diff IMPLEMENTATION.

  METHOD create.

    ro_app = NEW #( ).
    ro_app->mv_key       = iv_key.
    ro_app->mv_path      = iv_path.
    ro_app->mv_filename  = iv_filename.
    ro_app->ms_head-title = |{ iv_obj_type } { iv_obj_name }|.
    ro_app->ms_head-file  = |{ iv_path }{ iv_filename }|.

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      load_diff( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page`
        )->a( n = `title`          v = client->_bind( ms_head-title )
        )->a( n = `showNavButton`  v = `true`
        )->a( n = `navButtonPress` v = client->_event( `BACK` ) ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `text`  v = client->_bind( mv_toggle_text )
            )->a( n = `press` v = client->_event( `TOGGLE` ) ).

    DATA(content) = page->ele( `content` ).

    content->ele( `ObjectHeader`
        )->a( n = `title` v = client->_bind( ms_head-file )
        )->ele( `attributes`
            )->tag( `ObjectAttribute`
                )->a( n = `title` v = `Lines`
                )->a( n = `text`  v = client->_bind( ms_head-counts ) ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = `Local: the version in this system. Remote: the version in Git.`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMarginBeginEnd` ).

    IF mv_binary = abap_true.
      content->tag( `MessageStrip`
          )->a( n = `text`     v = `Binary file - no line diff`
          )->a( n = `type`     v = `Warning`
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiSmallMargin` ).
      client->view_display( view->stringify( ) ).
      RETURN.
    ENDIF.

    DATA(table) = content->ele( `Table`
        )->a( n = `items`      v = client->_bind( mt_rows )
        )->a( n = `noDataText` v = `Empty file`
        )->a( n = `class`      v = `sapUiSmallMarginTop` ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `4rem`
        )->tag( `Text`
            )->a( n = `text` v = `Remote` ).
    columns->ele( `Column`
        )->a( n = `width` v = `4rem`
        )->tag( `Text`
            )->a( n = `text` v = `Local` ).
    columns->ele( `Column`
        )->a( n = `width` v = `2rem` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Code` ).

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `highlight` v = `{HIGHLIGHT}`
            )->ele( `cells` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{REMOTE_NUM}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{LOCAL_NUM}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{MARKER}` ).
    cells->tag( `Text`
        )->a( n = `text`             v = `{TEXT}`
        )->a( n = `renderWhitespace` v = `true`
        )->a( n = `wrapping`         v = `false` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `TOGGLE`.
        mv_show_all = xsdbool( mv_show_all = abap_false ).
        rows_build( ).
    ENDCASE.

  ENDMETHOD.

  METHOD load_diff.

    TRY.
        DATA(ls_diff) = NEW zcl_ag2ui5_repo_service( )->zif_ag2ui5_repo_service~get_diff(
          iv_key      = mv_key
          iv_path     = mv_path
          iv_filename = mv_filename ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    mt_all    = ls_diff-lines.
    mv_binary = ls_diff-binary.
    ms_head-counts = |+{ ls_diff-local_count } local, -{ ls_diff-remote_count } remote|.
    rows_build( ).

  ENDMETHOD.

  METHOD rows_build.

    DATA(lt_lines) = COND #( WHEN mv_show_all = abap_true
                             THEN mt_all
                             ELSE zcl_ag2ui5_repo_service=>compact( mt_all ) ).
    mv_toggle_text = COND #( WHEN mv_show_all = abap_true THEN `Changes only` ELSE `Show all` ).

    CLEAR mt_rows.
    LOOP AT lt_lines INTO DATA(ls_line).
      INSERT VALUE #( remote_num = ls_line-remote_num
                      local_num  = ls_line-local_num
                      text       = ls_line-text
                      marker     = SWITCH #( ls_line-kind
                                             WHEN zif_ag2ui5_repo_service=>c_line_kind-local  THEN `+`
                                             WHEN zif_ag2ui5_repo_service=>c_line_kind-remote THEN `-` )
                      highlight  = SWITCH #( ls_line-kind
                                             WHEN zif_ag2ui5_repo_service=>c_line_kind-local  THEN `Success`
                                             WHEN zif_ag2ui5_repo_service=>c_line_kind-remote THEN `Error`
                                             WHEN zif_ag2ui5_repo_service=>c_line_kind-gap    THEN `Information`
                                             ELSE `None` ) )
        INTO TABLE mt_rows.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
