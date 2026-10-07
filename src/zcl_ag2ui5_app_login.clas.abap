"! Asks for the Git user and token when abapGit's user exit supplies none.
"! They go to abapGit's login manager, in the memory of this - then stateful -
"! session (ZIF_AG2UI5_REPO_SERVICE~login). The token is taken out of its
"! attribute first on every event, before abap2UI5 saves the app state
CLASS zcl_ag2ui5_app_login DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    DATA mv_title TYPE string.
    "! Opened on another ICF node: why there is no login here
    DATA mv_node_hint TYPE string.
    DATA mv_can_login TYPE abap_bool.
    DATA mv_user  TYPE string.
    "! Bound to a password field; on_event( ) clears it first on every event,
    "! so it is never part of the state abap2UI5 saves
    DATA mv_token TYPE string.

    "! The ICF node that ends an idle session after 30 minutes; only there the
    "! credentials may stay in a stateful session
    CONSTANTS c_node TYPE string VALUE `/sap/bc/zabapgit2ui5`.

    "! A login made this session stateful; the repository list ends it again
    CLASS-METHODS is_stateful
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.
    CLASS-METHODS set_stateful
      IMPORTING
        iv_yes TYPE abap_bool.

    "! The repository by key, or a URL not registered yet (New repository)
    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string OPTIONAL
        iv_url        TYPE string OPTIONAL
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_login.

  PROTECTED SECTION.
    "! Static: it survives the round trips only in a stateful session
    CLASS-DATA gv_stateful TYPE abap_bool.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.
    DATA mv_key TYPE string.
    DATA mv_url TYPE string.
    DATA mv_host TYPE string.

    METHODS service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.
    METHODS on_event
      IMPORTING
        iv_token TYPE string.
    METHODS log_in
      IMPORTING
        iv_token TYPE string.
    METHODS view_display.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_login IMPLEMENTATION.

  METHOD is_stateful.
    rv_yes = gv_stateful.
  ENDMETHOD.

  METHOD set_stateful.
    gv_stateful = iv_yes.
  ENDMETHOD.

  METHOD create.
    ro_app = NEW #( ).
    ro_app->mv_key = iv_key.
    ro_app->mv_url = iv_url.
  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    " a typed token arrives with every round trip - with an event, without
    " one, or on the way back - and abap2UI5 saves the app state after it
    " (into its draft table): it is taken out of the attribute first, always
    DATA(lv_token) = mv_token.
    CLEAR mv_token.

    IF client->check_on_init( ).
      " the host for the texts; a registered repository knows its URL
      DATA(lv_url) = mv_url.
      IF lv_url IS INITIAL AND mv_key IS NOT INITIAL.
        TRY.
            DATA(lt_repos) = service( )->list_repos( ).
            READ TABLE lt_repos INTO DATA(ls_repo) WITH KEY key = mv_key.
            IF sy-subrc = 0.
              lv_url = ls_repo-url.
            ENDIF.
          CATCH zcx_abapgit_exception ##NO_HANDLER.
        ENDTRY.
      ENDIF.
      mv_host = zcl_ag2ui5_repo_service=>url_host( lv_url ).
      mv_title = |Log in to { COND #( WHEN mv_host IS NOT INITIAL THEN mv_host ELSE `the Git server` ) }|.
      mv_can_login = zcl_ag2ui5_http=>is_own_node( ).
      IF mv_can_login = abap_false.
        mv_node_hint = |Logging in works only through { c_node }: only that ICF node ends an idle | &&
                       |session after 30 minutes. Open abapGit2UI5 there (transaction ZABAPGIT2UI5).|.
      ENDIF.
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( lv_token ).
    ENDIF.
    CLEAR lv_token.

  ENDMETHOD.

  METHOD service.
    ri_service = COND #( WHEN mi_service IS BOUND THEN mi_service ELSE NEW zcl_ag2ui5_repo_service( ) ).
  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `LOGIN`.
        log_in( iv_token ).
      WHEN `CANCEL`.
        CLEAR mv_user.
        client->nav_app_leave( ).
    ENDCASE.

  ENDMETHOD.

  METHOD log_in.

    IF mv_user IS INITIAL OR iv_token IS INITIAL.
      client->message_box_display( text = `Enter the Git user and the token or password` type = `error` ).
      RETURN.
    ENDIF.
    " /sap/bc/z2ui5 has no session timeout of its own: a stateful session
    " left there would keep the credentials in memory for good. The handler
    " of the own node marks the request; the browser's path does not count
    IF zcl_ag2ui5_http=>is_own_node( ) = abap_false.
      client->message_box_display(
        text = |To log in, open abapGit2UI5 through { c_node }: only that ICF node ends an idle session after 30 minutes.|
        type = `error` ).
      RETURN.
    ENDIF.
    TRY.
        service( )->login( iv_key   = mv_key
                           iv_url   = mv_url
                           iv_user  = mv_user
                           iv_token = iv_token ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.
    " the login manager is static: only a stateful session keeps it until
    " the next request; the ICF node ends the session after 30 minutes
    client->set_session_stateful( abap_true ).
    set_stateful( abap_true ).
    " some hosts take a token as the user name: nothing of it stays in the draft
    CLEAR mv_user.
    client->nav_app_leave( r_data = |LOGGED_IN:{ mv_host }| ).

  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
            )->a( n = `displayBlock` v = `true`
            )->a( n = `height`       v = `100%` ).

    DATA(page) = view->ele( `Page` ).
    DATA(header) = page->ele( `customHeader`
        )->ele( `OverflowToolbar` ).
    header->ele( `Button`
        )->a( n = `icon`    v = `sap-icon://nav-back`
        )->a( n = `tooltip` v = `Back`
        )->a( n = `type`    v = `Transparent`
        )->a( n = `press`   v = client->_event( `CANCEL` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `NeverOverflow` ).
    header->ele( `Title`
        )->a( n = `text`  v = client->_bind( mv_title )
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `true` ).

    DATA(content) = page->ele( `content` ).
    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( mv_node_hint )
        )->a( n = `type`     v = `Warning`
        )->a( n = `showIcon` v = `true`
        )->a( n = `visible`  v = |\{= !!$\{{ client->_bind( val = mv_node_hint path = abap_true ) }\} \}|
        )->a( n = `class`    v = `sapUiSmallMargin` ).
    content->tag( `MessageStrip`
        )->a( n = `text`     v = `abapGit's user exit supplied no credentials for this server. ` &&
                                 `User and token stay in this session's server memory only, at most 30 minutes ` &&
                                 `without use, and are dropped when you go back to the repository list. ` &&
                                 `They are never stored.`
        )->a( n = `type`     v = `Information`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin` ).
    DATA(form) = content->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` v = `true`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->ele( n = `content` ns = `form` ).
    form->tag( `Label`
        )->a( n = `text`     v = `Git user`
        )->a( n = `required` v = `true` ).
    form->tag( `Input`
        )->a( n = `value` v = client->_bind( mv_user ) ).
    form->tag( `Label`
        )->a( n = `text`     v = `Token or password`
        )->a( n = `required` v = `true` ).
    form->tag( `Input`
        )->a( n = `value` v = client->_bind( mv_token )
        )->a( n = `type`  v = `Password` ).
    form->tag( `Label` ).
    form->tag( `Button`
        )->a( n = `text`    v = `Log in`
        )->a( n = `type`    v = `Emphasized`
        )->a( n = `enabled` v = client->_bind( mv_can_login )
        )->a( n = `press`   v = client->_event( `LOGIN` ) ).
    form->tag( `Button`
        )->a( n = `text`  v = `Cancel`
        )->a( n = `press` v = client->_event( `CANCEL` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

ENDCLASS.
