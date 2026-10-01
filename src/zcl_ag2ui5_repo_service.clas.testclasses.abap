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


CLASS ltcl_preview DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS nothing_to_pull FOR TESTING.
    METHODS files_only_is_ready FOR TESTING.
    METHODS import_preselected FOR TESTING.
    METHODS overwrite_not_selected FOR TESTING.
    METHODS delete_not_selected FOR TESTING.
    METHODS delete_add_is_delete FOR TESTING.
    METHODS packmove_is_package FOR TESTING.
    METHODS warning_package_is_package FOR TESTING.
    METHODS data_loss_wins FOR TESTING.
    METHODS delete_tabl_is_data_loss FOR TESTING.
    METHODS no_support_not_selectable FOR TESTING.
    METHODS empty_text_fallback FOR TESTING.
    METHODS namespace_first FOR TESTING.
    METHODS requirements_need_ack FOR TESTING.
    METHODS dependencies_need_ack FOR TESTING.
    METHODS transport_blocks FOR TESTING.
    METHODS customizing_blocks FOR TESTING.
    METHODS package_note_kept FOR TESTING.
    METHODS transport_preset_passed FOR TESTING.
    METHODS transport_without_type_blocks FOR TESTING.

    METHODS overwrite_line
      IMPORTING
        iv_action      TYPE i
        iv_obj_type    TYPE tadir-object DEFAULT 'CLAS'
        iv_obj_name    TYPE tadir-obj_name DEFAULT 'ZCL_TEST'
        iv_text        TYPE string DEFAULT `Some text`
      RETURNING
        VALUE(rs_line) TYPE zif_abapgit_definitions=>ty_overwrite.

    METHODS one_change
      IMPORTING
        iv_action        TYPE i
        iv_text          TYPE string DEFAULT `Some text`
      RETURNING
        VALUE(rs_checks) TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    "! The only item of a preview, after asserting there is exactly one
    METHODS single_item
      IMPORTING
        is_preview     TYPE zif_ag2ui5_repo_service=>ty_preview
      RETURNING
        VALUE(rs_item) TYPE zif_ag2ui5_repo_service=>ty_decision_item.

ENDCLASS.


