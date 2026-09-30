"! Talks to the abapGit developer version on behalf of the apps
CLASS zcl_ag2ui5_repo_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service.

    "! Abort mode: applies the changes that lose nothing local and reports
    "! everything else as blocking - see the decision table in the design
    CLASS-METHODS classify
      IMPORTING
        is_checks        TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RETURNING
        VALUE(rs_result) TYPE zif_ag2ui5_repo_service=>ty_classification.

    "! Keeps the files that differ or are inactive
    CLASS-METHODS filter_status
      IMPORTING
        it_results     TYPE zif_abapgit_definitions=>ty_results_tt
      RETURNING
        VALUE(rt_rows) TYPE zif_ag2ui5_repo_service=>ty_status_rows.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CONSTANTS c_own_package TYPE devclass VALUE '$ABAPGIT2UI5'.

    METHODS silence_progress.

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
        ii_repo TYPE REF TO zif_abapgit_repo_online
      RAISING
        zcx_abapgit_exception.

    METHODS map_messages
      IMPORTING
        ii_log             TYPE REF TO zif_abapgit_log
      RETURNING
        VALUE(rt_messages) TYPE zif_ag2ui5_repo_service=>ty_messages.

    CLASS-METHODS block_objects
      IMPORTING
        it_objects TYPE zif_abapgit_definitions=>ty_overwrite_tt
        iv_reason  TYPE string
      CHANGING
        ct_items   TYPE zif_ag2ui5_repo_service=>ty_items.

    CLASS-METHODS block_condition
      IMPORTING
        iv_condition TYPE abap_bool
        iv_reason    TYPE string
      CHANGING
        ct_items     TYPE zif_ag2ui5_repo_service=>ty_items.

ENDCLASS.



