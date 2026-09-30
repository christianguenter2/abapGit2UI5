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
ENDCLASS.



CLASS zcl_ag2ui5_repo_service IMPLEMENTATION.

  METHOD classify.
  ENDMETHOD.

  METHOD filter_status.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_repos.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_status.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~pull.
  ENDMETHOD.

ENDCLASS.
