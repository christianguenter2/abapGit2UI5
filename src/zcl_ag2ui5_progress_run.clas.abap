"! abapGit's progress indicator, written into the run row of the task so
"! that Status can show how far serialization is
CLASS zcl_ag2ui5_progress_run DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_progress.

    METHODS constructor
      IMPORTING
        iv_run_id TYPE sysuuid_c32.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mv_run_id TYPE sysuuid_c32.
    DATA mv_total TYPE i.
    DATA mv_last_write TYPE timestampl.
ENDCLASS.



CLASS zcl_ag2ui5_progress_run IMPLEMENTATION.

  METHOD constructor.
    mv_run_id = iv_run_id.
  ENDMETHOD.

  METHOD zif_abapgit_progress~show.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    IF mv_last_write IS NOT INITIAL
        AND cl_abap_tstmp=>subtract( tstmp1 = lv_now tstmp2 = mv_last_write ) < 1.
      RETURN.
    ENDIF.
    UPDATE zag2ui5_run SET done_count = @iv_current, total_count = @mv_total, changed = @lv_now
      WHERE run_id = @mv_run_id AND uname = @sy-uname AND state = 'R'.
    IF sy-subrc = 0.
      COMMIT WORK.
      mv_last_write = lv_now.
    ENDIF.
  ENDMETHOD.

  METHOD zif_abapgit_progress~set_total.
    mv_total = iv_total.
  ENDMETHOD.

  METHOD zif_abapgit_progress~off ##NEEDED.
  ENDMETHOD.

ENDCLASS.
