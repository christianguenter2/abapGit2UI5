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
        "! Side-by-side column titles, system left and Git right as in abapGit:
        "! which side is old and which new
        system_label TYPE string,
        git_label    TYPE string,
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
        system_num    TYPE string,
        system_html   TYPE string,
        "! ObjectStatus marker per side: - (Error) old, + (Success) new
        system_marker TYPE string,
        system_state  TYPE string,
        git_num       TYPE string,
        git_html      TYPE string,
        git_marker    TYPE string,
        git_state     TYPE string,
        highlight     TYPE string,
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

    "! Patch mode: a checkbox per changed line, Apply instead of the layout switch
    DATA mv_patch TYPE abap_bool.
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
    " a patch is made on local changes: the system is always the new side
    ro_app->mv_remote_is_new = xsdbool( iv_remote_is_new = abap_true AND iv_patch = abap_false ).
    ro_app->mv_patch  = iv_patch.
    ro_app->mt_picked = it_picked.
    DATA(li_settings) = zcl_ag2ui5_settings=>get_instance( ).
    ro_app->mv_show_all = xsdbool( li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-diff_show_all
                                                     iv_default = `` ) = abap_true ).
    " a patch is picked inline
    IF iv_patch = abap_false.
      ro_app->mv_layout = li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-diff_layout
                                            iv_default = `INLINE` ).
    ENDIF.
    IF iv_patch = abap_true.
      ro_app->ms_head-title = |Pick lines - { ro_app->ms_head-title }|.
    ENDIF.
    ro_app->ms_head-system_label = COND #( WHEN ro_app->mv_remote_is_new = abap_true THEN `System (old)` ELSE `System (new)` ).
    ro_app->ms_head-git_label    = COND #( WHEN ro_app->mv_remote_is_new = abap_true THEN `Git (new)` ELSE `Git (old)` ).
    ro_app->ms_head-direction = COND #( WHEN ro_app->mv_remote_is_new = abap_true
                                        THEN `Changes in Git, compared with this system`
                                        ELSE `Changes in this system, compared with Git` ).

  ENDMETHOD.

  METHOD get_patch.

    rs_patch = ms_patch.

  ENDMETHOD.

  METHOD pick.

    " the ID arrives from the browser: only IDs of this diff count
    DATA(lt_ids) = patch_ids( ).
    IF NOT line_exists( lt_ids[ table_line = iv_id ] ).
      RETURN.
    ENDIF.
    DELETE mt_picked WHERE table_line = iv_id.
    IF iv_picked = abap_true.
      INSERT iv_id INTO TABLE mt_picked.
    ENDIF.
    rows_build( ).

  ENDMETHOD.

  METHOD pick_all.

    mt_picked = COND #( WHEN iv_picked = abap_true THEN patch_ids( ) ).
    rows_build( ).

  ENDMETHOD.

  METHOD patch_ids.

    " distinct, in file order: both halves of a changed line count once
    LOOP AT mt_all INTO DATA(ls_line) WHERE patch_id IS NOT INITIAL.
      IF NOT line_exists( rt_ids[ table_line = ls_line-patch_id ] ).
        INSERT ls_line-patch_id INTO TABLE rt_ids.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD picked_in_order.

    LOOP AT patch_ids( ) INTO DATA(lv_id).
      IF line_exists( mt_picked[ table_line = lv_id ] ).
        INSERT lv_id INTO TABLE rt_ids.
      ENDIF.
    ENDLOOP.

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
    IF mv_patch = abap_true.
      header_content->tag( `Text`
          )->a( n = `text` v = client->_bind( mv_pick_text ) ).
      header_content->tag( `Button`
          )->a( n = `text`  v = `All lines`
          )->a( n = `press` v = client->_event( `PICK_ALL` ) ).
      header_content->tag( `Button`
          )->a( n = `text`  v = `No lines`
          )->a( n = `press` v = client->_event( `PICK_NONE` ) ).
      header_content->tag( `Button`
          )->a( n = `text`  v = client->_bind( mv_toggle_text )
          )->a( n = `press` v = client->_event( `TOGGLE` ) ).
      IF mv_binary = abap_false AND mv_fingerprint IS NOT INITIAL.
        header_content->tag( `Button`
            )->a( n = `text`  v = `Apply`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `icon`  v = `sap-icon://accept`
            )->a( n = `press` v = client->_event( `APPLY` ) ).
      ENDIF.
    ELSE.
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
    ENDIF.

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
    IF mv_patch = abap_true.
      content->tag( `MessageStrip`
          )->a( n = `text`     v = `Pick the changes to commit. The two halves of a changed line go together.`
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiSmallMarginBeginEnd sapUiTinyMarginTop` ).
    ENDIF.

    IF mv_binary = abap_true.
      content->tag( `MessageStrip`
          )->a( n = `text`     v = `Binary file - no line diff`
          )->a( n = `type`     v = `Warning`
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiSmallMargin` ).
      client->view_display( view->stringify( ) ).
      RETURN.
    ENDIF.

    IF mv_layout = `SBS` AND mv_patch = abap_false.
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
    IF mv_patch = abap_true.
      columns->ele( `Column`
          )->a( n = `width` v = `4rem`
          )->tag( `Text`
              )->a( n = `text` v = `Commit` ).
    ENDIF.
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
    IF mv_patch = abap_true.
      " the new state comes from the event itself, not from the model
      cells->tag( `CheckBox`
          )->a( n = `selected` v = `{PICKED}`
          )->a( n = `visible`  v = `{PICKABLE}`
          )->a( n = `select`   v = client->_event( val   = `PICK`
                                                   t_arg = VALUE #( ( `${PATCH_ID}` ) ( `${$parameters>/selected}` ) ) ) ).
    ENDIF.
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

    " on narrow screens Git pops in below the system
    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `4rem`
        )->tag( `Text`
            )->a( n = `text` v = client->_bind( ms_head-system_label ) ).
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
            )->a( n = `text` v = client->_bind( ms_head-git_label ) ).
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
        )->a( n = `text` v = `{SYSTEM_NUM}` ).
    cells->tag( `ObjectStatus`
        )->a( n = `text`  v = `{SYSTEM_MARKER}`
        )->a( n = `state` v = `{SYSTEM_STATE}` ).
    cells->tag( `FormattedText`
        )->a( n = `htmlText` v = `{SYSTEM_HTML}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{GIT_NUM}` ).
    cells->tag( `ObjectStatus`
        )->a( n = `text`  v = `{GIT_MARKER}`
        )->a( n = `state` v = `{GIT_STATE}` ).
    cells->tag( `FormattedText`
        )->a( n = `htmlText` v = `{GIT_HTML}` ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `TOGGLE`.
        mv_show_all = xsdbool( mv_show_all = abap_false ).
        zcl_ag2ui5_settings=>get_instance( )->set( iv_key   = zif_ag2ui5_settings=>c_key-diff_show_all
                                                   iv_value = CONV #( mv_show_all ) ).
        rows_build( ).
      WHEN `PICK`.
        pick( iv_id     = client->get_event_arg( )
              " abap2UI5 hands booleans over as abap_bool
              iv_picked = xsdbool( client->get_event_arg( 2 ) = abap_true ) ).
      WHEN `PICK_ALL`.
        pick_all( abap_true ).
      WHEN `PICK_NONE`.
        pick_all( abap_false ).
      WHEN `APPLY`.
        " the diff did not load: there is nothing to hand back
        IF mv_fingerprint IS INITIAL.
          RETURN.
        ENDIF.
        " in file order, so the result does not depend on the click order
        ms_patch = VALUE #( applied     = abap_true
                            path        = mv_path
                            filename    = mv_filename
                            ids         = picked_in_order( )
                            total       = lines( patch_ids( ) )
                            fingerprint = mv_fingerprint ).
        client->nav_app_leave( ).
      WHEN `LAYOUT`.
        zcl_ag2ui5_settings=>get_instance( )->set( iv_key   = zif_ag2ui5_settings=>c_key-diff_layout
                                                   iv_value = mv_layout ).
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
    mv_fingerprint = ls_diff-fingerprint.
    " earlier picks that are no longer a change of this diff are dropped
    mt_picked = picked_in_order( ).
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
      " the background follows the marker: green +, red -, grey for a gap
      DATA(lv_tint) = COND string( WHEN ls_line-kind = lv_new_kind THEN `ADDED`
                                   WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-local
                                     OR ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-remote THEN `REMOVED`
                                   WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-gap THEN `GAP` ).
      INSERT VALUE #( remote_num = ls_line-remote_num
                      local_num  = ls_line-local_num
                      code_html  = zcl_ag2ui5_repo_service=>tinted_html(
                                     iv_html = zcl_ag2ui5_repo_service=>code_html( ls_line-text )
                                     iv_tint = lv_tint )
                      marker     = COND #( WHEN ls_line-kind = lv_new_kind THEN `+`
                                           WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-local
                                             OR ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-remote THEN `-` )
                      highlight  = COND #( WHEN ls_line-kind = lv_new_kind THEN `Success`
                                           WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-local
                                             OR ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-remote THEN `Error`
                                           WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-gap THEN `Information`
                                           ELSE `None` )
                      patch_id   = ls_line-patch_id
                      pickable   = xsdbool( mv_patch = abap_true AND ls_line-patch_id IS NOT INITIAL )
                      picked     = xsdbool( ls_line-patch_id IS NOT INITIAL
                                            AND line_exists( mt_picked[ table_line = ls_line-patch_id ] ) ) )
        INTO TABLE mt_rows.
    ENDLOOP.
    mv_pick_text = |{ lines( mt_picked ) } of { lines( patch_ids( ) ) } lines picked|.

    CLEAR mt_sbs.
    LOOP AT zcl_ag2ui5_repo_service=>to_side_by_side( it_lines         = lt_lines
                                                      iv_remote_is_new = mv_remote_is_new ) INTO DATA(ls_sbs).
      " the old and the new side, then placed: the system left, Git right
      DATA(lv_old_html) = COND string( WHEN ls_sbs-gap = abap_true
                                       THEN zcl_ag2ui5_repo_service=>tinted_html(
                                              iv_html = |<em>{ escape( val = ls_sbs-old_text format = cl_abap_format=>e_xml_text ) }</em>|
                                              iv_tint = `GAP` )
                                       ELSE zcl_ag2ui5_repo_service=>tinted_html(
                                              iv_html = zcl_ag2ui5_repo_service=>code_html( ls_sbs-old_text )
                                              iv_tint = COND #( WHEN ls_sbs-old_changed = abap_true THEN `REMOVED` ) ) ).
      DATA(lv_new_html) = COND string( WHEN ls_sbs-gap = abap_false
                                       THEN zcl_ag2ui5_repo_service=>tinted_html(
                                              iv_html = zcl_ag2ui5_repo_service=>code_html( ls_sbs-new_text )
                                              iv_tint = COND #( WHEN ls_sbs-new_changed = abap_true THEN `ADDED` ) ) ).
      DATA(lv_old_marker) = COND string( WHEN ls_sbs-old_changed = abap_true THEN `-` ).
      DATA(lv_new_marker) = COND string( WHEN ls_sbs-new_changed = abap_true THEN `+` ).
      DATA(ls_row) = VALUE ty_sbs_row(
        highlight = COND #( WHEN ls_sbs-gap = abap_true THEN `Information`
                            WHEN ls_sbs-old_changed = abap_true AND ls_sbs-new_changed = abap_true THEN `Warning`
                            WHEN ls_sbs-new_changed = abap_true THEN `Success`
                            WHEN ls_sbs-old_changed = abap_true THEN `Error`
                            ELSE `None` ) ).
      IF mv_remote_is_new = abap_true.
        ls_row-system_num    = ls_sbs-old_num.
        ls_row-system_html   = lv_old_html.
        ls_row-system_marker = lv_old_marker.
        ls_row-system_state  = `Error`.
        ls_row-git_num       = ls_sbs-new_num.
        ls_row-git_html      = lv_new_html.
        ls_row-git_marker    = lv_new_marker.
        ls_row-git_state     = `Success`.
      ELSE.
        ls_row-system_num    = ls_sbs-new_num.
        ls_row-system_html   = lv_new_html.
        ls_row-system_marker = lv_new_marker.
        ls_row-system_state  = `Success`.
        ls_row-git_num       = ls_sbs-old_num.
        ls_row-git_html      = lv_old_html.
        ls_row-git_marker    = lv_old_marker.
        ls_row-git_state     = `Error`.
      ENDIF.
      INSERT ls_row INTO TABLE mt_sbs.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
