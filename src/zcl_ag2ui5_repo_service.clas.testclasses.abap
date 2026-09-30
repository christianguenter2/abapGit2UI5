CLASS ltcl_pull_internals DEFINITION DEFERRED.
CLASS zcl_ag2ui5_repo_service DEFINITION LOCAL FRIENDS ltcl_pull_internals.

"! A repository whose import fails half-way, the way an activation error does
CLASS ltd_failing_repo DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo PARTIALLY IMPLEMENTED.
ENDCLASS.


CLASS ltd_failing_repo IMPLEMENTATION.
  METHOD zif_abapgit_repo~create_new_log.
    ri_log = NEW zcl_abapgit_log( iv_title ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~deserialize.
    ii_log->add_info( `Object ZCL_TEST imported` ).
    zcx_abapgit_exception=>raise( `Activation cancelled. Check the log and inactive objects.` ).
  ENDMETHOD.
ENDCLASS.


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
    METHODS data_loss_keeps_text FOR TESTING.
    METHODS object_blocks_once FOR TESTING.

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

  METHOD data_loss_keeps_text.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    INSERT overwrite_line( iv_action = zif_abapgit_objects=>c_deserialize_action-data_loss
                           iv_text   = `Field LENGTH shortened` ) INTO TABLE ls_checks-data_loss.

    DATA(ls_result) = zcl_ag2ui5_repo_service=>classify( ls_checks ).

    assert_blocked( ls_result ).
    cl_abap_unit_assert=>assert_equals(
      act = ls_result-blocking[ 1 ]-reason
      exp = `Field LENGTH shortened` ).
  ENDMETHOD.

  METHOD object_blocks_once.
    " a table that is deleted AND holds data comes in overwrite and in delete_tabl_with_data
    DATA(ls_checks) = one_change( iv_action = zif_abapgit_objects=>c_deserialize_action-delete
                                  iv_text   = `Delete local object` ).
    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-delete ) INTO TABLE ls_checks-delete_tabl_with_data.

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


CLASS ltcl_format_timestamp DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS minutes_in_given_zone FOR TESTING.
    METHODS initial_is_empty FOR TESTING.

ENDCLASS.


CLASS ltcl_format_timestamp IMPLEMENTATION.

  METHOD minutes_in_given_zone.
    DATA lv_timestamp TYPE timestampl VALUE '20260916063133.1049280'.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>format_timestamp( iv_timestamp = lv_timestamp
                                                       iv_timezone  = 'UTC' )
      exp = `2026-09-16 06:31` ).
  ENDMETHOD.

  METHOD initial_is_empty.
    DATA lv_timestamp TYPE timestampl.

    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>format_timestamp( lv_timestamp ) ).
  ENDMETHOD.

ENDCLASS.



CLASS ltcl_pull_internals DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS deserialize_error_keeps_log FOR TESTING RAISING cx_static_check.
    METHODS guard_refuses_abap2ui5 FOR TESTING RAISING cx_static_check.
    METHODS guard_refuses_super_package FOR TESTING RAISING cx_static_check.
    METHODS guard_allows_other_package FOR TESTING RAISING cx_static_check.
    METHODS empty_key_raises FOR TESTING RAISING cx_static_check.

    METHODS package_of_z2ui5
      RETURNING
        VALUE(rv_package) TYPE devclass.

ENDCLASS.


CLASS ltcl_pull_internals IMPLEMENTATION.

  METHOD deserialize_error_keeps_log.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    DATA(ls_result) = NEW zcl_ag2ui5_repo_service( )->deserialize_logged( ii_repo   = NEW ltd_failing_repo( )
                                                                          is_checks = ls_checks ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-failed ).
    " the messages written before the error survive, and the error is one of them
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_result-messages )
      exp = 2 ).
    cl_abap_unit_assert=>assert_char_cp(
      act = ls_result-messages[ 2 ]-text
      exp = `Activation cancelled*` ).
  ENDMETHOD.

  METHOD package_of_z2ui5.
    SELECT SINGLE devclass FROM tadir
      WHERE pgmid = 'R3TR' AND object = 'INTF' AND obj_name = 'Z2UI5_IF_APP'
      INTO @rv_package.
    IF sy-subrc <> 0.
      cl_abap_unit_assert=>skip( `abap2UI5 is not installed` ).
    ENDIF.
  ENDMETHOD.

  METHOD guard_refuses_abap2ui5.
    TRY.
        NEW zcl_ag2ui5_repo_service( )->assert_pull_allowed( package_of_z2ui5( ) ).
        cl_abap_unit_assert=>fail( `The guard let abap2UI5 through` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD guard_refuses_super_package.
    DATA lv_parent TYPE devclass.

    DATA(lv_package) = package_of_z2ui5( ).
    SELECT SINGLE parentcl FROM tdevc WHERE devclass = @lv_package INTO @lv_parent.
    IF sy-subrc <> 0 OR lv_parent IS INITIAL.
      cl_abap_unit_assert=>skip( `abap2UI5 has no super package here` ).
    ENDIF.

    TRY.
        NEW zcl_ag2ui5_repo_service( )->assert_pull_allowed( lv_parent ).
        cl_abap_unit_assert=>fail( `The guard let the abap2UI5 root package through` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD empty_key_raises.
    " the status app started without choosing a repository
    TRY.
        NEW zcl_ag2ui5_repo_service( )->zif_ag2ui5_repo_service~get_status( `` ).
        cl_abap_unit_assert=>fail( `No exception for an empty key` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD guard_allows_other_package.
    " not $TMP: local packages without a super package hang below it, so a
    " repository on $TMP would contain abap2UI5 as well
    NEW zcl_ag2ui5_repo_service( )->assert_pull_allowed( '$AG2UI5_NO_SUCH' ).
  ENDMETHOD.

ENDCLASS.
