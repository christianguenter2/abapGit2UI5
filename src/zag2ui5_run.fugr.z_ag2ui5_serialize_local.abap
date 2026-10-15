FUNCTION z_ag2ui5_serialize_local.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_RUN_ID) TYPE  SYSUUID_C32
*"     VALUE(IV_KEY) TYPE  STRING
*"----------------------------------------------------------------------

  zcl_ag2ui5_status_run=>serialize( iv_run_id = iv_run_id
                                    iv_key    = iv_key ).

ENDFUNCTION.
