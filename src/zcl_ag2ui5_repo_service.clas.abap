"! Talks to the abapGit developer version on behalf of the apps
CLASS zcl_ag2ui5_repo_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service.

    "! The decision dialog's content: one item per object, in its most
    "! dangerous group, with abapGit's defaults preselected
    CLASS-METHODS preview
      IMPORTING
        is_checks         TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RETURNING
        VALUE(rs_preview) TYPE zif_ag2ui5_repo_service=>ty_preview.

    "! Writes the decisions into every check table an object is in. Raises
    "! when an object has no item (the remote changed since the preview) or
    "! when unmet requirements are not acknowledged
    CLASS-METHODS apply_decisions
      IMPORTING
        is_checks        TYPE zif_abapgit_definitions=>ty_deserialize_checks
        it_items         TYPE zif_ag2ui5_repo_service=>ty_decision_items
        iv_acknowledged  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_checks) TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RAISING
        zcx_abapgit_exception.

    "! Keeps the files that differ or are inactive
    CLASS-METHODS filter_status
      IMPORTING
        it_results     TYPE zif_abapgit_definitions=>ty_results_tt
      RETURNING
        VALUE(rt_rows) TYPE zif_ag2ui5_repo_service=>ty_status_rows.

    "! Date and time to the minute in the user's time zone, empty if initial
    CLASS-METHODS format_timestamp
      IMPORTING
        iv_timestamp   TYPE timestampl
        iv_timezone    TYPE tznzone DEFAULT sy-zonlo
      RETURNING
        VALUE(rv_text) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS silence_progress.

    "! abapGit's own startup authorization (its user exit can restrict it)
    METHODS assert_authorized
      RAISING
        zcx_abapgit_exception.

    METHODS get_online_repo
      IMPORTING
        iv_key         TYPE string
      RETURNING
        VALUE(ri_repo) TYPE REF TO zif_abapgit_repo_online
      RAISING
        zcx_abapgit_exception.

    "! Refuses to replace code that runs in this very session
    METHODS assert_pull_allowed
      IMPORTING
        iv_package TYPE devclass
      RAISING
        zcx_abapgit_exception.

    "! Imports and turns the log into the result - also when the import
    "! raises half-way, which is when the log matters most
    METHODS deserialize_logged
      IMPORTING
        ii_repo          TYPE REF TO zif_abapgit_repo
        is_checks        TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RETURNING
        VALUE(rs_result) TYPE zif_ag2ui5_repo_service=>ty_pull_result.

    METHODS map_messages
      IMPORTING
        ii_log             TYPE REF TO zif_abapgit_log
      RETURNING
        VALUE(rt_messages) TYPE zif_ag2ui5_repo_service=>ty_messages.

    "! Deletes the objects whose deletion was selected, as abapGit's
    "! delete_unnecessary_objects does before deserializing
    METHODS delete_selected
      IMPORTING
        ii_repo   TYPE REF TO zif_abapgit_repo
        is_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks
        ii_log    TYPE REF TO zif_abapgit_log
      RAISING
        zcx_abapgit_exception.

    "! Adds the object, or moves it to the new group if that is more dangerous
    CLASS-METHODS add_item
      IMPORTING
        is_object     TYPE zif_abapgit_definitions=>ty_overwrite
        iv_group      TYPE zif_ag2ui5_repo_service=>ty_group
        iv_reason     TYPE string
        iv_selected   TYPE abap_bool DEFAULT abap_false
        iv_selectable TYPE abap_bool DEFAULT abap_true
      CHANGING
        ct_items      TYPE zif_ag2ui5_repo_service=>ty_decision_items.

    "! 1 is the most dangerous group
    CLASS-METHODS group_rank
      IMPORTING
        iv_group       TYPE zif_ag2ui5_repo_service=>ty_group
      RETURNING
        VALUE(rv_rank) TYPE i.

    CLASS-METHODS decide
      IMPORTING
        it_items           TYPE zif_ag2ui5_repo_service=>ty_decision_items
        is_object          TYPE zif_abapgit_definitions=>ty_overwrite
      RETURNING
        VALUE(rv_decision) TYPE zif_abapgit_definitions=>ty_yes_no
      RAISING
        zcx_abapgit_exception.

ENDCLASS.



