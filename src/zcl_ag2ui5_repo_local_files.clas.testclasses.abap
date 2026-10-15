CLASS ltd_repo DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo PARTIALLY IMPLEMENTED.
ENDCLASS.


CLASS ltd_repo IMPLEMENTATION.
  METHOD zif_abapgit_repo~get_key.
    rv_key = `000000000042`.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_local_files DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS local_files_are_stored FOR TESTING RAISING zcx_abapgit_exception.
    METHODS other_calls_delegate FOR TESTING.
ENDCLASS.


CLASS ltcl_local_files IMPLEMENTATION.

  METHOD local_files_are_stored.
    DATA(lt_files) = VALUE zif_abapgit_definitions=>ty_files_item_tt(
      ( file-path = `/src/` file-filename = `a.abap` ) ).
    DATA(li_repo) = CAST zif_abapgit_repo( NEW zcl_ag2ui5_repo_local_files( ii_repo  = NEW ltd_repo( )
                                                                           it_files = lt_files ) ).
    cl_abap_unit_assert=>assert_equals( act = li_repo->get_files_local( ) exp = lt_files ).
  ENDMETHOD.

  METHOD other_calls_delegate.
    DATA(li_repo) = CAST zif_abapgit_repo( NEW zcl_ag2ui5_repo_local_files( ii_repo  = NEW ltd_repo( )
                                                                           it_files = VALUE #( ) ) ).
    cl_abap_unit_assert=>assert_equals( act = li_repo->get_key( ) exp = `000000000042` ).
  ENDMETHOD.

ENDCLASS.
