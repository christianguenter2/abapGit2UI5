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
        branch          TYPE string,
        deserialized_at TYPE string,
        offline         TYPE abap_bool,
        "! Navigation for every repository
        nav_type        TYPE string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA mt_repos  TYPE ty_rows.
    DATA mv_search TYPE string.
    "! LIST or TILES; switched on the client, stored per user
    DATA mv_layout TYPE string VALUE `TILES`.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    "! The unfiltered list; mt_repos is what the search leaves of it
    DATA mt_all TYPE ty_rows.

    METHODS view_display.
    METHODS tiles_display
      IMPORTING
        io_content TYPE REF TO z2ui5_cl_ui5_view_builder.
    METHODS on_event.
    METHODS load_repos.
    METHODS apply_search.
    METHODS open_repo.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_repos IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ).
      mv_layout = zcl_ag2ui5_settings=>get_instance( )->get(
                    iv_key     = zif_ag2ui5_settings=>c_key-repos_layout
                    iv_default = `TILES` ).
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
                )->a( n = `shrinkable` v = `true` ).
    header_content->tag( `ToolbarSpacer` ).
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
        )->a( n = `visible`    v = |\{= $\{{ client->_bind( val = mv_layout path = abap_true ) }\} === 'LIST' \}| ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Name` ).
    columns->ele( `Column`
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

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type`  v = `{NAV_TYPE}`
            )->a( n = `press` v = client->_event( val = `OPEN` arg = `${KEY}` )
            )->ele( `cells` ).
    cells->tag( `ObjectIdentifier`
        )->a( n = `title` v = `{NAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{PACKAGE}` ).
    " a link opens in a new tab; a click on it does not open the repository
    cells->tag( `Link`
        )->a( n = `text`   v = `{URL}`
        )->a( n = `href`   v = `{URL}`
        )->a( n = `target` v = `_blank` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{BRANCH}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{DESERIALIZED_AT}` ).

    tiles_display( content ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD tiles_display.

    DATA(grid) = io_content->ele( n = `GridContainer` ns = `f`
        )->a( n = `items`   v = client->_bind( mt_repos )
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = mv_layout path = abap_true ) }\} === 'TILES' \}|
        )->a( n = `class`   v = `sapUiSmallMargin` ).
    grid->ele( n = `layout` ns = `f`
        )->tag( n = `GridContainerSettings` ns = `f`
            )->a( n = `columnSize` v = `20rem`
            )->a( n = `gap`        v = `1rem` ).

    " a click on the header opens the repository, as a table row does
    DATA(card) = grid->ele( n = `Card` ns = `f`
        )->a( n = `width` v = `100%` ).
    card->ele( n = `header` ns = `f`
        )->tag( n = `Header` ns = `card`
            )->a( n = `title`    v = `{NAME}`
            )->a( n = `subtitle` v = `{PACKAGE}`
            )->a( n = `iconSrc`  v = `{= ${OFFLINE} ? 'sap-icon://disconnected' : 'sap-icon://cloud' }`
            )->a( n = `press`    v = client->_event( val = `OPEN` arg = `${KEY}` ) ).

    DATA(box) = card->ele( n = `content` ns = `f`
        )->ele( `VBox`
            )->a( n = `class` v = `sapUiSmallMargin` ).
    " a link opens in a new tab; a click on it does not open the repository
    " a URL has no blank to wrap at: cut it off at the card's inner width
    " (column 20rem less the margins); the tooltip has all of it
    box->tag( `Link`
        )->a( n = `text`    v = `{URL}`
        )->a( n = `href`    v = `{URL}`
        )->a( n = `target`  v = `_blank`
        )->a( n = `width`   v = `18rem`
        )->a( n = `tooltip` v = `{URL}` ).
    box->tag( `ObjectAttribute`
        )->a( n = `title`   v = `Branch`
        )->a( n = `text`    v = `{BRANCH}`
        )->a( n = `visible` v = `{= !!${BRANCH} }` ).
    box->tag( `ObjectAttribute`
        )->a( n = `title`   v = `Last pull`
        )->a( n = `text`    v = `{DESERIALIZED_AT}`
        )->a( n = `visible` v = `{= !!${DESERIALIZED_AT} }` ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `SEARCH`.
        apply_search( ).
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
    ENDCASE.

  ENDMETHOD.

  METHOD load_repos.

    TRY.
        DATA(lt_repos) = NEW zcl_ag2ui5_repo_service( )->zif_ag2ui5_repo_service~list_repos( ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    CLEAR mt_all.
    LOOP AT lt_repos INTO DATA(ls_repo).
      DATA(ls_row) = CORRESPONDING ty_row( ls_repo ).
      ls_row-nav_type = `Navigation`.
      INSERT ls_row INTO TABLE mt_all.
    ENDLOOP.

    apply_search( ).

  ENDMETHOD.

  METHOD apply_search.

    IF mv_search IS INITIAL.
      mt_repos = mt_all.
      RETURN.
    ENDIF.

    " CS ignores case
    mt_repos = VALUE #( FOR ls_row IN mt_all
                        WHERE ( name CS mv_search OR package CS mv_search OR url CS mv_search )
                        ( ls_row ) ).

  ENDMETHOD.

  METHOD open_repo.

    READ TABLE mt_all INTO DATA(ls_row) WITH KEY key = client->get_event_arg( ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    client->nav_app_call( zcl_ag2ui5_app_status=>create( ls_row-key ) ).

  ENDMETHOD.

ENDCLASS.