CLASS zcl_ag2ui5_repo_service IMPLEMENTATION.

  METHOD preview.
  ENDMETHOD.

  METHOD apply_decisions.
  ENDMETHOD.

  METHOD add_item.
  ENDMETHOD.

  METHOD group_rank.
  ENDMETHOD.

  METHOD decide.
  ENDMETHOD.

  METHOD filter_status.

    LOOP AT it_results INTO DATA(ls_result) WHERE match = abap_false OR inactive = abap_true.
      INSERT VALUE #( obj_type = ls_result-obj_type
                      obj_name = ls_result-obj_name
                      path     = ls_result-path
                      filename = ls_result-filename
                      lstate   = ls_result-lstate
                      rstate   = ls_result-rstate
                      inactive = ls_result-inactive ) INTO TABLE rt_rows.
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_repos.

    assert_authorized( ).
    DATA li_online TYPE REF TO zif_abapgit_repo_online.

    silence_progress( ).

    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( ) INTO DATA(li_repo).
      DATA(ls_repo) = VALUE zif_ag2ui5_repo_service=>ty_repo(
        key     = li_repo->get_key( )
        name    = li_repo->get_name( )
        package = li_repo->get_package( )
        offline = li_repo->is_offline( ) ).

      ls_repo-deserialized_at = format_timestamp( li_repo->ms_data-deserialized_at ).

      IF ls_repo-offline = abap_false.
        li_online ?= li_repo.
        ls_repo-url    = li_online->get_url( ).
        ls_repo-branch = li_online->get_selected_branch( ).
      ENDIF.

      INSERT ls_repo INTO TABLE rt_repos.
    ENDLOOP.

    SORT rt_repos BY package.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_status.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).

    rs_status-key           = iv_key.
    rs_status-name          = li_repo->zif_abapgit_repo~get_name( ).
    rs_status-package       = li_repo->zif_abapgit_repo~get_package( ).
    rs_status-url           = li_repo->get_url( ).
    rs_status-branch        = li_repo->get_selected_branch( ).
    rs_status-remote_commit = li_repo->get_current_remote( ).
    rs_status-rows          = filter_status( zcl_abapgit_repo_status=>calculate( li_repo ) ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~preview_pull.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    assert_pull_allowed( li_repo->zif_abapgit_repo~get_package( ) ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).

    rs_preview = preview( li_repo->zif_abapgit_repo~deserialize_checks( ) ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~pull.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    assert_pull_allowed( li_repo->zif_abapgit_repo~get_package( ) ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).

    " check again - the remote or the system may have changed since the preview
    DATA(ls_checks)  = li_repo->zif_abapgit_repo~deserialize_checks( ).
    DATA(ls_preview) = preview( ls_checks ).

    CASE ls_preview-outcome.
      WHEN zif_ag2ui5_repo_service=>c_outcome-nothing.
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-nothing.
        RETURN.
      WHEN zif_ag2ui5_repo_service=>c_outcome-blocked.
        zcx_abapgit_exception=>raise( ls_preview-blocked ).
    ENDCASE.

    IF ls_preview-ack_text IS NOT INITIAL AND iv_acknowledged = abap_false.
      zcx_abapgit_exception=>raise( |{ ls_preview-ack_text } - confirm "Pull anyway" to continue| ).
    ENDIF.

    TRY.
        DATA(ls_decided) = apply_decisions( is_checks       = ls_checks
                                            it_items        = it_items
                                            iv_acknowledged = iv_acknowledged ).
      CATCH zcx_abapgit_exception.
        " the acknowledgement is checked above, so only an unknown object ends here
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-changed.
        RETURN.
    ENDTRY.

    rs_result = deserialize_logged( ii_repo   = li_repo
                                    is_checks = ls_decided ).

  ENDMETHOD.

  METHOD format_timestamp.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    IF iv_timestamp IS INITIAL.
      RETURN.
    ENDIF.

    CONVERT TIME STAMP iv_timestamp TIME ZONE iv_timezone INTO DATE lv_date TIME lv_time.
    rv_text = |{ lv_date DATE = ISO } { lv_time(2) }:{ lv_time+2(2) }|.

  ENDMETHOD.

  METHOD deserialize_logged.

    DATA(li_log) = ii_repo->create_new_log( `Pull Log` ).

    TRY.
        delete_selected( ii_repo   = ii_repo
                         is_checks = is_checks
                         ii_log    = li_log ).
        ii_repo->deserialize( is_checks = is_checks
                              ii_log    = li_log ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        " objects may already be imported - the log says which
        li_log->add_exception( lx_error ).
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-failed.
    ENDTRY.

    rs_result-messages = map_messages( li_log ).
    IF rs_result-outcome IS INITIAL.
      rs_result-outcome = COND #( WHEN li_log->get_status( ) = zif_abapgit_log=>c_status-error
                                  THEN zif_ag2ui5_repo_service=>c_outcome-failed
                                  ELSE zif_ag2ui5_repo_service=>c_outcome-pulled ).
    ENDIF.

  ENDMETHOD.

  METHOD delete_selected.

    DATA lt_tadir TYPE zif_abapgit_definitions=>ty_tadir_tt.
    DATA ls_delete_checks TYPE zif_abapgit_definitions=>ty_delete_checks.

    LOOP AT is_checks-overwrite INTO DATA(ls_change)
        WHERE ( action = zif_abapgit_objects=>c_deserialize_action-delete
             OR action = zif_abapgit_objects=>c_deserialize_action-delete_add )
          AND decision = zif_abapgit_definitions=>c_yes.
      INSERT VALUE #( pgmid    = 'R3TR'
                      object   = ls_change-obj_type
                      obj_name = ls_change-obj_name
                      devclass = ls_change-devclass ) INTO TABLE lt_tadir.
    ENDLOOP.

    IF lt_tadir IS INITIAL.
      RETURN.
    ENDIF.

    ls_delete_checks-transport = is_checks-transport.
    zcl_abapgit_objects=>delete( it_tadir  = lt_tadir
                                 is_checks = ls_delete_checks
                                 ii_log    = ii_log ).
    ii_repo->refresh( iv_drop_log = abap_false ).

  ENDMETHOD.

  METHOD assert_authorized.

    IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-startup ) = abap_false.
      zcx_abapgit_exception=>raise( `You are not authorized to use abapGit` ).
    ENDIF.

  ENDMETHOD.

  METHOD silence_progress.
    zcl_abapgit_progress=>set_instance( NEW zcl_ag2ui5_progress_silent( ) ).
  ENDMETHOD.

  METHOD get_online_repo.

    IF iv_key IS INITIAL.
      zcx_abapgit_exception=>raise( `No repository selected - start with zcl_ag2ui5_app_repos` ).
    ENDIF.

    DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->get( CONV #( iv_key ) ).

    IF li_repo->is_offline( ) = abap_true.
      zcx_abapgit_exception=>raise( |Repository { li_repo->get_name( ) } is offline - only online repositories are supported| ).
    ENDIF.

    ri_repo ?= li_repo.

  ENDMETHOD.

  METHOD assert_pull_allowed.

    " Decided by where the code serving this request lives, not by the URL: a
    " pull into any of these packages replaces classes this very request is
    " still executing (abapGit's check_self_update only covers ZABAPGIT)
    SELECT obj_name, devclass FROM tadir
      WHERE pgmid = 'R3TR'
        AND ( ( object = 'CLAS' AND obj_name = 'ZCL_ABAPGIT_REPO' )
           OR ( object = 'INTF' AND obj_name = 'Z2UI5_IF_APP' )
           OR ( object = 'CLAS' AND obj_name = 'ZCL_AG2UI5_REPO_SERVICE' ) )
      ORDER BY obj_name
      INTO TABLE @DATA(lt_running).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lt_tree) = zcl_abapgit_factory=>get_sap_package( iv_package )->list_subpackages( ).
    INSERT iv_package INTO TABLE lt_tree.

    LOOP AT lt_running INTO DATA(ls_running) WHERE devclass IS NOT INITIAL.
      IF line_exists( lt_tree[ table_line = ls_running-devclass ] ).
        zcx_abapgit_exception=>raise( |Pulling package { iv_package } would replace { ls_running-obj_name }, | &&
                                      |which is running in this session. Pull it with abapGit in SAP GUI.| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD map_messages.

    LOOP AT ii_log->get_messages( ) INTO DATA(ls_message).
      INSERT VALUE #( type     = ls_message-type
                      text     = ls_message-text
                      obj_type = ls_message-obj_type
                      obj_name = ls_message-obj_name ) INTO TABLE rt_messages.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
