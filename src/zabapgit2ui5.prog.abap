*&---------------------------------------------------------------------*
*& Transaction ZABAPGIT2UI5: opens abapGit2UI5 in the default browser
*&---------------------------------------------------------------------*
REPORT zabapgit2ui5.

START-OF-SELECTION.
  " protocol, host and port as configured for the node; where the server's
  " own name is not reachable from the browser (a container, for example),
  " table HTTPURLLOC maps /sap/bc/zabapgit2ui5 to the reachable host
  DATA(gv_url) = zcl_ag2ui5_http=>start_url(
    iv_location = cl_http_server=>if_http_server~get_location( application = zcl_ag2ui5_app_login=>c_node )
    iv_client   = sy-mandt ).
  DATA gv_url_c TYPE c LENGTH 1024.
  gv_url_c = gv_url.
  CALL FUNCTION 'CALL_BROWSER'
    EXPORTING
      url    = gv_url_c
    EXCEPTIONS
      OTHERS = 1.
  IF sy-subrc <> 0.
    MESSAGE |The browser could not be opened. Start abapGit2UI5 at { gv_url }| TYPE 'I'.
  ENDIF.
