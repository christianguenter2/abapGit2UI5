"! Starts the task as aRFC without a callback: the HTTP request returns at
"! once and the task runs on in its own session (checked on A4H25)
CLASS zcl_ag2ui5_run_starter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_run_starter.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_run_starter IMPLEMENTATION.

  METHOD zif_ag2ui5_run_starter~start.

    DATA lv_message TYPE c LENGTH 200.
    DATA(lv_task) = CONV char32( iv_run_id ).

    CALL FUNCTION 'Z_AG2UI5_SERIALIZE_LOCAL'
      STARTING NEW TASK lv_task
      DESTINATION 'NONE'
      EXPORTING
        iv_run_id             = iv_run_id
        iv_key                = iv_key
      EXCEPTIONS
        resource_failure      = 1
        system_failure        = 2 MESSAGE lv_message
        communication_failure = 3 MESSAGE lv_message
        OTHERS                = 4.
    rv_started = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.

ENDCLASS.
