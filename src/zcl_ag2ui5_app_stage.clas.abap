"! Select locally changed files, commit them and push. The credentials are
"! used for the push only: the token is cleared on every event, before
"! abap2UI5 saves the state
CLASS zcl_ag2ui5_app_stage DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      BEGIN OF ty_row,
        path     TYPE string,
        filename TYPE string,
        obj_type TYPE string,
        obj_name TYPE string,
        lstate   TYPE string,
        rstate   TYPE string,
        action   TYPE string,
        "! What the commit does with the file, for the table
        change   TYPE string,
        selected TYPE abap_bool,
        "! Only some lines are committed
        patched  TYPE abap_bool,
      END OF ty_row,
      ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

    DATA mt_rows   TYPE ty_rows.
    DATA ms_commit TYPE zif_ag2ui5_repo_service=>ty_commit.
    DATA mv_user   TYPE string.
    "! Bound to a password field; on_event( ) clears it first on every event,
    "! so it is never part of the state abap2UI5 saves
    DATA mv_token  TYPE string.

    CLASS-METHODS create
      IMPORTING
        iv_key        TYPE string
        iv_title      TYPE string
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_stage.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    DATA mv_key TYPE string.
    DATA mv_title TYPE string.
    "! Set only by unit tests; the real service otherwise
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.

    TYPES:
      BEGIN OF ty_patch,
        path        TYPE string,
        filename    TYPE string,
        ids         TYPE string_table,
        fingerprint TYPE string,
        "! The row's tick before its first patch, restored when no line is left
        was_selected TYPE abap_bool,
      END OF ty_patch,
      ty_patches TYPE STANDARD TABLE OF ty_patch WITH EMPTY KEY.
    "! The picked lines per file; a file without an entry is committed whole
    DATA mt_patches TYPE ty_patches.

    "! Takes the diff page's selection over into its row
    METHODS take_patch
      IMPORTING
        is_patch TYPE zcl_ag2ui5_app_diff=>ty_patch.
    "! The row's Change text: the action, how many lines, Git's change
    METHODS change_text
      IMPORTING
        is_row         TYPE ty_row
        iv_picked      TYPE i OPTIONAL
        iv_total       TYPE i OPTIONAL
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS view_display.
    METHODS on_event.
    METHODS load_stage.
    METHODS push
      IMPORTING
        iv_token TYPE string.
    METHODS select_all
      IMPORTING
        iv_selected TYPE abap_bool.

    METHODS service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_stage IMPLEMENTATION.

  METHOD create.

    ro_app = NEW #( ).
    ro_app->mv_key   = iv_key.
    ro_app->mv_title = iv_title.

  ENDMETHOD.

  METHOD take_patch.

    IF is_patch-applied = abap_false.
      RETURN.
    ENDIF.
    READ TABLE mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>)
      WITH KEY path = is_patch-path filename = is_patch-filename.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    READ TABLE mt_patches INTO DATA(ls_earlier)
      WITH KEY path = is_patch-path filename = is_patch-filename.
    DATA(lv_was_selected) = COND #( WHEN sy-subrc = 0 THEN ls_earlier-was_selected ELSE <ls_row>-selected ).
    DELETE mt_patches WHERE path = is_patch-path AND filename = is_patch-filename.
    " every line picked is the whole file, none picked is no patch
    IF is_patch-ids IS NOT INITIAL AND lines( is_patch-ids ) < is_patch-total.
      INSERT VALUE #( path         = is_patch-path
                      filename     = is_patch-filename
                      ids          = is_patch-ids
                      fingerprint  = is_patch-fingerprint
                      was_selected = lv_was_selected ) INTO TABLE mt_patches.
      <ls_row>-patched  = abap_true.
      <ls_row>-selected = abap_true.
      <ls_row>-change   = change_text( is_row    = <ls_row>
                                       iv_picked = lines( is_patch-ids )
                                       iv_total  = is_patch-total ).
    ELSE.
      <ls_row>-patched  = abap_false.
      " all lines: the whole file; none: the tick from before the first patch
      <ls_row>-selected = xsdbool( is_patch-ids IS NOT INITIAL OR lv_was_selected = abap_true ).
      <ls_row>-change   = change_text( <ls_row> ).
    ENDIF.

  ENDMETHOD.

  METHOD change_text.

    rv_text = SWITCH #( is_row-lstate
                        WHEN `A` THEN `add`
                        WHEN `D` THEN `delete`
                        ELSE `modify` ).
    IF iv_total > 0.
      rv_text = |{ rv_text } - { iv_picked } of { iv_total } lines|.
    ENDIF.
    IF is_row-rstate IS NOT INITIAL.
      rv_text = |{ rv_text } - changed in Git too, pull first|.
    ENDIF.

  ENDMETHOD.

  METHOD z2ui5_if_app~main.

    me->client = client.
    IF client->check_on_init( ).
      load_stage( ).
      view_display( ).
    ELSEIF client->check_on_navigated( ).
      CLEAR mv_token.
      " back from the diff page: in patch mode it hands the picked lines back
      TRY.
          take_patch( CAST zcl_ag2ui5_app_diff( client->get_app_prev( ) )->get_patch( ) ).
        CATCH cx_sy_move_cast_error ##NO_HANDLER.
      ENDTRY.
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
        )->a( n = `text`  t = |Stage - { mv_title }|
        )->a( n = `level` v = `H2`
        )->ele( `layoutData`
            )->tag( `OverflowToolbarLayoutData`
                )->a( n = `priority`   v = `NeverOverflow`
                )->a( n = `shrinkable` v = `true` ).
    header_content->tag( `ToolbarSpacer` ).
    header_content->tag( `Button`
        )->a( n = `text`  v = `Select all`
        )->a( n = `press` v = client->_event( `ALL` ) ).
    header_content->tag( `Button`
        )->a( n = `text`  v = `Select none`
        )->a( n = `press` v = client->_event( `NONE` ) ).

    DATA(content) = page->ele( `content` ).

    DATA(table) = content->ele( `Table`
        )->a( n = `items`      v = client->_bind( mt_rows )
        )->a( n = `noDataText` v = `No local changes to commit` ).

    DATA(columns) = table->ele( `columns` ).
    columns->ele( `Column`
        )->a( n = `width` v = `5rem`
        )->tag( `Text`
            )->a( n = `text` v = `Commit` ).
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
            )->a( n = `text` v = `File` ).
    columns->ele( `Column`
        )->tag( `Text`
            )->a( n = `text` v = `Change` ).
    columns->ele( `Column`
        )->a( n = `width` v = `9rem` ).

    DATA(cells) = table->ele( `items`
        )->ele( `ColumnListItem`
            )->a( n = `type`  v = `Navigation`
            )->a( n = `press` v = client->_event( val = `DIFF` t_arg = VALUE #( ( `${PATH}` ) ( `${FILENAME}` ) ) )
            )->ele( `cells` ).
    cells->tag( `CheckBox`
        )->a( n = `selected` v = `{SELECTED}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OBJ_TYPE}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{OBJ_NAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{FILENAME}` ).
    cells->tag( `Text`
        )->a( n = `text` v = `{CHANGE}` ).
    " a button press inside the row does not fire the row's press
    cells->tag( `Button`
        )->a( n = `text`  v = `Pick lines`
        )->a( n = `icon`  v = `sap-icon://multi-select`
        )->a( n = `type`  v = `Transparent`
        )->a( n = `press` v = client->_event( val = `PATCH` t_arg = VALUE #( ( `${PATH}` ) ( `${FILENAME}` ) ) ) ).

    DATA(form) = content->ele( n = `SimpleForm` ns = `form`
        )->a( n = `editable` v = `true`
        )->a( n = `layout`   v = `ResponsiveGridLayout`
        )->a( n = `title`    v = `Commit`
        )->ele( n = `content` ns = `form` ).
    form->tag( `Label`
        )->a( n = `text`     v = `Title`
        )->a( n = `required` v = `true` ).
    form->tag( `Input`
        )->a( n = `value`     v = client->_bind( ms_commit-title )
        )->a( n = `maxLength` v = `72` ).
    form->tag( `Label`
        )->a( n = `text` v = `Description` ).
    form->tag( `TextArea`
        )->a( n = `value` v = client->_bind( ms_commit-body )
        )->a( n = `rows`  v = `4` ).
    form->tag( `Label`
        )->a( n = `text`     v = `Committer`
        )->a( n = `required` v = `true` ).
    form->tag( `Input`
        )->a( n = `value`       v = client->_bind( ms_commit-name )
        )->a( n = `placeholder` v = `Name` ).
    form->tag( `Input`
        )->a( n = `value`       v = client->_bind( ms_commit-email )
        )->a( n = `placeholder` v = `E-mail` ).
    form->tag( `Label`
        )->a( n = `text` v = `Git user` ).
    form->tag( `Input`
        )->a( n = `value` v = client->_bind( mv_user ) ).
    form->tag( `Label`
        )->a( n = `text` v = `Token or password` ).
    form->tag( `Input`
        )->a( n = `value` v = client->_bind( mv_token )
        )->a( n = `type`  v = `Password` ).
    form->tag( `Label` ).
    form->tag( `Button`
        )->a( n = `text`  v = `Commit & push`
        )->a( n = `type`  v = `Emphasized`
        )->a( n = `icon`  v = `sap-icon://upload`
        )->a( n = `press` v = client->_event( `PUSH` ) ).

    client->view_display( view->stringify( ) ).

  ENDMETHOD.

  METHOD on_event.

    " a typed token arrives with whatever button is pressed next, and abap2UI5
    " saves the app state after every event (into its draft table) - so it is
    " taken out of the attribute before anything else, for every event
    DATA ls_row TYPE ty_row.

    DATA(lv_token) = mv_token.
    CLEAR mv_token.

    CASE client->get_event( ).
      WHEN `BACK`.
        client->nav_app_leave( ).
      WHEN `ALL`.
        select_all( abap_true ).
      WHEN `NONE`.
        select_all( abap_false ).
      WHEN `DIFF`.
        READ TABLE mt_rows INTO ls_row
          WITH KEY path = client->get_event_arg( ) filename = client->get_event_arg( 2 ).
        IF sy-subrc = 0.
          client->nav_app_call( zcl_ag2ui5_app_diff=>create( iv_key      = mv_key
                                                             iv_path     = ls_row-path
                                                             iv_filename = ls_row-filename
                                                             iv_obj_type = ls_row-obj_type
                                                             iv_obj_name = ls_row-obj_name ) ).
        ENDIF.
      WHEN `PATCH`.
        READ TABLE mt_rows INTO ls_row
          WITH KEY path = client->get_event_arg( ) filename = client->get_event_arg( 2 ).
        IF sy-subrc = 0.
          client->nav_app_call( zcl_ag2ui5_app_diff=>create(
            iv_key      = mv_key
            iv_path     = ls_row-path
            iv_filename = ls_row-filename
            iv_obj_type = ls_row-obj_type
            iv_obj_name = ls_row-obj_name
            iv_patch    = abap_true
            it_picked   = VALUE #( mt_patches[ path = ls_row-path filename = ls_row-filename ]-ids OPTIONAL ) ) ).
        ENDIF.
      WHEN `PUSH`.
        push( lv_token ).
    ENDCASE.

  ENDMETHOD.

  METHOD load_stage.

    TRY.
        DATA(ls_stage) = service( )->get_stage( mv_key ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.

    " after a reload the fingerprints are stale anyway
    CLEAR: mt_rows, mt_patches.
    LOOP AT ls_stage-items INTO DATA(ls_item).
      DATA(ls_row) = CORRESPONDING ty_row( ls_item ).
      ls_row-change = change_text( ls_row ).
      INSERT ls_row INTO TABLE mt_rows.
    ENDLOOP.
    IF ms_commit-name IS INITIAL.
      ms_commit-name  = ls_stage-name.
      ms_commit-email = ls_stage-email.
    ENDIF.

  ENDMETHOD.

  METHOD push.

    DATA lt_items TYPE zif_ag2ui5_repo_service=>ty_stage_items.

    DATA(lv_token) = iv_token.

    IF NOT line_exists( mt_rows[ selected = abap_true ] ).
      client->message_toast_display( `Select at least one file` ).
      RETURN.
    ENDIF.
    IF ms_commit-title IS INITIAL.
      client->message_toast_display( `Enter a commit title` ).
      RETURN.
    ENDIF.
    IF ms_commit-name IS INITIAL OR ms_commit-email IS INITIAL.
      client->message_toast_display( `Enter the committer's name and e-mail` ).
      RETURN.
    ENDIF.

    LOOP AT mt_rows INTO DATA(ls_row).
      DATA(ls_item) = CORRESPONDING zif_ag2ui5_repo_service=>ty_stage_item( ls_row ).
      READ TABLE mt_patches INTO DATA(ls_patch)
        WITH KEY path = ls_row-path filename = ls_row-filename.
      IF sy-subrc = 0.
        ls_item-patch_ids   = ls_patch-ids.
        ls_item-fingerprint = ls_patch-fingerprint.
      ENDIF.
      INSERT ls_item INTO TABLE lt_items.
    ENDLOOP.

    TRY.
        DATA(ls_result) = service( )->commit_push( iv_key    = mv_key
                                                   it_items  = lt_items
                                                   is_commit = ms_commit
                                                   iv_user   = mv_user
                                                   iv_token  = lv_token ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        CLEAR lv_token.
        client->message_box_display( text = lx_error->get_text( ) type = `error` ).
        RETURN.
    ENDTRY.
    CLEAR lv_token.

    CASE ls_result-outcome.
      WHEN zif_ag2ui5_repo_service=>c_outcome-pushed.
        CLEAR: ms_commit-title, ms_commit-body.
        client->message_toast_display( |Pushed { ls_result-commit }| ).
        load_stage( ).
      WHEN zif_ag2ui5_repo_service=>c_outcome-changed.
        load_stage( ).
        client->message_box_display( text = `The local changes changed since the page was loaded - nothing was pushed. Check the selection and push again.`
                                     type = `error` ).
    ENDCASE.

  ENDMETHOD.

  METHOD select_all.

    LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-selected = iv_selected.
    ENDLOOP.

  ENDMETHOD.

  METHOD service.

    ri_service = COND #( WHEN mi_service IS BOUND THEN mi_service ELSE NEW zcl_ag2ui5_repo_service( ) ).

  ENDMETHOD.

ENDCLASS.
