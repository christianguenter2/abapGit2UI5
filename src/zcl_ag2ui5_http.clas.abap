"! HTTP handler of the ICF node /sap/bc/zabapgit2ui5: abap2UI5 behind a node
"! of its own, with a 30 minute session timeout for the stateful sessions
"! that keep Git credentials in memory
CLASS zcl_ag2ui5_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

    "! The start URL of abapGit2UI5: the repository list on this node.
    "! iv_location is protocol, host and port as the browser reaches them
    CLASS-METHODS start_url
      IMPORTING
        iv_location   TYPE string
        iv_client     TYPE sy-mandt
        iv_language   TYPE sy-langu
      RETURNING
        VALUE(rv_url) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_http IMPLEMENTATION.

  METHOD start_url.

    DATA(lv_location) = iv_location.
    IF lv_location CP `*/`.
      lv_location = substring( val = lv_location len = strlen( lv_location ) - 1 ).
    ENDIF.
    rv_url = |{ lv_location }{ zcl_ag2ui5_app_login=>c_node }?sap-client={ iv_client }&sap-language={ iv_language }&app_start=zcl_ag2ui5_app_repos|.

  ENDMETHOD.

  METHOD if_http_extension~handle_request.

    z2ui5_cl_http_handler=>run( server ).

  ENDMETHOD.

ENDCLASS.
