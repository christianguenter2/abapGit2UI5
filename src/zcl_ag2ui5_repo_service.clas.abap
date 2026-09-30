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
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_status.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~pull.
  ENDMETHOD.

ENDCLASS.
