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
    CLASS-METHODS starter RETURNING VALUE(ri_starter) TYPE REF TO zif_ag2ui5_run_starter.
ENDCLASS.



CLASS zcl_ag2ui5_status_run IMPLEMENTATION.

  METHOD create.
    IF iv_key IS INITIAL OR strlen( iv_key ) > 12 OR iv_key CN `0123456789`.
      RETURN.
    ENDIF.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    DATA(lv_old) = cl_abap_tstmp=>subtractsecs( tstmp = lv_now secs = 3600 ).
    DELETE FROM zag2ui5_run WHERE uname = @sy-uname AND created < @lv_old ##SUBRC_OK.
    TRY.
        DATA(lv_id) = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        COMMIT WORK.
        RETURN.
    ENDTRY.
    DATA(ls_row) = VALUE zag2ui5_run( run_id = lv_id uname = sy-uname repo_key = iv_key
                                    created = lv_now changed = lv_now state = 'R' ).
    INSERT zag2ui5_run FROM @ls_row.
    IF sy-subrc <> 0.
      COMMIT WORK.
      RETURN.
    ENDIF.
    " The task runs in another session and must see the row before it starts.
    COMMIT WORK.
    IF starter( )->start( iv_run_id = lv_id iv_key = iv_key ) = abap_false.
      DELETE FROM zag2ui5_run WHERE run_id = @lv_id AND uname = @sy-uname AND repo_key = @iv_key ##SUBRC_OK.
      COMMIT WORK.
      RETURN.
    ENDIF.
    rv_run_id = lv_id.
  ENDMETHOD.

  METHOD state.
    SELECT SINGLE state, done_count, total_count, message, changed FROM zag2ui5_run
      WHERE run_id = @iv_run_id AND uname = @sy-uname AND repo_key = @iv_key
      INTO @DATA(ls_row).
    IF sy-subrc <> 0.
      rs_state-state = zif_ag2ui5_repo_service=>c_run_state-gone.
      RETURN.
    ENDIF.
    rs_state = VALUE #( state = ls_row-state done = ls_row-done_count
                       total = ls_row-total_count message = ls_row-message ).
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    rs_state-idle_seconds = CONV i( cl_abap_tstmp=>subtract( tstmp1 = lv_now tstmp2 = ls_row-changed ) ).
  ENDMETHOD.

  METHOD take_files.
    SELECT SINGLE state, files FROM zag2ui5_run
      WHERE run_id = @iv_run_id AND uname = @sy-uname AND repo_key = @iv_key
      INTO @DATA(ls_row).
    IF sy-subrc <> 0 OR ls_row-state <> 'D'.
      zcx_abapgit_exception=>raise( `Background run is not finished` ).
    ENDIF.
    TRY.
        IMPORT files = rt_files FROM DATA BUFFER ls_row-files.
        IF sy-subrc <> 0.
          zcx_abapgit_exception=>raise( `Background run has no local files` ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_error).
        zcx_abapgit_exception=>raise( |Cannot read background run: { lx_error->get_text( ) }| ).
    ENDTRY.
    DELETE FROM zag2ui5_run
      WHERE run_id = @iv_run_id AND uname = @sy-uname AND repo_key = @iv_key AND state = 'D'.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( `Background run was already consumed` ).
    ENDIF.
    COMMIT WORK.
  ENDMETHOD.

  METHOD serialize.
    zcl_abapgit_progress=>set_instance( NEW zcl_ag2ui5_progress_run( iv_run_id ) ).
    " Reject a missing or foreign row before loading any repository.
    SELECT SINGLE state FROM zag2ui5_run
      WHERE run_id = @iv_run_id AND uname = @sy-uname AND repo_key = @iv_key
      INTO @DATA(lv_state).
    IF sy-subrc <> 0 OR lv_state <> 'R'.
      RETURN.
    ENDIF.
    DATA lv_now TYPE timestampl.
    TRY.
        IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-startup ) = abap_false.
          zcx_abapgit_exception=>raise( `You are not authorized to use abapGit` ).
        ENDIF.
        DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->get( CONV #( iv_key ) ).
        li_repo->refresh( iv_drop_cache = abap_true ).
        DATA(lt_files) = li_repo->get_files_local( ).
        DATA lv_buffer TYPE xstring.
        EXPORT files = lt_files TO DATA BUFFER lv_buffer COMPRESSION ON.
        GET TIME STAMP FIELD lv_now.
        UPDATE zag2ui5_run SET state = 'D', files = @lv_buffer, changed = @lv_now
          WHERE run_id = @iv_run_id AND uname = @sy-uname AND repo_key = @iv_key AND state = 'R' ##SUBRC_OK.
        COMMIT WORK.
      CATCH cx_root INTO DATA(lx_error).
        DATA(lv_message) = lx_error->get_text( ).
        GET TIME STAMP FIELD lv_now.
        UPDATE zag2ui5_run SET state = 'E', message = @lv_message, changed = @lv_now
          WHERE run_id = @iv_run_id AND uname = @sy-uname AND repo_key = @iv_key AND state = 'R' ##SUBRC_OK.
        COMMIT WORK.
    ENDTRY.
  ENDMETHOD.

  METHOD starter.
    IF gi_starter IS BOUND.
      ri_starter = gi_starter.
    ELSE.
      ri_starter = NEW zcl_ag2ui5_run_starter( ).
    ENDIF.
  ENDMETHOD.

  METHOD inject.
    gi_starter = ii_starter.
  ENDMETHOD.

ENDCLASS.
