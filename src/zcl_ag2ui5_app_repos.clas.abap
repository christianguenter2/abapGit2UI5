"! Start app: every abapGit repository of the system. Start it with
"! ?app_start=zcl_ag2ui5_app_repos
CLASS zcl_ag2ui5_app_repos DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_row,
        key             TYPE string,
        name            TYPE string,
        package         TYPE string,
        url             TYPE string,
        branch_display  TYPE string,
        branch_link     TYPE string,
        deserialized_at TYPE string,
        offline         TYPE abap_bool,
        favorite        TYPE abap_bool,
        favorite_icon   TYPE string,
        favorite_text   TYPE string,
        "! Navigation for every repository
        nav_type        TYPE string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA mt_repos  TYPE ty_rows.
    DATA mv_search TYPE string.
    DATA mv_favorites_only TYPE abap_bool.
    DATA mv_empty TYPE abap_bool.
    DATA mv_empty_text TYPE string.
    "! LIST or TILES; switched on the client, stored per user
    DATA mv_layout TYPE string VALUE `TILES`.

    DATA mv_delete_title TYPE string.
    DATA mv_delete_text TYPE string.
    DATA mv_delete_confirmation TYPE string.
    DATA mv_delete_transport TYPE string.
    DATA mv_delete_error TYPE string.
    DATA mt_delete_objects TYPE zif_ag2ui5_repo_service=>ty_delete_objects.
    DATA mt_delete_transports TYPE zif_ag2ui5_repo_service=>ty_transports.
    DATA mt_delete_messages TYPE zif_ag2ui5_repo_service=>ty_messages.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    "! The unfiltered list; mt_repos is what the search leaves of it
    DATA mt_all TYPE ty_rows.
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.
    DATA ms_delete_preview TYPE zif_ag2ui5_repo_service=>ty_delete_preview.
    DATA mv_delete_failed TYPE abap_bool.
    DATA mv_delete_package TYPE string.

    METHODS view_display.
    METHODS tiles_display
      IMPORTING
        io_content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS on_event.
    METHODS load_repos.
    METHODS apply_search.
    METHODS favorite_set.
    METHODS favorites_filter IMPORTING iv_value TYPE string.
    METHODS favorite_display IMPORTING io_parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    CLASS-METHODS filtered_repos
      IMPORTING it_rows TYPE ty_rows iv_search TYPE string iv_favorites_only TYPE abap_bool
      RETURNING VALUE(rt_rows) TYPE ty_rows.
    METHODS open_repo.
    METHODS service RETURNING VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.
    METHODS actions_display IMPORTING io_parent TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS delete_open IMPORTING iv_action TYPE string.
    METHODS delete_display.
    METHODS delete_confirm.
    METHODS delete_clear.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_repos IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ).
      " back on the list, a repository was left: the Git credentials of the
      " session login go, and the session needs no state any more. abap2UI5
      " switches back only when this app made the session stateful itself:
      " on now, off in the next round trip (SESSION_END)
      service( )->logoff( ).
      IF zcl_ag2ui5_app_login=>is_stateful( ) = abap_true.
        client->set_session_stateful( abap_true ).
        client->follow_up_action( val   = client->cs_event-start_timer
                                  t_arg = VALUE #( ( `SESSION_END` ) ( `10` ) ) ).
      ENDIF.
      mv_layout = zcl_ag2ui5_settings=>get_instance( )->get(
                    iv_key     = zif_ag2ui5_settings=>c_key-repos_layout
                    iv_default = `TILES` ).
      mv_favorites_only = xsdbool( zcl_ag2ui5_settings=>get_instance( )->get(
        iv_key = zif_ag2ui5_settings=>c_key-repos_favorites_only iv_default = `` ) = `X` ).
      " also on the way back from a pull, so "Last pull" is current
      load_repos( ).
      view_display( ).
      " a page that created a repository hands its message over when it leaves
      DATA(lr_message) = client->get( )-r_event_data.
      IF lr_message IS BOUND.
        ASSIGN lr_message->* TO FIELD-SYMBOL(<lv_message>).
        client->message_toast_display( CONV #( <lv_message> ) ).
      ENDIF.
      " start typing right away: the cursor behind what is in the field,
      " scheduled for after the response, when the view is rendered
      DATA(lv_end) = |{ strlen( mv_search ) }|.
      client->follow_up_action( val   = client->cs_event-set_focus
                                t_arg = VALUE #( ( `search` ) ( lv_end ) ( lv_end ) ) ).
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
            )->a( n = `xmlns:f`      v = `sap.f`
            )->a( n = `xmlns:card`   v = `sap.f.cards`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    " the header is an overflow toolbar: on a narrow screen the buttons move
    " into its menu, the title stays
    DATA(page) = view->ele( `Page` ).
    DATA(header_content) = page->ele( `customHeader` )->ele( `OverflowToolbar` ).
    header_content->ele( `Title`
        )->a( n = `text`  v = `abapGit - Repositories`
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `false` ).
    header_content->tag( `ToolbarSpacer` ).
    header_content->ele( `OverflowToolbarToggleButton`
        )->a( n = `text`    v = `Favorites only`
        )->a( n = `icon`    v = `sap-icon://favorite`
        )->a( n = `tooltip` v = `Favorites only`
        )->a( n = `pressed` v = client->_bind( mv_favorites_only )
        )->a( n = `press`   v = client->_event( val = `FAVORITES_FILTER` arg = `${$parameters>/pressed}` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `Low` ).
    header_content->tag( `Button`
        )->a( n = `text`  v = `New repository`
        )->a( n = `icon`  v = `sap-icon://add`
        )->a( n = `press` v = client->_event( `NEW` ) ).
    " icon only in the bar, with its text in the overflow menu
    header_content->tag( `OverflowToolbarButton`
        )->a( n = `icon`    v = `sap-icon://refresh`
        )->a( n = `text`    v = `Refresh`
        )->a( n = `tooltip` v = `Refresh`
        )->a( n = `press`   v = client->_event( `REFRESH` ) ).

    page->ele( `subHeader`
        )->ele( `Toolbar`
            )->tag( `SearchField`
                )->a( n = `id`          v = `search`
                )->a( n = `value`       v = client->_bind( mv_search )
                )->a( n = `placeholder` v = `Search name, package or URL`
                )->a( n = `search`      v = client->_event( `SEARCH` )
            )->ele( `SegmentedButton`
                )->a( n = `selectedKey`     v = client->_bind( mv_layout )
                )->a( n = `selectionChange` v = client->_event( `LAYOUT` )
                )->ele( `items`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`     v = `LIST`
                        )->a( n = `icon`    v = `sap-icon://list`
                        )->a( n = `tooltip` v = `List`
                    )->tag( `SegmentedButtonItem`
                        )->a( n = `key`     v = `TILES`
                        )->a( n = `icon`    v = `sap-icon://grid`
                        )->a( n = `tooltip` v = `Tiles` ).

    " both layouts are in the view; the toggle only switches which one shows
    DATA(content) = page->ele( `content` ).
    DATA(table) = content->ele( `Table`
        )->a( n = `items`      v = client->_bind( mt_repos )
        )->a( n = `noDataText` v = `No repositories found`
        )->a( n = `visible`    v = |\{= $\{{ client->_bind( val = mv_layout path = abap_true ) }\} === 'LIST' && !$\{{ client->_bind( val = mv_empty path = abap_true ) }\} \}| ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `3rem`
        )->tag( n = `Icon` ns = `core`
            )->a( n = `src` v = `sap-icon://favorite`
            )->a( n = `tooltip` v = `Favorite` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Name` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Package` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Desktop`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `URL` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Branch` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Desktop`
        )->a( n = `demandPopin`    v = `true`
        )->tag( `Text`
            )->a( n = `text` v = `Last pull` ).
    columns->ele( `Column`
        )->a( n = `minScreenWidth` v = `Tablet`
        )->a( n = `demandPopin`    v = `true`
        )->a( n = `width` v = `10rem`
        )->tag( `Text`
            )->a( n = `text` v = `Actions` ).

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type`  v = `{NAV_TYPE}`
            )->a( n = `press` v = client->_event( val = `OPEN` arg = `${KEY}` )
            )->ele( `cells` ).
    favorite_display( cells ).
    cells->tag( `ObjectIdentifier`
        )->a( n = `title` v = `{NAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{PACKAGE}` ).
    " a link opens in a new tab; a click on it does not open the repository
    cells->tag( `Link`
        )->a( n = `text`   v = `{URL}`
        )->a( n = `href`   v = `{URL}`
        )->a( n = `target` v = `_blank` ).
    cells->tag( `Link`
        )->a( n = `text`    v = `{BRANCH_DISPLAY}`
        )->a( n = `href`    v = `{BRANCH_LINK}`
        )->a( n = `enabled` v = `{= !!${BRANCH_LINK} }`
        )->a( n = `target`  v = `_blank` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{DESERIALIZED_AT}` ).
    actions_display( cells ).

    tiles_display( content ).

    DATA(empty) = content->ele( `VBox`
        )->a( n = `visible` v = client->_bind( mv_empty )
        )->a( n = `alignItems` v = `Center`
        )->a( n = `class` v = `sapUiLargeMargin` ).
    empty->tag( `Text`
        )->a( n = `text` v = client->_bind( mv_empty_text ) ).
    empty->tag( `Button`
        )->a( n = `text` v = `Show all repositories`
        )->a( n = `visible` v = client->_bind( mv_favorites_only )
        )->a( n = `press` v = client->_event( `SHOW_ALL` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD tiles_display.

    DATA(grid) = io_content->ele( n = `GridContainer` ns = `f`
        )->a( n = `items`   v = client->_bind( mt_repos )
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = mv_layout path = abap_true ) }\} === 'TILES' && !$\{{ client->_bind( val = mv_empty path = abap_true ) }\} \}|
        )->a( n = `class`   v = `sapUiSmallMargin` ).
    grid->ele( n = `layout` ns = `f`
        )->tag( n = `GridContainerSettings` ns = `f`
            )->a( n = `columnSize` v = `20rem`
            )->a( n = `gap`        v = `1rem` ).

    " a click on the header opens the repository, as a table row does
    DATA(card) = grid->ele( n = `Card` ns = `f`
        )->a( n = `width` v = `100%` ).
    DATA(header) = card->ele( n = `header` ns = `f`
        )->ele( n = `Header` ns = `card`
            )->a( n = `title`    v = `{NAME}`
            )->a( n = `subtitle` v = `{PACKAGE}`
            )->a( n = `iconSrc`  v = `{= ${OFFLINE} ? 'sap-icon://disconnected' : 'sap-icon://cloud' }`
            )->a( n = `press`    v = client->_event( val = `OPEN` arg = `${KEY}` ) ).

    " Header actions stay separate from the repository-opening press event.
    DATA(header_actions) = header->ele( n = `toolbar` ns = `card` ).
    favorite_display( header_actions ).

    DATA(box) = card->ele( n = `content` ns = `f`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMarginBeginEnd sapUiTinyMarginBottom` ).

    " a link opens in a new tab; a click on it does not open the repository
    " a URL has no blank to wrap at: cut it off at the card's inner width
    " (column 20rem less the margins); the tooltip has all of it
    box->tag( `Link`
        )->a( n = `text`    v = `{URL}`
        )->a( n = `href`    v = `{URL}`
        )->a( n = `target`  v = `_blank`
        )->a( n = `width`   v = `18rem`
        )->a( n = `tooltip` v = `{URL}` ).
    box->ele( `ObjectAttribute`
        )->a( n = `title`   v = `Branch`
        )->a( n = `visible` v = `{= !!${BRANCH_DISPLAY} }`
        )->ele( `customContent`
            )->tag( `Link`
                )->a( n = `text`    v = `{BRANCH_DISPLAY}`
                )->a( n = `href`    v = `{BRANCH_LINK}`
                )->a( n = `enabled` v = `{= !!${BRANCH_LINK} }`
                )->a( n = `target`  v = `_blank` ).
    box->tag( `ObjectAttribute`
        )->a( n = `title`   v = `Last pull`
        )->a( n = `text`    v = `{DESERIALIZED_AT}`
        )->a( n = `visible` v = `{= !!${DESERIALIZED_AT} }` ).
    actions_display( box ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `SESSION_END`.
        " second half of the switch back to stateless, see main( )
        client->set_session_stateful( abap_false ).
        zcl_ag2ui5_app_login=>set_stateful( abap_false ).
      WHEN `SEARCH`.
        apply_search( ).
      WHEN `FAVORITE`.
        favorite_set( ).
      WHEN `FAVORITES_FILTER`.
        favorites_filter( client->get_event_arg( ) ).
      WHEN `SHOW_ALL`.
        favorites_filter( `` ).
      WHEN `REFRESH`.
        load_repos( ).
      WHEN `OPEN`.
        open_repo( ).
      WHEN `LAYOUT`.
        " switching happens on the client; the server only remembers it
        zcl_ag2ui5_settings=>get_instance( )->set( iv_key   = zif_ag2ui5_settings=>c_key-repos_layout
                                                   iv_value = mv_layout ).
      WHEN `NEW`.
        client->nav_app_call( zcl_ag2ui5_app_new_repo=>create( ) ).
      WHEN `REMOVE` OR `UNINSTALL`.
        delete_open( client->get_event( ) ).
      WHEN `DELETE_CONFIRM`.
        delete_confirm( ).
      WHEN `DELETE_CANCEL`.
        client->popup_destroy( ).
        delete_clear( ).
        load_repos( ).
    ENDCASE.

  ENDMETHOD.

  METHOD load_repos.

    TRY.
        DATA(lt_repos) = service( )->list_repos( ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    CLEAR mt_all.
    LOOP AT lt_repos INTO DATA(ls_repo).
      DATA(ls_row) = CORRESPONDING ty_row( ls_repo ).
      ls_row-nav_type = `Navigation`.
      ls_row-favorite_icon = COND #( WHEN ls_row-favorite = abap_true
        THEN `sap-icon://favorite` ELSE `sap-icon://unfavorite` ).
      ls_row-favorite_text = COND #( WHEN ls_row-favorite = abap_true
        THEN `Remove from favorites` ELSE `Add to favorites` ).
      INSERT ls_row INTO TABLE mt_all.
    ENDLOOP.

    apply_search( ).

  ENDMETHOD.

  METHOD apply_search.

    mt_repos = filtered_repos( it_rows = mt_all iv_search = mv_search iv_favorites_only = mv_favorites_only ).
    mv_empty = xsdbool( mt_repos IS INITIAL ).
    mv_empty_text = COND #( WHEN mv_favorites_only = abap_false THEN `No repositories found`
      WHEN NOT line_exists( mt_all[ favorite = abap_true ] ) THEN `No favorites yet`
      ELSE `No favorites match your search` ).

  ENDMETHOD.

  METHOD filtered_repos.

    LOOP AT it_rows INTO DATA(ls_row).
      IF iv_favorites_only = abap_true AND ls_row-favorite = abap_false.
        CONTINUE.
      ENDIF.
      IF iv_search IS NOT INITIAL AND NOT ( ls_row-name CS iv_search OR ls_row-package CS iv_search OR ls_row-url CS iv_search ).
        CONTINUE.
      ENDIF.
      INSERT ls_row INTO TABLE rt_rows.
    ENDLOOP.
    SORT rt_rows BY favorite DESCENDING package ASCENDING name ASCENDING key ASCENDING.

  ENDMETHOD.

  METHOD favorite_display.

    io_parent->tag( `ToggleButton`
        )->a( n = `icon`    v = `{FAVORITE_ICON}`
        )->a( n = `tooltip` v = `{FAVORITE_TEXT}`
        )->a( n = `pressed` v = `{= !!${FAVORITE} }`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `press`   v = client->_event( val = `FAVORITE`
                                                  t_arg = VALUE #( ( `${KEY}` ) ( `${$parameters>/pressed}` ) ) ) ).

  ENDMETHOD.

  METHOD favorite_set.

    TRY.
        DATA(lv_key) = client->get_event_arg( ).
        DATA(lv_favorite) = service( )->set_favorite( iv_key = lv_key iv_favorite = client->get_event_arg( 2 ) ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        " Restore the server's previous rows, including the star's pressed state.
        apply_search( ).
        view_display( ).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.
    " Keep the confirmed state even if refreshing the repository list fails.
    LOOP AT mt_all ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE key = lv_key.
      <ls_row>-favorite = lv_favorite.
      <ls_row>-favorite_icon = COND #( WHEN lv_favorite = abap_true
        THEN `sap-icon://favorite` ELSE `sap-icon://unfavorite` ).
      <ls_row>-favorite_text = COND #( WHEN lv_favorite = abap_true
        THEN `Remove from favorites` ELSE `Add to favorites` ).
    ENDLOOP.
    apply_search( ).
    load_repos( ).
    client->message_toast_display( COND #( WHEN lv_favorite = abap_true
      THEN `Repository added to favorites` ELSE `Repository removed from favorites` ) ).

  ENDMETHOD.

  METHOD favorites_filter.

    DATA(lv_value) = COND string( WHEN iv_value = ` ` THEN `` ELSE iv_value ).
    IF zcl_ag2ui5_settings=>get_instance( )->set(
      iv_key = zif_ag2ui5_settings=>c_key-repos_favorites_only iv_value = lv_value ) = abap_false.
      mv_favorites_only = xsdbool( zcl_ag2ui5_settings=>get_instance( )->get(
        iv_key = zif_ag2ui5_settings=>c_key-repos_favorites_only iv_default = `` ) = `X` ).
      client->message_box_display( text = `Favorites filter could not be saved` type = `error` ).
    ELSE.
      mv_favorites_only = xsdbool( lv_value = `X` ).
    ENDIF.
    apply_search( ).

  ENDMETHOD.

  METHOD service.
    ri_service = mi_service.
    IF ri_service IS NOT BOUND.
      ri_service = NEW zcl_ag2ui5_repo_service( ).
    ENDIF.
  ENDMETHOD.

  METHOD actions_display.
    io_parent->ele( `HBox`
        )->a( n = `justifyContent` v = `End`
        )->tag( `Button`
            )->a( n = `text` v = `Remove`
            )->a( n = `type` v = `Transparent`
            )->a( n = `tooltip` v = `Remove registration; keep SAP objects`
            )->a( n = `press` v = client->_event( val = `REMOVE` arg = `${KEY}` )
        )->tag( `Button`
            )->a( n = `text` v = `Uninstall`
            )->a( n = `type` v = `Transparent`
            )->a( n = `tooltip` v = `Delete SAP objects and remove registration`
            )->a( n = `press` v = client->_event( val = `UNINSTALL` arg = `${KEY}` ) ).
  ENDMETHOD.

  METHOD delete_clear.
    CLEAR: ms_delete_preview, mv_delete_failed, mv_delete_title, mv_delete_text,
      mv_delete_package, mv_delete_confirmation, mv_delete_transport,
      mv_delete_error, mt_delete_objects, mt_delete_transports, mt_delete_messages.
  ENDMETHOD.

  METHOD delete_open.
    delete_clear( ).
    TRY.
        ms_delete_preview = service( )->preview_delete(
          iv_key = client->get_event_arg( ) iv_action = iv_action ).
        mv_delete_package = ms_delete_preview-package.
        mt_delete_objects = ms_delete_preview-objects.
        IF ms_delete_preview-transport_required = abap_true.
          mt_delete_transports = service( )->list_transports( `K` ).
          INSERT VALUE #( text = `Choose a request` ) INTO mt_delete_transports INDEX 1.
        ENDIF.
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        delete_clear( ).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.
    IF iv_action = `REMOVE`.
      mv_delete_title = `Remove repository`.
      mv_delete_text = |Remove { ms_delete_preview-name } from package { mv_delete_package }? | &&
        `SAP objects and the remote repository will remain. Local abapGit settings will be removed.`.
    ELSE.
      mv_delete_title = `Uninstall repository`.
      mv_delete_text = |Uninstall { ms_delete_preview-name } from package { mv_delete_package }? | &&
        |Delete the { lines( mt_delete_objects ) } objects listed below and remove registration. | &&
        `This can delete table data and cannot be undone. The remote repository will remain. ` &&
        `Transportable packages may remain until the deletion transport is released.`.
    ENDIF.
    delete_display( ).
  ENDMETHOD.

  METHOD delete_display.
    DATA(popup) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `FragmentDefinition` ns = `core`
            )->a( n = `xmlns` v = `sap.m`
            )->a( n = `xmlns:core` v = `sap.ui.core` ).
    DATA(dialog) = popup->ele( `Dialog`
        )->a( n = `title` v = client->_bind( mv_delete_title )
        )->a( n = `contentWidth` v = `45rem`
        )->a( n = `stretch` v = `{device>/system/phone}` ).
    DATA(content) = dialog->ele( `content`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).
    content->tag( `MessageStrip`
        )->a( n = `text` v = client->_bind( mv_delete_text )
        )->a( n = `type` v = `Warning`
        )->a( n = `showIcon` v = `true` ).
    content->tag( `MessageStrip`
        )->a( n = `text` v = client->_bind( mv_delete_error )
        )->a( n = `type` v = `Error`
        )->a( n = `showIcon` v = `true`
        )->a( n = `visible` v = |\{= !!$\{{ client->_bind( val = mv_delete_error path = abap_true ) }\} \}| ).
    IF ms_delete_preview-action = `UNINSTALL`.
      DATA(table) = content->ele( `Table`
          )->a( n = `items` v = client->_bind( mt_delete_objects )
          )->a( n = `noDataText` v = `No SAP objects to delete` ).
      DATA(columns) = table->ele( `columns` ).
      columns->ele( `Column`
          )->a( n = `width` v = `5rem`
          )->tag( `Text`
              )->a( n = `text` v = `Type` ).
      columns->ele( `Column`
          )->tag( `Text`
              )->a( n = `text` v = `Object` ).
      columns->ele( `Column`
          )->a( n = `minScreenWidth` v = `Tablet`
          )->a( n = `demandPopin` v = `true`
          )->tag( `Text`
              )->a( n = `text` v = `Package` ).
      table->ele( `items`
          )->ele( `ColumnListItem`
              )->ele( `cells`
                  )->tag( `Text`
                      )->a( n = `text` v = `{OBJ_TYPE}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{OBJ_NAME}`
                  )->tag( `Text`
                      )->a( n = `text` v = `{PACKAGE}` ).
      content->tag( `Label`
          )->a( n = `text` t = |Type { mv_delete_package } to confirm uninstall|
          )->a( n = `labelFor` v = `deleteConfirmation` ).
      content->tag( `Input`
          )->a( n = `id` v = `deleteConfirmation`
          )->a( n = `value` v = client->_bind( mv_delete_confirmation )
          )->a( n = `valueLiveUpdate` v = `true` ).
    ENDIF.
    IF ms_delete_preview-transport_required = abap_true.
      content->tag( `Label`
          )->a( n = `text` v = `Workbench transport request`
          )->a( n = `labelFor` v = `deleteTransport` ).
      content->ele( `Select`
          )->a( n = `id` v = `deleteTransport`
          )->a( n = `width` v = `100%`
          )->a( n = `selectedKey` v = client->_bind( mv_delete_transport )
          )->a( n = `items` v = client->_bind( mt_delete_transports )
          )->ele( `items`
              )->tag( n = `Item` ns = `core`
                  )->a( n = `key` v = `{TRKORR}`
                  )->a( n = `text` v = `{= ${TRKORR} ? ${TRKORR} + ' ' + ${TEXT} : ${TEXT} }` ).
    ENDIF.
    content->ele( `List`
        )->a( n = `items` v = client->_bind( mt_delete_messages )
        )->a( n = `showNoData` v = `false`
        )->ele( `items`
            )->ele( `CustomListItem`
                )->ele( `content`
                    )->tag( `Text`
                        )->a( n = `text` v = `{TEXT}` ).
    DATA(buttons) = dialog->ele( `buttons` ).
    buttons->tag( `Button`
        )->a( n = `text` v = `Cancel`
        )->a( n = `press` v = client->_event( `DELETE_CANCEL` ) ).
    buttons->tag( `Button`
        )->a( n = `text` t = COND string( WHEN ms_delete_preview-action = `REMOVE` THEN `Remove` ELSE `Uninstall` )
        )->a( n = `type` v = `Reject`
        )->a( n = `enabled` b = xsdbool( mv_delete_failed = abap_false )
        )->a( n = `press` v = client->_event( `DELETE_CONFIRM` ) ).
    client->popup_display( popup->stringify( ) ).
  ENDMETHOD.

  METHOD delete_confirm.
    IF ms_delete_preview-key IS INITIAL OR mv_delete_failed = abap_true.
      RETURN.
    ENDIF.
    CLEAR: mv_delete_error, mt_delete_messages.
    TRY.
        DATA(ls_result) = service( )->delete_repo( is_preview = ms_delete_preview
          iv_confirmation = mv_delete_confirmation iv_transport = mv_delete_transport ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        mv_delete_error = lx_error->get_text( ).
        RETURN.
    ENDTRY.
    IF ls_result-outcome <> zif_ag2ui5_repo_service=>c_outcome-removed AND
       ls_result-outcome <> zif_ag2ui5_repo_service=>c_outcome-uninstalled.
      mv_delete_failed = abap_true.
      mt_delete_messages = ls_result-messages.
      mv_delete_error = `Uninstall did not finish. Some objects may already be deleted. ` &&
        `Registration is retained. Cancel and open a new preview to inspect the remaining objects.`.
      delete_display( ).
      RETURN.
    ENDIF.
    DATA(lv_message) = COND string( WHEN ls_result-outcome = zif_ag2ui5_repo_service=>c_outcome-removed
      THEN `Repository registration removed; SAP objects retained`
      ELSE `Repository uninstalled` ).
    client->popup_destroy( ).
    delete_clear( ).
    load_repos( ).
    client->message_toast_display( lv_message ).
  ENDMETHOD.

  METHOD open_repo.

    READ TABLE mt_all INTO DATA(ls_row) WITH KEY key = client->get_event_arg( ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    client->nav_app_call( zcl_ag2ui5_app_status=>create( ls_row-key ) ).

  ENDMETHOD.

ENDCLASS.
