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
        "! Navigation for online repositories, Inactive for offline ones
        nav_type        TYPE string,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA mt_repos  TYPE ty_rows.
    DATA mv_search TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    "! The unfiltered list; mt_repos is what the search leaves of it
    DATA mt_all TYPE ty_rows.

    METHODS view_display.
    METHODS on_event.
    METHODS load_repos.
    METHODS apply_search.
    METHODS open_repo.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_repos IMPLEMENTATION.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      load_repos( ).
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
        )->a( n = `title` v = `abapGit - Repositories` ).

    page->ele( `headerContent`
        )->tag( `Button`
            )->a( n = `icon`    v = `sap-icon://refresh`
            )->a( n = `tooltip` v = `Refresh`
            )->a( n = `press`   v = client->_event( `REFRESH` ) ).

    page->ele( `subHeader`
        )->ele( `Toolbar`
            )->tag( `SearchField`
                )->a( n = `value`       v = client->_bind( mv_search )
                )->a( n = `placeholder` v = `Search name, package or URL`
                )->a( n = `search`      v = client->_event( `SEARCH` ) ).

    DATA(table) = page->ele( `content`
        )->ele( `Table`
            )->a( n = `items`      v = client->_bind( mt_repos )
            )->a( n = `noDataText` v = `No repositories found` ).

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
    cells->tag( `Text`
        )->a( n = `text` v = `{URL}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{BRANCH}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{DESERIALIZED_AT}` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `SEARCH`.
        apply_search( ).
      WHEN `REFRESH`.
        load_repos( ).
      WHEN `OPEN`.
        open_repo( ).
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
      ls_row-nav_type = COND #( WHEN ls_repo-offline = abap_true THEN `Inactive` ELSE `Navigation` ).
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

    IF ls_row-offline = abap_true.
      client->message_toast_display( `Offline repositories are not supported` ).
      RETURN.
    ENDIF.

    client->nav_app_call( zcl_ag2ui5_app_status=>create( ls_row-key ) ).

  ENDMETHOD.

ENDCLASS.
