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
        package_link  TYPE string,
        url           TYPE string,
        branch_display TYPE string,
        branch_link    TYPE string,
        remote_commit TYPE string,
        labels        TYPE zif_ag2ui5_repo_service=>ty_labels,
      END OF ty_head.

    TYPES:
      BEGIN OF ty_row,
        obj_type TYPE string,
        obj_name TYPE string,
        object_display TYPE string,
        files_text TYPE string,
        object_link TYPE string,
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
        "! Objects view only: who changed the object, as on the Stage page
        changed_by TYPE string,
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

    "! Bound only while the binary upload dialog is open
    DATA mv_upload       TYPE string.
    DATA mv_upload_path  TYPE string.
    DATA mv_remote_label TYPE string VALUE `Remote`.
    DATA mv_pull_text    TYPE string VALUE `Pull`.
    DATA mv_row_type     TYPE string VALUE `Navigation`.
    DATA mv_overview_row_type TYPE string VALUE `Navigation`.
    DATA ms_head         TYPE ty_head.
    DATA mt_label_choices TYPE zif_ag2ui5_repo_service=>ty_labels.
    DATA mt_label_selected TYPE string_table.
    DATA mv_label_new TYPE string.
    DATA mv_label_error TYPE string.
    "! The rows shown: all files, or only the changed ones
    DATA mt_rows         TYPE ty_rows.
    "! Files of the selected object, bound only while its dialog is open
    DATA mt_object_files TYPE ty_rows.
    TYPES:
      BEGIN OF ty_summary,
        id TYPE string,
        text TYPE string,
        path TYPE string,
        filename TYPE string,
      END OF ty_summary,
      ty_summary_rows TYPE STANDARD TABLE OF ty_summary WITH EMPTY KEY.
    DATA mt_object_summary TYPE ty_summary_rows.
    DATA mv_object_summary_note TYPE string.
    DATA mv_files_title TYPE string.
    DATA mv_overview TYPE string VALUE `FILES`.
    "! ALL or CHANGES
    DATA mv_view         TYPE string VALUE `ALL`.
    "! What the empty table says - "match" only once a status was loaded
    DATA mv_no_data      TYPE string.
    DATA ms_decisions    TYPE ty_decisions.
    "! Stage is offered online, including rule management with no local changes
    DATA mv_can_stage    TYPE abap_bool.
    "! Some file differs (and an offline repository has its ZIP). Bound, so a
    "! refresh enables or disables Diff without rendering the view again
    DATA mv_can_diff     TYPE abap_bool.
    DATA mv_ack_text     TYPE string.
    DATA mv_acknowledged TYPE abap_bool.
    "! Filled when the package needs a request: the user's modifiable ones
    DATA mt_transports   TYPE zif_ag2ui5_repo_service=>ty_transports.
    DATA mv_transport    TYPE string.
    DATA mt_customizing  TYPE zif_ag2ui5_repo_service=>ty_transports.
    DATA mv_customizing  TYPE string.

    TYPES:
      BEGIN OF ty_branch_row,
        name    TYPE string,
        text    TYPE string,
        default TYPE abap_bool,
        current TYPE abap_bool,
        sha1    TYPE string,
        ref_sha1 TYPE string,
        link    TYPE string,
        "! The commit, 7 characters
        commit  TYPE string,
        "! Not the branch the repository follows
        can_switch TYPE abap_bool,
        "! Neither the remote's default nor the followed branch
        can_delete TYPE abap_bool,
      END OF ty_branch_row,
      ty_branch_rows TYPE STANDARD TABLE OF ty_branch_row WITH EMPTY KEY.
    "! The branch dialog: the remote's branches, each with its actions
    DATA mt_branches     TYPE ty_branch_rows.
    DATA mt_tags TYPE ty_branch_rows.
    DATA mv_ref_tab TYPE string VALUE `BRANCHES`.
    DATA mv_tags_note TYPE string VALUE `The remote has no tags`.
    DATA mv_is_tag TYPE abap_bool.
    "! New branch was pressed: the name field replaces the list
    DATA mv_new_mode     TYPE abap_bool.
    DATA mv_new_name     TYPE string.
    DATA mv_start_text   TYPE string.
    DATA ms_new_tag TYPE zif_ag2ui5_repo_service=>ty_new_tag.
    DATA mv_tag_new_mode TYPE abap_bool.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_status.

  PROTECTED SECTION.
    DATA ms_tag_expected TYPE zif_ag2ui5_repo_service=>ty_tag_target.
    DATA mv_delete_tag TYPE string.
    DATA mv_delete_tag_sha1 TYPE string.
    METHODS delete_tag.
    METHODS new_tag.
    METHODS create_tag.
    DATA mv_labels_open TYPE abap_bool.
    DATA mv_labels_expected TYPE string.
    METHODS labels_open.
    METHODS labels_add.
    METHODS labels_save.
    METHODS labels_close.
    METHODS popup_labels_display.
    "! OBJECT, FILE or TYPE; set through the sort menu, not bound
    DATA mv_sort         TYPE string VALUE `OBJECT`.
    DATA mv_changes_first TYPE abap_bool VALUE abap_true.
    DATA mv_files_open TYPE abap_bool.
    METHODS popup_files_display.
    METHODS open_object_files.
    DATA mt_semantic TYPE zif_ag2ui5_repo_service=>ty_semantic_changes.
    METHODS file_rows
      IMPORTING it_rows TYPE zif_ag2ui5_repo_service=>ty_status_rows
      RETURNING VALUE(rt_rows) TYPE ty_rows.
    "! ZIP bytes survive HTTP requests; no abapGit references in app state
    DATA mv_zip TYPE xstring.
    DATA mv_offline TYPE abap_bool.
    "! Test double only; the production service is constructed on demand
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.
    METHODS popup_upload_display.
    METHODS upload_zip.
    METHODS export_zip.

    "! The toggles of the header, stored for the user
    METHODS save_view_settings.
    "! The branch the open delete confirmation is about, set on the server
    DATA mv_delete_branch TYPE string.
    "! The commit the confirmation showed; the service refuses if it moved
    DATA mv_delete_sha1 TYPE string.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mv_key TYPE string.
    METHODS repo_diff_open.
    METHODS leave_list IMPORTING iv_message TYPE string OPTIONAL.
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
    METHODS load_tags.
    METHODS switch_tag IMPORTING iv_tag TYPE string iv_sha1 TYPE string.
    "! A login-required error opens the login page; any other error is shown
    METHODS show_error
      IMPORTING
        ix_error TYPE REF TO zcx_abapgit_exception.
    "! Some file differs, and an offline repository has its ZIP
    METHODS can_repo_diff
      RETURNING
        VALUE(rv_can) TYPE abap_bool.
    METHODS switch_branch
      IMPORTING
        iv_branch TYPE string.
    METHODS create_branch.
    METHODS delete_branch.

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
    METHODS mark_decisions IMPORTING iv_selected TYPE abap_bool.

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
    DATA(li_settings) = zcl_ag2ui5_settings=>get_instance( ).
    ro_app->mv_view = li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-status_view
                                        iv_default = `ALL` ).
    ro_app->mv_overview = li_settings->get( iv_key = zif_ag2ui5_settings=>c_key-status_overview
                                            iv_default = `FILES` ).
    ro_app->mv_sort = li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-status_sort
                                        iv_default = `OBJECT` ).
    ro_app->mv_changes_first = xsdbool( li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-status_changes_first
                                                          iv_default = `X` ) = abap_true ).

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->get_event( ) = `ROUTE_CHANGED`.
      zcl_ag2ui5_app_repos=>route_dispatch( client ).
      RETURN.
    ENDIF.
    zcl_ag2ui5_app_repos=>write_route( io_client = client iv_key = mv_key ).
    IF client->check_on_init( ).
      load_status( ).
      view_display( ).
      DATA(lr_route_message) = client->get( )-r_event_data.
      IF lr_route_message IS BOUND.
        ASSIGN lr_route_message->* TO FIELD-SYMBOL(<lv_route_message>).
        IF <lv_route_message> IS NOT INITIAL.
          client->message_toast_display( CONV string( <lv_route_message> ) ).
        ENDIF.
      ENDIF.
    ELSEIF client->check_on_navigated( ).
      " the stage page hands over a push: the followed branch may be new.
      " PUSHED:<text> - it left by itself and its message is shown here
      DATA(lr_returned) = client->get( )-r_event_data.
      IF lr_returned IS BOUND.
        ASSIGN lr_returned->* TO FIELD-SYMBOL(<lv_returned>).
        DATA(lv_returned) = CONV string( <lv_returned> ).
        IF lv_returned = `PUSHED` OR lv_returned CP `PUSHED:*` OR lv_returned CP `LOGGED_IN:*`.
          load_status( ).
        ENDIF.
        IF lv_returned CP `LOGGED_IN:*`.
          client->message_toast_display(
            |Logged in to { substring( val = lv_returned off = 10 ) } - repeat the action if it did not run| ).
        ENDIF.
        IF lv_returned CP `PUSHED:*` AND strlen( lv_returned ) > 7.
          client->message_toast_display( substring( val = lv_returned off = 7 ) ).
        ENDIF.
      ENDIF.
      view_display( ).
      IF mv_files_open = abap_true.
        popup_files_display( ).
      ENDIF.
      IF mv_labels_open = abap_true.
        popup_labels_display( ).
      ENDIF.
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

    " the header is an overflow toolbar: on a narrow screen the controls
    " move into its menu, the back button and the title stay
    DATA(page) = view->ele( `Page` ).
    DATA(header_content) = page->ele( `customHeader` )->ele( `OverflowToolbar` ).
    header_content->ele( `Button`
        )->a( n = `icon`    v = `sap-icon://nav-back`
        )->a( n = `tooltip` v = `Back`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `press`   v = client->_event( `BACK` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `NeverOverflow` ).
    header_content->ele( `Title`
        )->a( n = `text`  v = client->_bind( ms_head-name )
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `true` ).
    header_content->tag( `ToolbarSpacer` ).
    header_content->tag( `OverflowToolbarButton`
        )->a( n = `text` v = `Edit labels`
        )->a( n = `tooltip` v = `Edit labels`
        )->a( n = `icon` v = `sap-icon://tag`
        )->a( n = `press` v = client->_event( `LABELS_EDIT` ) ).
    " icon only in the bar, with its text in the overflow menu
    header_content->tag( `OverflowToolbarButton`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `text`    v = `Refresh status`
        )->a( n = `tooltip` v = `Refresh status`
        )->a( n = `press`   v = client->_event( `REFRESH` ) ).
    " the button names the followed branch and opens the branch list
    header_content->tag( `Button`
        )->a( n = `visible` b = xsdbool( mv_offline = abap_false )
        )->a( n = `text`    v = client->_bind( ms_head-branch_display )
        )->a( n = `tooltip` v = `Branches and tags`
        )->a( n = `icon`    v = `sap-icon://split`
        )->a( n = `press`   v = client->_event( `BRANCHES` ) ).
    header_content->tag( `Button`
        )->a( n = `visible` b = xsdbool( mv_offline = abap_false )
        )->a( n = `text`    v = `Stage`
        )->a( n = `icon`    v = `sap-icon://upload`
        )->a( n = `enabled` v = client->_bind( mv_can_stage )
        )->a( n = `press`   v = client->_event( `STAGE` ) ).
    header_content->tag( `Button`
        )->a( n = `visible` b = mv_offline
        )->a( n = `text`    v = `Export ZIP`
        )->a( n = `icon`    v = `sap-icon://download`
        )->a( n = `press`   v = client->_event( `EXPORT_ZIP` ) ).
    header_content->ele( `Button`
        )->a( n = `text`  v = client->_bind( mv_pull_text )
        )->a( n = `icon`  v = `sap-icon://download`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `press` v = client->_event( `PULL` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `NeverOverflow` ).

    DATA(content) = page->ele( `content` ).
    content->tag( `MessageStrip`
        )->a( n = `visible` v = client->_bind( mv_is_tag )
        )->a( n = `text` v = `Following a tag. Status and diff compare this release; Pull imports it. Switch to a branch to stage and push.`
        )->a( n = `type` v = `Information`
        )->a( n = `showIcon` v = `true` ).
    IF mv_offline = abap_true AND mv_zip IS INITIAL.
      content->tag( `MessageStrip`
          )->a( n = `text`     v = `Offline repository: import a ZIP to compare and choose what to change. Export ZIP downloads the current local files.`
          )->a( n = `type`     v = `Information`
          )->a( n = `showIcon` v = `true` ).
    ENDIF.

    " a changed row gets a light background in the colour of its bar; the
    " row writes its highlight as data-change, see the CustomData below
    content->tag( n = `HTML` ns = `core`
        )->a( n = `content` v = `<style>` &&
                                `tr[data-change="Indication03"] > td \{ background-color: #fff8d6 \}` &&
                                " Horizon has no yellow highlight: the bar is coloured here too
                                `tr[data-change="Indication03"] .sapMLIBHighlight \{ background-color: #e9c000 \}` &&
                                `</style>` ).

    DATA(attributes) = content->ele( `ObjectHeader`
        )->a( n = `title` v = client->_bind( ms_head-name )
        )->ele( `attributes` ).
    " the package opens in ADT; without a link it stays plain text
    attributes->ele( `ObjectAttribute`
        )->a( n = `title` v = `Package`
        )->ele( `customContent`
            )->tag( `Link`
                )->a( n = `text`    v = client->_bind( ms_head-package )
                )->a( n = `href`    v = client->_bind( ms_head-package_link )
                )->a( n = `enabled` v = |\{= !!$\{{ client->_bind( val = ms_head-package_link path = abap_true ) }\} \}| ).
    attributes->ele( `ObjectAttribute`
        )->a( n = `visible` b = xsdbool( mv_offline = abap_false )
        )->a( n = `title` v = `URL`
        )->ele( `customContent`
            )->tag( `Link`
                )->a( n = `text`   v = client->_bind( ms_head-url )
                )->a( n = `href`   v = client->_bind( ms_head-url )
                )->a( n = `target` v = `_blank` ).
    attributes->tag( `ObjectAttribute`
        )->a( n = `visible` b = xsdbool( mv_offline = abap_false )
        )->a( n = `title` v = `Remote commit`
        )->a( n = `text`  v = client->_bind( ms_head-remote_commit ) ).

    content->tag( n = `HTML` ns = `core`
        )->a( n = `content` v = zcl_ag2ui5_app_repos=>labels_css( ) ).
    DATA(tags) = content->ele( `FlexBox`
        )->a( n = `items` v = client->_bind( ms_head-labels )
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = ms_head-labels path = abap_true ) }\}.length > 0 \}|
        )->a( n = `wrap` v = `Wrap`
        )->a( n = `class` v = `ag2ui5RepoTags ag2ui5RepoLabelsAll sapUiMediumMarginBegin sapUiSmallMarginBottom` ).
    tags->ele( `items`
        )->ele( `Link`
            )->a( n = `text` v = `{TEXT}`
            )->a( n = `tooltip` v = `{TEXT}`
            )->a( n = `wrapping` v = `true`
            )->a( n = `press` v = client->_event( val = `HEADER_LABEL` arg = `${TEXT}` )
            )->a( n = `class` v = `ag2ui5RepoTag`
            )->ele( `customData`
                )->tag( n = `CustomData` ns = `core`
                    )->a( n = `key` v = `tag-color`
                    )->a( n = `value` v = `{COLOR}`
                    )->a( n = `writeToDom` v = `true` ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items`               v = client->_bind( mt_rows )
        )->a( n = `noDataText`          v = client->_bind( mv_no_data )
        )->a( n = `growing`             v = `true`
        )->a( n = `growingThreshold`    v = `200`
        )->a( n = `growingScrollToLoad` v = `true` ).

    " how the list looks: overview, filter and sort sit on the table
    DATA(table_toolbar) = table->ele( `headerToolbar`
        )->ele( `OverflowToolbar` ).
    table_toolbar->ele( `SegmentedButton`
        )->a( n = `selectedKey`     v = client->_bind( mv_overview )
        )->a( n = `selectionChange` v = client->_event( `OVERVIEW` )
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `FILES`
                )->a( n = `text` v = `Files`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `OBJECTS`
                )->a( n = `text` v = `Objects` ).
    table_toolbar->ele( `SegmentedButton`
        )->a( n = `selectedKey`     v = client->_bind( mv_view )
        )->a( n = `selectionChange` v = client->_event( `VIEW` )
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `ALL`
                )->a( n = `text` v = `All`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `CHANGES`
                )->a( n = `text` v = `Changes only` ).
    table_toolbar->tag( `Button`
        )->a( n = `text`    v = `Diff`
        )->a( n = `icon`    v = `sap-icon://compare`
        )->a( n = `tooltip` v = `All changes of the repository on one page`
        )->a( n = `enabled` v = client->_bind( mv_can_diff )
        )->a( n = `press`   v = client->_event( `REPO_DIFF` ) ).
    table_toolbar->tag( `ToolbarSpacer` ).
    " one menu for the order: the sort key (files only) and changes on top,
    " the current choices ticked
    DATA(sort_items) = table_toolbar->ele( `MenuButton`
        )->a( n = `icon`    v = `sap-icon://sort`
        )->a( n = `tooltip` v = `Sort`
        )->ele( `menu`
            )->ele( `Menu`
                )->ele( `items` ).
    IF mv_overview = `FILES`.
      sort_items->tag( `MenuItem`
          )->a( n = `text`  v = `Object`
          )->a( n = `icon`  v = COND #( WHEN mv_sort = `OBJECT` THEN `sap-icon://accept` )
          )->a( n = `press` v = client->_event( val = `SORT` arg = `OBJECT` ) ).
      sort_items->tag( `MenuItem`
          )->a( n = `text`  v = `File`
          )->a( n = `icon`  v = COND #( WHEN mv_sort = `FILE` THEN `sap-icon://accept` )
          )->a( n = `press` v = client->_event( val = `SORT` arg = `FILE` ) ).
      sort_items->tag( `MenuItem`
          )->a( n = `text`  v = `Type`
          )->a( n = `icon`  v = COND #( WHEN mv_sort = `TYPE` THEN `sap-icon://accept` )
          )->a( n = `press` v = client->_event( val = `SORT` arg = `TYPE` ) ).
    ENDIF.
    sort_items->tag( `MenuItem`
        )->a( n = `text`          v = `Changes on top`
        )->a( n = `icon`          v = COND #( WHEN mv_changes_first = abap_true THEN `sap-icon://accept` )
        )->a( n = `startsSection` b = xsdbool( mv_overview = `FILES` )
        )->a( n = `press`         v = client->_event( val = `SORT` arg = `CHANGES_FIRST` ) ).

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
            )->a( n = `text` v = COND #( WHEN mv_overview = `OBJECTS` THEN `Files` ELSE `File` ) ).
    " the Objects view only: who changed the object, as on the Stage page
    IF mv_overview = `OBJECTS`.
      columns->ele( `Column`
          )->a( n = `minScreenWidth` v = `Tablet`
          )->a( n = `demandPopin`    v = `true`
          )->tag( `Text`
              )->a( n = `text` v = `Changed by` ).
    ENDIF.
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Local` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = client->_bind( mv_remote_label ) ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Inactive` ).

    DATA(lt_row_args) = COND string_table( WHEN mv_overview = `OBJECTS`
      THEN VALUE #( ( `${OBJ_TYPE}` ) ( `${OBJ_NAME}` ) )
      ELSE VALUE #( ( `${PATH}` ) ( `${FILENAME}` ) ) ).
    DATA(item) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type` v = client->_bind( mv_overview_row_type )
            )->a( n = `highlight` v = `{HIGHLIGHT}`
            )->a( n = `press` v = client->_event(
                val = COND #( WHEN mv_overview = `OBJECTS` THEN `OBJECT` ELSE `DIFF` ) t_arg = lt_row_args ) ).
    " data-change="<highlight>" on the row, for the style block above
    item->ele( `customData`
        )->tag( n = `CustomData` ns = `core`
            )->a( n = `key`        v = `change`
            )->a( n = `value`      v = `{HIGHLIGHT}`
            )->a( n = `writeToDom` v = `true` ).
    DATA(cells) = item->ele( `cells` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OBJ_TYPE}` ).
    cells->ele( `HBox`
        )->ele( `items`
            )->tag( `Link`
                )->a( n = `text`    v = `{OBJECT_DISPLAY}`
                )->a( n = `href`    v = `{OBJECT_LINK}`
                )->a( n = `visible` v = `{= ${OBJECT_LINK} !== '' }`
                )->a( n = `tooltip` v = `Open object in ADT`
            )->tag( `Text`
                )->a( n = `text`    v = `{OBJECT_DISPLAY}`
                )->a( n = `visible` v = `{= ${OBJECT_LINK} === '' }` ).
    cells->tag( `Text`
        )->a( n = `text` v = COND #( WHEN mv_overview = `OBJECTS` THEN `{FILES_TEXT}` ELSE `{FILENAME}` ) ).
    IF mv_overview = `OBJECTS`.
      cells->tag( `Text`
          )->a( n = `text` v = `{CHANGED_BY}` ).
    ENDIF.
    cells->tag( `Text`
        )->a( n = `text` v = `{LOCAL}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{REMOTE}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{INACTIVE}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD labels_open.
    TRY.
        DATA(lt_repos) = service( )->list_repos( ).
        READ TABLE lt_repos INTO DATA(ls_repo) WITH KEY key = mv_key.
        IF sy-subrc <> 0.
          zcx_abapgit_exception=>raise( `This repository is no longer registered` ).
        ENDIF.
        CLEAR: mt_label_choices, mt_label_selected, mv_label_new, mv_label_error, mv_labels_expected.
        LOOP AT ls_repo-labels INTO DATA(ls_label).
          APPEND ls_label-text TO mt_label_selected.
        ENDLOOP.
        mv_labels_expected = concat_lines_of( table = mt_label_selected sep = `, ` ).
        LOOP AT lt_repos INTO ls_repo.
          LOOP AT ls_repo-labels INTO ls_label.
            IF NOT line_exists( mt_label_choices[ text = ls_label-text ] ).
              APPEND ls_label TO mt_label_choices.
            ENDIF.
          ENDLOOP.
        ENDLOOP.
        SORT mt_label_choices BY text.
        mv_labels_open = abap_true.
        popup_labels_display( ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
    ENDTRY.
  ENDMETHOD.

  METHOD labels_add.
    IF mv_labels_open = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_label) = condense( mv_label_new ).
    IF lv_label IS INITIAL.
      mv_label_error = `Enter a new label first.`.
    ELSE.
      TRY.
          IF lv_label CS `,`.
            zcx_abapgit_exception=>raise( `Add one label at a time.` ).
          ENDIF.
          zcl_ag2ui5_repo_service=>checked_labels( iv_labels = lv_label iv_expected = `` iv_fresh = `` ).
          IF NOT line_exists( mt_label_choices[ text = lv_label ] ).
            APPEND VALUE #( text = lv_label ) TO mt_label_choices.
            SORT mt_label_choices BY text.
          ENDIF.
          IF NOT line_exists( mt_label_selected[ table_line = lv_label ] ).
            APPEND lv_label TO mt_label_selected.
          ENDIF.
          CLEAR: mv_label_new, mv_label_error.
        CATCH zcx_abapgit_exception INTO DATA(lx_error).
          mv_label_error = lx_error->get_text( ).
      ENDTRY.
    ENDIF.
  ENDMETHOD.

  METHOD labels_save.
    IF mv_labels_open = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_pending) = condense( mv_label_new ).
    IF lv_pending IS NOT INITIAL.
      mv_label_error = `Press Add to include the new label, or clear the field before saving.`.
      RETURN.
    ENDIF.
    TRY.
        " Validate each selected key too: a posted comma must not create extra labels.
        LOOP AT mt_label_selected INTO DATA(lv_label).
          IF lv_label IS INITIAL OR lv_label CS `,` OR NOT line_exists( mt_label_choices[ text = lv_label ] ).
            zcx_abapgit_exception=>raise( `Choose labels from the list or add a new label first.` ).
          ENDIF.
        ENDLOOP.
        ms_head-labels = service( )->save_labels( iv_key = mv_key
          iv_labels = concat_lines_of( table = mt_label_selected sep = `, ` ) iv_expected = mv_labels_expected ).
        labels_close( ).
        client->message_toast_display( `Labels saved` ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        mv_label_error = lx_error->get_text( ).
    ENDTRY.
  ENDMETHOD.

  METHOD labels_close.
    CLEAR: mv_labels_open, mv_labels_expected, mt_label_choices, mt_label_selected, mv_label_new, mv_label_error.
    client->popup_destroy( ).
  ENDMETHOD.

  METHOD popup_labels_display.
    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).
    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns` v = `sap.m`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title` v = `Edit labels`
            )->a( n = `contentWidth` v = `32rem` ).
    DATA(box) = dialog->ele( `content`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).
    box->tag( `Text`
        )->a( n = `text` v = `Choose existing labels or add a new one. Remove a token to remove that label.`
        )->a( n = `class` v = `sapUiSmallMarginBottom` ).
    box->tag( `Label`
        )->a( n = `text` v = `Labels`
        )->a( n = `labelFor` v = `repoLabelSelection` ).
    box->ele( `MultiComboBox`
        )->a( n = `id` v = `repoLabelSelection`
        )->a( n = `width` v = `100%`
        )->a( n = `placeholder` v = `Select labels`
        )->a( n = `selectedKeys` v = client->_bind( mt_label_selected )
        )->a( n = `items` v = client->_bind( mt_label_choices )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key` v = `{TEXT}`
                )->a( n = `text` v = `{TEXT}` ).
    box->tag( `Label`
        )->a( n = `text` v = `New label`
        )->a( n = `labelFor` v = `repoLabelNew`
        )->a( n = `class` v = `sapUiSmallMarginTop` ).
    DATA(add_row) = box->ele( `HBox`
        )->a( n = `alignItems` v = `Center` ).
    add_row->ele( `Input`
        )->a( n = `id` v = `repoLabelNew`
        )->a( n = `value` v = client->_bind( mv_label_new )
        )->a( n = `valueLiveUpdate` v = `true`
        )->a( n = `placeholder` v = `For example: tools`
        )->a( n = `submit` v = client->_event( `LABELS_ADD` )
        )->ele( `layoutData`
            )->tag( `FlexItemData`
                )->a( n = `growFactor` v = `1` ).
    add_row->tag( `Button`
        )->a( n = `text` v = `Add`
        )->a( n = `class` v = `sapUiTinyMarginBegin`
        )->a( n = `press` v = client->_event( `LABELS_ADD` ) ).
    box->tag( `Text`
        )->a( n = `text` v = `Letters, numbers, spaces, hyphens, underscores and dots are allowed.`
        )->a( n = `class` v = `sapUiTinyMarginTop` ).
    box->tag( `MessageStrip`
        )->a( n = `text` v = client->_bind( mv_label_error )
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = mv_label_error path = abap_true ) }\} !== '' \}|
        )->a( n = `type` v = `Error`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class` v = `sapUiSmallMarginTop` ).
    dialog->ele( `beginButton`
        )->tag( `Button`
            )->a( n = `text` v = `Save`
            )->a( n = `type` v = `Emphasized`
            )->a( n = `press` v = client->_event( `LABELS_SAVE` ) ).
    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text` v = `Cancel`
            )->a( n = `press` v = client->_event( `LABELS_CANCEL` ) ).
    client->popup_display( popup->stringify( ) ).
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

    content->ele( `OverflowToolbar`
        )->tag( `ToolbarSpacer`
        )->tag( `Button`
            )->a( n = `text` v = `Mark all`
            )->a( n = `press` v = client->_event( `PULL_MARK_ALL` )
        )->tag( `Button`
            )->a( n = `text` v = `Unmark all`
            )->a( n = `press` v = client->_event( `PULL_UNMARK_ALL` ) ).

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
            )->a( n = `press` v = client->_event( `PULL_CANCEL` ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD file_rows.

    LOOP AT it_rows INTO DATA(ls_file).
      INSERT VALUE #( obj_type = ls_file-obj_type obj_name = ls_file-obj_name
        object_display = ls_file-obj_name object_link = ls_file-object_link
        path = ls_file-path filename = ls_file-filename
        local = state_text( ls_file-lstate ) remote = state_text( ls_file-rstate )
        lstate = ls_file-lstate rstate = ls_file-rstate
        inactive = COND #( WHEN ls_file-inactive = abap_true THEN `inactive` )
        changed = ls_file-changed
        highlight = zcl_ag2ui5_repo_service=>change_highlight( iv_lstate = ls_file-lstate
          iv_rstate = ls_file-rstate iv_inactive = ls_file-inactive ) ) INTO TABLE rt_rows.
    ENDLOOP.

  ENDMETHOD.

  METHOD rows_build.

    mv_overview_row_type = COND #( WHEN mv_overview = `OBJECTS` THEN `Navigation` ELSE mv_row_type ).
    CLEAR mt_rows.
    IF mv_overview = `OBJECTS`.
      LOOP AT zcl_ag2ui5_repo_service=>object_status_rows(
          it_rows = mt_status iv_changes_first = mv_changes_first ) INTO DATA(ls_object).
        IF mv_view = `CHANGES` AND ls_object-changed = abap_false.
          CONTINUE.
        ENDIF.
        INSERT VALUE #( obj_type = ls_object-obj_type obj_name = ls_object-obj_name
          object_display = COND #( WHEN ls_object-obj_name IS INITIAL THEN `Repository files` ELSE ls_object-obj_name )
          object_link = ls_object-object_link
          files_text = |{ ls_object-changed_count } of { ls_object-file_count } changed|
          local = state_text( ls_object-lstate ) remote = state_text( ls_object-rstate )
          lstate = ls_object-lstate rstate = ls_object-rstate
          inactive = COND #( WHEN ls_object-inactive = abap_true THEN `inactive` )
          changed = ls_object-changed
          changed_by = ls_object-changed_by
          highlight = COND #( WHEN ls_object-changed = abap_true THEN `Indication03` ELSE `None` ) ) INTO TABLE mt_rows.
      ENDLOOP.
    ELSE.
      mt_rows = file_rows( zcl_ag2ui5_repo_service=>sort_status_rows(
        it_rows = mt_status iv_by = mv_sort iv_changes_first = mv_changes_first ) ).
      IF mv_view = `CHANGES`.
        DELETE mt_rows WHERE changed = abap_false.
      ENDIF.
    ENDIF.
    IF mv_loaded = abap_true.
      mv_no_data = COND #( WHEN mv_view = `CHANGES` THEN `Local and remote match` ELSE `The repository has no files` ).
      IF mv_offline = abap_true AND mv_zip IS INITIAL.
        mv_no_data = `Choose a ZIP to compare with the local files`.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD open_object_files.

    IF mv_overview <> `OBJECTS`.
      RETURN.
    ENDIF.
    READ TABLE mt_rows INTO DATA(ls_object)
      WITH KEY obj_type = client->get_event_arg( ) obj_name = client->get_event_arg( 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA lt_files TYPE zif_ag2ui5_repo_service=>ty_status_rows.
    LOOP AT mt_status INTO DATA(ls_file).
      IF ( ls_object-obj_type IS INITIAL AND ls_object-obj_name IS INITIAL
          AND ( ls_file-obj_type IS INITIAL OR ls_file-obj_name IS INITIAL ) )
          OR ( ls_file-obj_type = ls_object-obj_type AND ls_file-obj_name = ls_object-obj_name ).
        INSERT ls_file INTO TABLE lt_files.
      ENDIF.
    ENDLOOP.
    mt_object_files = file_rows( zcl_ag2ui5_repo_service=>sort_status_rows(
      it_rows = lt_files iv_by = `FILE` iv_changes_first = mv_changes_first ) ).
    CLEAR: mt_semantic, mt_object_summary, mv_object_summary_note.
    IF ( ls_object-obj_type = `CLAS` OR ls_object-obj_type = `INTF` )
      AND ( mv_offline = abap_false OR mv_zip IS NOT INITIAL ).
      LOOP AT lt_files INTO DATA(ls_source_file) WHERE changed = abap_true.
        IF to_lower( ls_source_file-filename ) NP '*.abap'.
          CONTINUE.
        ENDIF.
        TRY.
            DATA(ls_diff) = service( )->get_diff(
              iv_key = mv_key iv_zip = mv_zip iv_path = ls_source_file-path iv_filename = ls_source_file-filename
              iv_remote_is_new = zcl_ag2ui5_repo_service=>remote_is_new(
                iv_lstate = ls_source_file-lstate iv_rstate = ls_source_file-rstate ) ).
            APPEND LINES OF ls_diff-semantic-changes TO mt_semantic.
            IF ls_diff-semantic-note CP `Structural summary unavailable*`.
              mv_object_summary_note = `Some source cannot be summarized; review its raw file diff.`.
            ENDIF.
          CATCH zcx_abapgit_exception.
            mv_object_summary_note = `Some source could not be loaded; open its file diff to retry.`.
        ENDTRY.
      ENDLOOP.
      mt_object_summary = CORRESPONDING #( mt_semantic ).
      IF mv_object_summary_note IS INITIAL.
        mv_object_summary_note = `Method declarations and implementations only. Comments, formatting and metadata stay in the file diffs.`.
      ENDIF.
    ENDIF.
    mv_files_title = |Files - { ls_object-object_display }|.
    mv_files_open = abap_true.
    popup_files_display( ).

  ENDMETHOD.

  METHOD popup_files_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).
    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns` v = `sap.m`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title` v = client->_bind( mv_files_title )
            )->a( n = `contentWidth` v = `48rem` ).
    DATA(dialog_content) = dialog->ele( `content` ).
    IF mv_object_summary_note IS NOT INITIAL.
      dialog_content->tag( `Title`
          )->a( n = `text` v = `Structural changes`
          )->a( n = `level` v = `H3`
          )->a( n = `class` v = `sapUiSmallMargin` ).
      dialog_content->tag( `Text`
          )->a( n = `text` v = client->_bind( mv_object_summary_note )
          )->a( n = `class` v = `sapUiSmallMarginBeginEnd` ).
      dialog_content->ele( `List`
          )->a( n = `items` v = client->_bind( mt_object_summary )
          )->a( n = `noDataText` v = `No method token changes; review the file diffs.`
          )->a( n = `growing` v = `true`
          )->a( n = `growingThreshold` v = `20`
          )->ele( `items`
              )->ele( `CustomListItem`
                  )->a( n = `type` v = `Navigation`
                  )->a( n = `press` v = client->_event( val = `SEMANTIC`
                      t_arg = VALUE #( ( `${PATH}` ) ( `${FILENAME}` ) ( `${ID}` ) ) )
                  )->ele( `content`
                      )->ele( `VBox`
                          )->a( n = `class` v = `sapUiSmallMargin`
                          )->tag( `Text`
                              )->a( n = `text` v = `{TEXT}`
                              )->a( n = `wrapping` v = `true`
                          )->tag( `Text`
                              )->a( n = `text` v = `{FILENAME}`
                              )->a( n = `class` v = `sapUiTinyMarginTop` ).
    ENDIF.
    DATA(table) = dialog_content->ele( `Table`
        )->a( n = `items` v = client->_bind( mt_object_files )
        )->a( n = `growing` v = `true`
        )->a( n = `growingThreshold` v = `200` ).
    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `55%`
        )->tag( `Text`
            )->a( n = `text` v = `File` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Local` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = client->_bind( mv_remote_label ) ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin` v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Inactive` ).
    DATA(item) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type` v = client->_bind( mv_row_type )
            )->a( n = `highlight` v = `{HIGHLIGHT}`
            )->a( n = `press` v = client->_event( val = `DIFF` t_arg = VALUE #( ( `${PATH}` ) ( `${FILENAME}` ) ) ) ).
    item->ele( `customData`
        )->tag( n = `CustomData` ns = `core`
            )->a( n = `key` v = `change`
            )->a( n = `value` v = `{HIGHLIGHT}`
            )->a( n = `writeToDom` v = `true` ).
    DATA(cells) = item->ele( `cells` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{PATH}{FILENAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{LOCAL}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{REMOTE}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{INACTIVE}` ).
    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text` v = `Close`
            )->a( n = `press` v = client->_event( `FILES_CLOSE` ) ).
    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD popup_branches_display.

    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory( ).

    DATA(dialog) = popup->ele( n = `FragmentDefinition` ns = `core`
        )->a( n = `xmlns`      v = `sap.m`
        )->a( n = `xmlns:core` v = `sap.ui.core`
        )->ele( `Dialog`
            )->a( n = `title`        v = `Branches and tags`
            )->a( n = `contentWidth` v = `40rem` ).

    DATA(box) = dialog->ele( `content`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).
    box->tag( `Text`
        )->a( n = `text`  v = `Switch changes the reference used for status and diff. Pull separately to import its contents. Create and delete act on the remote.`
        )->a( n = `class` v = `sapUiSmallMarginBottom` ).

    box->ele( `SegmentedButton`
        )->a( n = `selectedKey` v = client->_bind( mv_ref_tab )
        )->a( n = `selectionChange` v = client->_event( `REF_TAB` )
        )->a( n = `visible` v = |\{= !$\{{ client->_bind( val = mv_new_mode path = abap_true ) }\} \}|
        )->a( n = `class` v = `sapUiSmallMarginBottom`
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key` v = `BRANCHES`
                )->a( n = `text` v = `Branches`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key` v = `TAGS`
                )->a( n = `text` v = `Tags` ).

    DATA(table) = box->ele( `Table`
        )->a( n = `items`   v = client->_bind( mt_branches )
        )->a( n = `visible` v = |\{= !$\{{ client->_bind( val = mv_new_mode path = abap_true ) }\} | &&
                                |&& $\{{ client->_bind( val = mv_ref_tab path = abap_true ) }\} === 'BRANCHES' \}| ).
    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Branch` ).
    columns->ele( `Column`
        )->a( n = `width`          v = `6rem`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Commit` ).
    columns->ele( `Column`
        )->a( n = `width`  v = `9rem`
        )->a( n = `hAlign` v = `End` ).
    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells` ).
    " the name opens the branch on the remote; without a link it stays text
    cells->tag( `Link`
        )->a( n = `text`    v = `{TEXT}`
        )->a( n = `href`    v = `{LINK}`
        )->a( n = `enabled` v = `{= !!${LINK} }`
        )->a( n = `target`  v = `_blank` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{COMMIT}` ).
    DATA(actions) = cells->ele( `HBox`
        )->a( n = `justifyContent` v = `End` ).
    actions->tag( `Button`
        )->a( n = `text`    v = `Switch`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `visible` v = `{CAN_SWITCH}`
        )->a( n = `press`   v = client->_event( val = `BRANCH_SWITCH` arg = `${NAME}` ) ).
    actions->tag( `Button`
        )->a( n = `text`    v = `Delete`
        )->a( n = `type`    v = `Reject`
        )->a( n = `visible` v = `{CAN_DELETE}`
        )->a( n = `press`   v = client->_event( val = `BRANCH_DELETE` arg = `${NAME}` ) ).

    DATA(tag_table) = box->ele( `Table`
        )->a( n = `items` v = client->_bind( mt_tags )
        )->a( n = `noDataText` v = client->_bind( mv_tags_note )
        )->a( n = `growing` v = `true`
        )->a( n = `growingThreshold` v = `25`
        )->a( n = `visible` v = |\{= !$\{{ client->_bind( val = mv_new_mode path = abap_true ) }\} | &&
                                |&& $\{{ client->_bind( val = mv_ref_tab path = abap_true ) }\} === 'TAGS' \}| ).
    DATA(tag_columns) = tag_table->ele( `columns` ).
    tag_columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Tag` ).
    tag_columns->ele( `Column`
        )->a( n = `width` v = `6rem`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin` v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Commit` ).
    tag_columns->ele( `Column`
        )->a( n = `width` v = `9rem`
        )->a( n = `hAlign` v = `End`
        )->tag( `Text`
            )->a( n = `text` v = `Action` ).
    DATA(tag_cells) = tag_table->ele( `items`
        )->ele( `ColumnListItem`
            )->ele( `cells` ).
    tag_cells->tag( `Link`
        )->a( n = `text` v = `{TEXT}`
        )->a( n = `tooltip` v = `{TEXT}`
        )->a( n = `wrapping` v = `true`
        )->a( n = `href` v = `{LINK}`
        )->a( n = `enabled` v = `{= !!${LINK} }`
        )->a( n = `target` v = `_blank` ).
    tag_cells->tag( `Text`
        )->a( n = `text` v = `{COMMIT}` ).
    DATA(tag_actions) = tag_cells->ele( `HBox`
        )->a( n = `justifyContent` v = `End` ).
    tag_actions->tag( `Button`
        )->a( n = `text` v = `Switch`
        )->a( n = `type` v = `Transparent`
        )->a( n = `visible` v = `{CAN_SWITCH}`
        )->a( n = `press` v = client->_event( val = `TAG_SWITCH` arg = `${NAME}` ) ).

    tag_actions->tag( `Button`
        )->a( n = `text` v = `Delete`
        )->a( n = `type` v = `Reject`
        )->a( n = `visible` v = `{CAN_DELETE}`
        )->a( n = `press` v = client->_event( val = `TAG_DELETE` arg = `${NAME}` ) ).

    DATA(new_box) = box->ele( `VBox`
        )->a( n = `visible` v = client->_bind( mv_new_mode ) ).
    new_box->tag( `Text`
        )->a( n = `text`  v = client->_bind( mv_start_text )
        )->a( n = `class` v = `sapUiSmallMarginBottom` ).
    new_box->tag( `Label`
        )->a( n = `text`     v = `Name`
        )->a( n = `required` v = `true` ).
    new_box->tag( `Input`
        )->a( n = `value`       v = client->_bind( mv_new_name )
        )->a( n = `placeholder` v = `feature/my-change`
        )->a( n = `visible` v = |\{= !$\{{ client->_bind( val = mv_tag_new_mode path = abap_true ) }\} \}| ).
    DATA(tag_form) = new_box->ele( `VBox`
        )->a( n = `visible` v = client->_bind( mv_tag_new_mode ) ).
    tag_form->tag( `Input`
        )->a( n = `value` v = client->_bind( ms_new_tag-name )
        )->a( n = `valueLiveUpdate` v = `true`
        )->a( n = `placeholder` v = `v1.0.0` ).
    tag_form->tag( `Label`
        )->a( n = `text` v = `Type` ).
    tag_form->ele( `Select`
        )->a( n = `selectedKey` v = client->_bind( ms_new_tag-kind )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key` v = `LIGHTWEIGHT`
                )->a( n = `text` v = `Lightweight`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key` v = `ANNOTATED`
                )->a( n = `text` v = `Annotated` ).
    DATA(annotation) = tag_form->ele( `VBox`
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = ms_new_tag-kind path = abap_true ) }\} === 'ANNOTATED' \}| ).
    annotation->tag( `Label`
        )->a( n = `text` v = `Message`
        )->a( n = `required` v = `true` ).
    annotation->tag( `TextArea`
        )->a( n = `width` v = `100%`
        )->a( n = `rows` v = `3`
        )->a( n = `valueLiveUpdate` v = `true`
        )->a( n = `value` v = client->_bind( ms_new_tag-message ) ).
    annotation->tag( `Label`
        )->a( n = `text` v = `Author name`
        )->a( n = `required` v = `true` ).
    annotation->tag( `Input`
        )->a( n = `valueLiveUpdate` v = `true`
        )->a( n = `value` v = client->_bind( ms_new_tag-tagger_name ) ).
    annotation->tag( `Label`
        )->a( n = `text` v = `Author email`
        )->a( n = `required` v = `true` ).
    annotation->tag( `Input`
        )->a( n = `valueLiveUpdate` v = `true`
        )->a( n = `type` v = `Email`
        )->a( n = `value` v = client->_bind( ms_new_tag-tagger_email ) ).

    DATA(buttons) = dialog->ele( `buttons` ).
    buttons->tag( `Button`
        )->a( n = `text`    v = `New branch`
        )->a( n = `icon`    v = `sap-icon://add`
        )->a( n = `visible` v = |\{= !$\{{ client->_bind( val = mv_new_mode path = abap_true ) }\} | &&
                                |&& $\{{ client->_bind( val = mv_ref_tab path = abap_true ) }\} === 'BRANCHES' \}|
        )->a( n = `press`   v = client->_event( `BRANCH_NEW` ) ).
    buttons->tag( `Button`
        )->a( n = `text` v = `New tag`
        )->a( n = `icon` v = `sap-icon://add`
        )->a( n = `visible` v = |\{= !$\{{ client->_bind( val = mv_new_mode path = abap_true ) }\} | &&
                                |&& $\{{ client->_bind( val = mv_ref_tab path = abap_true ) }\} === 'TAGS' \}|
        )->a( n = `press` v = client->_event( `TAG_NEW` ) ).
    buttons->tag( `Button`
        )->a( n = `text`    v = `Close`
        )->a( n = `visible` v = |\{= !$\{{ client->_bind( val = mv_new_mode path = abap_true ) }\} \}|
        )->a( n = `press`   v = client->follow_up_action( val = z2ui5_if_client=>cs_event-popup_close ) ).
    buttons->tag( `Button`
        )->a( n = `text`    v = `Create`
        )->a( n = `type`    v = `Emphasized`
        )->a( n = `visible` v = client->_bind( mv_new_mode )
        )->a( n = `press`   v = client->_event( `BRANCH_CREATE` ) ).
    buttons->tag( `Button`
        )->a( n = `text`    v = `Back`
        )->a( n = `visible` v = client->_bind( mv_new_mode )
        )->a( n = `press`   v = client->_event( `BRANCH_BACK` ) ).

    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD load_branches.

    TRY.
        DATA(lt_branches) = service( )->list_branches( mv_key ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    CLEAR mt_branches.
    LOOP AT lt_branches INTO DATA(ls_branch).
      INSERT VALUE #( name       = ls_branch-name
                      text       = ls_branch-display && COND #( WHEN ls_branch-default = abap_true THEN ` (default)`
                                                                WHEN ls_branch-current = abap_true THEN ` (followed)` )
                      default    = ls_branch-default
                      current    = ls_branch-current
                      sha1       = ls_branch-sha1
                      link       = ls_branch-link
                      commit     = substring( val = ls_branch-sha1 len = nmin( val1 = 7 val2 = strlen( ls_branch-sha1 ) ) )
                      can_switch = xsdbool( ls_branch-current = abap_false )
                      can_delete = xsdbool( ls_branch-current = abap_false AND ls_branch-default = abap_false ) )
        INTO TABLE mt_branches.
    ENDLOOP.
    mv_start_text = |Starts from: { ms_head-branch_display } at { ms_head-remote_commit }|.
    CLEAR: mv_new_name, mv_new_mode, mv_tag_new_mode, ms_new_tag, ms_tag_expected.
    CLEAR: mt_tags, mv_delete_tag, mv_delete_tag_sha1.
    mv_ref_tab = COND #( WHEN mv_is_tag = abap_true THEN `TAGS` ELSE `BRANCHES` ).
    IF mv_ref_tab = `TAGS`.
      load_tags( ).
    ENDIF.
    popup_branches_display( ).

  ENDMETHOD.

  METHOD load_tags.
    CLEAR mt_tags.
    mv_tags_note = `The remote has no tags`.
    TRY.
        DATA(lt_tags) = service( )->list_tags( mv_key ).
        LOOP AT lt_tags INTO DATA(ls_tag).
          APPEND VALUE #( name = ls_tag-name text = ls_tag-display
            && COND #( WHEN ls_tag-current = abap_true THEN ` (selected)` )
            current = ls_tag-current sha1 = ls_tag-sha1 ref_sha1 = ls_tag-ref_sha1 link = ls_tag-link
            commit = COND #( WHEN ls_tag-sha1 IS NOT INITIAL THEN substring(
              val = ls_tag-sha1 len = nmin( val1 = 7 val2 = strlen( ls_tag-sha1 ) ) ) ELSE `Unresolved` )
            can_switch = xsdbool( ls_tag-current = abap_false AND ls_tag-sha1 IS NOT INITIAL )
            can_delete = xsdbool( ls_tag-current = abap_false AND ls_tag-ref_sha1 IS NOT INITIAL ) ) TO mt_tags.
        ENDLOOP.
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        mv_tags_note = `Tags could not be loaded. Select Branches and then Tags to retry.`.
        show_error( lx_error ).
    ENDTRY.
  ENDMETHOD.

  METHOD new_tag.
    TRY.
        ms_tag_expected = service( )->tag_target( mv_key ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.
    ms_new_tag = VALUE #( kind = `LIGHTWEIGHT` tagger_name = ms_tag_expected-name tagger_email = ms_tag_expected-email ).
    mv_start_text = |Creates a tag on the remote at { zcl_ag2ui5_repo_service=>branch_display( ms_tag_expected-ref ) }| &&
      | ({ ms_tag_expected-sha1 }). Local changes are not included. The selected reference stays unchanged.|.
    mv_new_mode = abap_true.
    mv_tag_new_mode = abap_true.
  ENDMETHOD.

  METHOD create_tag.
    TRY.
        DATA(lv_tag) = service( )->create_tag( iv_key = mv_key is_tag = ms_new_tag is_expected = ms_tag_expected ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.
    CLEAR: mv_new_mode, mv_tag_new_mode, ms_new_tag, ms_tag_expected.
    load_tags( ).
    popup_branches_display( ).
    client->message_toast_display( |Created { zcl_ag2ui5_repo_service=>branch_display( lv_tag ) }| ).
  ENDMETHOD.

  METHOD delete_tag.
    TRY.
        service( )->delete_tag( iv_key = mv_key iv_tag = mv_delete_tag iv_ref_sha1 = mv_delete_tag_sha1 ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.
    client->message_toast_display( |Deleted { zcl_ag2ui5_repo_service=>branch_display( mv_delete_tag ) }| ).
    load_tags( ).
  ENDMETHOD.

  METHOD switch_tag.
    TRY.
        service( )->switch_tag( iv_key = mv_key iv_tag = iv_tag iv_sha1 = iv_sha1 ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.
    client->popup_destroy( ).
    client->message_toast_display( |Selected { zcl_ag2ui5_repo_service=>branch_display( iv_tag ) }. Pull separately to import it.| ).
    load_status( ).
  ENDMETHOD.

  METHOD switch_branch.

    TRY.
        service( )->switch_branch( iv_key    = mv_key
                                   iv_branch = iv_branch ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    client->popup_destroy( ).
    client->message_toast_display( |Following { zcl_ag2ui5_repo_service=>branch_display( iv_branch ) } now| ).
    load_status( ).

  ENDMETHOD.

  METHOD create_branch.

    TRY.
        DATA(lv_branch) = service( )->create_branch( iv_key  = mv_key
                                                     iv_name = mv_new_name ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        " the dialog stays open with the name
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    client->popup_destroy( ).
    client->message_toast_display( |Created and following { substring( val = lv_branch off = 11 ) }| ).
    load_status( ).

  ENDMETHOD.

  METHOD delete_branch.

    TRY.
        DATA(lv_sha1) = service( )->delete_branch( iv_key    = mv_key
                                                   iv_branch = mv_delete_branch
                                                   iv_sha1   = mv_delete_sha1 ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    client->message_toast_display(
      |Deleted { substring( val = mv_delete_branch off = 11 ) } (was at { substring( val = lv_sha1 len = 7 ) })| ).
    " the list without the deleted branch, the current one picked again
    load_branches( ).

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
    cells->ele( `HBox`
        )->ele( `items`
            )->tag( `Link`
                )->a( n = `text`    v = `{OBJ_NAME}`
                )->a( n = `href`    v = `{OBJECT_LINK}`
                )->a( n = `visible` v = `{= ${OBJECT_LINK} !== '' }`
                )->a( n = `tooltip` v = `Open object in ADT`
            )->tag( `Text`
                )->a( n = `text`    v = `{OBJ_NAME}`
                )->a( n = `visible` v = `{= ${OBJECT_LINK} === '' }` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{REASON}` ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        CLEAR: mv_zip, mv_upload, mv_upload_path, mv_files_open, mt_object_files, mv_files_title,
          mt_object_summary, mt_semantic, mv_object_summary_note.
        leave_list( ).
      WHEN `HEADER_LABEL`.
        DATA(lv_label) = client->get_event_arg( ).
        IF lv_label IS NOT INITIAL AND line_exists( ms_head-labels[ text = lv_label ] ).
          DATA(lv_label_event) = |LABEL_FILTER:{ lv_label }|.
          CLEAR: mv_zip, mv_upload, mv_upload_path.
          leave_list( lv_label_event ).
        ENDIF.
      WHEN `REFRESH`.
        load_status( ).
      WHEN `LABELS_EDIT`.
        labels_open( ).
      WHEN `LABELS_ADD`.
        labels_add( ).
      WHEN `LABELS_SAVE`.
        labels_save( ).
      WHEN `LABELS_CANCEL`.
        labels_close( ).
      WHEN `VIEW`.
        save_view_settings( ).
        rows_build( ).
      WHEN `REPO_DIFF`.
        repo_diff_open( ).
      WHEN `SORT`.
        " the choice comes from the browser: only the known ones
        CASE client->get_event_arg( ).
          WHEN `OBJECT` OR `FILE` OR `TYPE`.
            mv_sort = client->get_event_arg( ).
          WHEN `CHANGES_FIRST`.
            mv_changes_first = xsdbool( mv_changes_first = abap_false ).
          WHEN OTHERS.
            RETURN.
        ENDCASE.
        save_view_settings( ).
        rows_build( ).
        " the ticks in the menu are part of the view
        view_display( ).
      WHEN `OVERVIEW`.
        IF mv_overview <> `FILES` AND mv_overview <> `OBJECTS`.
          mv_overview = `FILES`.
        ENDIF.
        zcl_ag2ui5_settings=>get_instance( )->set(
          iv_key = zif_ag2ui5_settings=>c_key-status_overview iv_value = mv_overview ).
        rows_build( ).
        view_display( ).
      WHEN `SEMANTIC`.
        READ TABLE mt_semantic INTO DATA(ls_semantic) WITH KEY
          path = client->get_event_arg( ) filename = client->get_event_arg( 2 ) id = client->get_event_arg( 3 ).
        IF sy-subrc <> 0 OR mv_files_open = abap_false.
          RETURN.
        ENDIF.
        READ TABLE mt_status INTO DATA(ls_semantic_file) WITH KEY path = ls_semantic-path filename = ls_semantic-filename.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        client->popup_destroy( ).
        client->nav_app_call( zcl_ag2ui5_app_diff=>create(
          iv_key = mv_key iv_zip = mv_zip iv_path = ls_semantic-path iv_filename = ls_semantic-filename
          iv_obj_type = ls_semantic_file-obj_type iv_obj_name = ls_semantic_file-obj_name
          iv_object_link = ls_semantic_file-object_link iv_focus = ls_semantic-id
          iv_remote_sha1 = ls_semantic_file-remote_sha1 iv_remote_known = abap_true
          iv_remote_is_new = zcl_ag2ui5_repo_service=>remote_is_new(
            iv_lstate = ls_semantic_file-lstate iv_rstate = ls_semantic_file-rstate ) ) ).
      WHEN `OBJECT`.
        open_object_files( ).
      WHEN `FILES_CLOSE`.
        CLEAR: mv_files_open, mt_object_files, mv_files_title, mt_object_summary, mt_semantic, mv_object_summary_note.
        client->popup_destroy( ).
      WHEN `STAGE`.
        IF mv_can_stage = abap_false.
          RETURN.
        ENDIF.
        client->nav_app_call( zcl_ag2ui5_app_stage=>create( iv_key = mv_key iv_title = ms_head-name ) ).
      WHEN `DIFF`.
        IF mv_offline = abap_true AND mv_zip IS INITIAL.
          RETURN.
        ENDIF.
        READ TABLE mt_rows INTO DATA(ls_row)
          WITH KEY path = client->get_event_arg( ) filename = client->get_event_arg( 2 ).
        IF sy-subrc <> 0.
          READ TABLE mt_object_files INTO ls_row
            WITH KEY path = client->get_event_arg( ) filename = client->get_event_arg( 2 ).
        ENDIF.
        IF sy-subrc = 0.
          READ TABLE mt_status INTO DATA(ls_server)
            WITH KEY path = ls_row-path filename = ls_row-filename.
          DATA(lv_known) = xsdbool( sy-subrc = 0 ).
          client->nav_app_call( zcl_ag2ui5_app_diff=>create( iv_key      = mv_key
                                                             iv_zip      = mv_zip
                                                             iv_path     = ls_row-path
                                                             iv_filename = ls_row-filename
                                                             iv_obj_type = ls_row-obj_type
                                                             iv_obj_name = ls_row-obj_name
                                                             iv_object_link = ls_row-object_link
                                                             iv_remote_sha1 = ls_server-remote_sha1
                                                             iv_remote_known = lv_known
                                                             iv_remote_is_new = zcl_ag2ui5_repo_service=>remote_is_new(
                                                                                  iv_lstate = ls_row-lstate
                                                                                  iv_rstate = ls_row-rstate ) ) ).
        ENDIF.
      WHEN `BRANCHES`.
        IF mv_offline = abap_false.
          load_branches( ).
        ENDIF.
      WHEN `BRANCH_SWITCH`.
        " the row's name comes from the browser: only a listed, switchable one
        READ TABLE mt_branches INTO DATA(ls_switch) WITH KEY name = client->get_event_arg( ).
        IF sy-subrc = 0 AND ls_switch-can_switch = abap_true.
          switch_branch( ls_switch-name ).
        ENDIF.
      WHEN `BRANCH_NEW`.
        CLEAR: mv_new_name, mv_tag_new_mode, ms_new_tag, ms_tag_expected.
        mv_new_mode = abap_true.
      WHEN `REF_TAB`.
        IF mv_offline = abap_false AND mv_new_mode = abap_false.
          IF mv_ref_tab = `TAGS`.
            load_tags( ).
          ELSE.
            mv_ref_tab = `BRANCHES`.
          ENDIF.
        ENDIF.
      WHEN `TAG_SWITCH`.
        READ TABLE mt_tags INTO DATA(ls_tag_switch) WITH KEY name = client->get_event_arg( ).
        IF mv_offline = abap_false AND mv_ref_tab = `TAGS` AND sy-subrc = 0 AND ls_tag_switch-can_switch = abap_true.
          switch_tag( iv_tag = ls_tag_switch-name iv_sha1 = ls_tag_switch-sha1 ).
        ENDIF.
      WHEN `TAG_NEW`.
        IF mv_offline = abap_false AND mv_ref_tab = `TAGS` AND mv_new_mode = abap_false.
          new_tag( ).
        ENDIF.
      WHEN `TAG_DELETE`.
        CLEAR: mv_delete_tag, mv_delete_tag_sha1.
        READ TABLE mt_tags INTO DATA(ls_tag_delete) WITH KEY name = client->get_event_arg( ).
        IF mv_offline = abap_false AND mv_ref_tab = `TAGS` AND mv_new_mode = abap_false
            AND sy-subrc = 0 AND ls_tag_delete-can_delete = abap_true.
          mv_delete_tag = ls_tag_delete-name.
          mv_delete_tag_sha1 = ls_tag_delete-ref_sha1.
          client->message_box_display(
            text = |Delete tag { ls_tag_delete-text } on the remote (commit: { ls_tag_delete-commit })? | &&
                   |This app cannot undo it. The local objects stay unchanged.|
            type = `confirm`
            actions = VALUE #( ( `CANCEL` ) ( `DELETE` ) )
            emphasizedaction = `CANCEL`
            onclose = `TAG_DELETE_CLOSE` ).
        ENDIF.
      WHEN `TAG_DELETE_CLOSE`.
        IF client->get_event_arg( ) = `DELETE` AND mv_delete_tag IS NOT INITIAL
            AND mv_delete_tag_sha1 IS NOT INITIAL AND mv_offline = abap_false.
          delete_tag( ).
        ENDIF.
        CLEAR: mv_delete_tag, mv_delete_tag_sha1.
      WHEN `BRANCH_BACK`.
        CLEAR: mv_new_mode, mv_tag_new_mode, ms_new_tag, ms_tag_expected.
        mv_start_text = |Starts from: { ms_head-branch_display } at { ms_head-remote_commit }|.
      WHEN `BRANCH_CREATE`.
        IF mv_new_mode = abap_true AND mv_offline = abap_false.
          IF mv_tag_new_mode = abap_true AND mv_ref_tab = `TAGS` AND ms_tag_expected-sha1 IS NOT INITIAL.
            create_tag( ).
          ELSEIF mv_tag_new_mode = abap_false AND mv_ref_tab = `BRANCHES`.
            create_branch( ).
          ENDIF.
        ENDIF.
      WHEN `BRANCH_DELETE`.
        READ TABLE mt_branches INTO DATA(ls_delete) WITH KEY name = client->get_event_arg( ).
        IF sy-subrc = 0 AND ls_delete-can_delete = abap_true.
          mv_delete_branch = ls_delete-name.
          mv_delete_sha1   = ls_delete-sha1.
          client->message_box_display(
            text             = |Delete branch { ls_delete-text } (at {
                                 substring( val = ls_delete-sha1 len = nmin( val1 = 7 val2 = strlen( ls_delete-sha1 ) ) )
                               }) on GitHub? abapGit cannot undo this.|
            type             = `confirm`
            actions          = VALUE #( ( `DELETE` ) ( `CANCEL` ) )
            emphasizedaction = `CANCEL`
            onclose          = `BRANCH_DELETE_CLOSE` ).
        ENDIF.
      WHEN `BRANCH_DELETE_CLOSE`.
        " only a confirmation this page opened deletes
        IF client->get_event_arg( ) = `DELETE` AND mv_delete_branch IS NOT INITIAL.
          delete_branch( ).
        ENDIF.
        CLEAR: mv_delete_branch, mv_delete_sha1.
      WHEN `PULL`.
        IF mv_offline = abap_true.
          popup_upload_display( ).
        ELSE.
          preview_pull( ).
        ENDIF.
      WHEN `ZIP_UPLOAD`.
        upload_zip( ).
      WHEN `ZIP_CANCEL`.
        CLEAR: mv_upload, mv_upload_path.
        client->popup_destroy( ).
      WHEN `EXPORT_ZIP`.
        export_zip( ).
      WHEN `PULL_CANCEL`.
        CLEAR: ms_decisions, mv_ack_text, mv_acknowledged, ms_transport_types,
               mt_transports, mv_transport, mt_customizing, mv_customizing.
        client->popup_destroy( ).
      WHEN `PULL_SELECTED`.
        pull_selected( ).
      WHEN `PULL_MARK_ALL`.
        mark_decisions( abap_true ).
      WHEN `PULL_UNMARK_ALL`.
        mark_decisions( abap_false ).
    ENDCASE.

  ENDMETHOD.

  METHOD leave_list.
    zcl_ag2ui5_app_repos=>write_route( client ).
    IF client->check_app_prev_stack( ).
      client->nav_app_leave( r_data = iv_message ).
    ELSE.
      client->nav_app_leave( app = NEW zcl_ag2ui5_app_repos( ) r_data = iv_message ).
    ENDIF.
  ENDMETHOD.

  METHOD repo_diff_open.
    IF can_repo_diff( ) = abap_false.
      RETURN.
    ENDIF.
    " every changed file in file order, independent of filter and sort
    DATA(lt_changed) = mt_status.
    DELETE lt_changed WHERE changed = abap_false.
    client->nav_app_call( zcl_ag2ui5_app_repo_diff=>create(
      iv_key   = mv_key
      iv_title = ms_head-name
      iv_zip   = mv_zip
      it_files = zcl_ag2ui5_repo_service=>sort_status_rows( it_rows          = lt_changed
                                                           iv_by            = `FILE`
                                                           iv_changes_first = abap_true ) ) ).
  ENDMETHOD.

  METHOD load_status.

    CLEAR: mv_files_open, mt_object_files, mv_files_title, mt_object_summary, mt_semantic, mv_object_summary_note.
    TRY.
        DATA(ls_status) = service( )->get_status( iv_key = mv_key iv_zip = mv_zip ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        CLEAR: mt_rows, mt_status, mv_loaded, mv_can_diff.
        mv_no_data = `Status could not be loaded`.
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    mv_loaded = abap_true.
    mv_offline = ls_status-offline.
    mv_remote_label = COND #( WHEN mv_offline = abap_true THEN `ZIP` ELSE `Remote` ).
    mv_pull_text = COND #( WHEN mv_offline = abap_true THEN `Import ZIP` ELSE `Pull` ).
    mv_row_type = COND #( WHEN mv_offline = abap_true AND mv_zip IS INITIAL THEN `Inactive` ELSE `Navigation` ).
    " Rule removal must stay reachable after all ignored files were committed
    mv_is_tag = xsdbool( ls_status-branch CP `refs/tags/*` ).
    mv_can_stage = xsdbool( mv_offline = abap_false AND mv_is_tag = abap_false ).
    ms_head = CORRESPONDING #( ls_status ).
    ms_head-remote_commit = COND #( WHEN strlen( ls_status-remote_commit ) > 7
                                    THEN substring( val = ls_status-remote_commit len = 7 )
                                    ELSE ls_status-remote_commit ).

    mt_status = ls_status-rows.
    mv_can_diff = can_repo_diff( ).
    rows_build( ).
  ENDMETHOD.

  METHOD preview_pull.

    CLEAR: ms_decisions, mv_ack_text, mv_acknowledged, ms_transport_types,
           mt_transports, mv_transport, mt_customizing, mv_customizing.

    TRY.
        DATA(ls_preview) = service( )->preview_pull( iv_key = mv_key iv_zip = mv_zip ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
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
        show_error( lx_error ).
        RETURN.
    ENDTRY.

    popup_decisions_display( ).

  ENDMETHOD.

  METHOD mark_decisions.

    " References are local only; every group holds the same plain row type.
    DATA lt_groups TYPE STANDARD TABLE OF REF TO zif_ag2ui5_repo_service=>ty_decision_items WITH EMPTY KEY.
    lt_groups = VALUE #( ( REF #( ms_decisions-data_loss ) ) ( REF #( ms_decisions-delete ) )
      ( REF #( ms_decisions-overwrite ) ) ( REF #( ms_decisions-package ) )
      ( REF #( ms_decisions-import ) ) ).
    LOOP AT lt_groups INTO DATA(lr_group).
      LOOP AT lr_group->* ASSIGNING FIELD-SYMBOL(<ls_item>).
        <ls_item>-selected = xsdbool( iv_selected = abap_true AND <ls_item>-selectable = abap_true ).
      ENDLOOP.
    ENDLOOP.
    " Unsupported objects never participate, even if a posted flag was changed.
    LOOP AT ms_decisions-skipped ASSIGNING <ls_item>.
      <ls_item>-selected = abap_false.
    ENDLOOP.

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
                                            iv_zip          = mv_zip
                                            it_items        = lt_items
                                            iv_acknowledged = mv_acknowledged
                                            iv_transport    = mv_transport
                                            iv_customizing  = mv_customizing ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
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

  METHOD popup_upload_display.

    CLEAR: mv_upload, mv_upload_path.
    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns`       v = `sap.m`
            )->a( n = `xmlns:core`  v = `sap.ui.core`
            )->a( n = `xmlns:z2ui5` v = `z2ui5.cc` ).
    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title`      v = `Import ZIP`
        )->a( n = `afterClose` v = client->_event( `ZIP_CANCEL` ) ).
    dialog->ele( `content`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin`
            )->tag( `Text`
                )->a( n = `text` v = `Choose an abapGit ZIP or a GitHub source ZIP. Review the decisions before importing.`
            )->tag( n = `FileUploader` ns = `z2ui5`
                )->a( n = `value`  v = client->_bind( mv_upload )
                )->a( n = `path`   v = client->_bind( mv_upload_path )
                )->a( n = `upload` v = client->_event( `ZIP_UPLOAD` ) ).
    dialog->ele( `endButton`
        )->tag( `Button`
            )->a( n = `text`  v = `Cancel`
            )->a( n = `press` v = client->_event( `ZIP_CANCEL` ) ).
    client->popup_display( popup->stringify( ) ).

  ENDMETHOD.

  METHOD upload_zip.

    DATA(lv_upload) = mv_upload.
    CLEAR: mv_upload, mv_upload_path.
    IF mv_offline = abap_false.
      RETURN.
    ENDIF.
    TRY.
        DATA(lv_zip) = zcl_ag2ui5_repo_service=>decode_zip( lv_upload ).
      CATCH cx_root INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.
    mv_zip = lv_zip.
    client->popup_destroy( ).
    load_status( ).
    view_display( ).
    preview_pull( ).

  ENDMETHOD.

  METHOD export_zip.

    IF mv_offline = abap_false.
      RETURN.
    ENDIF.
    TRY.
        DATA(lv_zip) = service( )->export_zip( mv_key ).
        DATA(lv_base64) = cl_http_utility=>encode_x_base64( lv_zip ).
        client->follow_up_action( val = client->cs_event-download_b64_file
                                  t_arg = VALUE #( ( `data:application/zip;base64,` && lv_base64 )
                                                   ( `repository.zip` ) ) ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        show_error( lx_error ).
    ENDTRY.

  ENDMETHOD.

  METHOD show_error.
    IF zcl_ag2ui5_repo_service=>login_required( ix_error ) = abap_true.
      " abapGit's user exit has no credentials for this remote
      client->popup_destroy( ).
      client->nav_app_call( zcl_ag2ui5_app_login=>create( iv_key = mv_key ) ).
      RETURN.
    ENDIF.
    client->message_box_display( text = ix_error->get_text( ) type = `error` ).
  ENDMETHOD.

  METHOD can_repo_diff.
    rv_can = xsdbool( line_exists( mt_status[ changed = abap_true ] )
                      AND NOT ( mv_offline = abap_true AND mv_zip IS INITIAL ) ).
  ENDMETHOD.

  METHOD service.
    ri_service = COND #( WHEN mi_service IS BOUND THEN mi_service ELSE NEW zcl_ag2ui5_repo_service( ) ).
  ENDMETHOD.

  METHOD state_text.

    rv_text = SWITCH #( iv_state
                        WHEN `A` THEN `added`
                        WHEN `M` THEN `modified`
                        WHEN `D` THEN `deleted`
                        WHEN `MIXED` THEN `mixed` ).

  ENDMETHOD.

  METHOD messages_text.

    DATA lt_lines TYPE string_table.

    LOOP AT it_messages INTO DATA(ls_message) WHERE type = `E` OR type = `A` OR type = `W`.
      INSERT |{ ls_message-obj_type } { ls_message-obj_name }: { ls_message-text }| INTO TABLE lt_lines.
    ENDLOOP.

    rv_text = concat_lines_of( table = lt_lines sep = |\n| ).

  ENDMETHOD.

  METHOD save_view_settings.

    DATA(li_settings) = zcl_ag2ui5_settings=>get_instance( ).
    li_settings->set( iv_key = zif_ag2ui5_settings=>c_key-status_view          iv_value = mv_view ).
    li_settings->set( iv_key = zif_ag2ui5_settings=>c_key-status_sort          iv_value = mv_sort ).
    li_settings->set( iv_key = zif_ag2ui5_settings=>c_key-status_changes_first iv_value = CONV #( mv_changes_first ) ).

  ENDMETHOD.

ENDCLASS.
