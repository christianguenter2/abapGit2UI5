"! Where the settings live: the table, or memory in the tests
INTERFACE lif_store.
  METHODS read
    IMPORTING
      iv_user  TYPE syuname
      iv_key   TYPE string
    EXPORTING
      ev_found TYPE abap_bool
      ev_value TYPE string.
  METHODS write
    IMPORTING
      iv_user  TYPE syuname
      iv_key   TYPE string
      iv_value TYPE string.
ENDINTERFACE.
