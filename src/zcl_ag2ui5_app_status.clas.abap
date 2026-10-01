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
        path     TYPE string,
        filename TYPE string,
        local    TYPE string,
        remote   TYPE string,
        inactive TYPE string,
        "! abapGit's one-letter states, for the diff direction
        lstate   TYPE string,
        rstate   TYPE string,
        "! The bar at the row's left edge: which side changed
        highlight TYPE string,
        changed   TYPE abap_bool,
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
    "! The rows shown: all files, or only the changed ones
    DATA mt_rows         TYPE ty_rows.
    "! ALL or CHANGES
    DATA mv_view         TYPE string VALUE `ALL`.
    "! OBJECT, FILE or TYPE
    DATA mv_sort         TYPE string VALUE `OBJECT`.
    DATA mv_changes_first TYPE abap_bool VALUE abap_true.
    "! What the empty table says - "match" only once a status was loaded
    DATA mv_no_data      TYPE string.
    DATA ms_decisions    TYPE ty_decisions.
    "! Stage is offered only when something changed locally
    DATA mv_can_stage    TYPE abap_bool.
    DATA mv_ack_text     TYPE string.
    DATA mv_acknowledged TYPE abap_bool.
    "! Filled when the package needs a request: the user's modifiable ones
    DATA mt_transports   TYPE zif_ag2ui5_repo_service=>ty_transports.
    DATA mv_transport    TYPE string.
    DATA mt_customizing  TYPE zif_ag2ui5_repo_service=>ty_transports.
    DATA mv_customizing  TYPE string.

    TYPES:
      BEGIN OF ty_branch_row,
        name TYPE string,
        text TYPE string,
      END OF ty_branch_row,
      ty_branch_rows TYPE STANDARD TABLE OF ty_branch_row WITH EMPTY KEY.
    "! The branch dialog: the remote's branches, and the one picked
    DATA mt_branches     TYPE ty_branch_rows.
    DATA mv_branch       TYPE string.
    "! New branch... is picked: the name field shows, the button creates
    DATA mv_new_mode     TYPE abap_bool.
    DATA mv_new_name     TYPE string.
    DATA mv_start_text   TYPE string.
    DATA mv_branch_button TYPE string VALUE `Switch`.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_status.

  PROTECTED SECTION.
    CONSTANTS c_new_branch TYPE string VALUE `NEW`.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mv_key TYPE string.
    "! Every file of the last status; sorting and the switch start from here
    DATA mt_status TYPE zif_ag2ui5_repo_service=>ty_status_rows.
    "! Set once a status was loaded, for the empty table's text
    DATA mv_loaded TYPE abap_bool.
    "! Which requests the open dialog asks for (request types, not bound)
    DATA:
      BEGIN OF ms_transport_types,
        transport   TYPE string,
        customizing TYPE string,
      END OF ms_transport_types.

    METHODS view_display.
    METHODS popup_decisions_display.
    METHODS popup_branches_display.
    METHODS load_branches.
    METHODS switch_branch.
    METHODS create_branch.

    "! One group of the decision dialog; nothing when the group is empty
    METHODS group_display
      IMPORTING
        io_content    TYPE REF TO z2ui5_cl_ui5_view_builder
        it_items      TYPE zif_ag2ui5_repo_service=>ty_decision_items
        iv_items_bind TYPE string
        iv_title      TYPE string
        iv_warning    TYPE string OPTIONAL
        iv_type       TYPE string DEFAULT `Warning`.

    "! A request Select, and a hint when the user has no request of that type
    METHODS transport_display
      IMPORTING
        io_content         TYPE REF TO z2ui5_cl_ui5_view_builder
        it_transports      TYPE zif_ag2ui5_repo_service=>ty_transports
        iv_transports_bind TYPE string
        iv_selected_bind   TYPE string
        iv_label           TYPE string
        iv_type            TYPE string.

    METHODS on_event.
    METHODS load_status.
    METHODS rows_build.
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
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page`
        )->a( n = `title`          v = client->_bind( ms_head-name )
        )->a( n = `showNavButton`  v = `true`
        )->a( n = `navButtonPress` v = client->_event( `BACK` ) ).

    DATA(header_content) = page->ele( `headerContent` ).
    header_content->ele( `SegmentedButton`
        )->a( n = `selectedKey`     v = client->_bind( mv_view )
        )->a( n = `selectionChange` v = client->_event( `VIEW` )
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `ALL`
                )->a( n = `text` v = `All files`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `CHANGES`
                )->a( n = `text` v = `Changes only` ).
    header_content->tag( `Label`
        )->a( n = `text` v = `Sort by` ).
    header_content->ele( `Select`
        )->a( n = `selectedKey` v = client->_bind( mv_sort )
        )->a( n = `change`      v = client->_event( `VIEW` )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `OBJECT`
                )->a( n = `text` v = `Object`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `FILE`
                )->a( n = `text` v = `File`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `TYPE`
                )->a( n = `text` v = `Type` ).
    header_content->tag( `ToggleButton`
        )->a( n = `text`    v = `Changes on top`
        )->a( n = `pressed` v = client->_bind( mv_changes_first )
        )->a( n = `press`   v = client->_event( `VIEW` ) ).
    header_content->tag( `Button`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `tooltip` v = `Refresh status`
        )->a( n = `press`   v = client->_event( `REFRESH` ) ).
    header_content->tag( `Button`
        )->a( n = `text`  v = `Switch branch`
        )->a( n = `icon`  v = `sap-icon://split`
        )->a( n = `press` v = client->_event( `BRANCHES` ) ).
    header_content->tag( `Button`
        )->a( n = `text`    v = `Stage`
        )->a( n = `icon`    v = `sap-icon://upload`
        )->a( n = `enabled` v = client->_bind( mv_can_stage )
        )->a( n = `press`   v = client->_event( `STAGE` ) ).
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
        )->a( n = `items`               v = client->_bind( mt_rows )
        )->a( n = `noDataText`          v = client->_bind( mv_no_data )
        )->a( n = `growing`             v = `true`
        )->a( n = `growingThreshold`    v = `200`
        )->a( n = `growingScrollToLoad` v = `true` ).

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
            )->a( n = `type`      v = `Navigation`
            )->a( n = `highlight` v = `{HIGHLIGHT}`
            )->a( n = `press`     v = client->_event( val = `DIFF` t_arg = VALUE #( ( `${PATH}` ) ( `${FILENAME}` ) ) )
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

    IF ms_transport_types-transport IS NOT INITIAL.
      transport_display( io_content         = content
                         it_transports      = mt_transports
                         iv_transports_bind = client->_bind( mt_transports )
                         iv_selected_bind   = client->_bind( mv_transport )
                         iv_label           = `Transport request`
                         iv_type            = ms_transport_types-transport ).
    ENDIF.
    IF ms_transport_types-customizing IS NOT INITIAL.
      transport_display( io_content         = content
                         it_transports      = mt_customizing
                         iv_transports_bind = client->_bind( mt_customizing )
                         iv_selected_bind   = client->_bind( mv_customizing )
                         iv_label           = `Customizing request`
                         iv_type            = ms_transport_types-customizing ).
    ENDIF.

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
                   iv_warning    = `Selected objects change their package, or overwrite an object that belongs to a package outside this repository.` ).
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

  METHOD rows_build.

    CLEAR mt_rows.
    LOOP AT zcl_ag2ui5_repo_service=>sort_status_rows( it_rows          = mt_status
                                                      iv_by            = mv_sort
                                                      iv_changes_first = mv_changes_first ) INTO DATA(ls_status_row).
      IF mv_view = `CHANGES` AND ls_status_row-changed = abap_false.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( obj_type  = ls_status_row-obj_type
                      obj_name  = ls_status_row-obj_name
                      path      = ls_status_row-path
                      filename  = ls_status_row-filename
                      local     = state_text( ls_status_row-lstate )
                      remote    = state_text( ls_status_row-rstate )
                      lstate    = ls_status_row-lstate
                      rstate    = ls_status_row-rstate
                      inactive  = COND #( WHEN ls_status_row-inactive = abap_true THEN `inactive` )
                      changed   = ls_status_row-changed
                      highlight = zcl_ag2ui5_repo_service=>change_highlight( iv_lstate   = ls_status_row-lstate
                                                                             iv_rstate   = ls_status_row-rstate
                                                                             iv_inactive = ls_status_row-inactive ) )
        INTO TABLE mt_rows.
    ENDLOOP.
    IF mv_loaded = abap_true.
      mv_no_data = COND #( WHEN mv_view = `CHANGES` THEN `Local and remote match` ELSE `The repository has no files` ).
    ENDIF.

  ENDMETHOD.

  METHOD popup_branches_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns`      v = `sap.m`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`        v = `Switch branch`
            )->a( n = `contentWidth` v = `28rem` ).

    DATA(box) = dialog->ele( `content`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).
    box->tag( `Text`
        )->a( n = `text`  v = `Only the branch the repository follows changes. The status then shows what a pull would bring.`
        )->a( n = `class` v = `sapUiSmallMarginBottom` ).
    box->tag( `Label`
        )->a( n = `text` v = `Branch` ).
    box->ele( `Select`
        )->a( n = `selectedKey` v = client->_bind( mv_branch )
        )->a( n = `width`       v = `100%`
        )->a( n = `items`       v = client->_bind( mt_branches )
        )->a( n = `change`      v = client->_event( `BRANCH_PICK` )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `{NAME}`
                )->a( n = `text` v = `{TEXT}` ).
    box->tag( `Text`
        )->a( n = `text`    v = client->_bind( mv_start_text )
        )->a( n = `visible` v = client->_bind( mv_new_mode )
        )->a( n = `class`   v = `sapUiSmallMarginTop` ).
    box->tag( `Label`
        )->a( n = `text`     v = `Name`
        )->a( n = `required` v = `true`
        )->a( n = `visible`  v = client->_bind( mv_new_mode ) ).
    box->tag( `Input`
        )->a( n = `value`       v = client->_bind( mv_new_name )
        )->a( n = `placeholder` v = `feature/my-change`
        )->a( n = `visible`     v = client->_bind( mv_new_mode ) ).

    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text`  v = client->_bind( mv_branch_button )
            )->a( n = `type`  v = `Emphasized`
            )->a( n = `press` v = client->_event( `SWITCH_BRANCH` ) ).
    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Cancel`
            )->a( n = `press` v = client->follow_up_action( val = z2ui5_if_client=>cs_event-popup_close ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD load_branches.

    TRY.
        DATA(lt_branches) = service( )->list_branches( mv_key ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    CLEAR: mt_branches, mv_branch.
    LOOP AT lt_branches INTO DATA(ls_branch).
      INSERT VALUE #( name = ls_branch-name
                      text = ls_branch-display && COND #( WHEN ls_branch-default = abap_true THEN ` (default)` ) )
        INTO TABLE mt_branches.
      IF ls_branch-current = abap_true.
        mv_branch = ls_branch-name.
      ENDIF.
    ENDLOOP.
    INSERT VALUE #( name = c_new_branch text = `New branch...` ) INTO TABLE mt_branches.
    mv_start_text = |Starts from: { ms_head-branch } at { ms_head-remote_commit }|.
    CLEAR: mv_new_mode, mv_new_name.
    mv_branch_button = `Switch`.
    popup_branches_display( ).

  ENDMETHOD.

  METHOD switch_branch.

    IF mv_branch = c_new_branch.
      create_branch( ).
      RETURN.
    ENDIF.

    TRY.
        service( )->switch_branch( iv_key    = mv_key
                                   iv_branch = mv_branch ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    client->popup_destroy( ).
    client->message_toast_display( |Following { VALUE #( mt_branches[ name = mv_branch ]-text OPTIONAL ) } now| ).
    load_status( ).

  ENDMETHOD.

  METHOD create_branch.

    TRY.
        DATA(lv_branch) = service( )->create_branch( iv_key  = mv_key
                                                     iv_name = mv_new_name ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        " the dialog stays open with the name
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    client->popup_destroy( ).
    client->message_toast_display( |Created and following { substring( val = lv_branch off = 11 ) }| ).
    load_status( ).

  ENDMETHOD.

  METHOD transport_display.

    IF it_transports IS INITIAL.
      io_content->tag( `MessageStrip`
          )->a( n = `text`     t = |{ iv_label }: you have no modifiable request of type { iv_type }. Create one in SE09, then pull again.|
          )->a( n = `type`     v = `Error`
          )->a( n = `showIcon` v = `true`
          )->a( n = `class`    v = `sapUiSmallMargin` ).
      RETURN.
    ENDIF.

    DATA(box) = io_content->ele( `VBox`
        )->a( n = `class` v = `sapUiSmallMargin` ).
    box->tag( `Label`
        )->a( n = `text`     v = iv_label
        )->a( n = `required` v = `true` ).
    box->ele( `Select`
        )->a( n = `selectedKey` v = iv_selected_bind
        )->a( n = `width`       v = `100%`
        )->a( n = `items`       v = iv_transports_bind
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `{TRKORR}`
                )->a( n = `text` v = `{TRKORR} {TEXT}` ).

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
      WHEN `VIEW`.
        rows_build( ).
      WHEN `STAGE`.
        client->nav_app_call( zcl_ag2ui5_app_stage=>create( iv_key = mv_key iv_title = ms_head-name ) ).
      WHEN `DIFF`.
        READ TABLE mt_rows INTO DATA(ls_row)
          WITH KEY path = client->get_event_arg( ) filename = client->get_event_arg( 2 ).
        IF sy-subrc = 0.
          client->nav_app_call( zcl_ag2ui5_app_diff=>create( iv_key      = mv_key
                                                             iv_path     = ls_row-path
                                                             iv_filename = ls_row-filename
                                                             iv_obj_type = ls_row-obj_type
                                                             iv_obj_name = ls_row-obj_name
                                                             iv_remote_is_new = zcl_ag2ui5_repo_service=>remote_is_new(
                                                                                  iv_lstate = ls_row-lstate
                                                                                  iv_rstate = ls_row-rstate ) ) ).
        ENDIF.
      WHEN `BRANCHES`.
        load_branches( ).
      WHEN `BRANCH_PICK`.
        mv_new_mode      = xsdbool( mv_branch = c_new_branch ).
        mv_branch_button = COND #( WHEN mv_new_mode = abap_true THEN `Create` ELSE `Switch` ).
      WHEN `SWITCH_BRANCH`.
        switch_branch( ).
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
        CLEAR: mt_rows, mt_status, mv_loaded.
        mv_no_data = `Status could not be loaded`.
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    mv_loaded = abap_true.
    mv_can_stage = xsdbool( line_exists( ls_status-rows[ lstate = `A` ] )
                         OR line_exists( ls_status-rows[ lstate = `M` ] )
                         OR line_exists( ls_status-rows[ lstate = `D` ] ) ).
    ms_head = CORRESPONDING #( ls_status ).
    ms_head-remote_commit = COND #( WHEN strlen( ls_status-remote_commit ) > 7
                                    THEN substring( val = ls_status-remote_commit len = 7 )
                                    ELSE ls_status-remote_commit ).

    mt_status = ls_status-rows.
    rows_build( ).
  ENDMETHOD.

  METHOD preview_pull.

    CLEAR: ms_decisions, mv_ack_text, mv_acknowledged, ms_transport_types,
           mt_transports, mv_transport, mt_customizing, mv_customizing.

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
    " a request abapGit determined itself is used without asking
    mv_transport   = ls_preview-transport_preset.
    mv_customizing = ls_preview-customizing_preset.

    TRY.
        IF ls_preview-transport_type IS NOT INITIAL AND ls_preview-transport_preset IS INITIAL.
          ms_transport_types-transport = ls_preview-transport_type.
          mt_transports = service( )->list_transports( ls_preview-transport_type ).
          mv_transport  = VALUE #( mt_transports[ 1 ]-trkorr OPTIONAL ).
        ENDIF.
        IF ls_preview-customizing_type IS NOT INITIAL AND ls_preview-customizing_preset IS INITIAL.
          ms_transport_types-customizing = ls_preview-customizing_type.
          mt_customizing = service( )->list_transports( ls_preview-customizing_type ).
          mv_customizing = VALUE #( mt_customizing[ 1 ]-trkorr OPTIONAL ).
        ENDIF.
      CATCH zcx_abapgit_exception INTO lx_error.
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

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
    IF ( ms_transport_types-transport IS NOT INITIAL AND mv_transport IS INITIAL )
        OR ( ms_transport_types-customizing IS NOT INITIAL AND mv_customizing IS INITIAL ).
      client->message_toast_display( `Choose a transport request first` ).
      RETURN.
    ENDIF.

    client->popup_destroy( ).

    TRY.
        DATA(ls_result) = service( )->pull( iv_key          = mv_key
                                            it_items        = lt_items
                                            iv_acknowledged = mv_acknowledged
                                            iv_transport    = mv_transport
                                            iv_customizing  = mv_customizing ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    " the dialog's lists would otherwise travel on every round trip
    CLEAR: ms_decisions, mv_ack_text, mv_acknowledged, ms_transport_types,
           mt_transports, mv_transport, mt_customizing, mv_customizing.

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
