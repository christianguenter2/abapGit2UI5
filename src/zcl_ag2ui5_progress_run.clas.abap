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
ENDCLASS.



CLASS zcl_ag2ui5_progress_run IMPLEMENTATION.

  METHOD constructor.
    mv_run_id = iv_run_id.
  ENDMETHOD.

  METHOD zif_abapgit_progress~show ##NEEDED.
    " contract stub, implemented in the backend task
  ENDMETHOD.

  METHOD zif_abapgit_progress~set_total ##NEEDED.
    " contract stub, implemented in the backend task
  ENDMETHOD.

  METHOD zif_abapgit_progress~off ##NEEDED.
  ENDMETHOD.

ENDCLASS.