CLASS ltcl_preview IMPLEMENTATION.

  METHOD overwrite_line.
    rs_line-obj_type = iv_obj_type.
    rs_line-obj_name = iv_obj_name.
    rs_line-devclass = '$TEST'.
    rs_line-action   = iv_action.
    rs_line-text     = iv_text.
  ENDMETHOD.

  METHOD one_change.
    INSERT overwrite_line( iv_action = iv_action iv_text = iv_text ) INTO TABLE rs_checks-overwrite.
  ENDMETHOD.

  METHOD single_item.
    cl_abap_unit_assert=>assert_equals(
      act = lines( is_preview-items )
      exp = 1 ).
    rs_item = is_preview-items[ 1 ].
  ENDMETHOD.

  METHOD nothing_to_pull.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>preview( ls_checks )-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-nothing ).
  ENDMETHOD.

  METHOD files_only_is_ready.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.
    DATA ls_file TYPE zif_abapgit_git_definitions=>ty_file.

    ls_file-path     = '/src/'.
    ls_file-filename = 'zcl_test.clas.abap'.
    INSERT ls_file INTO TABLE ls_checks-overwrite_files.

    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>preview( ls_checks )-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
  ENDMETHOD.

  METHOD import_preselected.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-add ) INTO TABLE ls_checks-overwrite.
    INSERT overwrite_line( iv_action   = zif_abapgit_objects=>c_deserialize_action-update
                           iv_obj_name = 'ZCL_TEST_2' ) INTO TABLE ls_checks-overwrite.

    DATA(ls_preview) = zcl_ag2ui5_repo_service=>preview( ls_checks ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_preview-outcome
      exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( ls_preview-items )
      exp = 2 ).
    LOOP AT ls_preview-items INTO DATA(ls_item).
      cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                          exp = zif_ag2ui5_repo_service=>c_group-import ).
      cl_abap_unit_assert=>assert_true( ls_item-selected ).
      cl_abap_unit_assert=>assert_true( ls_item-selectable ).
    ENDLOOP.
  ENDMETHOD.

  METHOD overwrite_not_selected.
    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview(
      one_change( iv_action = zif_abapgit_objects=>c_deserialize_action-overwrite
                  iv_text   = `Overwrite local object` ) ) ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_item
      exp = VALUE zif_ag2ui5_repo_service=>ty_decision_item( obj_type   = `CLAS`
                                                             obj_name   = `ZCL_TEST`
                                                             group      = zif_ag2ui5_repo_service=>c_group-overwrite
                                                             reason     = `Overwrite local object`
                                                             selected   = abap_false
                                                             selectable = abap_true ) ).
  ENDMETHOD.

  METHOD delete_not_selected.
    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview(
      one_change( zif_abapgit_objects=>c_deserialize_action-delete ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-delete ).
    cl_abap_unit_assert=>assert_false( ls_item-selected ).
  ENDMETHOD.

  METHOD delete_add_is_delete.
    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview(
      one_change( zif_abapgit_objects=>c_deserialize_action-delete_add ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-delete ).
  ENDMETHOD.

  METHOD packmove_is_package.
    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview(
      one_change( zif_abapgit_objects=>c_deserialize_action-packmove ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-package ).
    cl_abap_unit_assert=>assert_false( ls_item-selected ).
  ENDMETHOD.

  METHOD warning_package_is_package.
    " the object is an update, but it sits in a package outside the repository
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-update ) INTO TABLE ls_checks-warning_package.

    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview( ls_checks ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-package ).
    cl_abap_unit_assert=>assert_false( ls_item-selected ).
  ENDMETHOD.

  METHOD data_loss_wins.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    INSERT overwrite_line( iv_action = zif_abapgit_objects=>c_deserialize_action-data_loss
                           iv_text   = `Field LENGTH shortened` ) INTO TABLE ls_checks-data_loss.

    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview( ls_checks ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-data_loss ).
    cl_abap_unit_assert=>assert_equals( act = ls_item-reason
                                        exp = `Field LENGTH shortened` ).
    cl_abap_unit_assert=>assert_false( ls_item-selected ).
  ENDMETHOD.

  METHOD delete_tabl_is_data_loss.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-delete ).
    INSERT overwrite_line( zif_abapgit_objects=>c_deserialize_action-delete ) INTO TABLE ls_checks-delete_tabl_with_data.

    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview( ls_checks ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-data_loss ).
  ENDMETHOD.

  METHOD no_support_not_selectable.
    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview(
      one_change( zif_abapgit_objects=>c_deserialize_action-no_support ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-skipped ).
    cl_abap_unit_assert=>assert_false( ls_item-selectable ).
    cl_abap_unit_assert=>assert_false( ls_item-selected ).
  ENDMETHOD.

  METHOD empty_text_fallback.
    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview(
      one_change( iv_action = zif_abapgit_objects=>c_deserialize_action-overwrite
                  iv_text   = `` ) ) ).

    cl_abap_unit_assert=>assert_not_initial( ls_item-reason ).
  ENDMETHOD.

  METHOD namespace_first.
    DATA ls_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    INSERT overwrite_line( iv_action   = zif_abapgit_objects=>c_deserialize_action-add
                           iv_obj_type = 'NSPC'
                           iv_obj_name = '/TEST/' ) INTO TABLE ls_checks-overwrite.
    INSERT overwrite_line( iv_action   = zif_abapgit_objects=>c_deserialize_action-add
                           iv_obj_name = '/TEST/CL_A' ) INTO TABLE ls_checks-overwrite.

    DATA(ls_preview) = zcl_ag2ui5_repo_service=>preview( ls_checks ).

    cl_abap_unit_assert=>assert_true( ls_preview-items[ obj_type = `NSPC` ]-selected ).
    cl_abap_unit_assert=>assert_false( ls_preview-items[ obj_name = `/TEST/CL_A` ]-selected ).
  ENDMETHOD.

  METHOD requirements_need_ack.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-requirements-met = zif_abapgit_definitions=>c_no.

    DATA(ls_preview) = zcl_ag2ui5_repo_service=>preview( ls_checks ).

    cl_abap_unit_assert=>assert_equals( act = ls_preview-outcome
                                        exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
    cl_abap_unit_assert=>assert_not_initial( ls_preview-ack_text ).
  ENDMETHOD.

  METHOD dependencies_need_ack.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-dependencies-met = zif_abapgit_definitions=>c_no.

    cl_abap_unit_assert=>assert_not_initial( zcl_ag2ui5_repo_service=>preview( ls_checks )-ack_text ).
  ENDMETHOD.

  METHOD transport_blocks.
    " no longer a block: the dialog asks for a request of that type
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-transport-required     = abap_true.
    ls_checks-transport-type-request = 'K'.

    DATA(ls_preview) = zcl_ag2ui5_repo_service=>preview( ls_checks ).

    cl_abap_unit_assert=>assert_equals( act = ls_preview-outcome
                                        exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
    cl_abap_unit_assert=>assert_equals( act = ls_preview-transport_type
                                        exp = `K` ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_preview-items )
                                        exp = 1 ).
  ENDMETHOD.

  METHOD customizing_blocks.
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-customizing-required     = abap_true.
    ls_checks-customizing-type-request = 'W'.

    DATA(ls_preview) = zcl_ag2ui5_repo_service=>preview( ls_checks ).

    cl_abap_unit_assert=>assert_equals( act = ls_preview-outcome
                                        exp = zif_ag2ui5_repo_service=>c_outcome-ready ).
    cl_abap_unit_assert=>assert_equals( act = ls_preview-customizing_type
                                        exp = `W` ).
    cl_abap_unit_assert=>assert_initial( ls_preview-transport_type ).
  ENDMETHOD.

  METHOD transport_preset_passed.
    " abapGit fills the request from the repository setting or the user exit
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-transport-required     = abap_true.
    ls_checks-transport-type-request = 'K'.
    ls_checks-transport-transport    = 'A4HK900001'.

    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>preview( ls_checks )-transport_preset
                                        exp = `A4HK900001` ).
  ENDMETHOD.

  METHOD transport_without_type_blocks.
    " without a type there is nothing to offer, and deserialize would fail late
    DATA(ls_checks) = one_change( zif_abapgit_objects=>c_deserialize_action-update ).
    ls_checks-transport-required = abap_true.

    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>preview( ls_checks )-outcome
                                        exp = zif_ag2ui5_repo_service=>c_outcome-blocked ).
  ENDMETHOD.

  METHOD package_note_kept.
    " overwriting an object that lives in another package: both facts matter
    DATA(ls_checks) = one_change( iv_action = zif_abapgit_objects=>c_deserialize_action-overwrite
                                  iv_text   = `Overwrite local object` ).
    DATA(ls_line) = overwrite_line( zif_abapgit_objects=>c_deserialize_action-overwrite ).
    ls_line-devclass = '$OTHER'.
    INSERT ls_line INTO TABLE ls_checks-warning_package.

    DATA(ls_item) = single_item( zcl_ag2ui5_repo_service=>preview( ls_checks ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_item-group
                                        exp = zif_ag2ui5_repo_service=>c_group-overwrite ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_item-reason
                                         exp = `Overwrite local object*$OTHER*` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_merge DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS selection_carried_over FOR TESTING RAISING cx_static_check.
    METHODS import_turned_delete FOR TESTING.
    METHODS new_object FOR TESTING.
    METHODS selected_object_gone FOR TESTING.
    METHODS unselected_object_gone FOR TESTING RAISING cx_static_check.
    METHODS skipped_stays_unselected FOR TESTING RAISING cx_static_check.

    METHODS item
      IMPORTING
        iv_obj_name    TYPE string
        iv_group       TYPE zif_ag2ui5_repo_service=>ty_group
        iv_selected    TYPE abap_bool
        iv_selectable  TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_item) TYPE zif_ag2ui5_repo_service=>ty_decision_item.

    METHODS assert_changed
      IMPORTING
        it_fresh  TYPE zif_ag2ui5_repo_service=>ty_decision_items
        it_posted TYPE zif_ag2ui5_repo_service=>ty_decision_items.

ENDCLASS.


CLASS ltcl_merge IMPLEMENTATION.

  METHOD item.
    rs_item = VALUE #( obj_type   = `CLAS`
                       obj_name   = iv_obj_name
                       group      = iv_group
                       selected   = iv_selected
                       selectable = iv_selectable ).
  ENDMETHOD.

  METHOD assert_changed.
    TRY.
        zcl_ag2ui5_repo_service=>merge_decisions( it_fresh = it_fresh it_posted = it_posted ).
        cl_abap_unit_assert=>fail( `A change since the preview was not detected` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD selection_carried_over.
    DATA(lt_items) = zcl_ag2ui5_repo_service=>merge_decisions(
      it_fresh  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT`    iv_selected = abap_true ) )
                           ( item( iv_obj_name = `ZCL_B` iv_group = `OVERWRITE` iv_selected = abap_false ) ) )
      it_posted = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT`    iv_selected = abap_false ) )
                           ( item( iv_obj_name = `ZCL_B` iv_group = `OVERWRITE` iv_selected = abap_true ) ) ) ).

    cl_abap_unit_assert=>assert_false( lt_items[ obj_name = `ZCL_A` ]-selected ).
    cl_abap_unit_assert=>assert_true( lt_items[ obj_name = `ZCL_B` ]-selected ).
  ENDMETHOD.

  METHOD import_turned_delete.
    " the user ticked an import; meanwhile the remote dropped the object
    assert_changed(
      it_fresh  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `DELETE` iv_selected = abap_false ) ) )
      it_posted = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT` iv_selected = abap_true ) ) ) ).
  ENDMETHOD.

  METHOD new_object.
    assert_changed(
      it_fresh  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT` iv_selected = abap_true ) )
                           ( item( iv_obj_name = `ZCL_B` iv_group = `IMPORT` iv_selected = abap_true ) ) )
      it_posted = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT` iv_selected = abap_true ) ) ) ).
  ENDMETHOD.

  METHOD selected_object_gone.
    assert_changed(
      it_fresh  = VALUE #( )
      it_posted = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT` iv_selected = abap_true ) ) ) ).
  ENDMETHOD.

  METHOD unselected_object_gone.
    " nothing was going to happen to it, so its disappearance changes nothing
    DATA(lt_items) = zcl_ag2ui5_repo_service=>merge_decisions(
      it_fresh  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT` iv_selected = abap_true ) ) )
      it_posted = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `IMPORT`    iv_selected = abap_true ) )
                           ( item( iv_obj_name = `ZCL_B` iv_group = `OVERWRITE` iv_selected = abap_false ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_items )
                                        exp = 1 ).
  ENDMETHOD.

  METHOD skipped_stays_unselected.
    " the client cannot tick what the server made unselectable
    DATA(lt_items) = zcl_ag2ui5_repo_service=>merge_decisions(
      it_fresh  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `SKIPPED` iv_selected = abap_false iv_selectable = abap_false ) ) )
      it_posted = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_group = `SKIPPED` iv_selected = abap_true ) ) ) ).

    cl_abap_unit_assert=>assert_false( lt_items[ 1 ]-selected ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_transport DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mt_transports TYPE zif_ag2ui5_repo_service=>ty_transports.

    METHODS setup.
    METHODS own_request_accepted FOR TESTING RAISING cx_static_check.
    METHODS other_request_refused FOR TESTING.
    METHODS missing_request_refused FOR TESTING.
    METHODS preset_wins FOR TESTING RAISING cx_static_check.
    METHODS chosen_used_without_preset FOR TESTING RAISING cx_static_check.

ENDCLASS.


CLASS ltcl_transport IMPLEMENTATION.

  METHOD setup.
    mt_transports = VALUE #( ( trkorr = `A4HK900148` text = `Test` ) ).
  ENDMETHOD.

  METHOD own_request_accepted.
    zcl_ag2ui5_repo_service=>assert_transport( iv_transport  = `A4HK900148`
                                               it_transports = mt_transports ).
  ENDMETHOD.

  METHOD other_request_refused.
    " the client may send any number - only the user's modifiable ones count
    TRY.
        zcl_ag2ui5_repo_service=>assert_transport( iv_transport  = `A4HK999999`
                                                   it_transports = mt_transports ).
        cl_abap_unit_assert=>fail( `A request outside the list was accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD preset_wins.
    " a request abapGit determined comes from system configuration, not from
    " the client, and need not be one of the user's own
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>effective_transport( iv_preset     = `A4HK900001`
                                                          iv_chosen     = `A4HK900148`
                                                          it_transports = mt_transports )
      exp = `A4HK900001` ).
  ENDMETHOD.

  METHOD chosen_used_without_preset.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>effective_transport( iv_preset     = ``
                                                          iv_chosen     = `A4HK900148`
                                                          it_transports = mt_transports )
      exp = `A4HK900148` ).
  ENDMETHOD.

  METHOD missing_request_refused.
    TRY.
        zcl_ag2ui5_repo_service=>assert_transport( iv_transport  = ``
                                                   it_transports = mt_transports ).
        cl_abap_unit_assert=>fail( `A missing request was accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_apply DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA ms_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks.

    METHODS setup.
    METHODS choice_lands_in_every_table FOR TESTING RAISING cx_static_check.
    METHODS every_row_decided FOR TESTING RAISING cx_static_check.
    METHODS unknown_object_raises FOR TESTING.
    METHODS requirements_without_ack FOR TESTING.
    METHODS requirements_with_ack FOR TESTING RAISING cx_static_check.

    METHODS item
      IMPORTING
        iv_obj_name    TYPE string
        iv_selected    TYPE abap_bool
      RETURNING
        VALUE(rs_item) TYPE zif_ag2ui5_repo_service=>ty_decision_item.

ENDCLASS.


CLASS ltcl_apply IMPLEMENTATION.

  METHOD setup.
    DATA ls_line TYPE zif_abapgit_definitions=>ty_overwrite.

    " ZCL_A: an update with data loss; ZCL_B: an overwrite
    ls_line-obj_type = 'CLAS'.
    ls_line-obj_name = 'ZCL_A'.
    ls_line-action   = zif_abapgit_objects=>c_deserialize_action-update.
    INSERT ls_line INTO TABLE ms_checks-overwrite.
    INSERT ls_line INTO TABLE ms_checks-data_loss.

    ls_line-obj_name = 'ZCL_B'.
    ls_line-action   = zif_abapgit_objects=>c_deserialize_action-overwrite.
    INSERT ls_line INTO TABLE ms_checks-overwrite.
  ENDMETHOD.

  METHOD item.
    rs_item-obj_type = `CLAS`.
    rs_item-obj_name = iv_obj_name.
    rs_item-selected = iv_selected.
  ENDMETHOD.

  METHOD choice_lands_in_every_table.
    DATA(ls_checks) = zcl_ag2ui5_repo_service=>apply_decisions(
      is_checks = ms_checks
      it_items  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_selected = abap_true ) )
                           ( item( iv_obj_name = `ZCL_B` iv_selected = abap_false ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = ls_checks-overwrite[ obj_name = 'ZCL_A' ]-decision
                                        exp = zif_abapgit_definitions=>c_yes ).
    cl_abap_unit_assert=>assert_equals( act = ls_checks-data_loss[ obj_name = 'ZCL_A' ]-decision
                                        exp = zif_abapgit_definitions=>c_yes ).
    cl_abap_unit_assert=>assert_equals( act = ls_checks-overwrite[ obj_name = 'ZCL_B' ]-decision
                                        exp = zif_abapgit_definitions=>c_no ).
  ENDMETHOD.

  METHOD every_row_decided.
    DATA(ls_checks) = zcl_ag2ui5_repo_service=>apply_decisions(
      is_checks = ms_checks
      it_items  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_selected = abap_false ) )
                           ( item( iv_obj_name = `ZCL_B` iv_selected = abap_false ) ) ) ).

    LOOP AT ls_checks-overwrite INTO DATA(ls_line).
      cl_abap_unit_assert=>assert_not_initial( ls_line-decision ).
    ENDLOOP.
    LOOP AT ls_checks-data_loss INTO ls_line.
      cl_abap_unit_assert=>assert_not_initial( ls_line-decision ).
    ENDLOOP.
  ENDMETHOD.

  METHOD unknown_object_raises.
    " ZCL_B was not in the preview: the remote changed in between
    TRY.
        zcl_ag2ui5_repo_service=>apply_decisions(
          is_checks = ms_checks
          it_items  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_selected = abap_true ) ) ) ).
        cl_abap_unit_assert=>fail( `No exception for an object the preview did not show` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD requirements_without_ack.
    ms_checks-requirements-met = zif_abapgit_definitions=>c_no.
    TRY.
        zcl_ag2ui5_repo_service=>apply_decisions(
          is_checks = ms_checks
          it_items  = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_selected = abap_true ) )
                               ( item( iv_obj_name = `ZCL_B` iv_selected = abap_false ) ) ) ).
        cl_abap_unit_assert=>fail( `No exception for unmet requirements without acknowledgement` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD requirements_with_ack.
    ms_checks-requirements-met = zif_abapgit_definitions=>c_no.

    DATA(ls_checks) = zcl_ag2ui5_repo_service=>apply_decisions(
      is_checks       = ms_checks
      it_items        = VALUE #( ( item( iv_obj_name = `ZCL_A` iv_selected = abap_true ) )
                                 ( item( iv_obj_name = `ZCL_B` iv_selected = abap_false ) ) )
      iv_acknowledged = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = ls_checks-requirements-decision
                                        exp = zif_abapgit_definitions=>c_yes ).
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


CLASS ltcl_diff DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS compact_no_change FOR TESTING.
    METHODS compact_change_in_middle FOR TESTING.
    METHODS compact_change_at_edges FOR TESTING.
    METHODS compact_context_overlaps FOR TESTING.
    METHODS compact_context_zero FOR TESTING.
    METHODS compact_empty FOR TESTING.
    METHODS map_all_results FOR TESTING.
    METHODS map_changed_block FOR TESTING.
    METHODS map_control_characters FOR TESTING.

    "! n unchanged lines, numbered from iv_from
    METHODS same_lines
      IMPORTING
        iv_count        TYPE i
        iv_from         TYPE i DEFAULT 1
      RETURNING
        VALUE(rt_lines) TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    METHODS kinds
      IMPORTING
        it_lines       TYPE zif_ag2ui5_repo_service=>ty_diff_lines
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS ltcl_diff IMPLEMENTATION.

  METHOD same_lines.
    DO iv_count TIMES.
      DATA(lv_num) = |{ iv_from + sy-index - 1 }|.
      INSERT VALUE #( local_num = lv_num remote_num = lv_num text = |line { lv_num }|
                      kind = zif_ag2ui5_repo_service=>c_line_kind-same ) INTO TABLE rt_lines.
    ENDDO.
  ENDMETHOD.

  METHOD kinds.
    " one letter per line: S same, L local, R remote, G gap
    LOOP AT it_lines INTO DATA(ls_line).
      rv_text = rv_text && ls_line-kind(1).
    ENDLOOP.
  ENDMETHOD.

  METHOD compact_no_change.
    DATA(lt_lines) = zcl_ag2ui5_repo_service=>compact( same_lines( 20 ) ).

    cl_abap_unit_assert=>assert_equals( act = kinds( lt_lines )
                                        exp = `G` ).
  ENDMETHOD.

  METHOD compact_change_in_middle.
    DATA(lt_lines) = same_lines( 10 ).
    INSERT VALUE #( local_num = `11` text = `new` kind = zif_ag2ui5_repo_service=>c_line_kind-local ) INTO TABLE lt_lines.
    INSERT LINES OF same_lines( iv_count = 10 iv_from = 12 ) INTO TABLE lt_lines.

    DATA(lt_compact) = zcl_ag2ui5_repo_service=>compact( lt_lines ).

    " 7 unchanged, 3 context, the change, 3 context, 7 unchanged
    cl_abap_unit_assert=>assert_equals( act = kinds( lt_compact )
                                        exp = `GSSSLSSSG` ).
    cl_abap_unit_assert=>assert_char_cp( act = lt_compact[ 1 ]-text
                                         exp = `*7 unchanged lines*` ).
  ENDMETHOD.

  METHOD compact_change_at_edges.
    DATA lt_lines TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    INSERT VALUE #( remote_num = `1` text = `old` kind = zif_ag2ui5_repo_service=>c_line_kind-remote ) INTO TABLE lt_lines.
    INSERT LINES OF same_lines( 10 ) INTO TABLE lt_lines.
    INSERT VALUE #( local_num = `11` text = `new` kind = zif_ag2ui5_repo_service=>c_line_kind-local ) INTO TABLE lt_lines.

    cl_abap_unit_assert=>assert_equals( act = kinds( zcl_ag2ui5_repo_service=>compact( lt_lines ) )
                                        exp = `RSSSGSSSL` ).
  ENDMETHOD.

  METHOD compact_context_overlaps.
    " two changes 4 lines apart: their contexts touch, so no gap between them
    DATA(lt_lines) = same_lines( 5 ).
    INSERT VALUE #( local_num = `6` text = `a` kind = zif_ag2ui5_repo_service=>c_line_kind-local ) INTO TABLE lt_lines.
    INSERT LINES OF same_lines( iv_count = 4 iv_from = 7 ) INTO TABLE lt_lines.
    INSERT VALUE #( local_num = `11` text = `b` kind = zif_ag2ui5_repo_service=>c_line_kind-local ) INTO TABLE lt_lines.
    INSERT LINES OF same_lines( iv_count = 5 iv_from = 12 ) INTO TABLE lt_lines.

    cl_abap_unit_assert=>assert_equals( act = kinds( zcl_ag2ui5_repo_service=>compact( lt_lines ) )
                                        exp = `GSSSLSSSSLSSSG` ).
  ENDMETHOD.

  METHOD compact_context_zero.
    DATA(lt_lines) = same_lines( 3 ).
    INSERT VALUE #( local_num = `4` text = `new` kind = zif_ag2ui5_repo_service=>c_line_kind-local ) INTO TABLE lt_lines.
    INSERT LINES OF same_lines( iv_count = 3 iv_from = 5 ) INTO TABLE lt_lines.

    cl_abap_unit_assert=>assert_equals( act = kinds( zcl_ag2ui5_repo_service=>compact( it_lines = lt_lines iv_context = 0 ) )
                                        exp = `GLG` ).
  ENDMETHOD.

  METHOD compact_empty.
    DATA lt_lines TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>compact( lt_lines ) ).
  ENDMETHOD.

  METHOD map_changed_block.
    " a run of changed lines reads as a block, as in git and abapGit
    DATA lt_diff TYPE zif_abapgit_definitions=>ty_diffs_tt.

    INSERT VALUE #( new_num = '1' new = `new 1` old_num = '1' old = `old 1`
                    result = zif_abapgit_definitions=>c_diff-update ) INTO TABLE lt_diff.
    INSERT VALUE #( new_num = '2' new = `new 2` old_num = '2' old = `old 2`
                    result = zif_abapgit_definitions=>c_diff-update ) INTO TABLE lt_diff.
    INSERT VALUE #( new_num = '3' new = `same` old_num = '3' old = `same`
                    result = zif_abapgit_definitions=>c_diff-unchanged ) INTO TABLE lt_diff.

    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( lt_diff ).

    cl_abap_unit_assert=>assert_equals( act = kinds( lt_lines )
                                        exp = `RRLLS` ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-text
                                        exp = `old 2` ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 3 ]-text
                                        exp = `new 1` ).
  ENDMETHOD.

  METHOD map_control_characters.
    " abapGit marks a missing final newline with a form feed; raw control
    " characters break the JSON the frontend parses
    DATA lt_diff TYPE zif_abapgit_definitions=>ty_diffs_tt.

    INSERT VALUE #( new_num = '1' new = |last{ cl_abap_char_utilities=>form_feed }|
                    result = zif_abapgit_definitions=>c_diff-insert ) INTO TABLE lt_diff.
    INSERT VALUE #( old_num = '1' old = |crlf{ cl_abap_char_utilities=>cr_lf(1) }|
                    result = zif_abapgit_definitions=>c_diff-delete ) INTO TABLE lt_diff.
    INSERT VALUE #( new_num = '2' new = |a{ cl_abap_char_utilities=>horizontal_tab }b|
                    result = zif_abapgit_definitions=>c_diff-insert ) INTO TABLE lt_diff.

    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( lt_diff ).

    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-text
                                        exp = `last (no newline at end of file)` ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 2 ]-text
                                        exp = `crlf[CR]` ).
    " a tab is legal in JSON and stays
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 3 ]-text
                                        exp = |a{ cl_abap_char_utilities=>horizontal_tab }b| ).
  ENDMETHOD.

  METHOD map_all_results.
    DATA lt_diff TYPE zif_abapgit_definitions=>ty_diffs_tt.

    INSERT VALUE #( new_num = '1' new = `same` old_num = '1' old = `same`
                    result = zif_abapgit_definitions=>c_diff-unchanged ) INTO TABLE lt_diff.
    INSERT VALUE #( new_num = '2' new = `added`
                    result = zif_abapgit_definitions=>c_diff-insert ) INTO TABLE lt_diff.
    INSERT VALUE #( old_num = '2' old = `removed`
                    result = zif_abapgit_definitions=>c_diff-delete ) INTO TABLE lt_diff.
    INSERT VALUE #( new_num = '3' new = `changed new` old_num = '3' old = `changed old`
                    result = zif_abapgit_definitions=>c_diff-update ) INTO TABLE lt_diff.

    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( lt_diff ).

    cl_abap_unit_assert=>assert_equals( act = kinds( lt_lines )
                                        exp = `SLRRL` ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_lines[ 4 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_diff_line( remote_num = `3` text = `changed old`
                                                          kind = zif_ag2ui5_repo_service=>c_line_kind-remote ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_lines[ 5 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_diff_line( local_num = `3` text = `changed new`
                                                          kind = zif_ag2ui5_repo_service=>c_line_kind-local ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-local_num
                                        exp = `1` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_side_by_side DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS direction FOR TESTING.
    METHODS map_swapped FOR TESTING.
    METHODS pairs_changed_block FOR TESTING.
    METHODS pads_uneven_block FOR TESTING.
    METHODS same_and_gap FOR TESTING.
    METHODS swapped_sides FOR TESTING.
    METHODS html_escaped_and_indented FOR TESTING.
    METHODS html_keeps_inner_spaces FOR TESTING.
    METHODS html_expands_tabs FOR TESTING.
    METHODS counts_follow_direction FOR TESTING.

    METHODS line
      IMPORTING
        iv_kind        TYPE zif_ag2ui5_repo_service=>ty_line_kind
        iv_local       TYPE string OPTIONAL
        iv_remote      TYPE string OPTIONAL
        iv_text        TYPE string
      RETURNING
        VALUE(rs_line) TYPE zif_ag2ui5_repo_service=>ty_diff_line.

ENDCLASS.


CLASS ltcl_side_by_side IMPLEMENTATION.

  METHOD line.
    rs_line = VALUE #( kind = iv_kind local_num = iv_local remote_num = iv_remote text = iv_text ).
  ENDMETHOD.

  METHOD direction.
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = `` iv_rstate = `M` ) ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = `M` iv_rstate = `M` ) ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = `A` iv_rstate = `` ) ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>remote_is_new( iv_lstate = `` iv_rstate = `` ) ).
  ENDMETHOD.

  METHOD map_swapped.
    " the remote is abapGit's "new" side now: an insert is a remote line
    DATA lt_diff TYPE zif_abapgit_definitions=>ty_diffs_tt.

    INSERT VALUE #( new_num = '5' new = `from git` result = zif_abapgit_definitions=>c_diff-insert ) INTO TABLE lt_diff.
    INSERT VALUE #( old_num = '6' old = `only here` result = zif_abapgit_definitions=>c_diff-delete ) INTO TABLE lt_diff.

    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( it_diff = lt_diff iv_remote_is_new = abap_true ).

    cl_abap_unit_assert=>assert_equals(
      act = lt_lines[ 1 ]
      exp = line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-remote iv_remote = `5` iv_text = `from git` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_lines[ 2 ]
      exp = line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-local iv_local = `6` iv_text = `only here` ) ).
  ENDMETHOD.

  METHOD pairs_changed_block.
    " not swapped: the remote is old (left), the system is new (right)
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>to_side_by_side( VALUE #(
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-remote iv_remote = `3` iv_text = `old a` ) )
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-remote iv_remote = `4` iv_text = `old b` ) )
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-local  iv_local  = `3` iv_text = `new a` ) )
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-local  iv_local  = `4` iv_text = `new b` ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows )
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_rows[ 2 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_sbs_row( old_num = `4` old_text = `old b` old_changed = abap_true
                                                        new_num = `4` new_text = `new b` new_changed = abap_true ) ).
  ENDMETHOD.

  METHOD pads_uneven_block.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>to_side_by_side( VALUE #(
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-local iv_local = `7` iv_text = `added 1` ) )
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-local iv_local = `8` iv_text = `added 2` ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows )
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 2 ]-old_text ).
    cl_abap_unit_assert=>assert_false( lt_rows[ 2 ]-old_changed ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-new_text
                                        exp = `added 2` ).
  ENDMETHOD.

  METHOD same_and_gap.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>to_side_by_side( VALUE #(
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-gap  iv_text = `... 9 unchanged lines ...` ) )
      ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-same iv_local = `11` iv_remote = `10` iv_text = `x` ) ) ) ).

    cl_abap_unit_assert=>assert_true( lt_rows[ 1 ]-gap ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_rows[ 2 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_sbs_row( old_num = `10` old_text = `x` new_num = `11` new_text = `x` ) ).
  ENDMETHOD.

  METHOD swapped_sides.
    " the remote is new: it goes right, its numbers with it
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>to_side_by_side(
      it_lines         = VALUE #( ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-same iv_local = `11` iv_remote = `10` iv_text = `x` ) )
                                  ( line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-remote iv_remote = `11` iv_text = `from git` ) ) )
      iv_remote_is_new = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-old_num
                                        exp = `11` ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-new_num
                                        exp = `10` ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-new_text
                                        exp = `from git` ).
    cl_abap_unit_assert=>assert_true( lt_rows[ 2 ]-new_changed ).
  ENDMETHOD.

  METHOD html_keeps_inner_spaces.
    " aligned columns, and a change that only touches blanks, must stay visible;
    " every second blank stays a normal one, so long lines can still wrap
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>code_html( `a  = 1` )
                                        exp = `<code>a&nbsp; = 1</code>` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>code_html( `a   = 1` )
                                        exp = `<code>a&nbsp;&nbsp; = 1</code>` ).
  ENDMETHOD.

  METHOD html_expands_tabs.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>code_html( |{ cl_abap_char_utilities=>horizontal_tab }x| )
      exp = `<code>&nbsp;&nbsp;&nbsp;&nbsp;x</code>` ).
  ENDMETHOD.

  METHOD counts_follow_direction.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>counts_text( iv_local = 2 iv_remote = 1 iv_remote_is_new = abap_false )
      exp = `+2 in this system, -1 in Git` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>counts_text( iv_local = 2 iv_remote = 1 iv_remote_is_new = abap_true )
      exp = `+1 in Git, -2 in this system` ).
  ENDMETHOD.

  METHOD html_escaped_and_indented.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>code_html( `  IF a < b & c.` )
      exp = `<code>&nbsp;&nbsp;IF a &lt; b &amp; c.</code>` ).
  ENDMETHOD.

ENDCLASS.
