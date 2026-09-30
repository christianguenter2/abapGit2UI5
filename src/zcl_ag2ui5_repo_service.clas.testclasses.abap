CLASS ltcl_classify DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS c_obj_name TYPE tadir-obj_name VALUE 'ZCL_TEST'.

    METHODS nothing_to_pull FOR TESTING.
    METHODS files_only_is_ready FOR TESTING.
    METHODS add_update_applied FOR TESTING.
    METHODS overwrite_blocks FOR TESTING.
    METHODS delete_blocks FOR TESTING.
    METHODS delete_add_blocks FOR TESTING.
    METHODS packmove_blocks FOR TESTING.
    METHODS no_support_is_info FOR TESTING.
    METHODS empty_text_fallback FOR TESTING.
    METHODS data_loss_blocks FOR TESTING.
    METHODS delete_tabl_blocks FOR TESTING.
    METHODS warning_package_blocks FOR TESTING.
    METHODS requirements_block FOR TESTING.
    METHODS dependencies_block FOR TESTING.
    METHODS transport_blocks FOR TESTING.
    METHODS customizing_blocks FOR TESTING.

    "! Checks with one changed object
    METHODS one_change
      IMPORTING
        iv_action        TYPE i
        iv_text          TYPE string DEFAULT `Some text`
      RETURNING
        VALUE(rs_checks) TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    METHODS overwrite_line
      IMPORTING
        iv_action      TYPE i
        iv_text        TYPE string DEFAULT `Some text`
      RETURNING
        VALUE(rs_line) TYPE zif_abapgit_definitions=>ty_overwrite.

    METHODS assert_blocked
      IMPORTING
        is_result TYPE zif_ag2ui5_repo_service=>ty_classification.

ENDCLASS.


