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

    "! The fresh preview's items with the user's ticks. Raises when anything
    "! differs from what the user saw: a new object, an object in another
    "! group now, or a ticked object that is gone
    CLASS-METHODS merge_decisions
      IMPORTING
        it_fresh        TYPE zif_ag2ui5_repo_service=>ty_decision_items
        it_posted       TYPE zif_ag2ui5_repo_service=>ty_decision_items
      RETURNING
        VALUE(rt_items) TYPE zif_ag2ui5_repo_service=>ty_decision_items
      RAISING
        zcx_abapgit_exception.

    "! Raises unless the request is one of the user's modifiable requests
    CLASS-METHODS assert_transport
      IMPORTING
        iv_transport  TYPE string
        it_transports TYPE zif_ag2ui5_repo_service=>ty_transports
      RAISING
        zcx_abapgit_exception.

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

    IF is_checks-overwrite IS INITIAL AND is_checks-overwrite_files IS INITIAL.
      rs_preview-outcome = zif_ag2ui5_repo_service=>c_outcome-nothing.
      RETURN.
    ENDIF.

    " the dialog asks for a request of these types
    IF is_checks-transport-required = abap_true.
      rs_preview-transport_type = is_checks-transport-type-request.
    ENDIF.
    IF is_checks-customizing-required = abap_true.
      rs_preview-customizing_type = is_checks-customizing-type-request.
    ENDIF.

    " as in abapGit's popup_decisions: a new namespace has to arrive before
    " the objects in it, so only the namespace is preselected then
    DATA(lv_new_namespace) = xsdbool( line_exists( is_checks-overwrite[
      obj_type = 'NSPC'
      action   = zif_abapgit_objects=>c_deserialize_action-add ] ) ).

    LOOP AT is_checks-overwrite INTO DATA(ls_change).
      DATA(lv_reason) = COND string( WHEN ls_change-text IS NOT INITIAL
                                     THEN ls_change-text
                                     ELSE |Action { ls_change-action }| ).
      CASE ls_change-action.
        WHEN zif_abapgit_objects=>c_deserialize_action-add
          OR zif_abapgit_objects=>c_deserialize_action-update.
          add_item( EXPORTING is_object   = ls_change
                              iv_group    = zif_ag2ui5_repo_service=>c_group-import
                              iv_reason   = lv_reason
                              iv_selected = xsdbool( lv_new_namespace = abap_false OR ls_change-obj_type = 'NSPC' )
                    CHANGING  ct_items    = rs_preview-items ).
        WHEN zif_abapgit_objects=>c_deserialize_action-delete
          OR zif_abapgit_objects=>c_deserialize_action-delete_add.
          add_item( EXPORTING is_object = ls_change
                              iv_group  = zif_ag2ui5_repo_service=>c_group-delete
                              iv_reason = lv_reason
                    CHANGING  ct_items  = rs_preview-items ).
        WHEN zif_abapgit_objects=>c_deserialize_action-packmove.
          add_item( EXPORTING is_object = ls_change
                              iv_group  = zif_ag2ui5_repo_service=>c_group-package
                              iv_reason = lv_reason
                    CHANGING  ct_items  = rs_preview-items ).
        WHEN zif_abapgit_objects=>c_deserialize_action-no_support.
          add_item( EXPORTING is_object     = ls_change
                              iv_group      = zif_ag2ui5_repo_service=>c_group-skipped
                              iv_reason     = `Object type not supported`
                              iv_selectable = abap_false
                    CHANGING  ct_items      = rs_preview-items ).
        WHEN OTHERS.
          " overwrite, and anything abapGit adds later: a local change is at stake
          add_item( EXPORTING is_object = ls_change
                              iv_group  = zif_ag2ui5_repo_service=>c_group-overwrite
                              iv_reason = lv_reason
                    CHANGING  ct_items  = rs_preview-items ).
      ENDCASE.
    ENDLOOP.

    LOOP AT is_checks-warning_package INTO ls_change.
      DATA(lv_package_note) = |Object is in package { ls_change-devclass }, outside this repository|.
      add_item( EXPORTING is_object = ls_change
                          iv_group  = zif_ag2ui5_repo_service=>c_group-package
                          iv_reason = lv_package_note
                CHANGING  ct_items  = rs_preview-items ).
      " when a more dangerous group wins, the foreign package must still show
      READ TABLE rs_preview-items ASSIGNING FIELD-SYMBOL(<ls_item>)
        WITH KEY obj_type = CONV string( ls_change-obj_type ) obj_name = CONV string( ls_change-obj_name ).
      IF sy-subrc = 0 AND <ls_item>-reason NS lv_package_note.
        <ls_item>-reason = |{ <ls_item>-reason } - { lv_package_note }|.
      ENDIF.
    ENDLOOP.
    LOOP AT is_checks-data_loss INTO ls_change.
      add_item( EXPORTING is_object = ls_change
                          iv_group  = zif_ag2ui5_repo_service=>c_group-data_loss
                          iv_reason = COND #( WHEN ls_change-text IS NOT INITIAL
                                              THEN ls_change-text
                                              ELSE `Data would be lost` )
                CHANGING  ct_items  = rs_preview-items ).
    ENDLOOP.
    LOOP AT is_checks-delete_tabl_with_data INTO ls_change.
      add_item( EXPORTING is_object = ls_change
                          iv_group  = zif_ag2ui5_repo_service=>c_group-data_loss
                          iv_reason = `Table with data would be deleted`
                CHANGING  ct_items  = rs_preview-items ).
    ENDLOOP.

    IF is_checks-requirements-met = zif_abapgit_definitions=>c_no.
      rs_preview-ack_text = `The system does not meet the requirements in .abapgit.xml.`.
    ENDIF.
    IF is_checks-dependencies-met = zif_abapgit_definitions=>c_no.
      rs_preview-ack_text = condense( |{ rs_preview-ack_text } APACK dependencies are not installed.| ).
    ENDIF.

    rs_preview-outcome = zif_ag2ui5_repo_service=>c_outcome-ready.

  ENDMETHOD.

  METHOD add_item.

    READ TABLE ct_items ASSIGNING FIELD-SYMBOL(<ls_item>)
      WITH KEY obj_type = CONV string( is_object-obj_type )
               obj_name = CONV string( is_object-obj_name ).
    IF sy-subrc <> 0.
      INSERT VALUE #( obj_type   = is_object-obj_type
                      obj_name   = is_object-obj_name
                      group      = iv_group
                      reason     = iv_reason
                      selected   = iv_selected
                      selectable = iv_selectable ) INTO TABLE ct_items.
    ELSEIF group_rank( iv_group ) < group_rank( <ls_item>-group ).
      " a more dangerous group also takes the default of that group
      <ls_item>-group      = iv_group.
      <ls_item>-reason     = iv_reason.
      <ls_item>-selected   = iv_selected.
      <ls_item>-selectable = iv_selectable.
    ENDIF.

  ENDMETHOD.

  METHOD group_rank.

    rv_rank = SWITCH #( iv_group
                        WHEN zif_ag2ui5_repo_service=>c_group-data_loss THEN 1
                        WHEN zif_ag2ui5_repo_service=>c_group-delete    THEN 2
                        WHEN zif_ag2ui5_repo_service=>c_group-overwrite THEN 3
                        WHEN zif_ag2ui5_repo_service=>c_group-package   THEN 4
                        WHEN zif_ag2ui5_repo_service=>c_group-import    THEN 5
                        ELSE 6 ).

  ENDMETHOD.

  METHOD assert_transport.

    IF iv_transport IS INITIAL.
      zcx_abapgit_exception=>raise( `This package needs a transport request - choose one` ).
    ENDIF.
    IF NOT line_exists( it_transports[ trkorr = iv_transport ] ).
      zcx_abapgit_exception=>raise( |{ iv_transport } is not one of your modifiable requests of the required type| ).
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_transports.

    DATA lv_type TYPE e070-trfunction.

    assert_authorized( ).
    lv_type = iv_type.

    " D = modifiable, L = modifiable and protected - both still take objects
    SELECT e070~trkorr, e07t~as4text FROM e070
      LEFT OUTER JOIN e07t ON e07t~trkorr = e070~trkorr AND e07t~langu = @sy-langu
      WHERE e070~as4user    = @sy-uname
        AND e070~trfunction = @lv_type
        AND e070~trstatus   IN ('D', 'L')
        AND e070~strkorr    = @space
      ORDER BY e070~trkorr DESCENDING
      INTO TABLE @DATA(lt_requests).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rt_transports = VALUE #( FOR ls_request IN lt_requests
                             ( trkorr = ls_request-trkorr text = ls_request-as4text ) ).

  ENDMETHOD.

  METHOD merge_decisions.

    LOOP AT it_fresh INTO DATA(ls_fresh).
      READ TABLE it_posted INTO DATA(ls_posted)
        WITH KEY obj_type = ls_fresh-obj_type obj_name = ls_fresh-obj_name.
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( |{ ls_fresh-obj_type } { ls_fresh-obj_name } is new since the preview| ).
      ENDIF.
      " a tick given to an import must not turn into a delete or an overwrite
      IF ls_posted-group <> ls_fresh-group.
        zcx_abapgit_exception=>raise( |{ ls_fresh-obj_type } { ls_fresh-obj_name } is { ls_fresh-group } now, | &&
                                      |not { ls_posted-group }| ).
      ENDIF.
      " the server decides what can be ticked, not the client
      ls_fresh-selected = xsdbool( ls_posted-selected = abap_true AND ls_fresh-selectable = abap_true ).
      INSERT ls_fresh INTO TABLE rt_items.
    ENDLOOP.

    LOOP AT it_posted INTO ls_posted WHERE selected = abap_true.
      IF NOT line_exists( it_fresh[ obj_type = ls_posted-obj_type obj_name = ls_posted-obj_name ] ).
        zcx_abapgit_exception=>raise( |{ ls_posted-obj_type } { ls_posted-obj_name } is no longer part of the pull| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD apply_decisions.

    FIELD-SYMBOLS <ls_row> TYPE zif_abapgit_definitions=>ty_overwrite.

    rs_checks = is_checks.

    " every row of every table gets a decision, so abapGit's checks_adjust
    " never finds one without
    LOOP AT rs_checks-overwrite ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.
    LOOP AT rs_checks-warning_package ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.
    LOOP AT rs_checks-data_loss ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.
    LOOP AT rs_checks-delete_tabl_with_data ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.

    IF rs_checks-requirements-met = zif_abapgit_definitions=>c_no
        OR rs_checks-dependencies-met = zif_abapgit_definitions=>c_no.
      IF iv_acknowledged = abap_false.
        zcx_abapgit_exception=>raise( `Requirements or dependencies are not met and were not acknowledged` ).
      ENDIF.
      rs_checks-requirements-decision = zif_abapgit_definitions=>c_yes.
      rs_checks-dependencies-decision = zif_abapgit_definitions=>c_yes.
    ENDIF.

  ENDMETHOD.

  METHOD decide.

    READ TABLE it_items INTO DATA(ls_item)
      WITH KEY obj_type = CONV string( is_object-obj_type )
               obj_name = CONV string( is_object-obj_name ).
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |{ is_object-obj_type } { is_object-obj_name } was not in the preview| ).
    ENDIF.

    " skipped items cannot be ticked in the dialog, so selected alone decides
    rv_decision = COND #( WHEN ls_item-selected = abap_true
                          THEN zif_abapgit_definitions=>c_yes
                          ELSE zif_abapgit_definitions=>c_no ).

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

    " the request comes from the client, so it is checked against the
    " user's own modifiable requests before anything is written to it
    IF ls_preview-transport_type IS NOT INITIAL.
      assert_transport( iv_transport  = iv_transport
                        it_transports = zif_ag2ui5_repo_service~list_transports( ls_preview-transport_type ) ).
    ENDIF.
    IF ls_preview-customizing_type IS NOT INITIAL.
      assert_transport( iv_transport  = iv_customizing
                        it_transports = zif_ag2ui5_repo_service~list_transports( ls_preview-customizing_type ) ).
    ENDIF.

    IF ls_preview-ack_text IS NOT INITIAL AND iv_acknowledged = abap_false.
      zcx_abapgit_exception=>raise( |{ ls_preview-ack_text } - confirm "Pull anyway" to continue| ).
    ENDIF.

    TRY.
        DATA(lt_items) = merge_decisions( it_fresh  = ls_preview-items
                                          it_posted = it_items ).
      CATCH zcx_abapgit_exception.
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-changed.
        RETURN.
    ENDTRY.

    " abapGit refuses a pull with nothing selected; deserialize( ) would still
    " move the last-pull timestamp
    IF ls_checks-overwrite IS NOT INITIAL AND NOT line_exists( lt_items[ selected = abap_true ] ).
      rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-nothing.
      RETURN.
    ENDIF.

    DATA(ls_decided) = apply_decisions( is_checks       = ls_checks
                                        it_items        = lt_items
                                        iv_acknowledged = iv_acknowledged ).
    " deletion and deserialize both record their objects on these requests
    IF ls_preview-transport_type IS NOT INITIAL.
      ls_decided-transport-transport = iv_transport.
    ENDIF.
    IF ls_preview-customizing_type IS NOT INITIAL.
      ls_decided-customizing-transport = iv_customizing.
    ENDIF.

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
