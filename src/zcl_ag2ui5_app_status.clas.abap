"! Status of one repository, and pulling it with a decision per object
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

    "! The decision dialog: one table per group, each bound on its own
    TYPES:
      BEGIN OF ty_decisions,
        data_loss TYPE zif_ag2ui5_repo_service=>ty_decision_items,
        delete    TYPE zif_ag2ui5_repo_service=>ty_decision_items,
        overwrite TYPE zif_ag2ui5_repo_service=>ty_decision_items,
        package   TYPE zif_ag2ui5_repo_service=>ty_decision_items,
        import    TYPE zif_ag2ui5_repo_service=>ty_decision_items,
        skipped   TYPE zif_ag2ui5_repo_service=>ty_decision_items,
      END OF ty_decisions.

    DATA ms_head         TYPE ty_head.
    DATA mt_rows         TYPE ty_rows.
    "! What the empty table says - "match" only once a status was loaded
    DATA mv_no_data      TYPE string.
    DATA ms_decisions    TYPE ty_decisions.
    DATA mv_ack_text     TYPE string.
    DATA mv_acknowledged TYPE abap_bool.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_status.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mv_key TYPE string.

    METHODS view_display.
    METHODS popup_decisions_display.

    "! One group of the decision dialog; nothing when the group is empty
    METHODS group_display
      IMPORTING
        io_content    TYPE REF TO z2ui5_cl_ui5_view_builder
        it_items      TYPE zif_ag2ui5_repo_service=>ty_decision_items
        iv_items_bind TYPE string
        iv_title      TYPE string
        iv_warning    TYPE string OPTIONAL
        iv_type       TYPE string DEFAULT `Warning`.

    METHODS on_event.
    METHODS load_status.
    METHODS preview_pull.
    METHODS pull_selected.

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

  METHOD popup_decisions_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns`      v = `sap.m`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`        v = `Pull - choose what to change`
            )->a( n = `contentWidth` v = `48rem` ).

    DATA(content) = dialog->ele( `content` ).

    group_display( io_content    = content
                   it_items      = ms_decisions-data_loss
                   iv_items_bind = client->_bind( ms_decisions-data_loss )
                   iv_title      = `Data loss`
                   iv_warning    = `Changing these objects loses data. Select only what really has to change.`
                   iv_type       = `Error` ).
    group_display( io_content    = content
                   it_items      = ms_decisions-delete
                   iv_items_bind = client->_bind( ms_decisions-delete )
                   iv_title      = `Delete local objects`
                   iv_warning    = `These objects are not in the remote. Selected ones are deleted from the system.` ).
    group_display( io_content    = content
                   it_items      = ms_decisions-overwrite
                   iv_items_bind = client->_bind( ms_decisions-overwrite )
                   iv_title      = `Overwrite local changes`
                   iv_warning    = `Selected objects get the remote version - their local changes are lost.` ).
    group_display( io_content    = content
                   it_items      = ms_decisions-package
                   iv_items_bind = client->_bind( ms_decisions-package )
                   iv_title      = `Package change`
                   iv_warning    = `Selected objects are moved to the package the remote expects.` ).
    group_display( io_content    = content
                   it_items      = ms_decisions-import
                   iv_items_bind = client->_bind( ms_decisions-import )
                   iv_title      = `Import` ).
    group_display( io_content    = content
                   it_items      = ms_decisions-skipped
                   iv_items_bind = client->_bind( ms_decisions-skipped )
                   iv_title      = `Skipped - object type not supported` ).

    IF mv_ack_text IS NOT INITIAL.
      content->tag( `MessageStrip`
          )->a( n = `text`     v = client->_bind( mv_ack_text )
          )->a( n = `type`     v = `Warning`
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiSmallMargin` ).
      content->tag( `CheckBox`
          )->a( n = `text`     v = `Pull anyway`
          )->a( n = `selected` v = client->_bind( mv_acknowledged )
          )->a( n = `class`    v = `sapUiSmallMarginBegin` ).
    ENDIF.

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Pull selected`
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `PULL_SELECTED` ) ).
    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Cancel`
            )->a( n = `press` v = client->follow_up_action( val = z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD group_display.

    IF it_items IS INITIAL.
      RETURN.
    ENDIF.

    io_content->tag( `Title`
        )->a( n = `text`  v = iv_title
        )->a( n = `class` v = `sapUiSmallMarginBegin sapUiSmallMarginTop` ).

    IF iv_warning IS NOT INITIAL.
      io_content->tag( `MessageStrip`
          )->a( n = `text`     v = iv_warning
          )->a( n = `type`     v = iv_type
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiSmallMarginBeginEnd sapUiTinyMarginTop` ).
    ENDIF.

    DATA(table) = io_content->ele( `Table`
        )->a( n = `items` v = iv_items_bind ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `4rem`
        )->tag( `Text`
            )->a( n = `text` v = `Change` ).
    columns->ele( `Column`
        )->a( n = `width` v = `5rem`
        )->tag( `Text`
            )->a( n = `text` v = `Type` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Object` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Reason` ).

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells` ).
    cells->tag( `CheckBox`
        )->a( n = `selected` v = `{SELECTED}`
        )->a( n = `enabled`  v = `{SELECTABLE}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OBJ_TYPE}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OBJ_NAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{REASON}` ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `REFRESH`.
        load_status( ).
      WHEN `PULL`.
        preview_pull( ).
      WHEN `PULL_SELECTED`.
        pull_selected( ).
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

  METHOD preview_pull.

    CLEAR: ms_decisions, mv_ack_text, mv_acknowledged.

    TRY.
        DATA(ls_preview) = service( )->preview_pull( mv_key ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    CASE ls_preview-outcome.
      WHEN zif_ag2ui5_repo_service=>c_outcome-nothing.
        client->message_toast_display( `Already up to date` ).
        RETURN.
      WHEN zif_ag2ui5_repo_service=>c_outcome-blocked.
        client->message_box_display( text = ls_preview-blocked type = `error` ).
        RETURN.
    ENDCASE.

    LOOP AT ls_preview-items INTO DATA(ls_item).
      CASE ls_item-group.
        WHEN zif_ag2ui5_repo_service=>c_group-data_loss.
          INSERT ls_item INTO TABLE ms_decisions-data_loss.
        WHEN zif_ag2ui5_repo_service=>c_group-delete.
          INSERT ls_item INTO TABLE ms_decisions-delete.
        WHEN zif_ag2ui5_repo_service=>c_group-overwrite.
          INSERT ls_item INTO TABLE ms_decisions-overwrite.
        WHEN zif_ag2ui5_repo_service=>c_group-package.
          INSERT ls_item INTO TABLE ms_decisions-package.
        WHEN zif_ag2ui5_repo_service=>c_group-import.
          INSERT ls_item INTO TABLE ms_decisions-import.
        WHEN OTHERS.
          INSERT ls_item INTO TABLE ms_decisions-skipped.
      ENDCASE.
    ENDLOOP.
    mv_ack_text = ls_preview-ack_text.

    popup_decisions_display( ).

  ENDMETHOD.

  METHOD pull_selected.

    DATA lt_items TYPE zif_ag2ui5_repo_service=>ty_decision_items.

    INSERT LINES OF: ms_decisions-data_loss INTO TABLE lt_items,
                     ms_decisions-delete    INTO TABLE lt_items,
                     ms_decisions-overwrite INTO TABLE lt_items,
                     ms_decisions-package   INTO TABLE lt_items,
                     ms_decisions-import    INTO TABLE lt_items,
                     ms_decisions-skipped   INTO TABLE lt_items.

    " an empty list is a pull of files only; a list with nothing ticked is a no-op
    IF lt_items IS NOT INITIAL AND NOT line_exists( lt_items[ selected = abap_true ] ).
      client->message_toast_display( `Nothing selected` ).
      RETURN.
    ENDIF.
    IF mv_ack_text IS NOT INITIAL AND mv_acknowledged = abap_false.
      client->message_toast_display( `Confirm "Pull anyway" first` ).
      RETURN.
    ENDIF.

    client->popup_destroy( ).

    TRY.
        DATA(ls_result) = service( )->pull( iv_key          = mv_key
                                            it_items        = lt_items
                                            iv_acknowledged = mv_acknowledged ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    " the dialog's lists would otherwise travel on every round trip
    CLEAR: ms_decisions, mv_ack_text, mv_acknowledged.

    CASE ls_result-outcome.
      WHEN zif_ag2ui5_repo_service=>c_outcome-nothing.
        client->message_toast_display( `Already up to date` ).
      WHEN zif_ag2ui5_repo_service=>c_outcome-changed.
        load_status( ).
        client->message_box_display( text = `The remote changed since the preview - nothing was imported. Pull again to review.`
                                     type = `error` ).
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
