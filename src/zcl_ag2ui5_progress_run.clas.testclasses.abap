CLASS ltcl_progress_run DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS off_does_nothing FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.


CLASS ltcl_progress_run IMPLEMENTATION.

  METHOD off_does_nothing.
    DATA(li_progress) = CAST zif_abapgit_progress( NEW zcl_ag2ui5_progress_run( `NO_SUCH_RUN` ) ).
    li_progress->off( ).
    cl_abap_unit_assert=>assert_bound( li_progress ).
  ENDMETHOD.

ENDCLASS.
