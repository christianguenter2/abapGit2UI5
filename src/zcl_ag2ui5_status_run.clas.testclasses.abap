CLASS ltcl_status_run DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS unknown_id_is_gone FOR TESTING.
ENDCLASS.


CLASS ltcl_status_run IMPLEMENTATION.

  METHOD unknown_id_is_gone.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_status_run=>state( iv_run_id = `NO_SUCH_RUN` iv_key = `000000000001` )-state
      exp = zif_ag2ui5_repo_service=>c_run_state-gone ).
  ENDMETHOD.

ENDCLASS.