CLASS zcl_ag2ui5_repo_service IMPLEMENTATION.

  METHOD classify.

    FIELD-SYMBOLS <ls_change> LIKE LINE OF rs_result-checks-overwrite.

    rs_result-checks = is_checks.

    IF is_checks-overwrite IS INITIAL AND is_checks-overwrite_files IS INITIAL.
      rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-nothing.
      RETURN.
    ENDIF.

    LOOP AT rs_result-checks-overwrite ASSIGNING <ls_change>.
      CASE <ls_change>-action.
        WHEN zif_abapgit_objects=>c_deserialize_action-add
          OR zif_abapgit_objects=>c_deserialize_action-update.
          " nothing local is lost: added or changed remotely only
          <ls_change>-decision = zif_abapgit_definitions=>c_yes.
        WHEN zif_abapgit_objects=>c_deserialize_action-no_support.
          <ls_change>-decision = zif_abapgit_definitions=>c_no.
          INSERT VALUE #( obj_type = <ls_change>-obj_type
                          obj_name = <ls_change>-obj_name
                          reason   = `Object type not supported, skipped` ) INTO TABLE rs_result-info.
        WHEN OTHERS.
          " overwrite, delete, delete_add, packmove: a local change would be lost
          <ls_change>-decision = zif_abapgit_definitions=>c_no.
          INSERT VALUE #( obj_type = <ls_change>-obj_type
                          obj_name = <ls_change>-obj_name
                          reason   = COND #( WHEN <ls_change>-text IS NOT INITIAL
                                             THEN <ls_change>-text
                                             ELSE |Local change would be lost (action { <ls_change>-action })| ) )
            INTO TABLE rs_result-blocking.
      ENDCASE.
    ENDLOOP.

    block_objects( EXPORTING it_objects = is_checks-data_loss
                             iv_reason  = `Data would be lost`
                   CHANGING  ct_items   = rs_result-blocking ).
    block_objects( EXPORTING it_objects = is_checks-delete_tabl_with_data
                             iv_reason  = `Table with data would be deleted`
                   CHANGING  ct_items   = rs_result-blocking ).
    block_objects( EXPORTING it_objects = is_checks-warning_package
                             iv_reason  = `Object belongs to a package outside this repository`
                   CHANGING  ct_items   = rs_result-blocking ).

    block_condition(
      EXPORTING iv_condition = xsdbool( is_checks-requirements-met = zif_abapgit_definitions=>c_no )
                iv_reason    = `The system does not meet the requirements in .abapgit.xml`
      CHANGING  ct_items     = rs_result-blocking ).
    block_condition(
      EXPORTING iv_condition = xsdbool( is_checks-dependencies-met = zif_abapgit_definitions=>c_no )
                iv_reason    = `APACK dependencies are not installed`
      CHANGING  ct_items     = rs_result-blocking ).
    block_condition(
      EXPORTING iv_condition = is_checks-transport-required
                iv_reason    = `A transport request is required - only local packages are supported`
      CHANGING  ct_items     = rs_result-blocking ).
    block_condition(
      EXPORTING iv_condition = is_checks-customizing-required
                iv_reason    = `A customizing request is required - only local packages are supported`
      CHANGING  ct_items     = rs_result-blocking ).

    rs_result-outcome = COND #( WHEN rs_result-blocking IS INITIAL
                                THEN zif_ag2ui5_repo_service=>c_outcome-ready
                                ELSE zif_ag2ui5_repo_service=>c_outcome-blocked ).

  ENDMETHOD.

  METHOD block_objects.

    LOOP AT it_objects INTO DATA(ls_object).
      INSERT VALUE #( obj_type = ls_object-obj_type
                      obj_name = ls_object-obj_name
                      reason   = iv_reason ) INTO TABLE ct_items.
    ENDLOOP.

  ENDMETHOD.

  METHOD block_condition.

    IF iv_condition = abap_true.
      INSERT VALUE #( reason = iv_reason ) INTO TABLE ct_items.
    ENDIF.

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

    DATA li_online TYPE REF TO zif_abapgit_repo_online.

    silence_progress( ).

    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( ) INTO DATA(li_repo).
      DATA(ls_repo) = VALUE zif_ag2ui5_repo_service=>ty_repo(
        key     = li_repo->get_key( )
        name    = li_repo->get_name( )
        package = li_repo->get_package( )
        offline = li_repo->is_offline( ) ).

      IF li_repo->ms_data-deserialized_at IS NOT INITIAL.
        ls_repo-deserialized_at = |{ li_repo->ms_data-deserialized_at TIMESTAMP = ISO }|.
      ENDIF.

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

  METHOD zif_ag2ui5_repo_service~pull.

    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    assert_pull_allowed( li_repo ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).

    DATA(ls_classification) = classify( li_repo->zif_abapgit_repo~deserialize_checks( ) ).
    rs_result-outcome  = ls_classification-outcome.
    rs_result-blocking = ls_classification-blocking.
    rs_result-info     = ls_classification-info.

    IF ls_classification-outcome <> zif_ag2ui5_repo_service=>c_outcome-ready.
      RETURN.
    ENDIF.

    " deletions always block, so unlike abapGit's own pull there is nothing to
    " delete before deserializing
    DATA(li_log) = li_repo->zif_abapgit_repo~create_new_log( `Pull Log` ).
    li_repo->zif_abapgit_repo~deserialize( is_checks = ls_classification-checks
                                           ii_log    = li_log ).

    rs_result-messages = map_messages( li_log ).
    rs_result-outcome  = COND #( WHEN li_log->get_status( ) = zif_abapgit_log=>c_status-error
                                 THEN zif_ag2ui5_repo_service=>c_outcome-failed
                                 ELSE zif_ag2ui5_repo_service=>c_outcome-pulled ).

  ENDMETHOD.

  METHOD silence_progress.
    zcl_abapgit_progress=>set_instance( NEW zcl_ag2ui5_progress_silent( ) ).
  ENDMETHOD.

  METHOD get_online_repo.

    DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->get( CONV #( iv_key ) ).

    IF li_repo->is_offline( ) = abap_true.
      zcx_abapgit_exception=>raise( |Repository { li_repo->get_name( ) } is offline - only online repositories are supported| ).
    ENDIF.

    ri_repo ?= li_repo.

  ENDMETHOD.

  METHOD assert_pull_allowed.

    " abapGit's own guard (check_self_update in zcl_abapgit_services_repo) only
    " fires when the running program is ZABAPGIT, which this one is not
    IF zcl_abapgit_url=>is_abapgit_repo( ii_repo->get_url( ) ) = abap_true
        OR ii_repo->zif_abapgit_repo~get_package( ) = c_own_package.
      zcx_abapgit_exception=>raise( |Pulling { ii_repo->zif_abapgit_repo~get_name( ) } would replace code | &&
                                    |that is running in this session. Pull it with abapGit in SAP GUI.| ).
    ENDIF.

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
