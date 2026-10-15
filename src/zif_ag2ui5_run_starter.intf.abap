"! Starts the background task of a Status run; tests replace it
INTERFACE zif_ag2ui5_run_starter
  PUBLIC.

  "! Starts Z_AG2UI5_SERIALIZE_LOCAL; false when the system refuses
  METHODS start
    IMPORTING
      iv_run_id         TYPE sysuuid_c32
      iv_key            TYPE string
    RETURNING
      VALUE(rv_started) TYPE abap_bool.

ENDINTERFACE.
