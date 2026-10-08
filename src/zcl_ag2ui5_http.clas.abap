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
    "! The current request came through this node (set by the handler).
    "! Only here may a login keep credentials in a stateful session: the node
    "! ends idle sessions after 30 minutes
    CLASS-METHODS is_own_node
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.
    CLASS-METHODS mark_own_node
      IMPORTING
        iv_yes TYPE abap_bool.

    CLASS-METHODS start_url
      IMPORTING
        iv_location   TYPE string
        iv_client     TYPE sy-mandt DEFAULT sy-mandt
        iv_language   TYPE sy-langu DEFAULT sy-langu
      RETURNING
        VALUE(rv_url) TYPE string.

  PROTECTED SECTION.
    "! Server side, unlike the path the browser reports
    CLASS-DATA gv_own_node TYPE abap_bool.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_http IMPLEMENTATION.

  METHOD start_url.
    DATA: language TYPE string.

    DATA(lv_location) = iv_location.
    IF lv_location CP `*/`.
      lv_location = substring( val = lv_location len = strlen( lv_location ) - 1 ).
    ENDIF.

    CALL FUNCTION 'CONVERSION_EXIT_ISOLA_OUTPUT'
      EXPORTING input  = iv_language
      IMPORTING output = language.

    rv_url = |{ lv_location }{ zcl_ag2ui5_app_login=>c_node }?sap-client={ iv_client }&sap-language={ language }&app_start=zcl_ag2ui5_app_repos|.

  ENDMETHOD.

  METHOD is_own_node.
    rv_yes = gv_own_node.
  ENDMETHOD.

  METHOD mark_own_node.
    gv_own_node = iv_yes.
  ENDMETHOD.

  METHOD if_http_extension~handle_request.

    mark_own_node( abap_true ).
    zcl_ag2ui5_repo_service=>request_start( ).
    z2ui5_cl_http_handler=>run( server ).

  ENDMETHOD.

ENDCLASS.
