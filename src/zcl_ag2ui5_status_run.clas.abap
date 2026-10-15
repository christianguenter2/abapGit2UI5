"! Background Status runs: the task serializes the local files of one
"! repository into ZAG2UI5_RUN; Status polls the row and takes the files.
"! Rows are only read for the current user and the given repository
CLASS zcl_ag2ui5_status_run DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Writes a running row and starts the task; empty when it did not start
    CLASS-METHODS create
      IMPORTING
        iv_key           TYPE string
      RETURNING
        VALUE(rv_run_id) TYPE string.

    "! State of a run of this user and repository; gone for anything else
    CLASS-METHODS state
      IMPORTING
        iv_run_id       TYPE string
        iv_key          TYPE string
      RETURNING
        VALUE(rs_state) TYPE zif_ag2ui5_repo_service=>ty_run_state.

    "! The local files of a finished run; the row is deleted
    CLASS-METHODS take_files
      IMPORTING
        iv_run_id       TYPE string
        iv_key          TYPE string
      RETURNING
        VALUE(rt_files) TYPE zif_abapgit_definitions=>ty_files_item_tt
      RAISING
        zcx_abapgit_exception.

    "! Body of Z_AG2UI5_SERIALIZE_LOCAL, runs in the task
    CLASS-METHODS serialize
      IMPORTING
        iv_run_id TYPE sysuuid_c32
        iv_key    TYPE string.

    "! Tests replace the task start
    CLASS-METHODS inject
      IMPORTING
        ii_starter TYPE REF TO zif_ag2ui5_run_starter.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA gi_starter TYPE REF TO zif_ag2ui5_run_starter.
ENDCLASS.



CLASS zcl_ag2ui5_status_run IMPLEMENTATION.

  METHOD create.
    " contract stub, implemented in the backend task: nothing starts
    IF iv_key IS INITIAL OR gi_starter IS BOUND.
      CLEAR rv_run_id.
    ENDIF.
  ENDMETHOD.

  METHOD state.
    " contract stub, implemented in the backend task
    SELECT SINGLE state FROM zag2ui5_run
      WHERE run_id = @iv_run_id AND uname = @sy-uname AND repo_key = @iv_key
      INTO @rs_state-state.
    IF sy-subrc <> 0.
      rs_state-state = zif_ag2ui5_repo_service=>c_run_state-gone.
    ENDIF.
  ENDMETHOD.

  METHOD take_files.
    " contract stub, implemented in the backend task
    CLEAR rt_files.
    zcx_abapgit_exception=>raise( |Background run { iv_run_id } of { iv_key } not found| ).
  ENDMETHOD.

  METHOD serialize.
    " contract stub, implemented in the backend task
    ASSERT iv_run_id IS NOT INITIAL AND iv_key IS NOT INITIAL.
  ENDMETHOD.

  METHOD inject.
    gi_starter = ii_starter.
  ENDMETHOD.

ENDCLASS.
