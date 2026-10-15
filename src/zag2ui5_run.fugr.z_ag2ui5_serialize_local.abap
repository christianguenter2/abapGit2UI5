FUNCTION z_ag2ui5_serialize_local.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(IV_RUN_ID) TYPE  SYSUUID_C32
*"     VALUE(IV_KEY) TYPE  STRING
*"----------------------------------------------------------------------

  " spike: replaced by zcl_ag2ui5_status_run=>serialize( )
  WAIT UP TO 20 SECONDS.
  DATA lv_now TYPE timestampl.
  GET TIME STAMP FIELD lv_now.
  UPDATE zag2ui5_run SET state = 'D' changed = lv_now WHERE run_id = iv_run_id.
  COMMIT WORK.

ENDFUNCTION.
