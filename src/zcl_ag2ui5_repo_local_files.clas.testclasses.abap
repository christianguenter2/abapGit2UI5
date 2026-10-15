CLASS ltd_checksums DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo_checksums PARTIALLY IMPLEMENTED.
ENDCLASS.
CLASS ltd_checksums IMPLEMENTATION.
  METHOD zif_abapgit_repo_checksums~get_checksums_per_file.
    CLEAR rt_checksums.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_repo DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo PARTIALLY IMPLEMENTED.
    METHODS constructor.
    DATA mt_files TYPE zif_abapgit_definitions=>ty_files_item_tt.
ENDCLASS.
CLASS ltd_repo IMPLEMENTATION.
  METHOD constructor.
    zif_abapgit_repo~ms_data-local_settings-labels = `backend`.
  ENDMETHOD.
  METHOD zif_abapgit_repo~get_key.
    rv_key = `000000000042`.
  ENDMETHOD.
  METHOD zif_abapgit_repo~get_package.
    rv_package = '$AG2UI5_TEST'.
  ENDMETHOD.
  METHOD zif_abapgit_repo~get_files_local.
    rt_files = mt_files.
  ENDMETHOD.
  METHOD zif_abapgit_repo~get_files_remote.
    CLEAR rt_files.
  ENDMETHOD.
  METHOD zif_abapgit_repo~get_dot_abapgit.
    ro_dot_abapgit = zcl_abapgit_dot_abapgit=>build_default( ).
  ENDMETHOD.
  METHOD zif_abapgit_repo~find_remote_dot_abapgit.
    ro_dot = zcl_abapgit_dot_abapgit=>build_default( ).
  ENDMETHOD.
  METHOD zif_abapgit_repo~checksums.
    ri_checksums = NEW ltd_checksums( ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_local_files DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS local_files_are_stored FOR TESTING RAISING zcx_abapgit_exception.
    METHODS other_calls_delegate FOR TESTING.
    METHODS ms_data_is_copied FOR TESTING.
    METHODS calculate_matches_repository FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.
CLASS ltcl_local_files IMPLEMENTATION.
  METHOD local_files_are_stored.
    DATA(lt_files) = VALUE zif_abapgit_definitions=>ty_files_item_tt(
      ( file-path = `/src/` file-filename = `a.abap` ) ).
    DATA(lo_original) = NEW ltd_repo( ).
    lo_original->mt_files = VALUE #( ( file-path = `/` file-filename = `other.abap` ) ).
    DATA(li_repo) = CAST zif_abapgit_repo( NEW zcl_ag2ui5_repo_local_files( ii_repo = lo_original it_files = lt_files ) ).
    cl_abap_unit_assert=>assert_equals( act = li_repo->get_files_local( ) exp = lt_files ).
    DATA(lt_actual) = li_repo->get_files_local( ).
    cl_abap_unit_assert=>assert_false( xsdbool( lt_actual = lo_original->mt_files ) ).
  ENDMETHOD.
  METHOD other_calls_delegate.
    DATA(li_repo) = CAST zif_abapgit_repo( NEW zcl_ag2ui5_repo_local_files( ii_repo = NEW ltd_repo( ) it_files = VALUE #( ) ) ).
    cl_abap_unit_assert=>assert_equals( act = li_repo->get_key( ) exp = `000000000042` ).
    cl_abap_unit_assert=>assert_equals( act = li_repo->get_package( ) exp = '$AG2UI5_TEST' ).
  ENDMETHOD.
  METHOD ms_data_is_copied.
    DATA(lo_original) = NEW ltd_repo( ).
    DATA(li_repo) = CAST zif_abapgit_repo( NEW zcl_ag2ui5_repo_local_files( ii_repo = lo_original it_files = VALUE #( ) ) ).
    cl_abap_unit_assert=>assert_equals( act = li_repo->ms_data exp = lo_original->zif_abapgit_repo~ms_data ).
  ENDMETHOD.
  METHOD calculate_matches_repository.
    DATA(lo_original) = NEW ltd_repo( ).
    lo_original->mt_files = VALUE #(
      ( item-obj_type = 'CLAS' item-obj_name = 'ZCL_FIXTURE'
        file-path = `/src/` file-filename = `zcl_fixture.clas.abap`
        file-data = '010203' file-sha1 = '1111111111111111111111111111111111111111' ) ).
    DATA(lt_expected) = zcl_abapgit_repo_status=>calculate( lo_original ).
    DATA(li_repo) = CAST zif_abapgit_repo( NEW zcl_ag2ui5_repo_local_files(
      ii_repo = lo_original it_files = lo_original->mt_files ) ).
    CLEAR lo_original->mt_files.
    DATA(lt_actual) = zcl_abapgit_repo_status=>calculate( li_repo ).
    cl_abap_unit_assert=>assert_not_initial( lt_expected ).
    cl_abap_unit_assert=>assert_equals( act = lt_actual exp = lt_expected ).
  ENDMETHOD.
ENDCLASS.
