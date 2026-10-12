CLASS ltcl_start_url DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS repository_list FOR TESTING.
    METHODS trailing_slash FOR TESTING.
ENDCLASS.


CLASS ltcl_start_url IMPLEMENTATION.

  METHOD repository_list.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_http=>start_url( iv_location = `https://host.example:50001` iv_client = '001' iv_language = 'E' )
      exp = `https://host.example:50001/sap/bc/zabapgit2ui5?sap-client=001&sap-language=EN&app_start=zcl_ag2ui5_app_repos` ).
  ENDMETHOD.

  METHOD trailing_slash.
    " a location ending in a slash must not give a double slash
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_http=>start_url( iv_location = `https://host.example/` iv_client = '100' iv_language = 'D' )
      exp = `https://host.example/sap/bc/zabapgit2ui5?sap-client=100&sap-language=DE&app_start=zcl_ag2ui5_app_repos` ).
  ENDMETHOD.

ENDCLASS.
