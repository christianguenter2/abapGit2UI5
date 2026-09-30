"! Status of one repository, and pulling it in abort mode
CLASS zcl_ag2ui5_app_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_head,
        name          TYPE string,
        package       TYPE string,
        url           TYPE string,
        branch        TYPE string,
        remote_commit TYPE string,
      END OF ty_head.

    TYPES:
      BEGIN OF ty_row,
        obj_type TYPE string,
        obj_name TYPE string,
        filename TYPE string,
        local    TYPE string,
        remote   TYPE string,
        inactive TYPE string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA ms_head     TYPE ty_head.
    DATA mt_rows     TYPE ty_rows.
    DATA mt_blocking TYPE zif_ag2ui5_repo_service=>ty_items.
    DATA mt_info     TYPE zif_ag2ui5_repo_service=>ty_items.
    "! What the empty table says - "match" only once a status was loaded
    DATA mv_no_data  TYPE string.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_status.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mv_key TYPE string.

    METHODS view_display.
    METHODS popup_blocked_display.
    METHODS on_event.
    METHODS load_status.
    METHODS pull.

    METHODS service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.

    "! abapGit's one-letter file states as words
    METHODS state_text
      IMPORTING
        iv_state       TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS messages_text
      IMPORTING
        it_messages    TYPE zif_ag2ui5_repo_service=>ty_messages
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_status IMPLEMENTATION.

  METHOD create.

    ro_app = NEW #( ).
    ro_app->mv_key = iv_key.

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      load_status( ).
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
        )->a( n = `title`          v = client->_bind( ms_head-name )
        )->a( n = `showNavButton`  v = `true`
        )->a( n = `navButtonPress` v = client->_event( `BACK` ) ).

    DATA(header_content) = page->ele( `headerContent` ).
    header_content->tag( `Button`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `tooltip` v = `Refresh status`
        )->a( n = `press`   v = client->_event( `REFRESH` ) ).
    header_content->tag( `Button`
        )->a( n = `text`  v = `Pull`
        )->a( n = `icon`  v = `sap-icon://download`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `press` v = client->_event( `PULL` ) ).

    DATA(content) = page->ele( `content` ).

    DATA(attributes) = content->ele( `ObjectHeader`
        )->a( n = `title` v = client->_bind( ms_head-package )
        )->ele( `attributes` ).
    attributes->tag( `ObjectAttribute`
        )->a( n = `title` v = `URL`
        )->a( n = `text`  v = client->_bind( ms_head-url ) ).
    attributes->tag( `ObjectAttribute`
        )->a( n = `title` v = `Branch`
        )->a( n = `text`  v = client->_bind( ms_head-branch ) ).
    attributes->tag( `ObjectAttribute`
        )->a( n = `title` v = `Remote commit`
        )->a( n = `text`  v = client->_bind( ms_head-remote_commit ) ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items`      v = client->_bind( mt_rows )
        )->a( n = `noDataText` v = client->_bind( mv_no_data ) ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Type` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Object` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `File` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Local` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Remote` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Inactive` ).

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OBJ_TYPE}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OBJ_NAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{FILENAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{LOCAL}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{REMOTE}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{INACTIVE}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD popup_blocked_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns`      v = `sap.m`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`        v = `Pull blocked - nothing was imported`
            )->a( n = `contentWidth` v = `40rem` ).

    DATA(content) = dialog->ele( `content` ).
    content->tag( `MessageStrip`
        )->a( n = `text`     v = `Pulling would lose local work. Resolve these in abapGit in SAP GUI, or push the local changes first.`
        )->a( n = `type`     v = `Warning`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin` ).

    content->ele( `List`
        )->a( n = `headerText` v = `Blocking`
        )->a( n = `items`      v = client->_bind( mt_blocking )
        )->ele( `items`
            )->tag( `StandardListItem`
                )->a( n = `title`       v = `{REASON}`
                )->a( n = `description` v = `{OBJ_TYPE} {OBJ_NAME}` ).

    IF mt_info IS NOT INITIAL.
      content->ele( `List`
          )->a( n = `headerText` v = `Skipped`
          )->a( n = `items`      v = client->_bind( mt_info )
          )->ele( `items`
              )->tag( `StandardListItem`
                  )->a( n = `title`       v = `{REASON}`
                  )->a( n = `description` v = `{OBJ_TYPE} {OBJ_NAME}` ).
    ENDIF.

    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Close`
            )->a( n = `press` v = client->follow_up_action( val = z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `REFRESH`.
        load_status( ).
      WHEN `PULL`.
        pull( ).
    ENDCASE.

  ENDMETHOD.

  METHOD load_status.

    TRY.
        DATA(ls_status) = service( )->get_status( mv_key ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        CLEAR mt_rows.
        mv_no_data = `Status could not be loaded`.
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    mv_no_data = `Local and remote match`.
    ms_head = CORRESPONDING #( ls_status ).
    ms_head-remote_commit = COND #( WHEN strlen( ls_status-remote_commit ) > 7
                                    THEN substring( val = ls_status-remote_commit len = 7 )
                                    ELSE ls_status-remote_commit ).

    CLEAR mt_rows.
    LOOP AT ls_status-rows INTO DATA(ls_status_row).
      INSERT VALUE #( obj_type = ls_status_row-obj_type
                      obj_name = ls_status_row-obj_name
                      filename = ls_status_row-filename
                      local    = state_text( ls_status_row-lstate )
                      remote   = state_text( ls_status_row-rstate )
                      inactive = COND #( WHEN ls_status_row-inactive = abap_true THEN `inactive` ) )
        INTO TABLE mt_rows.
    ENDLOOP.

  ENDMETHOD.

  METHOD pull.

    " the lists of an earlier blocked pull would otherwise travel on every round trip
    CLEAR: mt_blocking, mt_info.

    TRY.
        DATA(ls_result) = service( )->pull( mv_key ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    CASE ls_result-outcome.
      WHEN zif_ag2ui5_repo_service=>c_outcome-nothing.
        client->message_toast_display( `Already up to date` ).
      WHEN zif_ag2ui5_repo_service=>c_outcome-pulled.
        load_status( ).
        DATA(lv_warnings) = messages_text( ls_result-messages ).
        IF lv_warnings IS INITIAL.
          client->message_toast_display( `Pulled` ).
        ELSE.
          client->message_box_display( text    = `Pulled, with warnings`
                                       type    = `warning`
                                       details = lv_warnings ).
        ENDIF.
      WHEN zif_ag2ui5_repo_service=>c_outcome-blocked.
        mt_blocking = ls_result-blocking.
        mt_info     = ls_result-info.
        popup_blocked_display( ).
      WHEN zif_ag2ui5_repo_service=>c_outcome-failed.
        load_status( ).
        client->message_box_display( text    = `The pull finished with errors`
                                     type    = `error`
                                     details = messages_text( ls_result-messages ) ).
    ENDCASE.

  ENDMETHOD.

  METHOD service.
    ri_service = NEW zcl_ag2ui5_repo_service( ).
  ENDMETHOD.

  METHOD state_text.

    rv_text = SWITCH #( iv_state
                        WHEN `A` THEN `added`
                        WHEN `M` THEN `modified`
                        WHEN `D` THEN `deleted` ).

  ENDMETHOD.

  METHOD messages_text.

    DATA lt_lines TYPE string_table.

    LOOP AT it_messages INTO DATA(ls_message) WHERE type = `E` OR type = `A` OR type = `W`.
      INSERT |{ ls_message-obj_type } { ls_message-obj_name }: { ls_message-text }| INTO TABLE lt_lines.
    ENDLOOP.

    rv_text = concat_lines_of( table = lt_lines sep = |\n| ).

  ENDMETHOD.

ENDCLASS.
