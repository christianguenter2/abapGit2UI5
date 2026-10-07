"! All changed files of a repository: one collapsible diff panel per file
CLASS zcl_ag2ui5_app_repo_diff DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_line,
        remote_num TYPE string,
        local_num  TYPE string,
        marker     TYPE string,
        "! The line for sap.m.FormattedText: escaped, monospace
        code_html  TYPE string,
        highlight  TYPE string,
      END OF ty_line,
      ty_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_sbs_line,
        system_num    TYPE string,
        system_html   TYPE string,
        system_marker TYPE string,
        system_state  TYPE string,
        git_num       TYPE string,
        git_html      TYPE string,
        git_marker    TYPE string,
        git_state     TYPE string,
        highlight     TYPE string,
      END OF ty_sbs_line,
      ty_sbs_lines TYPE STANDARD TABLE OF ty_sbs_line WITH EMPTY KEY.
    TYPES:
      "! One panel; the browser sends INDEX back, nothing else is trusted
      BEGIN OF ty_file,
        index       TYPE i,
        file        TYPE string,
        object_text TYPE string,
        object_link TYPE string,
        state       TYPE string,
        "! +x -y once loaded
        counts      TYPE string,
        expanded    TYPE abap_bool,
        "! Binary file, or the error of the load
        note        TYPE string,
        "! Only the current layout's rows are filled, only while expanded
        lines       TYPE ty_lines,
        sbs         TYPE ty_sbs_lines,
      END OF ty_file,
      ty_files TYPE STANDARD TABLE OF ty_file WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_head,
        title        TYPE string,
        summary      TYPE string,
        remote_label TYPE string,
      END OF ty_head.

    "! Files loaded on start
    CONSTANTS c_initial TYPE i VALUE 3.
    "! Expand all stops at this many open panels
    CONSTANTS c_max_expanded TYPE i VALUE 25.

    DATA ms_head TYPE ty_head.
    DATA mt_files TYPE ty_files.
    "! INLINE or SBS
    DATA mv_layout TYPE string VALUE `INLINE`.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
        iv_title      TYPE string
        iv_zip        TYPE xstring OPTIONAL
        it_files      TYPE zif_ag2ui5_repo_service=>ty_status_rows
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_repo_diff.

  PROTECTED SECTION.
    TYPES:
      BEGIN OF ty_loaded,
        index         TYPE i,
        remote_is_new TYPE abap_bool,
        lines         TYPE zif_ag2ui5_repo_service=>ty_diff_lines,
        new_count     TYPE i,
        old_count     TYPE i,
      END OF ty_loaded,
      ty_loaded_tab TYPE SORTED TABLE OF ty_loaded WITH UNIQUE KEY index.

    DATA client TYPE REF TO z2ui5_if_client.
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.
    DATA mv_key TYPE string.
    DATA mv_zip TYPE xstring.
    "! The files as the status page handed them over; the source of truth
    DATA mt_source TYPE zif_ag2ui5_repo_service=>ty_status_rows.
    "! Every loaded file's lines - serialized with the app, never sent
    DATA mt_loaded TYPE ty_loaded_tab.

    METHODS service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.
    METHODS on_event.
    "! The index from the browser, or 0 when it names no file
    METHODS checked_index
      IMPORTING
        iv_arg          TYPE string
      RETURNING
        VALUE(rv_index) TYPE i.
    METHODS expand
      IMPORTING
        iv_index TYPE i.
    METHODS collapse
      IMPORTING
        iv_index TYPE i.
    METHODS expand_all.
    METHODS open
      IMPORTING
        iv_index TYPE i.
    "! The rows of the current layout, for an expanded and loaded file
    METHODS rows_build
      IMPORTING
        iv_index TYPE i.
    METHODS summary_build.
    METHODS view_display.
    "! The line table of a panel, for the current layout
    METHODS lines_display
      IMPORTING
        io_content TYPE REF TO z2ui5_cl_ui5_view_builder.
    CLASS-METHODS state_text
      IMPORTING
        iv_lstate      TYPE string
        iv_rstate      TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_repo_diff IMPLEMENTATION.

  METHOD create.

    ro_app = NEW #( ).
    ro_app->mv_key    = iv_key.
    ro_app->mv_zip    = iv_zip.
    ro_app->mt_source = it_files.
    ro_app->ms_head-title = |Diff - { iv_title }|.
    ro_app->ms_head-remote_label = COND #( WHEN iv_zip IS NOT INITIAL THEN `ZIP` ELSE `Git` ).
    LOOP AT it_files INTO DATA(ls_file).
      INSERT VALUE #( index       = sy-tabix
                      file        = ls_file-path && ls_file-filename
                      object_text = COND #( WHEN ls_file-obj_type IS NOT INITIAL
                                            THEN |{ ls_file-obj_type } { ls_file-obj_name }| )
                      object_link = ls_file-object_link
                      state       = state_text( iv_lstate = ls_file-lstate iv_rstate = ls_file-rstate ) )
        INTO TABLE ro_app->mt_files.
    ENDLOOP.

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      DO nmin( val1 = c_initial val2 = lines( mt_files ) ) TIMES.
        expand( sy-index ).
      ENDDO.
      summary_build( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.

  METHOD service.
    ri_service = COND #( WHEN mi_service IS BOUND THEN mi_service ELSE NEW zcl_ag2ui5_repo_service( ) ).
  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
        RETURN.
      WHEN `PANEL`.
        DATA(lv_index) = checked_index( client->get_event_arg( ) ).
        IF lv_index = 0.
          RETURN.
        ENDIF.
        " the event carries the panel's new state: X or true opens it
        IF client->get_event_arg( 2 ) = `X` OR client->get_event_arg( 2 ) = `true`.
          expand( lv_index ).
        ELSE.
          collapse( lv_index ).
        ENDIF.
      WHEN `EXPAND_ALL`.
        expand_all( ).
      WHEN `COLLAPSE_ALL`.
        LOOP AT mt_files INTO DATA(ls_file) WHERE expanded = abap_true.
          collapse( ls_file-index ).
        ENDLOOP.
      WHEN `LAYOUT`.
        IF mv_layout <> `SBS`.
          mv_layout = `INLINE`.
        ENDIF.
        LOOP AT mt_files INTO ls_file WHERE expanded = abap_true.
          rows_build( ls_file-index ).
        ENDLOOP.
      WHEN `OPEN`.
        open( checked_index( client->get_event_arg( ) ) ).
        RETURN.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    summary_build( ).
    view_display( ).

  ENDMETHOD.

  METHOD checked_index.

    IF iv_arg IS NOT INITIAL AND iv_arg CO `0123456789` AND strlen( iv_arg ) <= 6.
      rv_index = iv_arg.
    ENDIF.
    IF rv_index < 1 OR rv_index > lines( mt_source ).
      rv_index = 0.
    ENDIF.

  ENDMETHOD.

  METHOD expand.

    ASSIGN mt_files[ iv_index ] TO FIELD-SYMBOL(<ls_file>).
    <ls_file>-expanded = abap_true.
    IF NOT line_exists( mt_loaded[ index = iv_index ] ) AND <ls_file>-note IS INITIAL.
      DATA(ls_source) = mt_source[ iv_index ].
      TRY.
          DATA(ls_diff) = service( )->get_diff(
            iv_key           = mv_key
            iv_path          = ls_source-path
            iv_filename      = ls_source-filename
            iv_remote_is_new = zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = ls_source-lstate
                                                                      iv_rstate = ls_source-rstate )
            iv_zip           = mv_zip ).
        CATCH zcx_abapgit_exception INTO DATA(lx_error).
          " one unreadable file does not stop the others
          <ls_file>-note = lx_error->get_text( ).
          RETURN.
      ENDTRY.
      IF ls_diff-binary = abap_true.
        <ls_file>-note = `Binary file - no line diff`.
        RETURN.
      ENDIF.
      DATA(ls_loaded) = VALUE ty_loaded(
        index         = iv_index
        remote_is_new = ls_diff-remote_is_new
        lines         = ls_diff-lines
        new_count     = COND #( WHEN ls_diff-remote_is_new = abap_true THEN ls_diff-remote_count ELSE ls_diff-local_count )
        old_count     = COND #( WHEN ls_diff-remote_is_new = abap_true THEN ls_diff-local_count ELSE ls_diff-remote_count ) ).
      INSERT ls_loaded INTO TABLE mt_loaded.
      <ls_file>-counts = |+{ ls_loaded-new_count } -{ ls_loaded-old_count }|.
    ENDIF.
    rows_build( iv_index ).

  ENDMETHOD.

  METHOD collapse.

    ASSIGN mt_files[ iv_index ] TO FIELD-SYMBOL(<ls_file>).
    <ls_file>-expanded = abap_false.
    CLEAR: <ls_file>-lines, <ls_file>-sbs.

  ENDMETHOD.

  METHOD expand_all.

    DATA(lv_open) = REDUCE i( INIT n = 0 FOR f IN mt_files WHERE ( expanded = abap_true ) NEXT n = n + 1 ).
    DATA(lv_skipped) = 0.
    LOOP AT mt_files INTO DATA(ls_file) WHERE expanded = abap_false.
      IF lv_open >= c_max_expanded.
        lv_skipped = lv_skipped + 1.
        CONTINUE.
      ENDIF.
      expand( ls_file-index ).
      lv_open = lv_open + 1.
    ENDLOOP.
    IF lv_skipped > 0.
      client->message_toast_display( |{ lv_skipped } files stay collapsed: at most { c_max_expanded } are open at once| ).
    ENDIF.

  ENDMETHOD.

  METHOD open.

    IF iv_index = 0.
      RETURN.
    ENDIF.
    " the server's row, not what the browser posted
    DATA(ls_source) = mt_source[ iv_index ].
    client->nav_app_call( zcl_ag2ui5_app_diff=>create(
      iv_key           = mv_key
      iv_zip           = mv_zip
      iv_path          = ls_source-path
      iv_filename      = ls_source-filename
      iv_obj_type      = ls_source-obj_type
      iv_obj_name      = ls_source-obj_name
      iv_object_link   = ls_source-object_link
      iv_remote_is_new = zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = ls_source-lstate
                                                                iv_rstate = ls_source-rstate ) ) ).

  ENDMETHOD.

  METHOD rows_build.

    ASSIGN mt_files[ iv_index ] TO FIELD-SYMBOL(<ls_file>).
    CLEAR: <ls_file>-lines, <ls_file>-sbs.
    READ TABLE mt_loaded INTO DATA(ls_loaded) WITH TABLE KEY index = iv_index.
    IF sy-subrc <> 0 OR <ls_file>-expanded = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_lines) = zcl_ag2ui5_repo_service=>compact( ls_loaded-lines ).

    IF mv_layout = `SBS`.
      LOOP AT zcl_ag2ui5_repo_service=>to_side_by_side( it_lines         = lt_lines
                                                        iv_remote_is_new = ls_loaded-remote_is_new ) INTO DATA(ls_sbs).
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
        DATA(ls_row) = VALUE ty_sbs_line(
          highlight = COND #( WHEN ls_sbs-gap = abap_true THEN `Information`
                              WHEN ls_sbs-old_changed = abap_true AND ls_sbs-new_changed = abap_true THEN `Warning`
                              WHEN ls_sbs-new_changed = abap_true THEN `Success`
                              WHEN ls_sbs-old_changed = abap_true THEN `Error`
                              ELSE `None` ) ).
        IF ls_loaded-remote_is_new = abap_true.
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
        INSERT ls_row INTO TABLE <ls_file>-sbs.
      ENDLOOP.
      RETURN.
    ENDIF.

    " green and + for the side that changed, red and - for the other
    DATA(lv_new_kind) = COND zif_ag2ui5_repo_service=>ty_line_kind(
      WHEN ls_loaded-remote_is_new = abap_true THEN zif_ag2ui5_repo_service=>c_line_kind-remote
      ELSE zif_ag2ui5_repo_service=>c_line_kind-local ).
    LOOP AT lt_lines INTO DATA(ls_line).
      DATA(lv_changed) = xsdbool( ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-local
                                  OR ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-remote ).
      DATA(lv_tint) = COND string( WHEN ls_line-kind = lv_new_kind THEN `ADDED`
                                   WHEN lv_changed = abap_true THEN `REMOVED`
                                   WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-gap THEN `GAP` ).
      INSERT VALUE #( remote_num = ls_line-remote_num
                      local_num  = ls_line-local_num
                      code_html  = zcl_ag2ui5_repo_service=>tinted_html(
                                     iv_html = zcl_ag2ui5_repo_service=>code_html( ls_line-text )
                                     iv_tint = lv_tint )
                      marker     = COND #( WHEN ls_line-kind = lv_new_kind THEN `+`
                                           WHEN lv_changed = abap_true THEN `-` )
                      highlight  = COND #( WHEN ls_line-kind = lv_new_kind THEN `Success`
                                           WHEN lv_changed = abap_true THEN `Error`
                                           WHEN ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-gap THEN `Information`
                                           ELSE `None` ) )
        INTO TABLE <ls_file>-lines.
    ENDLOOP.

  ENDMETHOD.

  METHOD summary_build.

    DATA lv_new TYPE i.
    DATA lv_old TYPE i.
    LOOP AT mt_loaded INTO DATA(ls_loaded).
      lv_new = lv_new + ls_loaded-new_count.
      lv_old = lv_old + ls_loaded-old_count.
    ENDLOOP.
    " files that were never opened; a binary or failed file has its note
    DATA(lv_open) = REDUCE i( INIT n = 0 FOR f IN mt_files
                              WHERE ( note IS INITIAL ) NEXT n = n + 1 ) - lines( mt_loaded ).
    ms_head-summary = |{ lines( mt_files ) } { COND #( WHEN lines( mt_files ) = 1 THEN `file` ELSE `files` ) }| &&
                      |, +{ lv_new } -{ lv_old }| &&
                      COND #( WHEN lv_open > 0 THEN | ({ lv_open } not loaded)| ).

  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    " the header is an overflow toolbar: on a narrow screen the controls
    " move into its menu, the back button and the title stay
    DATA(page) = view->ele( `Page` ).
    DATA(header) = page->ele( `customHeader`
        )->ele( `OverflowToolbar` ).
    header->ele( `Button`
        )->a( n = `icon`    v = `sap-icon://nav-back`
        )->a( n = `tooltip` v = `Back`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `press`   v = client->_event( `BACK` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `NeverOverflow` ).
    header->ele( `Title`
        )->a( n = `text`  v = client->_bind( ms_head-title )
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `true` ).
    header->tag( `ToolbarSpacer` ).
    header->tag( `Text`
        )->a( n = `text` v = client->_bind( ms_head-summary ) ).
    header->ele( `SegmentedButton`
        )->a( n = `selectedKey`     v = client->_bind( mv_layout )
        )->a( n = `selectionChange` v = client->_event( `LAYOUT` )
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `INLINE`
                )->a( n = `text` v = `Inline`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `SBS`
                )->a( n = `text` v = `Side by side` ).
    header->tag( `Button`
        )->a( n = `text`  v = `Expand all`
        )->a( n = `icon`  v = `sap-icon://expand-group`
        )->a( n = `press` v = client->_event( `EXPAND_ALL` ) ).
    header->tag( `Button`
        )->a( n = `text`  v = `Collapse all`
        )->a( n = `icon`  v = `sap-icon://collapse-group`
        )->a( n = `press` v = client->_event( `COLLAPSE_ALL` ) ).

    " one panel per file; each file row carries its own line rows
    DATA(panel) = page->ele( `content`
        )->ele( `VBox`
            )->a( n = `items` v = client->_bind( mt_files )
            )->a( n = `class` v = `sapUiSmallMargin`
            )->ele( `items`
                )->ele( `Panel`
                    )->a( n = `expandable` v = `true`
                    )->a( n = `expanded`   v = `{EXPANDED}`
                    )->a( n = `width`      v = `auto`
                    )->a( n = `class`      v = `sapUiSmallMarginBottom`
                    )->a( n = `expand`     v = client->_event( val   = `PANEL`
                                                               t_arg = VALUE #( ( `${INDEX}` ) ( `${$parameters>/expand}` ) ) ) ).
    DATA(panel_header) = panel->ele( `headerToolbar`
        )->ele( `OverflowToolbar` ).
    panel_header->tag( `Title`
        )->a( n = `text` v = `{FILE}` ).
    panel_header->tag( `Link`
        )->a( n = `text`    v = `{OBJECT_TEXT}`
        )->a( n = `href`    v = `{OBJECT_LINK}`
        )->a( n = `visible` v = `{= !!${OBJECT_LINK} }` ).
    panel_header->tag( `Text`
        )->a( n = `text`    v = `{OBJECT_TEXT}`
        )->a( n = `visible` v = `{= !${OBJECT_LINK} && !!${OBJECT_TEXT} }` ).
    panel_header->tag( `Text`
        )->a( n = `text` v = `{STATE}` ).
    panel_header->tag( `ToolbarSpacer` ).
    panel_header->tag( `Text`
        )->a( n = `text` v = `{COUNTS}` ).
    panel_header->tag( `Button`
        )->a( n = `text`    v = `Open`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `tooltip` v = `The whole file, with its method summary`
        )->a( n = `press`   v = client->_event( val = `OPEN` arg = `${INDEX}` ) ).
    DATA(content) = panel->ele( `content` ).
    content->tag( `Text`
        )->a( n = `text`    v = `{NOTE}`
        )->a( n = `visible` v = `{= !!${NOTE} }` ).
    lines_display( content ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD lines_display.

    IF mv_layout = `SBS`.
      " on narrow screens Git pops in below the system
      DATA(sbs) = io_content->ele( `Table`
          )->a( n = `items`   v = `{SBS}`
          )->a( n = `visible` v = `{= ${SBS}.length > 0 }` ).
      DATA(sbs_columns) = sbs->ele( `columns` ).
      sbs_columns->ele( `Column`
          )->a( n = `width` v = `4rem`
          )->tag( `Text`
              )->a( n = `text` v = `System` ).
      sbs_columns->ele( `Column`
          )->a( n = `width` v = `2rem` ).
      sbs_columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text` v = `Code` ).
      sbs_columns->ele( `Column`
          )->a( n = `width`          v = `4rem`
          )->a( n = `minScreenWidth` v = `Tablet`
          )->a( n = `demandPopin`    v = `true`
          )->tag( `Text`
              )->a( n = `text` v = client->_bind( ms_head-remote_label ) ).
      sbs_columns->ele( `Column`
          )->a( n = `width`          v = `2rem`
          )->a( n = `minScreenWidth` v = `Tablet`
          )->a( n = `demandPopin`    v = `true` ).
      sbs_columns->ele( `Column`
          )->a( n = `minScreenWidth` v = `Tablet`
          )->a( n = `demandPopin`    v = `true`
          )->tag( `Text`
              )->a( n = `text` v = `Code` ).
      DATA(sbs_cells) = sbs->ele( `items`
          )->ele( `ColumnListItem`
              )->a( n = `highlight` v = `{HIGHLIGHT}`
              )->ele( `cells` ).
      sbs_cells->tag( `Text`
          )->a( n = `text` v = `{SYSTEM_NUM}` ).
      sbs_cells->tag( `ObjectStatus`
          )->a( n = `text`  v = `{SYSTEM_MARKER}`
          )->a( n = `state` v = `{SYSTEM_STATE}` ).
      sbs_cells->tag( `FormattedText`
          )->a( n = `htmlText` v = `{SYSTEM_HTML}` ).
      sbs_cells->tag( `Text`
          )->a( n = `text` v = `{GIT_NUM}` ).
      sbs_cells->tag( `ObjectStatus`
          )->a( n = `text`  v = `{GIT_MARKER}`
          )->a( n = `state` v = `{GIT_STATE}` ).
      sbs_cells->tag( `FormattedText`
          )->a( n = `htmlText` v = `{GIT_HTML}` ).
      RETURN.
    ENDIF.

    DATA(inline) = io_content->ele( `Table`
        )->a( n = `items`   v = `{LINES}`
        )->a( n = `visible` v = `{= ${LINES}.length > 0 }` ).
    DATA(columns) = inline->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `5rem`
        )->tag( `Text`
            )->a( n = `text` v = client->_bind( ms_head-remote_label ) ).
    columns->ele( `Column`
        )->a( n = `width` v = `5rem`
        )->tag( `Text`
            )->a( n = `text` v = `Local` ).
    columns->ele( `Column`
        )->a( n = `width` v = `2rem` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Code` ).
    DATA(cells) = inline->ele( `items`
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

  METHOD state_text.

    DATA(lv_local) = SWITCH string( iv_lstate WHEN `A` THEN `added` WHEN `M` THEN `modified` WHEN `D` THEN `deleted` ).
    DATA(lv_remote) = SWITCH string( iv_rstate WHEN `A` THEN `added` WHEN `M` THEN `modified` WHEN `D` THEN `deleted` ).
    rv_text = COND #( WHEN lv_local IS NOT INITIAL AND lv_local = lv_remote THEN |both { lv_local }|
                      WHEN lv_local IS NOT INITIAL AND lv_remote IS NOT INITIAL THEN |local { lv_local }, remote { lv_remote }|
                      WHEN lv_local IS NOT INITIAL THEN |local { lv_local }|
                      WHEN lv_remote IS NOT INITIAL THEN |remote { lv_remote }| ).

  ENDMETHOD.

ENDCLASS.
