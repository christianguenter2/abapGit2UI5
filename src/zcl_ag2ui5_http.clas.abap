"! HTTP handler of the ICF node /sap/bc/zabapgit2ui5: abap2UI5 behind a node
"! of its own, with a 30 minute session timeout for the stateful sessions
"! that keep Git credentials in memory
CLASS zcl_ag2ui5_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_http IMPLEMENTATION.

  METHOD if_http_extension~handle_request.

    z2ui5_cl_http_handler=>run( server ).

  ENDMETHOD.

ENDCLASS.
