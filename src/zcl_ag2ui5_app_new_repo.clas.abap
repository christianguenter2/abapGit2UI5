"! Creates an online or offline abapGit repository from a form
CLASS zcl_ag2ui5_app_new_repo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      "! the error text per field of the form; empty: no error
      BEGIN OF ty_error_texts,
        url            TYPE string,
        branch         TYPE string,
        name           TYPE string,
        package        TYPE string,
        display_name   TYPE string,
        folder_logic   TYPE string,
        labels         TYPE string,
        abap_lang_vers TYPE string,
      END OF ty_error_texts.

    CLASS-METHODS create
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_new_repo.

    DATA ms_repo TYPE zif_ag2ui5_repo_service=>ty_new_repo.
    DATA ms_error_text TYPE ty_error_texts.
    "! an error that belongs to no field
    DATA mv_message TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    "! Set only by unit tests; the real service otherwise
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.

    METHODS view_display.
    METHODS on_event.
    METHODS create_repo.
    METHODS show_errors
      IMPORTING
        it_errors TYPE zif_ag2ui5_repo_service=>ty_field_errors.
    METHODS service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_new_repo IMPLEMENTATION.

  METHOD create.

    ro_app = NEW #( ).
    " abapGit's defaults
    ro_app->ms_repo-kind         = zif_ag2ui5_repo_service=>c_repo_kind-online.
    ro_app->ms_repo-folder_logic = zif_abapgit_dot_abapgit=>c_folder_logic-prefix.

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_navigated( ).
      view_display( ).
    ELSEIF client->check_on_event( ).
      on_event( ).
    ENDIF.

  ENDMETHOD.

  METHOD on_event.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `CREATE`.
        create_repo( ).
    ENDCASE.

  ENDMETHOD.

  METHOD create_repo.

    CLEAR: ms_error_text, mv_message.
    TRY.
        DATA(ls_result) = service( )->create_repo( ms_repo ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        mv_message = lx_error->get_text( ).
        RETURN.
    ENDTRY.

    IF ls_result-outcome <> zif_ag2ui5_repo_service=>c_outcome-created.
      show_errors( ls_result-errors ).
      RETURN.
    ENDIF.

    IF ms_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
      " offline repositories open in slice 2; the list shows the new one
      client->message_toast_display( |Offline repository { ms_repo-name } created| ).
      client->nav_app_leave( ).
    ELSE.
      " leave this page for the status page: its Back returns to the list
      client->nav_app_leave( zcl_ag2ui5_app_status=>create( ls_result-key ) ).
    ENDIF.

  ENDMETHOD.

  METHOD show_errors.

    FIELD-SYMBOLS <lv_text> TYPE string.

    LOOP AT it_errors INTO DATA(ls_error).
      UNASSIGN <lv_text>.
      IF ls_error-field IS NOT INITIAL.
        DATA(lv_component) = to_upper( ls_error-field ).
        ASSIGN COMPONENT lv_component OF STRUCTURE ms_error_text TO <lv_text>.
      ENDIF.
      IF <lv_text> IS ASSIGNED.
        <lv_text> = ls_error-text.
      ELSE.
        mv_message = COND #( WHEN mv_message IS INITIAL THEN ls_error-text
                             ELSE |{ mv_message } { ls_error-text }| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD view_display.

    DATA(view) = z2ui5_cl_ui5_view_builder=>factory(
        )->ele( n = `View` ns = `mvc`
            )->a( n = `xmlns`        v = `sap.m`
            )->a( n = `xmlns:mvc`    v = `sap.ui.core.mvc`
            )->a( n = `xmlns:core`   v = `sap.ui.core`
            )->a( n = `xmlns:form`   v = `sap.ui.layout.form`
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
        )->a( n = `text`  v = `New repository`
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `true` ).
    header_content->tag( `ToolbarSpacer` ).
    header_content->ele( `Button`
        )->a( n = `text`  v = `Create`
        )->a( n = `icon`  v = `sap-icon://add`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `press` v = client->_event( `CREATE` )
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority` v = `NeverOverflow` ).

    DATA(content) = page->ele( `content` ).

    " an error that belongs to no field
    content->tag( `MessageStrip`
        )->a( n = `text`     v = client->_bind( mv_message )
        )->a( n = `type`     v = `Error`
        )->a( n = `showIcon` v = `true`
        )->a( n = `class`    v = `sapUiSmallMargin`
        )->a( n = `visible`  v = |\{= !!$\{{ client->_bind( val = mv_message path = abap_true ) }\} \}| ).

    DATA(form) = content->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` v = `true`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->ele( n = `content` ns = `form` ).

    form->tag( `Label`
        )->a( n = `text` v = `Kind` ).
    form->ele( `SegmentedButton`
        )->a( n = `selectedKey` v = client->_bind( ms_repo-kind )
        )->ele( `items`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `ONLINE`
                )->a( n = `text` v = `Online`
            )->tag( `SegmentedButtonItem`
                )->a( n = `key`  v = `OFFLINE`
                )->a( n = `text` v = `Offline` ).

    " online: URL, branch, display name - the kind switches on the client
    form->tag( `Label`
        )->a( n = `text`     v = `Git repository URL`
        )->a( n = `required` v = `true`
        )->a( n = `visible`  v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-url )
        )->a( n = `placeholder`    v = `https://github.com/...git`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-url path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-url )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Label`
        )->a( n = `text`    v = `Branch`
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-branch )
        )->a( n = `placeholder`    v = `Default branch of the remote`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-branch path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-branch )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).

    " offline: a name
    form->tag( `Label`
        )->a( n = `text`     v = `Name`
        )->a( n = `required` v = `true`
        )->a( n = `visible`  v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'OFFLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-name )
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-name path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-name )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'OFFLINE' \}| ).

    form->tag( `Label`
        )->a( n = `text`     v = `Package`
        )->a( n = `required` v = `true` ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-package )
        )->a( n = `placeholder`    v = `Z... / $...`
        )->a( n = `maxLength`      v = `30`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-package path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-package ) ).

    form->tag( `Label`
        )->a( n = `text`    v = `Display name`
        )->a( n = `visible` v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).
    form->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-display_name )
        )->a( n = `placeholder`    v = `Optional`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-display_name path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-display_name )
        )->a( n = `visible`        v = |\{= $\{{ client->_bind( val = ms_repo-kind path = abap_true ) }\} === 'ONLINE' \}| ).

    " the rarely changed settings, collapsed
    DATA(more) = content->ele( `Panel`
        )->a( n = `headerText` v = `More settings`
        )->a( n = `expandable` v = `true`
        )->a( n = `expanded`   v = `false`
        )->ele( `content`
            )->ele( n = `SimpleForm` ns = `form`
                )->a( n = `editable` v = `true`
                )->a( n = `layout`   v = `ResponsiveGridLayout`
                )->ele( n = `content` ns = `form` ).

    more->tag( `Label`
        )->a( n = `text` v = `Folder logic` ).
    more->ele( `Select`
        )->a( n = `selectedKey`    v = client->_bind( ms_repo-folder_logic )
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-folder_logic path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-folder_logic )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `PREFIX`
                )->a( n = `text` v = `Prefix`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `FULL`
                )->a( n = `text` v = `Full`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `MIXED`
                )->a( n = `text` v = `Mixed` ).

    more->tag( `Label`
        )->a( n = `text` v = `Labels` ).
    more->tag( `Input`
        )->a( n = `value`          v = client->_bind( ms_repo-labels )
        )->a( n = `placeholder`    v = `Comma-separated, optional`
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-labels path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-labels ) ).

    more->tag( `Label`
        )->a( n = `text` v = `Ignore subpackages` ).
    more->tag( `CheckBox`
        )->a( n = `selected` v = client->_bind( ms_repo-ign_subpackages ) ).

    more->tag( `Label`
        )->a( n = `text` v = `Main language only` ).
    more->tag( `CheckBox`
        )->a( n = `selected` v = client->_bind( ms_repo-main_lang_only ) ).

    more->tag( `Label`
        )->a( n = `text` v = `ABAP language version` ).
    more->ele( `Select`
        )->a( n = `selectedKey`    v = client->_bind( ms_repo-abap_lang_vers )
        )->a( n = `valueState`     v = |\{= $\{{ client->_bind( val = ms_error_text-abap_lang_vers path = abap_true ) }\} ? 'Error' : 'None' \}|
        )->a( n = `valueStateText` v = client->_bind( ms_error_text-abap_lang_vers )
        )->ele( `items`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = ``
                )->a( n = `text` v = `Any`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `ignore`
                )->a( n = `text` v = `Ignore`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `standard`
                )->a( n = `text` v = `Standard`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `keyUser`
                )->a( n = `text` v = `For key users`
            )->tag( n = `Item` ns = `core`
                )->a( n = `key`  v = `cloudDevelopment`
                )->a( n = `text` v = `For cloud development` ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD service.
    ri_service = COND #( WHEN mi_service IS BOUND THEN mi_service ELSE NEW zcl_ag2ui5_repo_service( ) ).
  ENDMETHOD.

ENDCLASS.
