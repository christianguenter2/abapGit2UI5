*&---------------------------------------------------------------------*
*& Transaction ZABAPGIT2UI5: opens abapGit2UI5 in the default browser
*&---------------------------------------------------------------------*
REPORT zabapgit2ui5.

"! Opens the repository list of abapGit2UI5 in the default browser
CLASS lcl_app DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    "! Protocol, host and port as configured for the ICF node. Where the
    "! server's own name is not reachable from the browser (a container, for
    "! example), table HTTPURLLOC maps the node to the reachable host
    METHODS start_url
      RETURNING
        VALUE(rv_url) TYPE string.
    "! A message with the URL when no browser can be opened (no SAP GUI)
    METHODS open_browser
      IMPORTING
        iv_url TYPE string.

ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD run.
    open_browser( start_url( ) ).
  ENDMETHOD.

  METHOD start_url.
    rv_url = zcl_ag2ui5_http=>start_url(
      iv_location = cl_http_server=>if_http_server~get_location( application = zcl_ag2ui5_app_login=>c_node )
      iv_client   = sy-mandt ).
  ENDMETHOD.

  METHOD open_browser.

    " CALL_BROWSER takes a character field
    DATA lv_url TYPE c LENGTH 1024.

    lv_url = iv_url.
    CALL FUNCTION 'CALL_BROWSER'
      EXPORTING
        url    = lv_url
      EXCEPTIONS
        OTHERS = 1.
    IF sy-subrc <> 0.
      MESSAGE |The browser could not be opened. Start abapGit2UI5 at { iv_url }| TYPE 'I'.
    ENDIF.

  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->run( ).