CLASS ltcl_classify IMPLEMENTATION.

  METHOD overwrite_line.
    rs_line-obj_type = 'CLAS'.
    rs_line-obj_name = c_obj_name.
    rs_line-devclass = '$TEST'.
    rs_line-action   = iv_action.
    rs_line-text     = iv_text.
  ENDMETHOD.

  METHOD one_change.
    INSERT overwrite_line( iv_action = iv_action iv_text = iv_text ) INTO TABLE rs_checks-overwrite.
  ENDMETHOD.

  METHOD assert_blocked.
    cl_abap_unit_assert=>assert_equals(
      act = is_result-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-blocked ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( is_result-blocking )
      exp = 1 ).
  ENDMETHOD.

  METHOD nothing_to_pull.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>classify( ls_checks )-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-nothing ).
  ENDMETHOD.

  METHOD files_only_is_ready.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.
    DATA ls_file TYPE zif_abapgit_git_definitions=>ty_file.

    ls_file-path     = '/src/'.
    ls_file-filename = 'zcl_test.clas.abap'.
    INSERT ls_file INTO TABLE ls_checks-overwrite_files.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>classify( ls_checks )-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
  ENDMETHOD.

  METHOD add_update_applied.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.
    DATA ls_line TYPE zif_abapgit_definitions=>ty_overwrite.

    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-add ) INTO TABLE ls_checks-overwrite.
    ls_line = overwrite_line( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_line-obj_name = 'ZCL_TEST_2'.
    INSERT ls_line INTO TABLE ls_checks-overwrite.

    DATA(ls_result) = zcl_ag2ui5_repo_service=>classify( ls_checks ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
    LOOP AT ls_result-checks-overwrite INTO ls_line.
      cl_abap_unit_assert=>assert_equals(
        act = ls_line-decision
        exp = zif_abapgit_definitions=>c_yes ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_result-checks-overwrite )
      exp = 2 ).
  ENDMETHOD.

  METHOD overwrite_blocks.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>classify(
      one_change( iv_action = zif_abapgit_objects=>c_deserialize_action-overwrite
                  iv_text   = `Overwrite local object` ) ).

    assert_blocked( ls_result ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-blocking[ 1 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_item( obj_type = `CLAS`
                                                    obj_name = `ZCL_TEST`
                                                    reason   = `Overwrite local object` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-checks-overwrite[ 1 ]-decision
      exp = zif_abapgit_definitions=>c_no ).
  ENDMETHOD.

  METHOD delete_blocks.
    assert_blocked( zcl_ag2ui5_repo_service=>classify(
      one_change( zif_abapgit_objects=>c_deserialize_action-delete ) ) ).
  ENDMETHOD.

  METHOD delete_add_blocks.
    assert_blocked( zcl_ag2ui5_repo_service=>classify(
      one_change( zif_abapgit_objects=>c_deserialize_action-delete_add ) ) ).
  ENDMETHOD.

  METHOD packmove_blocks.
    assert_blocked( zcl_ag2ui5_repo_service=>classify(
      one_change( zif_abapgit_objects=>c_deserialize_action-packmove ) ) ).
  ENDMETHOD.

  METHOD no_support_is_info.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>classify(
      one_change( zif_abapgit_objects=>c_deserialize_action-no_support ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_result-info )
      exp = 1 ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-checks-overwrite[ 1 ]-decision
      exp = zif_abapgit_definitions=>c_no ).
  ENDMETHOD.

  METHOD empty_text_fallback.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>classify(
      one_change( iv_action = zif_abapgit_objects=>c_deserialize_action-overwrite
                  iv_text   = `` ) ).

    assert_blocked( ls_result ).
    cl_abap_unit_assert=>assert_not_initial( ls_result-blocking[ 1 ]-reason ).
  ENDMETHOD.

  METHOD data_loss_blocks.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-data_loss ) INTO TABLE ls_checks-data_loss.

    assert_blocked( zcl_ag2ui5_repo_service=>classify( ls_checks ) ).
  ENDMETHOD.

  METHOD delete_tabl_blocks.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-delete ) INTO TABLE ls_checks-delete_tabl_with_data.

    assert_blocked( zcl_ag2ui5_repo_service=>classify( ls_checks ) ).
  ENDMETHOD.

  METHOD warning_package_blocks.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-update ) INTO TABLE ls_checks-warning_package.

    assert_blocked( zcl_ag2ui5_repo_service=>classify( ls_checks ) ).
  ENDMETHOD.

  METHOD requirements_block.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-requirements-met = zif_abapgit_definitions=>c_no.

    assert_blocked( zcl_ag2ui5_repo_service=>classify( ls_checks ) ).
  ENDMETHOD.

  METHOD dependencies_block.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-dependencies-met = zif_abapgit_definitions=>c_no.

    assert_blocked( zcl_ag2ui5_repo_service=>classify( ls_checks ) ).
  ENDMETHOD.

  METHOD transport_blocks.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-transport-required = abap_true.

    assert_blocked( zcl_ag2ui5_repo_service=>classify( ls_checks ) ).
  ENDMETHOD.

  METHOD customizing_blocks.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-customizing-required = abap_true.

    assert_blocked( zcl_ag2ui5_repo_service=>classify( ls_checks ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_filter_status DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS keeps_differences_and_inactive FOR TESTING.

ENDCLASS.


CLASS ltcl_filter_status IMPLEMENTATION.

  METHOD keeps_differences_and_inactive.
    DATA lt_results TYPE zif_abapgit_definitions=>ty_results_tt.
    DATA ls_result LIKE LINE OF lt_results.

    ls_result-obj_type = 'CLAS'.
    ls_result-obj_name = 'ZCL_SAME'.
    ls_result-match    = abap_true.
    INSERT ls_result INTO TABLE lt_results.

    ls_result-obj_name = 'ZCL_INACTIVE'.
    ls_result-inactive = abap_true.
    INSERT ls_result INTO TABLE lt_results.

    CLEAR ls_result.
    ls_result-obj_type = 'CLAS'.
    ls_result-obj_name = 'ZCL_CHANGED'.
    ls_result-lstate   = 'M'.
    INSERT ls_result INTO TABLE lt_results.

    DATA(lt_rows) = zcl_ag2ui5_repo_service=>filter_status( lt_results ).

    cl_abap_unit_assert=>assert_equals(
      act = lines( lt_rows )
      exp = 2 ).
    cl_abap_unit_assert=>assert_table_contains(
      line  = VALUE zif_ag2ui5_repo_service=>ty_status_row( obj_type = `CLAS` obj_name = `ZCL_INACTIVE` inactive = abap_true )
      table = lt_rows ).
    cl_abap_unit_assert=>assert_table_contains(
      line  = VALUE zif_ag2ui5_repo_service=>ty_status_row( obj_type = `CLAS` obj_name = `ZCL_CHANGED` lstate = `M` )
      table = lt_rows ).
  ENDMETHOD.

ENDCLASS.
