"! Line diff of one file: the system's version against Git's
CLASS zcl_ag2ui5_app_diff DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_head,
        title     TYPE string,
        file      TYPE string,
        counts    TYPE string,
        direction TYPE string,
        "! Side-by-side column titles: which side is old and which new
        old_label TYPE string,
        new_label TYPE string,
      END OF ty_head.

    TYPES:
      BEGIN OF ty_row,
        remote_num TYPE string,
        local_num  TYPE string,
        marker     TYPE string,
        "! The line for sap.m.FormattedText: escaped, monospace
        code_html  TYPE string,
        "! sap.ui.core.MessageType of the row: Success new, Error old
        highlight  TYPE string,
        patch_id   TYPE string,
        "! Patch mode, and a changed line: it has a checkbox
        pickable   TYPE abap_bool,
        picked     TYPE abap_bool,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_sbs_row,
        old_num        TYPE string,
        old_html       TYPE string,
        "! ObjectStatus marker per side: - (Error) old, + (Success) new
        old_marker     TYPE string,
        new_num        TYPE string,
        new_html       TYPE string,
        new_marker     TYPE string,
        highlight      TYPE string,
      END OF ty_sbs_row,
      ty_sbs_rows TYPE STANDARD TABLE OF ty_sbs_row WITH EMPTY KEY.

    TYPES:
      "! The picked lines, handed back to the staging page by Apply
      BEGIN OF ty_patch,
        "! Set by Apply; Back leaves it initial
        applied     TYPE abap_bool,
        path        TYPE string,
        filename    TYPE string,
        ids         TYPE string_table,
        "! Distinct patch IDs in the file: "3 of 7 lines"
        total       TYPE i,
        fingerprint TYPE string,
      END OF ty_patch.

    DATA ms_head        TYPE ty_head.
    "! Only the visible rows travel to the browser
    DATA mt_rows        TYPE ty_rows.
    DATA mt_sbs         TYPE ty_sbs_rows.
    DATA mv_toggle_text TYPE string.
    "! INLINE or SBS
    DATA mv_layout      TYPE string VALUE `INLINE`.
    "! Patch mode: a checkbox per changed line, Apply instead of the layout switch
    DATA mv_patch       TYPE abap_bool.
    "! "3 of 7 lines picked"
    DATA mv_pick_text   TYPE string.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
        iv_path       TYPE string
        iv_filename   TYPE string
        iv_obj_type   TYPE string
        iv_obj_name   TYPE string
        iv_remote_is_new TYPE abap_bool DEFAULT abap_false
        iv_patch      TYPE abap_bool DEFAULT abap_false
        it_picked     TYPE string_table OPTIONAL
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_diff.

    "! What Apply handed back; applied is initial after Back
    METHODS get_patch
      RETURNING
        VALUE(rs_patch) TYPE ty_patch.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mv_key TYPE string.
    DATA mv_path TYPE string.
    DATA mv_filename TYPE string.
    DATA mv_show_all TYPE abap_bool.
    DATA mv_binary TYPE abap_bool.
    DATA mv_remote_is_new TYPE abap_bool.
    "! Every line of the diff - serialized with the app, never sent to the browser
    DATA mt_all TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    METHODS view_display.
    METHODS inline_display
      IMPORTING
        io_content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS side_by_side_display
      IMPORTING
        io_content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS on_event.
    METHODS load_diff.
    METHODS rows_build.

    "! The picked patch IDs; the source of truth, rows only show it
    DATA mt_picked TYPE string_table.
    DATA mv_fingerprint TYPE string.
    DATA ms_patch TYPE ty_patch.
    METHODS pick
      IMPORTING
        iv_id     TYPE string
        iv_picked TYPE abap_bool.
    METHODS pick_all
      IMPORTING
        iv_picked TYPE abap_bool.
    "! Distinct patch IDs of the diff, in file order
    METHODS patch_ids
      RETURNING
        VALUE(rt_ids) TYPE string_table.
    "! The picked IDs that are in the diff, in file order
    METHODS picked_in_order
      RETURNING
        VALUE(rt_ids) TYPE string_table.

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
    ro_app->mv_remote_is_new = iv_remote_is_new.
    ro_app->ms_head-old_label = COND #( WHEN iv_remote_is_new = abap_true THEN `System (old)` ELSE `Git (old)` ).
    ro_app->ms_head-new_label = COND #( WHEN iv_remote_is_new = abap_true THEN `Git (new)` ELSE `System (new)` ).
    ro_app->ms_head-direction = COND #( WHEN iv_remote_is_new = abap_true
                                        THEN `Changes in Git, compared with this system`
                                        ELSE `Changes in this system, compared with Git` ).

  ENDMETHOD.

  METHOD get_patch.
  ENDMETHOD.

  METHOD pick.
  ENDMETHOD.

  METHOD pick_all.
  ENDMETHOD.

  METHOD patch_ids.
  ENDMETHOD.

  METHOD picked_in_order.
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

    DATA(header_content) = page->ele( `headerContent` ).
    header_content->ele( `SegmentedButton`
        )->a( n = `selectedKey`     v = client->_bind( mv_layout )
        )->a( n = `selectionChange` v = client->_event( `LAYOUT` )
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `INLINE`
                )->a( n = `text` v = `Inline`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `SBS`
                )->a( n = `text` v = `Side by side` ).
    header_content->tag( `Button`
        )->a( n = `text`  v = client->_bind( mv_toggle_text )
        )->a( n = `press` v = client->_event( `TOGGLE` ) ).

    DATA(content) = page->ele( `content` ).

    content->ele( `ObjectHeader`
        )->a( n = `title` v = client->_bind( ms_head-file )
        )->ele( `attributes`
            )->tag( `ObjectAttribute`
                )->a( n = `title` v = `Lines`
                )->a( n = `text`  v = client->_bind( ms_head-counts )
            )->tag( `ObjectAttribute`
                )->a( n = `title` v = `Direction`
                )->a( n = `text`  v = client->_bind( ms_head-direction ) ).

    content->tag( `MessageStrip`
        )->a( n = `text`     v = `Local: the version in this system. Remote: the version in Git. Green (+) is the side that changed.`
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

    IF mv_layout = `SBS`.
      side_by_side_display( content ).
    ELSE.
      inline_display( content ).
    ENDIF.

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD inline_display.

    DATA(table) = io_content->ele( `Table`
        )->a( n = `items`               v = client->_bind( mt_rows )
        )->a( n = `noDataText`          v = `Empty file`
        )->a( n = `growing`             v = `true`
        )->a( n = `growingThreshold`    v = `500`
        )->a( n = `growingScrollToLoad` v = `true`
        )->a( n = `class`               v = `sapUiSmallMarginTop` ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `5rem`
        )->tag( `Text`
            )->a( n = `text` v = `Remote` ).
    columns->ele( `Column`
        )->a( n = `width` v = `5rem`
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
    cells->tag( `FormattedText`
        )->a( n = `htmlText` v = `{CODE_HTML}` ).

  ENDMETHOD.

  METHOD side_by_side_display.

    DATA(table) = io_content->ele( `Table`
        )->a( n = `items`               v = client->_bind( mt_sbs )
        )->a( n = `noDataText`          v = `Empty file`
        )->a( n = `growing`             v = `true`
        )->a( n = `growingThreshold`    v = `500`
        )->a( n = `growingScrollToLoad` v = `true`
        )->a( n = `class`               v = `sapUiSmallMarginTop` ).

    " on narrow screens the new side pops in below the old one
    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `4rem`
        )->tag( `Text`
            )->a( n = `text` v = client->_bind( ms_head-old_label ) ).
    columns->ele( `Column`
        )->a( n = `width` v = `2rem` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Code` ).
    columns->ele( `Column`
        )->a( n = `width`          v = `4rem`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = client->_bind( ms_head-new_label ) ).
    columns->ele( `Column`
        )->a( n = `width`          v = `2rem`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Code` ).

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `highlight` v = `{HIGHLIGHT}`
            )->ele( `cells` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OLD_NUM}` ).
    cells->tag( `ObjectStatus`
        )->a( n = `text`  v = `{OLD_MARKER}`
        )->a( n = `state` v = `Error` ).
    cells->tag( `FormattedText`
        )->a( n = `htmlText` v = `{OLD_HTML}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{NEW_NUM}` ).
    cells->tag( `ObjectStatus`
        )->a( n = `text`  v = `{NEW_MARKER}`
        )->a( n = `state` v = `Success` ).
    cells->tag( `FormattedText`
        )->a( n = `htmlText` v = `{NEW_HTML}` ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `TOGGLE`.
        mv_show_all = xsdbool( mv_show_all = abap_false ).
        rows_build( ).
      WHEN `LAYOUT`.
        " the layout changes the view's structure, not only its data
        view_display( ).
    ENDCASE.

  ENDMETHOD.

  METHOD load_diff.

    TRY.
        DATA(ls_diff) = NEW zcl_ag2ui5_repo_service( )->zif_ag2ui5_repo_service~get_diff(
          iv_key      = mv_key
          iv_path     = mv_path
          iv_filename = mv_filename
          iv_remote_is_new = mv_remote_is_new ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    mt_all    = ls_diff-lines.
    mv_binary = ls_diff-binary.
    ms_head-counts = zcl_ag2ui5_repo_service=>counts_text( iv_local         = ls_diff-local_count
                                                          iv_remote        = ls_diff-remote_count
                                                          iv_remote_is_new = mv_remote_is_new ).
    rows_build( ).

  ENDMETHOD.

  METHOD rows_build.

    DATA(lt_lines) = COND #( WHEN mv_show_all = abap_true
                             THEN mt_all
                             ELSE zcl_ag2ui5_repo_service=>compact( mt_all ) ).
    mv_toggle_text = COND #( WHEN mv_show_all = abap_true THEN `Changes only` ELSE `Show all` ).

    " green and + for the side that changed, red and - for the other
    DATA(lv_new_kind) = COND zif_ag2ui5_repo_service=>ty_line_kind(
      WHEN mv_remote_is_new = abap_true THEN zif_ag2ui5_repo_service=>c_line_kind-remote
      ELSE zif_ag2ui5_repo_service=>c_line_kind-local ).

    CLEAR mt_rows.
    LOOP AT lt_lines INTO DATA(ls_line).
      INSERT VALUE #( remote_num = ls_line-remote_num
                      local_num  = ls_line-local_num
                      code_html  = zcl_ag2ui5_repo_service=>code_html( ls_line-text )
                      marker     = COND #( WHEN ls_line-kind = lv_new_kind THEN `+`
                                           WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-local
                                             OR ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-remote THEN `-` )
                      highlight  = COND #( WHEN ls_line-kind = lv_new_kind THEN `Success`
                                           WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-local
                                             OR ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-remote THEN `Error`
                                           WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-gap THEN `Information`
                                           ELSE `None` ) )
        INTO TABLE mt_rows.
    ENDLOOP.

    CLEAR mt_sbs.
    LOOP AT zcl_ag2ui5_repo_service=>to_side_by_side( it_lines         = lt_lines
                                                      iv_remote_is_new = mv_remote_is_new ) INTO DATA(ls_sbs).
      INSERT VALUE #( old_num    = ls_sbs-old_num
                      old_html   = COND #( WHEN ls_sbs-gap = abap_true
                                           THEN |<em>{ escape( val = ls_sbs-old_text format = cl_abap_format=>e_xml_text ) }</em>|
                                           ELSE zcl_ag2ui5_repo_service=>code_html( ls_sbs-old_text ) )
                      old_marker = COND #( WHEN ls_sbs-old_changed = abap_true THEN `-` )
                      new_num    = ls_sbs-new_num
                      new_html   = COND #( WHEN ls_sbs-gap = abap_false THEN zcl_ag2ui5_repo_service=>code_html( ls_sbs-new_text ) )
                      new_marker = COND #( WHEN ls_sbs-new_changed = abap_true THEN `+` )
                      highlight  = COND #( WHEN ls_sbs-gap = abap_true THEN `Information`
                                           WHEN ls_sbs-old_changed = abap_true AND ls_sbs-new_changed = abap_true THEN `Warning`
                                           WHEN ls_sbs-new_changed = abap_true THEN `Success`
                                           WHEN ls_sbs-old_changed = abap_true THEN `Error`
                                           ELSE `None` ) )
        INTO TABLE mt_sbs.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
