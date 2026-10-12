CLASS ltcl_tags DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS annotated_and_lightweight FOR TESTING RAISING zcx_abapgit_exception.
    METHODS rejects_forged_or_moved FOR TESTING.
    METHODS unresolved_not_switchable FOR TESTING.
    METHODS display_and_links FOR TESTING.
    METHODS registered_ref_context FOR TESTING RAISING zcx_abapgit_exception.
    METHODS only_commit_targets FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.

CLASS ltcl_tags IMPLEMENTATION.
  METHOD registered_ref_context.
    zcl_ag2ui5_repo_service=>assert_tag_context( iv_commit = `` iv_origin = `` ).
    DO 3 TIMES.
      DATA(lv_commit) = COND string( WHEN sy-index <> 1 THEN `fixed` ).
      DATA(lv_origin) = COND string( WHEN sy-index <> 2 THEN `https://fork.example/repo@main` ).
      TRY.
          zcl_ag2ui5_repo_service=>assert_tag_context( iv_commit = lv_commit iv_origin = lv_origin ).
          cl_abap_unit_assert=>fail( `Fixed commits and switched origins must refuse all tag operations` ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDDO.
  ENDMETHOD.
  METHOD only_commit_targets.
    DATA(lt_tags) = zcl_ag2ui5_repo_service=>tag_rows( iv_current = `` it_tags = VALUE #(
      ( name = `refs/tags/blob` sha1 = '1111111' )
      ( name = `refs/tags/tree` sha1 = '2222222' )
      ( name = `refs/tags/tree^{}` sha1 = '3333333' )
      ( name = `refs/tags/commit` sha1 = '4444444' )
      ( name = `refs/tags/commit^{}` sha1 = '5555555' ) ) ).
    DATA(lt_objects) = VALUE zif_abapgit_definitions=>ty_objects_tt(
      ( sha1 = '1111111' type = zif_abapgit_git_definitions=>c_type-blob )
      ( sha1 = '3333333' type = zif_abapgit_git_definitions=>c_type-tree )
      ( sha1 = '5555555' type = zif_abapgit_git_definitions=>c_type-commit ) ).
    LOOP AT lt_tags ASSIGNING FIELD-SYMBOL(<ls_tag>).
      <ls_tag>-sha1 = zcl_ag2ui5_repo_service=>tag_commit( iv_sha1 = <ls_tag>-sha1 it_objects = lt_objects ).
      IF <ls_tag>-name = `refs/tags/commit`.
        cl_abap_unit_assert=>assert_equals( act = <ls_tag>-sha1 exp = `5555555` ).
        zcl_ag2ui5_repo_service=>assert_tag( iv_tag = <ls_tag>-name iv_sha1 = <ls_tag>-sha1 it_tags = lt_tags ).
      ELSE.
        cl_abap_unit_assert=>assert_initial( <ls_tag>-sha1 ).
        TRY.
            zcl_ag2ui5_repo_service=>assert_tag( iv_tag = <ls_tag>-name iv_sha1 = `` it_tags = lt_tags ).
            cl_abap_unit_assert=>fail( `Noncommit tag must not be switchable` ).
          CATCH zcx_abapgit_exception ##NO_HANDLER.
        ENDTRY.
      ENDIF.
      " Verification must leave the raw ref available for deletion, including annotated tree tags.
      zcl_ag2ui5_repo_service=>assert_deletable_tag(
        iv_tag = <ls_tag>-name iv_ref_sha1 = <ls_tag>-ref_sha1 it_tags = lt_tags ).
    ENDLOOP.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>tag_commit( iv_sha1 = `missing` it_objects = lt_objects ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>tag_commit( iv_sha1 = `` it_objects = lt_objects ) ).
  ENDMETHOD.
  METHOD annotated_and_lightweight.
    DATA(lt_tags) = zcl_ag2ui5_repo_service=>tag_rows( iv_current = `refs/tags/v1`
      it_tags = VALUE #(
        ( name = `refs/tags/v1` sha1 = '1111111' )
        ( name = `refs/tags/v2` sha1 = '2222222' type = zif_abapgit_git_definitions=>c_git_branch_type-annotated_tag )
        ( name = `refs/tags/v2^{}` sha1 = '3333333' )
        ( name = `refs/heads/main` sha1 = '4444444' ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_tags ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_tags[ 1 ]-name exp = `refs/tags/v2` ).
    cl_abap_unit_assert=>assert_equals( act = lt_tags[ 1 ]-sha1 exp = `3333333` ).
    cl_abap_unit_assert=>assert_equals( act = lt_tags[ 1 ]-ref_sha1 exp = `2222222` ).
    cl_abap_unit_assert=>assert_equals( act = lt_tags[ 2 ]-ref_sha1 exp = `1111111` ).
    cl_abap_unit_assert=>assert_equals( act = lt_tags[ 1 ]-kind exp = `Annotated` ).
    cl_abap_unit_assert=>assert_true( lt_tags[ 2 ]-current ).
    cl_abap_unit_assert=>assert_equals( act = lt_tags[ 2 ]-kind exp = `Lightweight` ).
    zcl_ag2ui5_repo_service=>assert_tag( iv_tag = `refs/tags/v2` iv_sha1 = `3333333` it_tags = lt_tags ).
  ENDMETHOD.
  METHOD rejects_forged_or_moved.
    LOOP AT VALUE string_table( ( `` ) ( `refs/heads/v1` ) ( `refs/tags/missing` ) ( `refs/tags/v1^{}` ) ( `refs/tags/v1` ) ) INTO DATA(lv_tag).
      TRY.
          zcl_ag2ui5_repo_service=>assert_tag( iv_tag = lv_tag iv_sha1 = `old`
            it_tags = VALUE #( ( name = `refs/tags/v1` sha1 = `new` ) ) ).
          cl_abap_unit_assert=>fail( |Invalid or moved tag accepted: { lv_tag }| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
  METHOD unresolved_not_switchable.
    DATA(lt_tags) = zcl_ag2ui5_repo_service=>tag_rows( iv_current = ``
      it_tags = VALUE #( ( name = `refs/tags/v1` sha1 = '1111111' type = zif_abapgit_git_definitions=>c_git_branch_type-annotated_tag ) ) ).
    cl_abap_unit_assert=>assert_initial( lt_tags[ 1 ]-sha1 ).
    TRY.
        zcl_ag2ui5_repo_service=>assert_tag( iv_tag = `refs/tags/v1` iv_sha1 = `` it_tags = lt_tags ).
        cl_abap_unit_assert=>fail( `Unresolved annotated tag must not be selected` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
  METHOD display_and_links.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_display( `refs/tags/release/v1` ) exp = `Tag release/v1` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_link(
      iv_url = `https://github.com/a/b.git` iv_branch = `refs/tags/release/v1` ) exp = `https://github.com/a/b/tree/release%2fv1` ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_repo_labels DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS split_and_clean FOR TESTING RAISING zcx_abapgit_exception.
    METHODS stable_colors FOR TESTING RAISING zcx_abapgit_exception.
    METHODS configured_colors FOR TESTING RAISING zcx_abapgit_exception.
    METHODS builtin_label_colors FOR TESTING RAISING zcx_abapgit_exception.
    METHODS invalid_colors_fall_back FOR TESTING RAISING zcx_abapgit_exception.
    METHODS edit_normalizes FOR TESTING RAISING zcx_abapgit_exception.
    METHODS edit_rejects_invalid FOR TESTING.
    METHODS edit_rejects_stale FOR TESTING.
ENDCLASS.

CLASS ltcl_repo_labels IMPLEMENTATION.
  METHOD edit_normalizes.
    cl_abap_unit_assert=>assert_equals( exp = `core, tools` act = zcl_ag2ui5_repo_service=>checked_labels(
      iv_labels = ` tools, core,tools ` iv_expected = `tools, core` iv_fresh = `core, tools` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>checked_labels(
      iv_labels = `` iv_expected = `core` iv_fresh = `core` ) ).
  ENDMETHOD.
  METHOD edit_rejects_invalid.
    TRY.
        zcl_ag2ui5_repo_service=>checked_labels( iv_labels = `bad<label` iv_expected = `` iv_fresh = `` ).
        cl_abap_unit_assert=>fail( `Invalid labels must be refused before persistence` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
  METHOD edit_rejects_stale.
    TRY.
        zcl_ag2ui5_repo_service=>checked_labels( iv_labels = `tools` iv_expected = `core` iv_fresh = `core, new` ).
        cl_abap_unit_assert=>fail( `Concurrent changes must be retained` ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_char_cp( act = lx_error->get_text( ) exp = `*changed*` ).
    ENDTRY.
  ENDMETHOD.
  METHOD split_and_clean.
    DATA(lt_labels) = zcl_ag2ui5_repo_service=>repo_labels( | core, tools,core, , bad{ cl_abap_char_utilities=>newline }label | ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_labels ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 1 ]-text exp = `core` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 3 ]-text exp = `bad?label` ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>repo_labels( ` , ` ) ).
  ENDMETHOD.
  METHOD stable_colors.
    DATA(lt_first) = zcl_ag2ui5_repo_service=>repo_labels( `Core, ui5` ).
    DATA(lt_second) = zcl_ag2ui5_repo_service=>repo_labels( `other, UI5, core` ).
    cl_abap_unit_assert=>assert_equals( act = lt_first[ 1 ]-color exp = lt_second[ 3 ]-color ).
    cl_abap_unit_assert=>assert_equals( act = lt_first[ 2 ]-color exp = lt_second[ 2 ]-color ).
    DATA(lt_spaces) = zcl_ag2ui5_repo_service=>repo_labels( `  multiple   words ` ).
    DATA(lt_normal) = zcl_ag2ui5_repo_service=>repo_labels( `multiple words` ).
    cl_abap_unit_assert=>assert_equals( act = lt_spaces exp = lt_normal ).
  ENDMETHOD.
  METHOD configured_colors.
    DATA(lt_labels) = zcl_ag2ui5_repo_service=>repo_labels(
      iv_labels = `one, two, three, four, five` iv_colors = `one:blue-set, two:purple, three:#00F, four:#fff/00ff00, five:#fff` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 1 ]-color exp = `blue` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 2 ]-color exp = `purple` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 3 ]-color exp = `blue` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 4 ]-color exp = `teal` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 5 ]-color exp = `slate` ).
  ENDMETHOD.
  METHOD builtin_label_colors.
    DATA(lt_labels) = zcl_ag2ui5_repo_service=>repo_labels(
      iv_labels = `abap2UI5, abapGit, unconfigured`
      iv_colors = `abap2UI5:lightblue, abapGit:lightred` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 1 ]-color exp = `blue` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 2 ]-color exp = `rose` ).
    DATA(lt_auto) = zcl_ag2ui5_repo_service=>repo_labels( `unconfigured` ).
    cl_abap_unit_assert=>assert_equals( act = lt_labels[ 3 ]-color exp = lt_auto[ 1 ]-color ).
    DATA(lt_styles) = zcl_ag2ui5_repo_service=>repo_labels(
      iv_labels = `white, white-b, white-r, grey, dark-w, dark-y, dark-r, dark-b, lightblue, darkblue, lightgreen, darkgreen, lightred, darkred, yellow, darkyellow, orange, brown, pink, teal, darkviolet`
      iv_colors = `white:white, white-b:white-b, white-r:white-r, grey:grey, dark-w:dark-w, dark-y:dark-y, dark-r:dark-r, dark-b:dark-b, `
        && `lightblue:lightblue, darkblue:darkblue, lightgreen:lightgreen, darkgreen:darkgreen, lightred:lightred, darkred:darkred, `
        && `yellow:yellow, darkyellow:darkyellow, orange:orange, brown:brown, pink:pink, teal:teal, darkviolet:darkviolet` ).
    DATA(lt_expected) = VALUE string_table(
      ( `slate` ) ( `blue` ) ( `rose` ) ( `slate` ) ( `slate` ) ( `amber` ) ( `rose` ) ( `blue` )
      ( `blue` ) ( `blue` ) ( `teal` ) ( `teal` ) ( `rose` ) ( `rose` ) ( `amber` ) ( `amber` )
      ( `amber` ) ( `amber` ) ( `rose` ) ( `teal` ) ( `purple` ) ).
    LOOP AT lt_styles INTO DATA(ls_style).
      cl_abap_unit_assert=>assert_equals( act = ls_style-color exp = lt_expected[ sy-tabix ] msg = ls_style-text ).
    ENDLOOP.
  ENDMETHOD.
  METHOD invalid_colors_fall_back.
    DATA(lt_auto) = zcl_ag2ui5_repo_service=>repo_labels( `unsafe, unknown, after` ).
    DATA(lt_actual) = zcl_ag2ui5_repo_service=>repo_labels(
      iv_labels = `unsafe, unknown, after` iv_colors = `unsafe:#fff;background:red, unknown:my-custom-css` ).
    cl_abap_unit_assert=>assert_equals( act = lt_actual exp = lt_auto ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_login DEFINITION DEFERRED.
CLASS zcl_ag2ui5_repo_service DEFINITION LOCAL FRIENDS ltcl_login.

CLASS ltcl_delete_preview DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA ms_preview TYPE zif_ag2ui5_repo_service=>ty_delete_preview.
    METHODS setup.
    METHODS unchanged_is_allowed FOR TESTING RAISING zcx_abapgit_exception.
    METHODS remove_needs_no_typed_name FOR TESTING RAISING zcx_abapgit_exception.
    METHODS confirmation_is_exact FOR TESTING.
    METHODS changed_objects_refused FOR TESTING.
    METHODS changed_identity_refused FOR TESTING.
    METHODS changed_transport_refused FOR TESTING.
    METHODS invalid_action_refused FOR TESTING.
    METHODS empty_key_refused FOR TESTING.
    METHODS malformed_key_refused FOR TESTING.
    METHODS empty_package_refused FOR TESTING.
    METHODS rejected IMPORTING is_actual TYPE zif_ag2ui5_repo_service=>ty_delete_preview
      iv_confirmation TYPE string DEFAULT `$FIXTURE`.
ENDCLASS.

CLASS ltcl_delete_preview IMPLEMENTATION.
  METHOD setup.
    ms_preview = VALUE #( key = `42` name = `Fixture` package = `$FIXTURE` action = `UNINSTALL`
      objects = VALUE #( ( obj_type = `CLAS` obj_name = `ZFIXTURE` package = `$FIXTURE` ) ) ).
  ENDMETHOD.
  METHOD rejected.
    TRY.
        zcl_ag2ui5_repo_service=>assert_delete_preview(
          is_expected = ms_preview is_actual = is_actual iv_confirmation = iv_confirmation ).
        cl_abap_unit_assert=>fail( `Deletion should have been refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
  METHOD unchanged_is_allowed.
    zcl_ag2ui5_repo_service=>assert_delete_preview(
      is_expected = ms_preview is_actual = ms_preview iv_confirmation = `$FIXTURE` ).
  ENDMETHOD.
  METHOD remove_needs_no_typed_name.
    ms_preview-action = `REMOVE`.
    CLEAR ms_preview-objects.
    zcl_ag2ui5_repo_service=>assert_delete_preview(
      is_expected = ms_preview is_actual = ms_preview iv_confirmation = `` ).
  ENDMETHOD.
  METHOD confirmation_is_exact.
    rejected( is_actual = ms_preview iv_confirmation = `` ).
    rejected( is_actual = ms_preview iv_confirmation = `$fixture` ).
    rejected( is_actual = ms_preview iv_confirmation = `$FIXTURE ` ).
  ENDMETHOD.
  METHOD changed_objects_refused.
    DATA(ls_actual) = ms_preview.
    INSERT VALUE #( obj_type = `TABL` obj_name = `ZNEW` package = `$FIXTURE` ) INTO TABLE ls_actual-objects.
    rejected( ls_actual ).
    ls_actual = ms_preview.
    CLEAR ls_actual-objects.
    rejected( ls_actual ).
    ls_actual = ms_preview.
    ls_actual-objects[ 1 ]-package = `$OTHER`.
    rejected( ls_actual ).
  ENDMETHOD.
  METHOD changed_identity_refused.
    DATA(ls_actual) = ms_preview.
    ls_actual-package = `$OTHER`.
    rejected( ls_actual ).
    ls_actual = ms_preview.
    ls_actual-key = `43`.
    rejected( ls_actual ).
    ls_actual = ms_preview.
    ls_actual-url = `https://example.com/changed.git`.
    rejected( ls_actual ).
    ls_actual = ms_preview.
    ls_actual-action = `REMOVE`.
    rejected( ls_actual ).
  ENDMETHOD.
  METHOD changed_transport_refused.
    DATA(ls_actual) = ms_preview.
    ls_actual-transport_required = abap_true.
    rejected( ls_actual ).
  ENDMETHOD.
  METHOD invalid_action_refused.
    ms_preview-action = `FORGED`.
    rejected( ms_preview ).
  ENDMETHOD.
  METHOD empty_key_refused.
    CLEAR ms_preview-key.
    rejected( ms_preview ).
  ENDMETHOD.
  METHOD malformed_key_refused.
    ms_preview-key = ` `.
    rejected( ms_preview ).
    ms_preview-key = `0000000000201`.
    rejected( ms_preview ).
    ms_preview-key = `FORGED`.
    rejected( ms_preview ).
  ENDMETHOD.
  METHOD empty_package_refused.
    CLEAR ms_preview-package.
    rejected( ms_preview ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_object_links DEFINITION DEFERRED.
CLASS zcl_ag2ui5_repo_service DEFINITION LOCAL FRIENDS ltcl_object_links.

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



CLASS ltcl_status_rows DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS every_file_kept FOR TESTING.
    METHODS highlight_per_side FOR TESTING.
    METHODS sort_by_object FOR TESTING.
    METHODS sort_by_file FOR TESTING.
    METHODS sort_by_type FOR TESTING.
    METHODS changes_on_top FOR TESTING.
    "! b.prog (changed), A.clas xml + abap, a.intf in /src/z/ (changed)
    METHODS unsorted
      RETURNING
        VALUE(rt_rows) TYPE zif_ag2ui5_repo_service=>ty_status_rows.
    METHODS order
      IMPORTING
        it_rows        TYPE zif_ag2ui5_repo_service=>ty_status_rows
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS ltcl_status_rows IMPLEMENTATION.

  METHOD every_file_kept.
    DATA lt_results TYPE zif_abapgit_definitions=>ty_results_tt.
    DATA ls_result LIKE LINE OF lt_results.

    ls_result-obj_type = 'CLAS'.
    ls_result-obj_name = 'ZCL_SAME'.
    ls_result-match    = abap_true.
    INSERT ls_result INTO TABLE lt_results.

    " no file difference, but inactive in the system
    ls_result-obj_name = 'ZCL_INACTIVE'.
    ls_result-inactive = abap_true.
    INSERT ls_result INTO TABLE lt_results.

    CLEAR ls_result.
    ls_result-obj_type = 'CLAS'.
    ls_result-obj_name = 'ZCL_CHANGED'.
    ls_result-lstate   = 'M'.
    INSERT ls_result INTO TABLE lt_results.

    " only in Git
    CLEAR ls_result.
    ls_result-obj_type = 'CLAS'.
    ls_result-obj_name = 'ZCL_NEW_IN_GIT'.
    ls_result-rstate   = 'A'.
    INSERT ls_result INTO TABLE lt_results.

    DATA(lt_rows) = zcl_ag2ui5_repo_service=>status_rows( lt_results ).

    cl_abap_unit_assert=>assert_equals(
      act = concat_lines_of( table = VALUE string_table( FOR r IN lt_rows ( |{ r-obj_name }:{ r-changed }| ) ) sep = `,` )
      exp = `ZCL_SAME:,ZCL_INACTIVE:X,ZCL_CHANGED:X,ZCL_NEW_IN_GIT:X` ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_rows[ 3 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_status_row( obj_type = `CLAS` obj_name = `ZCL_CHANGED` lstate = `M` changed = abap_true ) ).
  ENDMETHOD.

  METHOD unsorted.
    rt_rows = VALUE #(
      ( obj_type = `PROG` obj_name = `ZB`  path = `/src/`   filename = `zb.prog.abap` changed = abap_true )
      ( obj_type = `CLAS` obj_name = `za`  path = `/src/`   filename = `za.clas.xml` )
      ( obj_type = `CLAS` obj_name = `ZA`  path = `/src/`   filename = `za.clas.abap` )
      ( obj_type = `INTF` obj_name = `ZC`  path = `/src/z/` filename = `a.intf.abap` changed = abap_true ) ).
  ENDMETHOD.

  METHOD order.
    rv_text = concat_lines_of( table = VALUE string_table( FOR r IN it_rows ( r-filename ) ) sep = `,` ).
  ENDMETHOD.

  METHOD sort_by_object.
    " type, then name ignoring case, then file: a class's files stay together
    cl_abap_unit_assert=>assert_equals(
      act = order( zcl_ag2ui5_repo_service=>sort_status_rows( it_rows = unsorted( ) iv_by = `OBJECT` iv_changes_first = abap_false ) )
      exp = `za.clas.abap,za.clas.xml,a.intf.abap,zb.prog.abap` ).
  ENDMETHOD.

  METHOD sort_by_file.
    cl_abap_unit_assert=>assert_equals(
      act = order( zcl_ag2ui5_repo_service=>sort_status_rows( it_rows = unsorted( ) iv_by = `FILE` iv_changes_first = abap_false ) )
      exp = `za.clas.abap,za.clas.xml,zb.prog.abap,a.intf.abap` ).
  ENDMETHOD.

  METHOD sort_by_type.
    " within a type and name the original order stays
    cl_abap_unit_assert=>assert_equals(
      act = order( zcl_ag2ui5_repo_service=>sort_status_rows( it_rows = unsorted( ) iv_by = `TYPE` iv_changes_first = abap_false ) )
      exp = `za.clas.xml,za.clas.abap,a.intf.abap,zb.prog.abap` ).
  ENDMETHOD.

  METHOD changes_on_top.
    cl_abap_unit_assert=>assert_equals(
      act = order( zcl_ag2ui5_repo_service=>sort_status_rows( it_rows = unsorted( ) iv_by = `OBJECT` iv_changes_first = abap_true ) )
      exp = `a.intf.abap,zb.prog.abap,za.clas.abap,za.clas.xml` ).
  ENDMETHOD.

  METHOD highlight_per_side.
    " every change is yellow, whichever side changed; the Local and Remote
    " columns tell the sides apart
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>change_highlight( iv_lstate = `` iv_rstate = `` iv_inactive = abap_false )
      exp = `None` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>change_highlight( iv_lstate = `M` iv_rstate = `` iv_inactive = abap_false )
      exp = `Indication03` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>change_highlight( iv_lstate = `` iv_rstate = `` iv_inactive = abap_true )
      exp = `Indication03` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>change_highlight( iv_lstate = `` iv_rstate = `D` iv_inactive = abap_false )
      exp = `Indication03` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>change_highlight( iv_lstate = `M` iv_rstate = `M` iv_inactive = abap_false )
      exp = `Indication03` ).
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
      exp = VALUE zif_ag2ui5_repo_service=>ty_diff_line( remote_num = `3` text = `changed old` patch_id = `N3`
                                                          kind = zif_ag2ui5_repo_service=>c_line_kind-remote ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_lines[ 5 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_diff_line( local_num = `3` text = `changed new` patch_id = `N3`
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
    METHODS tint_per_kind FOR TESTING.
    METHODS no_tint_unchanged FOR TESTING.
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
      exp = VALUE zif_ag2ui5_repo_service=>ty_diff_line(
              BASE line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-remote iv_remote = `5` iv_text = `from git` )
              patch_id = `N5` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_lines[ 2 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_diff_line(
              BASE line( iv_kind = zif_ag2ui5_repo_service=>c_line_kind-local iv_local = `6` iv_text = `only here` )
              patch_id = `O6` ) ).
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

  METHOD tint_per_kind.
    " a block, so the colour fills the cell; min-height keeps an empty line visible
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>tinted_html( iv_html = `<code>a</code>` iv_tint = `ADDED` )
      exp = `<span style="display:block;min-height:1em;background-color:#e6ffec"><code>a</code></span>` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>tinted_html( iv_html = `<code>a</code>` iv_tint = `REMOVED` )
      exp = `<span style="display:block;min-height:1em;background-color:#ffebe9"><code>a</code></span>` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>tinted_html( iv_html = `<em>gap</em>` iv_tint = `GAP` )
      exp = `<span style="display:block;min-height:1em;background-color:#f6f8fa"><em>gap</em></span>` ).
  ENDMETHOD.

  METHOD no_tint_unchanged.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>tinted_html( iv_html = `<code>a</code>` iv_tint = `` )
      exp = `<code>a</code>` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>tinted_html( iv_html = `<code>a</code>` iv_tint = `SAME` )
      exp = `<code>a</code>` ).
  ENDMETHOD.

  METHOD html_escaped_and_indented.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>code_html( `  IF a < b & c.` )
      exp = `<code>&nbsp;&nbsp;IF a &lt; b &amp; c.</code>` ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_stage DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS candidates_both_sides FOR TESTING.
    METHODS classic_file_candidates FOR TESTING.
    METHODS selection_still_valid FOR TESTING RAISING cx_static_check.
    METHODS selection_file_gone FOR TESTING.
    METHODS selection_action_changed FOR TESTING.
    METHODS selection_remote_changed FOR TESTING.
    METHODS remote_changes_allowed FOR TESTING RAISING cx_static_check.
    METHODS moved_needs_old_path FOR TESTING.
    METHODS moved_with_old_path FOR TESTING RAISING cx_static_check.
    METHODS moved_partial_removal FOR TESTING.
    METHODS message_title_only FOR TESTING.
    METHODS message_with_body FOR TESTING.

    METHODS item
      IMPORTING
        iv_filename    TYPE string
        iv_action      TYPE zif_ag2ui5_repo_service=>ty_stage_action DEFAULT `ADD`
      RETURNING
        VALUE(rs_item) TYPE zif_ag2ui5_repo_service=>ty_stage_item.

ENDCLASS.


CLASS ltcl_stage IMPLEMENTATION.

  METHOD item.
    rs_item = VALUE #( path = `/src/` filename = iv_filename action = iv_action selected = abap_true ).
  ENDMETHOD.

  METHOD candidates_both_sides.
    DATA lt_results TYPE zif_abapgit_definitions=>ty_results_tt.

    INSERT VALUE #( obj_type = 'CLAS' obj_name = 'ZCL_A' path = '/src/' filename = 'zcl_a.clas.abap' lstate = 'M' ) INTO TABLE lt_results.
    INSERT VALUE #( obj_type = 'CLAS' obj_name = 'ZCL_B' path = '/src/' filename = 'zcl_b.clas.abap' lstate = 'D' ) INTO TABLE lt_results.
    INSERT VALUE #( obj_type = 'CLAS' obj_name = 'ZCL_C' path = '/src/' filename = 'zcl_c.clas.abap' lstate = 'A' rstate = 'M' ) INTO TABLE lt_results.
    " A remote-only edit can be reverted by committing the SAP version.
    INSERT VALUE #( obj_type = 'CLAS' obj_name = 'ZCL_D' path = '/src/' filename = 'zcl_d.clas.abap' rstate = 'M' ) INTO TABLE lt_results.
    INSERT VALUE #( obj_type = 'CLAS' obj_name = 'ZCL_E' path = '/src/' filename = 'zcl_e.clas.abap' match = abap_true ) INTO TABLE lt_results.

    DATA(lt_items) = zcl_ag2ui5_repo_service=>stage_candidates( lt_results ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_items )
                                        exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `zcl_b.clas.abap` ]-action
                                        exp = zif_ag2ui5_repo_service=>c_stage_action-rm ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `zcl_a.clas.abap` ]-action
                                        exp = zif_ag2ui5_repo_service=>c_stage_action-add ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `zcl_c.clas.abap` ]-obj_name
                                        exp = `ZCL_C` ).
    cl_abap_unit_assert=>assert_false( lt_items[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `zcl_c.clas.abap` ]-rstate
                                        exp = `M` ).
  ENDMETHOD.

  METHOD classic_file_candidates.
    DATA(ls_files) = VALUE zif_abapgit_definitions=>ty_stage_files(
      local = VALUE #( ( file = VALUE #( path = `/src/` filename = `changed.abap` )
                        item = VALUE #( obj_type = `CLAS` obj_name = `ZCL_A` ) )
                       ( file = VALUE #( path = `/src/` filename = `restore.abap` ) ) )
      remote = VALUE #( ( path = `/src/` filename = `remote-only.abap` )
                        ( path = `/src/` filename = `deleted.abap` )
                        ( path = `/` filename = `.abapgit.xml` ) ) ).
    DATA(lt_items) = zcl_ag2ui5_repo_service=>stage_candidates( is_files = ls_files
      it_results = VALUE #( ( path = `/src/` filename = `changed.abap` rstate = `M` )
                            ( path = `/src/` filename = `restore.abap` rstate = `D` )
                            ( path = `/src/` filename = `remote-only.abap` rstate = `A` )
                            ( path = `/src/` filename = `deleted.abap` lstate = `D` rstate = `M` )
                            ( path = `/src/` filename = `same.abap` match = abap_true ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 4 ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `changed.abap` ]-action exp = `ADD` ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `changed.abap` ]-lstate exp = `M` ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `restore.abap` ]-action exp = `ADD` ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `restore.abap` ]-lstate exp = `A` ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `remote-only.abap` ]-action exp = `RM` ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `deleted.abap` ]-action exp = `RM` ).
    cl_abap_unit_assert=>assert_false( lt_items[ 1 ]-selected ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ filename = `changed.abap` ]-obj_name exp = `ZCL_A` ).
  ENDMETHOD.

  METHOD selection_still_valid.
    " a new local change that was not selected does not matter
    zcl_ag2ui5_repo_service=>check_selection(
      it_fresh    = VALUE #( ( item( `zcl_a.clas.abap` ) ) ( item( `zcl_new.clas.abap` ) ) )
      it_selected = VALUE #( ( item( `zcl_a.clas.abap` ) ) ) ).
  ENDMETHOD.

  METHOD selection_file_gone.
    TRY.
        zcl_ag2ui5_repo_service=>check_selection(
          it_fresh    = VALUE #( )
          it_selected = VALUE #( ( item( `zcl_a.clas.abap` ) ) ) ).
        cl_abap_unit_assert=>fail( `A file that is no longer changed was accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD selection_action_changed.
    " modified when the page loaded, deleted by now
    TRY.
        zcl_ag2ui5_repo_service=>check_selection(
          it_fresh    = VALUE #( ( item( iv_filename = `zcl_a.clas.abap` iv_action = `RM` ) ) )
          it_selected = VALUE #( ( item( `zcl_a.clas.abap` ) ) ) ).
        cl_abap_unit_assert=>fail( `A changed action was accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD selection_remote_changed.
    " Git touched the file between page load and push
    DATA(ls_fresh) = item( `zcl_a.clas.abap` ).
    ls_fresh-rstate = `M`.
    TRY.
        zcl_ag2ui5_repo_service=>check_selection(
          it_fresh    = VALUE #( ( ls_fresh ) )
          it_selected = VALUE #( ( item( `zcl_a.clas.abap` ) ) ) ).
        cl_abap_unit_assert=>fail( `A remote change since the page load was not detected` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD remote_changes_allowed.
    " Like classic staging, explicitly selected SAP contents can replace Git.
    DATA(ls_item) = item( `zcl_a.clas.abap` ).
    ls_item-rstate = `M`.
    zcl_ag2ui5_repo_service=>check_push_allowed( VALUE #( ( ls_item ) ) ).
    ls_item-lstate = `M`.
    zcl_ag2ui5_repo_service=>check_push_allowed( VALUE #( ( ls_item ) ) ).
  ENDMETHOD.

  METHOD moved_needs_old_path.
    " the object moved folders: adding the new path alone duplicates it
    DATA(ls_new) = item( `zcl_a.clas.abap` ).
    ls_new-path = `/src/new/`.
    DATA(ls_old) = item( iv_filename = `zcl_a.clas.abap` iv_action = `RM` ).
    ls_old-selected = abap_false.
    TRY.
        zcl_ag2ui5_repo_service=>check_push_allowed( VALUE #( ( ls_new ) ( ls_old ) ) ).
        cl_abap_unit_assert=>fail( `A move without removing the old path was accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD moved_with_old_path.
    DATA(ls_new) = item( `zcl_a.clas.abap` ).
    ls_new-path = `/src/new/`.
    zcl_ag2ui5_repo_service=>check_push_allowed(
      VALUE #( ( ls_new ) ( item( iv_filename = `zcl_a.clas.abap` iv_action = `RM` ) ) ) ).
  ENDMETHOD.

  METHOD moved_partial_removal.
    " some lines of the old path are no removal: the file would stay in both
    DATA(ls_new) = item( `zcl_a.clas.abap` ).
    ls_new-path = `/src/new/`.
    DATA(ls_old) = item( iv_filename = `zcl_a.clas.abap` iv_action = `RM` ).
    ls_old-patch_ids = VALUE #( ( `O2` ) ).
    TRY.
        zcl_ag2ui5_repo_service=>check_push_allowed( VALUE #( ( ls_new ) ( ls_old ) ) ).
        cl_abap_unit_assert=>fail( `A move with a partial removal was accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD message_title_only.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>commit_message( iv_title = `Fix it` iv_body = `` )
                                        exp = `Fix it` ).
  ENDMETHOD.

  METHOD message_with_body.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>commit_message( iv_title = `Fix it` iv_body = `Because.` )
      exp = |Fix it{ cl_abap_char_utilities=>newline }{ cl_abap_char_utilities=>newline }Because.| ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_patch DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS ids_per_result FOR TESTING.
    METHODS fingerprint_follows_both_sides FOR TESTING RAISING cx_static_check.
    METHODS flags_by_id FOR TESTING RAISING cx_static_check.
    METHODS unknown_id_raises FOR TESTING.
    METHODS unchanged_line_id_raises FOR TESTING.
    METHODS empty_ids_raise FOR TESTING.
    METHODS malformed_id_raises FOR TESTING.
    METHODS lstate_matrix FOR TESTING.
    METHODS patch_content_partial FOR TESTING RAISING cx_static_check.
    METHODS patch_content_partial_delete FOR TESTING RAISING cx_static_check.
    METHODS patch_content_no_final_newline FOR TESTING RAISING cx_static_check.
    METHODS patch_content_mixed_newline FOR TESTING RAISING cx_static_check.

    "! unchanged, insert, delete, update - as in map_all_results
    METHODS sample_diff
      RETURNING
        VALUE(rt_diff) TYPE zif_abapgit_definitions=>ty_diffs_tt.

    "! abapGit's real diff of two texts (lines separated by newline), local new
    METHODS real_diff
      IMPORTING
        iv_local       TYPE string
        iv_remote      TYPE string
      RETURNING
        VALUE(rt_diff) TYPE zif_abapgit_definitions=>ty_diffs_tt
      RAISING
        zcx_abapgit_exception.

    "! The content zcl_abapgit_git_add_patch builds, as a string
    METHODS patched
      IMPORTING
        it_diff        TYPE zif_abapgit_definitions=>ty_diffs_tt
      RETURNING
        VALUE(rv_text) TYPE string
      RAISING
        zcx_abapgit_exception.

    METHODS text_of
      IMPORTING
        it_lines       TYPE string_table
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS ltcl_patch IMPLEMENTATION.

  METHOD sample_diff.
    INSERT VALUE #( new_num = '1' new = `same` old_num = '1' old = `same`
                    result = zif_abapgit_definitions=>c_diff-unchanged ) INTO TABLE rt_diff.
    INSERT VALUE #( new_num = '2' new = `added`
                    result = zif_abapgit_definitions=>c_diff-insert ) INTO TABLE rt_diff.
    INSERT VALUE #( old_num = '2' old = `removed`
                    result = zif_abapgit_definitions=>c_diff-delete ) INTO TABLE rt_diff.
    INSERT VALUE #( new_num = '3' new = `changed new` old_num = '3' old = `changed old`
                    result = zif_abapgit_definitions=>c_diff-update ) INTO TABLE rt_diff.
  ENDMETHOD.

  METHOD real_diff.
    rt_diff = zcl_abapgit_diff_factory=>get( )->create(
      iv_new = zcl_abapgit_convert=>string_to_xstring_utf8( iv_local )
      iv_old = zcl_abapgit_convert=>string_to_xstring_utf8( iv_remote ) )->get( ).
  ENDMETHOD.

  METHOD patched.
    rv_text = zcl_abapgit_convert=>xstring_to_string_utf8(
      NEW zcl_abapgit_git_add_patch( it_diff )->get_patch_binary( ) ).
  ENDMETHOD.

  METHOD text_of.
    rv_text = concat_lines_of( table = it_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.

  METHOD ids_per_result.
    " both halves of a changed line share one ID, so they are picked together
    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( sample_diff( ) ).

    cl_abap_unit_assert=>assert_equals( act = concat_lines_of( table = VALUE string_table(
                                                FOR l IN lt_lines ( |{ l-patch_id }/| ) ) )
                                        exp = `/N2/O2/N3/N3/` ).
  ENDMETHOD.

  METHOD fingerprint_follows_both_sides.
    DATA(lv_base) = zcl_ag2ui5_repo_service=>fingerprint( iv_local = CONV #( `41` ) iv_remote = CONV #( `42` ) ).

    cl_abap_unit_assert=>assert_not_initial( lv_base ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>fingerprint( iv_local = CONV #( `41` ) iv_remote = CONV #( `42` ) )
      exp = lv_base ).
    cl_abap_unit_assert=>assert_differs(
      act = zcl_ag2ui5_repo_service=>fingerprint( iv_local = CONV #( `43` ) iv_remote = CONV #( `42` ) )
      exp = lv_base ).
    cl_abap_unit_assert=>assert_differs(
      act = zcl_ag2ui5_repo_service=>fingerprint( iv_local = CONV #( `41` ) iv_remote = CONV #( `43` ) )
      exp = lv_base ).
    " no ambiguity where one side ends and the other begins
    cl_abap_unit_assert=>assert_differs(
      act = zcl_ag2ui5_repo_service=>fingerprint( iv_local = CONV #( `4142` ) iv_remote = CONV #( `` ) )
      exp = zcl_ag2ui5_repo_service=>fingerprint( iv_local = CONV #( `41` ) iv_remote = CONV #( `42` ) ) ).
  ENDMETHOD.

  METHOD flags_by_id.
    DATA(lt_diff) = zcl_ag2ui5_repo_service=>apply_patch( it_diff = sample_diff( )
                                                          it_ids  = VALUE #( ( `O2` ) ( `N3` ) ) ).

    cl_abap_unit_assert=>assert_equals( act = concat_lines_of( table = VALUE string_table(
                                                FOR d IN lt_diff ( COND #( WHEN d-patch_flag = abap_true THEN `X` ELSE `-` ) ) ) )
                                        exp = `--XX` ).
  ENDMETHOD.

  METHOD unknown_id_raises.
    TRY.
        zcl_ag2ui5_repo_service=>apply_patch( it_diff = sample_diff( )
                                              it_ids  = VALUE #( ( `N9` ) ) ).
        cl_abap_unit_assert=>fail( `An unknown ID must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD unchanged_line_id_raises.
    " line 1 is unchanged: N1 names no change, O2 names the deletion only
    TRY.
        zcl_ag2ui5_repo_service=>apply_patch( it_diff = sample_diff( )
                                              it_ids  = VALUE #( ( `N1` ) ) ).
        cl_abap_unit_assert=>fail( `An unchanged line must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD empty_ids_raise.
    TRY.
        zcl_ag2ui5_repo_service=>apply_patch( it_diff = sample_diff( )
                                              it_ids  = VALUE #( ) ).
        cl_abap_unit_assert=>fail( `An empty patch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD malformed_id_raises.
    " the IDs come from the browser: a short one must be refused, not dump
    LOOP AT VALUE string_table( ( `` ) ( `N` ) ( `X2` ) ) INTO DATA(lv_id).
      TRY.
          zcl_ag2ui5_repo_service=>apply_patch( it_diff = sample_diff( )
                                                it_ids  = VALUE #( ( lv_id ) ) ).
          cl_abap_unit_assert=>fail( |ID "{ lv_id }" must be refused| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD lstate_matrix.
    DATA(lt_all)  = sample_diff( ).
    MODIFY lt_all FROM VALUE #( patch_flag = abap_true ) TRANSPORTING patch_flag WHERE patch_flag = abap_false.
    DATA(lt_some) = sample_diff( ).
    lt_some[ 2 ]-patch_flag = abap_true.

    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>patch_lstate( iv_lstate = `D` it_diff = lt_all )
                                        exp = `D` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>patch_lstate( iv_lstate = `D` it_diff = lt_some )
                                        exp = `M` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>patch_lstate( iv_lstate = `A` it_diff = lt_all )
                                        exp = `A` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>patch_lstate( iv_lstate = `A` it_diff = lt_some )
                                        exp = `M` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>patch_lstate( iv_lstate = `M` it_diff = lt_all )
                                        exp = `M` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>patch_lstate( iv_lstate = `M` it_diff = lt_some )
                                        exp = `M` ).
  ENDMETHOD.

  METHOD patch_content_partial.
    " Git: a b c d. Local: a B c e (b changed to B, d replaced by e).
    " Picking only the first change gives a B c d.
    DATA(lt_diff) = real_diff( iv_local  = text_of( VALUE #( ( `a` ) ( `B` ) ( `c` ) ( `e` ) ( `` ) ) )
                               iv_remote = text_of( VALUE #( ( `a` ) ( `b` ) ( `c` ) ( `d` ) ( `` ) ) ) ).
    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( lt_diff ).
    DATA(lv_first) = lt_lines[ text = `B` ]-patch_id.

    DATA(lv_text) = patched( zcl_ag2ui5_repo_service=>apply_patch( it_diff = lt_diff
                                                                   it_ids  = VALUE #( ( lv_first ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lv_text
                                        exp = text_of( VALUE #( ( `a` ) ( `B` ) ( `c` ) ( `d` ) ( `` ) ) ) ).
  ENDMETHOD.

  METHOD patch_content_partial_delete.
    " deleted locally: every line is a removal. Picking the removal of b
    " only leaves a c in Git
    DATA(lt_diff) = real_diff( iv_local  = ``
                               iv_remote = text_of( VALUE #( ( `a` ) ( `b` ) ( `c` ) ( `` ) ) ) ).
    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( lt_diff ).

    DATA(lt_flagged) = zcl_ag2ui5_repo_service=>apply_patch( it_diff = lt_diff
                                                             it_ids  = VALUE #( ( lt_lines[ text = `b` ]-patch_id ) ) ).

    cl_abap_unit_assert=>assert_equals( act = patched( lt_flagged )
                                        exp = text_of( VALUE #( ( `a` ) ( `c` ) ( `` ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>patch_lstate( iv_lstate = `D` it_diff = lt_flagged )
                                        exp = `M` ).
  ENDMETHOD.

  METHOD patch_content_mixed_newline.
    " Git's last line has no newline, the system's has one: abapGit's diff
    " marks the old last line with a form feed, which must not reach Git
    DATA(lt_diff) = real_diff( iv_local  = text_of( VALUE #( ( `a` ) ( `b` ) ( `c` ) ( `` ) ) )
                               iv_remote = text_of( VALUE #( ( `a` ) ( `b` ) ) ) ).
    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( lt_diff ).

    DATA(lv_text) = patched( zcl_ag2ui5_repo_service=>apply_patch(
      it_diff = lt_diff
      it_ids  = VALUE #( ( lt_lines[ text = `c` ]-patch_id ) ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lv_text
                                        exp = text_of( VALUE #( ( `a` ) ( `b` ) ( `c` ) ( `` ) ) ) ).
  ENDMETHOD.

  METHOD patch_content_no_final_newline.
    " as abapGit: the patch always ends in a newline
    DATA(lt_diff) = real_diff( iv_local  = text_of( VALUE #( ( `a` ) ( `b` ) ) )
                               iv_remote = text_of( VALUE #( ( `a` ) ) ) ).
    DATA(lt_lines) = zcl_ag2ui5_repo_service=>map_diff( lt_diff ).
    DATA(lt_ids) = VALUE string_table( FOR l IN lt_lines WHERE ( patch_id IS NOT INITIAL ) ( l-patch_id ) ).
    SORT lt_ids.
    DELETE ADJACENT DUPLICATES FROM lt_ids.

    cl_abap_unit_assert=>assert_char_cp(
      act = patched( zcl_ag2ui5_repo_service=>apply_patch( it_diff = lt_diff it_ids = lt_ids ) )
      exp = |a{ cl_abap_char_utilities=>newline }b*{ cl_abap_char_utilities=>newline }| ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_branches DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS remote_list
      RETURNING
        VALUE(rt_branches) TYPE zif_abapgit_git_definitions=>ty_git_branch_list_tt.
    METHODS rows
      RETURNING
        VALUE(rt_rows) TYPE zif_ag2ui5_repo_service=>ty_branches.

    METHODS head_duplicate_and_empty_gone FOR TESTING.
    METHODS default_first_then_by_name FOR TESTING.
    METHODS default_and_current_marked FOR TESTING.
    METHODS listed_branch_accepted FOR TESTING RAISING cx_static_check.
    METHODS unknown_branch_refused FOR TESTING.
    METHODS empty_branch_refused FOR TESTING.
    METHODS sha1_carried FOR TESTING.
    METHODS other_branch_deletable FOR TESTING RAISING cx_static_check.
    METHODS default_not_deletable FOR TESTING.
    METHODS current_not_deletable FOR TESTING.
    METHODS unknown_not_deletable FOR TESTING.
    METHODS moved_not_deletable FOR TESTING.
    METHODS unmoved_deletable FOR TESTING RAISING cx_static_check.
    METHODS branch_name_normalized FOR TESTING.
    METHODS branch_name_keeps_prefix FOR TESTING.
    METHODS branch_name_trims FOR TESTING.
    METHODS valid_name_accepted FOR TESTING RAISING cx_static_check.
    METHODS invalid_names_refused FOR TESTING.
    METHODS existing_branch_refused FOR TESTING.
    METHODS case_differs_is_new FOR TESTING RAISING cx_static_check.
    METHODS push_branch_blank_is_none FOR TESTING RAISING cx_static_check.
    METHODS push_branch_normalized FOR TESTING RAISING cx_static_check.
    METHODS push_branch_invalid_refused FOR TESTING.
    METHODS push_branch_current_refused FOR TESTING.
    METHODS registered_url_unswitched FOR TESTING RAISING cx_static_check.
    METHODS registered_url_switched FOR TESTING RAISING cx_static_check.
    METHODS registered_url_malformed FOR TESTING.
    METHODS switch_needed FOR TESTING.

ENDCLASS.


CLASS ltcl_branches IMPLEMENTATION.

  METHOD remote_list.
    " as get_branches_only( ) returns it: HEAD next to the real default
    rt_branches = VALUE #(
      ( name = `refs/heads/zeta`  display_name = `zeta` sha1 = '1111111' )
      ( name = `HEAD`             display_name = `HEAD` is_head = abap_true sha1 = '2222222' )
      ( name = `refs/heads/main`  display_name = `main` is_head = abap_true sha1 = '2222222' )
      ( name = ``                 display_name = `` )
      ( name = `refs/heads/alpha` display_name = `alpha` sha1 = '3333333' ) ).
  ENDMETHOD.

  METHOD rows.
    rt_rows = zcl_ag2ui5_repo_service=>branch_rows( it_branches    = remote_list( )
                                                    iv_head_symref = `refs/heads/main`
                                                    iv_current     = `refs/heads/zeta` ).
  ENDMETHOD.

  METHOD head_duplicate_and_empty_gone.
    DATA(lt_rows) = rows( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 3 ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_rows[ name = `HEAD` ] ) ) ).
  ENDMETHOD.

  METHOD default_first_then_by_name.
    cl_abap_unit_assert=>assert_equals(
      act = concat_lines_of( table = VALUE string_table( FOR r IN rows( ) ( r-display ) ) sep = `,` )
      exp = `main,alpha,zeta` ).
  ENDMETHOD.

  METHOD default_and_current_marked.
    DATA(lt_rows) = rows( ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_rows[ 1 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_branch( name = `refs/heads/main` display = `main` default = abap_true sha1 = `2222222` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lt_rows[ 3 ]
      exp = VALUE zif_ag2ui5_repo_service=>ty_branch( name = `refs/heads/zeta` display = `zeta` current = abap_true sha1 = `1111111` ) ).
  ENDMETHOD.

  METHOD registered_url_unswitched.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>registered_url( iv_url = `https://github.com/a/repo.git` iv_switched_origin = `` )
      exp = `https://github.com/a/repo.git` ).
  ENDMETHOD.

  METHOD registered_url_switched.
    " abapGit stores the registered remote as <url>@<branch>, split at the last @
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>registered_url( iv_url = `https://github.com/fork/repo.git`
        iv_switched_origin = `https://github.com/a/repo.git@refs/heads/main` )
      exp = `https://github.com/a/repo.git` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>registered_url( iv_url = `https://github.com/fork/repo.git`
        iv_switched_origin = `https://user@git.example/a/repo.git@refs/heads/main` )
      exp = `https://user@git.example/a/repo.git` ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>registered_url( iv_url = `https://github.com/fork/repo.git`
        iv_switched_origin = `https://github.com/a/repo.git@` )
      exp = `https://github.com/a/repo.git` ).
  ENDMETHOD.

  METHOD registered_url_malformed.
    " abapGit refuses this format too ("Incorrect format of switched origin")
    DO 2 TIMES.
      DATA(lv_origin) = COND string( WHEN sy-index = 1 THEN `https://github.com/a/repo.git` ELSE `@refs/heads/main` ).
      TRY.
          zcl_ag2ui5_repo_service=>registered_url( iv_url = `https://github.com/fork/repo.git` iv_switched_origin = lv_origin ).
          cl_abap_unit_assert=>fail( |A switched origin without registered URL must be refused: { lv_origin }| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDDO.
  ENDMETHOD.

  METHOD switch_needed.
    " Same branch on the registered remote: nothing to do
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>switch_needed( iv_selected = `refs/heads/main`
      iv_branch = `refs/heads/main` iv_commit = `` iv_origin = `` ) ).
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>switch_needed( iv_selected = `refs/heads/main`
      iv_branch = `refs/heads/dev` iv_commit = `` iv_origin = `` ) ).
    " Same name, but a fixed commit or a fork still has to be reset
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>switch_needed( iv_selected = `refs/heads/main`
      iv_branch = `refs/heads/main` iv_commit = `1234567` iv_origin = `` ) ).
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>switch_needed( iv_selected = `refs/heads/main`
      iv_branch = `refs/heads/main` iv_commit = `` iv_origin = `https://github.com/a/repo.git@refs/heads/main` ) ).
  ENDMETHOD.

  METHOD listed_branch_accepted.
    zcl_ag2ui5_repo_service=>assert_branch( iv_branch = `refs/heads/alpha` it_branches = rows( ) ).
  ENDMETHOD.

  METHOD unknown_branch_refused.
    " the name comes from the browser
    TRY.
        zcl_ag2ui5_repo_service=>assert_branch( iv_branch = `refs/heads/nope` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `An unknown branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD empty_branch_refused.
    TRY.
        zcl_ag2ui5_repo_service=>assert_branch( iv_branch = `` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `An empty branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD branch_name_normalized.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_name( `feature x` )
                                        exp = `refs/heads/feature-x` ).
  ENDMETHOD.

  METHOD branch_name_keeps_prefix.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_name( `refs/heads/a` )
                                        exp = `refs/heads/a` ).
  ENDMETHOD.

  METHOD branch_name_trims.
    cl_abap_unit_assert=>assert_equals( act = zcl_ag2ui5_repo_service=>branch_name( `  x  ` )
                                        exp = `refs/heads/x` ).
  ENDMETHOD.

  METHOD valid_name_accepted.
    zcl_ag2ui5_repo_service=>assert_branch_name( `refs/heads/feature/x-1` ).
  ENDMETHOD.

  METHOD invalid_names_refused.
    " the name comes from the browser; the remote would reject these too
    LOOP AT VALUE string_table( ( `refs/heads/` ) ( `refs/heads/a..b` ) ( `refs/heads/a~b` )
                                ( `refs/heads/a:b` ) ( `refs/heads/a^b` ) ( `refs/heads/a?b` )
                                ( `refs/heads/a*b` ) ( `refs/heads/a[b` ) ( `refs/heads/a\b` )
                                ( `refs/heads//a` ) ( `refs/heads/a/` ) ( `refs/heads/.a` )
                                ( `refs/heads/a.` ) ( `refs/heads/a.lock` )
                                ( |refs/heads/a{ cl_abap_char_utilities=>horizontal_tab }b| ) ) INTO DATA(lv_name).
      TRY.
          zcl_ag2ui5_repo_service=>assert_branch_name( lv_name ).
          cl_abap_unit_assert=>fail( |{ lv_name } must be refused| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD existing_branch_refused.
    TRY.
        zcl_ag2ui5_repo_service=>assert_new_branch( iv_branch = `refs/heads/main` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `An existing branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD case_differs_is_new.
    " Git refs are case-sensitive, as abapGit's check
    zcl_ag2ui5_repo_service=>assert_new_branch( iv_branch = `refs/heads/Main` it_branches = rows( ) ).
  ENDMETHOD.

  METHOD push_branch_blank_is_none.
    cl_abap_unit_assert=>assert_initial(
      zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = `   ` it_branches = rows( ) ) ).
  ENDMETHOD.

  METHOD push_branch_normalized.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = ` feature x ` it_branches = rows( ) )
      exp = `refs/heads/feature-x` ).
  ENDMETHOD.

  METHOD push_branch_invalid_refused.
    TRY.
        zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = `a..b` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `An invalid name must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD push_branch_current_refused.
    " rows( ) follows zeta; pushing "to a new branch" zeta must not pass
    TRY.
        zcl_ag2ui5_repo_service=>push_branch( iv_new_branch = `zeta` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `The followed branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD sha1_carried.
    DATA(lt_rows) = rows( ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ name = `refs/heads/alpha` ]-sha1 exp = `3333333` ).
  ENDMETHOD.

  METHOD other_branch_deletable.
    zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = `refs/heads/alpha` it_branches = rows( ) ).
  ENDMETHOD.

  METHOD default_not_deletable.
    TRY.
        zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = `refs/heads/main` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `The default branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD current_not_deletable.
    TRY.
        zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = `refs/heads/zeta` it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `The current branch must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD moved_not_deletable.
    " the user confirmed the commit shown; someone pushed since
    TRY.
        zcl_ag2ui5_repo_service=>assert_deletable( iv_branch   = `refs/heads/alpha`
                                                   iv_sha1     = `9999999`
                                                   it_branches = rows( ) ).
        cl_abap_unit_assert=>fail( `A branch that moved must not be deleted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD unmoved_deletable.
    zcl_ag2ui5_repo_service=>assert_deletable( iv_branch   = `refs/heads/alpha`
                                               iv_sha1     = `3333333`
                                               it_branches = rows( ) ).
  ENDMETHOD.

  METHOD unknown_not_deletable.
    " the name comes from the browser; HEAD is never listed
    LOOP AT VALUE string_table( ( `refs/heads/gone` ) ( `HEAD` ) ( `` ) ) INTO DATA(lv_name).
      TRY.
          zcl_ag2ui5_repo_service=>assert_deletable( iv_branch = lv_name it_branches = rows( ) ).
          cl_abap_unit_assert=>fail( |{ lv_name } must be refused| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_new_repo DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS valid_online
      RETURNING
        VALUE(rs_repo) TYPE zif_ag2ui5_repo_service=>ty_new_repo.
    METHODS fields
      IMPORTING
        it_errors      TYPE zif_ag2ui5_repo_service=>ty_field_errors
      RETURNING
        VALUE(rv_list) TYPE string.

    METHODS normalize_trims_upper FOR TESTING.
    METHODS normalize_branch_full_name FOR TESTING.
    METHODS normalize_clears_other_kind FOR TESTING.
    METHODS valid_online_no_errors FOR TESTING.
    METHODS online_needs_url FOR TESTING.
    METHODS offline_needs_name FOR TESTING.
    METHODS package_required FOR TESTING.
    METHODS unknown_kind FOR TESTING.
    METHODS folder_logic_allowed FOR TESTING.
    METHODS language_version_allowed FOR TESTING.
    METHODS invalid_form_creates_nothing FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.


CLASS ltcl_new_repo IMPLEMENTATION.

  METHOD valid_online.
    rs_repo = VALUE #( kind         = zif_ag2ui5_repo_service=>c_repo_kind-online
                       url          = `https://github.com/abapGit-tests/DTEL.git`
                       package      = `$AG2UI5_NEW`
                       folder_logic = `PREFIX` ).
  ENDMETHOD.

  METHOD fields.
    " the fields with an error, in order, for one compact assertion
    LOOP AT it_errors INTO DATA(ls_error).
      rv_list = rv_list && |{ ls_error-field };|.
    ENDLOOP.
  ENDMETHOD.

  METHOD normalize_trims_upper.
    " the form comes from the browser: blanks around, a package in lower case
    DATA(ls_repo) = zcl_ag2ui5_repo_service=>normalize_new_repo( VALUE #(
      kind           = ` online `
      url            = `  https://github.com/abapGit-tests/DTEL.git `
      package        = `  $ag2ui5_new `
      display_name   = ` My repo `
      folder_logic   = ` full `
      labels         = ` a,b `
      abap_lang_vers = ` keyUser ` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `ONLINE` act = ls_repo-kind ).
    cl_abap_unit_assert=>assert_equals( exp = `https://github.com/abapGit-tests/DTEL.git` act = ls_repo-url ).
    cl_abap_unit_assert=>assert_equals( exp = `$AG2UI5_NEW` act = ls_repo-package ).
    " inner blanks stay in a name
    cl_abap_unit_assert=>assert_equals( exp = `My repo` act = ls_repo-display_name ).
    cl_abap_unit_assert=>assert_equals( exp = `FULL` act = ls_repo-folder_logic ).
    cl_abap_unit_assert=>assert_equals( exp = `a,b` act = ls_repo-labels ).
    " abapGit's language versions are case-sensitive
    cl_abap_unit_assert=>assert_equals( exp = `keyUser` act = ls_repo-abap_lang_vers ).
  ENDMETHOD.

  METHOD normalize_branch_full_name.
    DATA(ls_repo) = valid_online( ).
    ls_repo-branch = ` main `.
    cl_abap_unit_assert=>assert_equals(
      exp = `refs/heads/main`
      act = zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo )-branch ).
    " empty stays empty: the remote's default branch
    ls_repo-branch = ``.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo )-branch ).
  ENDMETHOD.

  METHOD normalize_clears_other_kind.
    " the browser keeps the fields of the kind the user switched away from
    DATA(ls_repo) = valid_online( ).
    ls_repo-name = `left over`.
    ls_repo = zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo ).
    cl_abap_unit_assert=>assert_initial( ls_repo-name ).

    ls_repo = valid_online( ).
    ls_repo-kind         = zif_ag2ui5_repo_service=>c_repo_kind-offline.
    ls_repo-name         = `offline`.
    ls_repo-branch       = `main`.
    ls_repo-display_name = `shown`.
    ls_repo = zcl_ag2ui5_repo_service=>normalize_new_repo( ls_repo ).
    cl_abap_unit_assert=>assert_initial( ls_repo-url ).
    cl_abap_unit_assert=>assert_initial( ls_repo-branch ).
    cl_abap_unit_assert=>assert_initial( ls_repo-display_name ).
    cl_abap_unit_assert=>assert_equals( exp = `offline` act = ls_repo-name ).
  ENDMETHOD.

  METHOD valid_online_no_errors.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_repo_errors( valid_online( ) ) ).
  ENDMETHOD.

  METHOD online_needs_url.
    DATA(ls_repo) = valid_online( ).
    CLEAR ls_repo-url.
    cl_abap_unit_assert=>assert_equals(
      exp = `url;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD offline_needs_name.
    DATA(ls_repo) = valid_online( ).
    ls_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
    CLEAR ls_repo-url.
    cl_abap_unit_assert=>assert_equals(
      exp = `name;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD package_required.
    DATA(ls_repo) = valid_online( ).
    CLEAR ls_repo-package.
    cl_abap_unit_assert=>assert_equals(
      exp = `package;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD unknown_kind.
    " no field: the switch only offers the two kinds
    DATA(ls_repo) = valid_online( ).
    ls_repo-kind = `ZIP`.
    cl_abap_unit_assert=>assert_equals(
      exp = `;`
      act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
  ENDMETHOD.

  METHOD folder_logic_allowed.
    DATA(ls_repo) = valid_online( ).
    LOOP AT VALUE string_table( ( `PREFIX` ) ( `FULL` ) ( `MIXED` ) ) INTO ls_repo-folder_logic.
      cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ).
    ENDLOOP.
    LOOP AT VALUE string_table( ( `` ) ( `FLAT` ) ) INTO ls_repo-folder_logic.
      cl_abap_unit_assert=>assert_equals(
        exp = `folder_logic;`
        act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD language_version_allowed.
    DATA(ls_repo) = valid_online( ).
    LOOP AT VALUE string_table( ( `` ) ( `ignore` ) ( `standard` ) ( `keyUser` ) ( `cloudDevelopment` ) )
         INTO ls_repo-abap_lang_vers.
      cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ).
    ENDLOOP.
    LOOP AT VALUE string_table( ( `STANDARD` ) ( `undefined` ) ( `cloud` ) ) INTO ls_repo-abap_lang_vers.
      cl_abap_unit_assert=>assert_equals(
        exp = `abap_lang_vers;`
        act = fields( zcl_ag2ui5_repo_service=>new_repo_errors( ls_repo ) ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD invalid_form_creates_nothing.
    " no URL, no package: refused before anything reaches abapGit
    DATA(li_service) = CAST zif_ag2ui5_repo_service( NEW zcl_ag2ui5_repo_service( ) ).
    DATA(lv_before) = lines( li_service->list_repos( ) ).
    DATA(ls_result) = li_service->create_repo( VALUE #( kind = ` online ` folder_logic = `PREFIX` ) ).
    cl_abap_unit_assert=>assert_equals( exp = zif_ag2ui5_repo_service=>c_outcome-invalid act = ls_result-outcome ).
    cl_abap_unit_assert=>assert_equals( exp = `url;package;` act = fields( ls_result-errors ) ).
    cl_abap_unit_assert=>assert_initial( ls_result-key ).
    cl_abap_unit_assert=>assert_equals( exp = lv_before act = lines( li_service->list_repos( ) ) ).
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_zip DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS archive
      IMPORTING
        iv_prefix      TYPE string OPTIONAL
        iv_extra       TYPE string DEFAULT `src/ztest.abap`
      RETURNING
        VALUE(rv_zip) TYPE xstring
      RAISING zcx_abapgit_exception.
    METHODS rejects
      IMPORTING iv_zip TYPE xstring.
    METHODS abapgit_zip FOR TESTING RAISING zcx_abapgit_exception.
    METHODS github_zip FOR TESTING RAISING zcx_abapgit_exception.
    METHODS binary_upload FOR TESTING RAISING zcx_abapgit_exception.
    METHODS empty_upload FOR TESTING.
    METHODS empty_zip FOR TESTING.
    METHODS malformed_zip FOR TESTING.
    METHODS missing_metadata FOR TESTING.
    METHODS invalid_metadata FOR TESTING.
    METHODS parent_path FOR TESTING RAISING zcx_abapgit_exception.
    METHODS duplicate_paths FOR TESTING RAISING zcx_abapgit_exception.
ENDCLASS.

CLASS ltcl_zip IMPLEMENTATION.

  METHOD archive.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = iv_prefix && `.abapgit.xml`
                content = zcl_abapgit_dot_abapgit=>build_default( )->serialize( ) ).
    " Includes bytes that cannot survive conversion through a text string
    lo_zip->add( name = iv_prefix && iv_extra content = CONV xstring( '00FF0C80' ) ).
    rv_zip = lo_zip->save( ).
  ENDMETHOD.

  METHOD rejects.
    TRY.
        zcl_ag2ui5_repo_service=>zip_files( iv_zip ).
        cl_abap_unit_assert=>fail( `Invalid ZIP accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD abapgit_zip.
    DATA(lt_files) = zcl_ag2ui5_repo_service=>zip_files( archive( ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_files ) ).
    cl_abap_unit_assert=>assert_equals( exp = CONV xstring( '00FF0C80' )
                                       act = lt_files[ path = `/src/` filename = `ztest.abap` ]-data ).
  ENDMETHOD.

  METHOD github_zip.
    DATA(lt_files) = zcl_ag2ui5_repo_service=>zip_files( archive( iv_prefix = `repository-main/` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_files[ path = `/` filename = `.abapgit.xml` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_files[ path = `/src/` filename = `ztest.abap` ] ) ) ).
  ENDMETHOD.

  METHOD binary_upload.
    DATA(lv_zip) = archive( ).
    cl_abap_unit_assert=>assert_equals( exp = lv_zip act = zcl_ag2ui5_repo_service=>decode_zip(
      `data:application/octet-stream;base64,` && cl_http_utility=>encode_x_base64( lv_zip ) ) ).
  ENDMETHOD.

  METHOD empty_upload.
    TRY.
        zcl_ag2ui5_repo_service=>decode_zip( `` ).
        cl_abap_unit_assert=>fail( `Empty upload accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

  METHOD empty_zip.
    rejects( NEW cl_abap_zip( )->save( ) ).
  ENDMETHOD.

  METHOD malformed_zip.
    rejects( CONV xstring( '01020304' ) ).
  ENDMETHOD.

  METHOD missing_metadata.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = `src/ztest.abap` content = CONV xstring( '00FF' ) ).
    rejects( lo_zip->save( ) ).
  ENDMETHOD.

  METHOD invalid_metadata.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = `.abapgit.xml` content = CONV xstring( '01020304' ) ).
    rejects( lo_zip->save( ) ).
  ENDMETHOD.

  METHOD parent_path.
    rejects( archive( iv_extra = `../src/ztest.abap` ) ).
  ENDMETHOD.

  METHOD duplicate_paths.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->add( name = `.abapgit.xml` content = zcl_abapgit_dot_abapgit=>build_default( )->serialize( ) ).
    lo_zip->add( name = `src/ZTEST.abap` content = CONV xstring( '01' ) ).
    lo_zip->add( name = `src/ztest.abap` content = CONV xstring( '02' ) ).
    rejects( lo_zip->save( ) ).
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_object_links DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS existing_interface FOR TESTING.
    METHODS missing_object FOR TESTING.
    METHODS invalid_key FOR TESTING.
    METHODS cache_by_object FOR TESTING.
    METHODS existing_package FOR TESTING.
ENDCLASS.

CLASS ltcl_object_links IMPLEMENTATION.
  METHOD existing_package.
    " the Status header links the repository's package
    DATA lt_links TYPE zcl_ag2ui5_repo_service=>ty_object_links.
    DATA(lv_link) = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `DEVC` iv_obj_name = `$ABAPGIT2UI5`
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_link exp = |adt://{ sy-sysid }/sap/bc/adt/packages/%24abapgit2ui5| ).
  ENDMETHOD.

  METHOD existing_interface.
    DATA lt_links TYPE zcl_ag2ui5_repo_service=>ty_object_links.
    DATA(lv_link) = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `INTF` iv_obj_name = `ZIF_AG2UI5_REPO_SERVICE`
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_equals(
      act = lv_link exp = |adt://{ sy-sysid }/sap/bc/adt/oo/interfaces/zif_ag2ui5_repo_service| ).
  ENDMETHOD.

  METHOD missing_object.
    DATA lt_links TYPE zcl_ag2ui5_repo_service=>ty_object_links.
    DATA(lv_link) = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `CLAS` iv_obj_name = `ZCL_AG2UI5_LINK_DOES_NOT_EXIST`
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_initial( lv_link ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 ).
  ENDMETHOD.

  METHOD invalid_key.
    DATA lt_links TYPE zcl_ag2ui5_repo_service=>ty_object_links.
    DATA(lv_link) = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `INTFX` iv_obj_name = `ZIF_AG2UI5_REPO_SERVICE`
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_initial( lv_link ).
    lv_link = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `INTF` iv_obj_name = ``
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_initial( lv_link ).
    lv_link = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `INTF` iv_obj_name = `ZIF_AG2UI5_REPO_SERVICEXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_initial( lv_link ).
  ENDMETHOD.

  METHOD cache_by_object.
    DATA lt_links TYPE zcl_ag2ui5_repo_service=>ty_object_links.
    DATA(lv_first) = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `INTF` iv_obj_name = `ZIF_AG2UI5_REPO_SERVICE`
      CHANGING ct_links = lt_links ).
    DATA(lv_second) = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `INTF` iv_obj_name = `ZIF_AG2UI5_REPO_SERVICE`
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_equals( act = lv_second exp = lv_first ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 ).
    lv_second = zcl_ag2ui5_repo_service=>object_link(
      EXPORTING iv_obj_type = `CLAS` iv_obj_name = `ZIF_AG2UI5_REPO_SERVICE`
      CHANGING ct_links = lt_links ).
    cl_abap_unit_assert=>assert_initial( lv_second ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 2 ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_object_status DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS counts_and_states FOR TESTING.
    METHODS owner_from_first_file FOR TESTING.
    METHODS local_only_no_owner FOR TESTING.
    METHODS mixed_states FOR TESTING.
    METHODS repository_files FOR TESTING.
    METHODS distinct_types FOR TESTING.
    METHODS changes_first FOR TESTING.
    METHODS empty_status FOR TESTING.
ENDCLASS.

CLASS ltcl_object_status IMPLEMENTATION.
  METHOD owner_from_first_file.
    " the object takes the owner of its first file that has one, as the Stage page does
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>object_status_rows( VALUE #(
      ( obj_type = `CLAS` obj_name = `ZCL_A` filename = `a.abap` rstate = `M` changed_by = `` )
      ( obj_type = `CLAS` obj_name = `ZCL_A` filename = `a.xml` rstate = `M` changed_by = `ALICE` )
      ( obj_type = `CLAS` obj_name = `ZCL_B` filename = `b.abap` rstate = `M` changed_by = `UNKNOWN` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ obj_name = `ZCL_A` ]-changed_by exp = `ALICE` ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ obj_name = `ZCL_B` ]-changed_by exp = `UNKNOWN` ).
  ENDMETHOD.
  METHOD local_only_no_owner.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>object_status_rows( VALUE #(
      ( obj_type = `CLAS` obj_name = `ZCL_A` filename = `a.abap` lstate = `M` changed_by = `` ) ) ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-changed_by ).
  ENDMETHOD.
  METHOD counts_and_states.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>object_status_rows( VALUE #(
      ( obj_type = `CLAS` obj_name = `ZCL_A` filename = `a.abap` lstate = `M` changed = abap_true object_link = `adt://A4H/a` )
      ( obj_type = `CLAS` obj_name = `ZCL_A` filename = `a.xml` )
      ( obj_type = `CLAS` obj_name = `ZCL_A` filename = `a.testclasses.abap` inactive = abap_true changed = abap_true ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-file_count exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-changed_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-lstate exp = `M` ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-rstate ).
    cl_abap_unit_assert=>assert_true( lt_rows[ 1 ]-inactive ).
    cl_abap_unit_assert=>assert_true( lt_rows[ 1 ]-changed ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-object_link exp = `adt://A4H/a` ).
  ENDMETHOD.
  METHOD mixed_states.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>object_status_rows( VALUE #(
      ( obj_type = `CLAS` obj_name = `ZCL_A` lstate = `A` rstate = `M` changed = abap_true )
      ( obj_type = `CLAS` obj_name = `ZCL_A` lstate = `D` rstate = `A` changed = abap_true )
      ( obj_type = `CLAS` obj_name = `ZCL_A` lstate = `M` rstate = `M` changed = abap_true ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-lstate exp = `MIXED` ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-rstate exp = `MIXED` ).
  ENDMETHOD.
  METHOD repository_files.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>object_status_rows( VALUE #(
      ( filename = `.abapgit.xml` )
      ( filename = `README.md` lstate = `A` changed = abap_true )
      ( obj_type = `CLAS` filename = `unmapped.abap` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-obj_type ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-obj_name ).
    cl_abap_unit_assert=>assert_initial( lt_rows[ 1 ]-object_link ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-file_count exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-changed_count exp = 1 ).
  ENDMETHOD.
  METHOD distinct_types.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>object_status_rows( VALUE #(
      ( obj_type = `CLAS` obj_name = `ZTEST` )
      ( obj_type = `INTF` obj_name = `ZTEST` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 ).
  ENDMETHOD.
  METHOD changes_first.
    DATA(lt_files) = VALUE zif_ag2ui5_repo_service=>ty_status_rows(
      ( obj_type = `CLAS` obj_name = `ZA` filename = `a.xml` )
      ( obj_type = `CLAS` obj_name = `ZB` filename = `b.xml` )
      ( obj_type = `CLAS` obj_name = `ZB` filename = `b.abap` changed = abap_true lstate = `M` ) ).
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>object_status_rows( lt_files ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-obj_name exp = `ZB` ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-file_count exp = 2 ).
    lt_rows = zcl_ag2ui5_repo_service=>object_status_rows( it_rows = lt_files iv_changes_first = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-obj_name exp = `ZA` ).
  ENDMETHOD.
  METHOD empty_status.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>object_status_rows( VALUE #( ) ) ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_ignore DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    METHODS native_filter FOR TESTING.
    METHODS metadata_removal FOR TESTING.
    METHODS ordered_negation FOR TESTING.
    METHODS namespace_literal FOR TESTING.
    METHODS add_remove FOR TESTING RAISING cx_static_check.
    METHODS invalid_rules FOR TESTING.
    METHODS preview_scope FOR TESTING RAISING cx_static_check.
    METHODS no_match FOR TESTING.
    METHODS stale_preview FOR TESTING RAISING cx_static_check.
    METHODS results RETURNING VALUE(rt_rows) TYPE zif_abapgit_definitions=>ty_results_tt.
ENDCLASS.
CLASS ltcl_ignore IMPLEMENTATION.
  METHOD results.
    rt_rows = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` lstate = `M` )
      ( path = `/src/` filename = `zcl_b.clas.abap` lstate = `D` )
      ( path = `/src/` filename = `zcl_a.clas.xml` lstate = `M` )
      ( path = `/` filename = `.abapgit.xml` lstate = `M` )
      ( path = `/` filename = `README.md` lstate = `D` ) ).
  ENDMETHOD.
  METHOD native_filter.
    DATA(ls_dot) = VALUE zif_abapgit_dot_abapgit=>ty_dot_abapgit(
      starting_folder = `/src/` ignore = VALUE #( ( `/src/*.clas.abap` ) ) ).
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>stage_candidates( it_results = results( ) is_dot = ls_dot ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_rows[ filename = `.abapgit.xml` ] ) ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_rows[ filename = `zcl_b.clas.abap` ] ) ) ).
  ENDMETHOD.
  METHOD metadata_removal.
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>stage_candidates(
      VALUE #( ( path = `/` filename = `.abapgit.xml` lstate = `D` ) ) ).
    cl_abap_unit_assert=>assert_initial( lt_rows ).
  ENDMETHOD.
  METHOD ordered_negation.
    DATA(ls_dot) = VALUE zif_abapgit_dot_abapgit=>ty_dot_abapgit( starting_folder = `/src/`
      ignore = VALUE #( ( `/src/*.abap` ) ( `!/src/zcl_a.clas.abap` ) ) ).
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>stage_candidates( it_results = results( ) is_dot = ls_dot ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_rows[ filename = `zcl_a.clas.abap` ] ) ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( line_exists( lt_rows[ filename = `zcl_b.clas.abap` ] ) ) ).
  ENDMETHOD.
  METHOD namespace_literal.
    DATA(ls_dot) = VALUE zif_abapgit_dot_abapgit=>ty_dot_abapgit( starting_folder = `/src/`
      ignore = VALUE #( ( `/src/#test#cl_a.clas.+bap` ) ) ).
    DATA(lt_rows) = zcl_ag2ui5_repo_service=>stage_candidates( is_dot = ls_dot
      it_results = VALUE #( ( path = `/src/` filename = `#test#cl_a.clas.abap` lstate = `A` )
        ( path = `/src/` filename = `testcl_a.clas.abap` lstate = `A` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-filename exp = `testcl_a.clas.abap` ).
  ENDMETHOD.
  METHOD add_remove.
    DATA(ls_dot) = VALUE zif_abapgit_dot_abapgit=>ty_dot_abapgit( starting_folder = `/src/` ).
    DATA(ls_added) = zcl_ag2ui5_repo_service=>change_ignore_rules( is_dot = ls_dot iv_rule = `/src/*.abap` ).
    cl_abap_unit_assert=>assert_initial( ls_dot-ignore ).
    cl_abap_unit_assert=>assert_equals( act = ls_added-starting_folder exp = `/src/` ).
    DATA(ls_removed) = zcl_ag2ui5_repo_service=>change_ignore_rules(
      is_dot = ls_added iv_rule = `/src/*.abap` iv_remove = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_removed exp = ls_dot ).
  ENDMETHOD.
  METHOD invalid_rules.
    LOOP AT VALUE string_table( ( `` ) ( `*.abap` ) ( `/.abapgit.xml` ) ( `/.apack-manifest.xml` )
        ( |/src/a{ cl_abap_char_utilities=>newline }b| ) ( |/src/a{ cl_abap_char_utilities=>horizontal_tab }b| )
        ( repeat( val = `/` occ = 256 ) ) ) INTO DATA(lv_rule).
      TRY.
          zcl_ag2ui5_repo_service=>change_ignore_rules( is_dot = VALUE #( ) iv_rule = lv_rule ).
          cl_abap_unit_assert=>fail( `Invalid rule accepted` ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
    TRY.
        zcl_ag2ui5_repo_service=>change_ignore_rules( is_dot = VALUE #( ignore = VALUE #( ( `/src/a` ) ) )
          iv_rule = `/src/a` ).
        cl_abap_unit_assert=>fail( `Duplicate accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
    TRY.
        zcl_ag2ui5_repo_service=>change_ignore_rules( is_dot = VALUE #( ) iv_rule = `/src/a` iv_remove = abap_true ).
        cl_abap_unit_assert=>fail( `Missing rule removed` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
  METHOD preview_scope.
    DATA(ls_preview) = zcl_ag2ui5_repo_service=>ignore_preview( it_results = results( )
      is_dot = VALUE #( starting_folder = `/src/` ) iv_rule = `/src/*.clas.abap` ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_preview-files ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_preview-files[ 1 ]-filename exp = `zcl_a.clas.abap` ).
    cl_abap_unit_assert=>assert_initial( ls_preview-rules ).
    DATA(ls_remove) = zcl_ag2ui5_repo_service=>ignore_preview( it_results = results( )
      is_dot = VALUE #( starting_folder = `/src/` ignore = VALUE #( ( `/src/*.clas.abap` ) ) )
      iv_rule = `/src/*.clas.abap` iv_remove = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_remove-files ) exp = 2 ).
  ENDMETHOD.
  METHOD no_match.
    TRY.
        zcl_ag2ui5_repo_service=>ignore_preview( it_results = results( )
          is_dot = VALUE #( starting_folder = `/src/` ) iv_rule = `/src/no-such-file` ).
        cl_abap_unit_assert=>fail( `Empty preview accepted` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
  METHOD stale_preview.
    DATA(ls_preview) = zcl_ag2ui5_repo_service=>ignore_preview( it_results = results( )
      is_dot = VALUE #( starting_folder = `/src/` ) iv_rule = `/src/*.abap` ).
    zcl_ag2ui5_repo_service=>assert_ignore_preview( is_expected = ls_preview is_fresh = ls_preview ).
    DO 4 TIMES.
      DATA(ls_changed) = ls_preview.
      CASE sy-index.
        WHEN 1. APPEND `/src/other` TO ls_changed-rules.
        WHEN 2. DELETE ls_changed-files INDEX 1.
        WHEN 3. ls_changed-files[ 1 ]-rstate = `M`.
        WHEN 4. ls_changed-rule = `/src/*`.
      ENDCASE.
      TRY.
          zcl_ag2ui5_repo_service=>assert_ignore_preview( is_expected = ls_preview is_fresh = ls_changed ).
          cl_abap_unit_assert=>fail( `Stale preview accepted` ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDDO.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_new_package DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS normalization FOR TESTING.
    METHODS required_fields FOR TESTING.
    METHODS no_truncation FOR TESTING.
    METHODS local_has_no_transport FOR TESTING.
    METHODS transport_required FOR TESTING.
    METHODS invalid_does_not_create FOR TESTING RAISING cx_static_check.
    METHODS existing_is_refused FOR TESTING RAISING cx_static_check.
    METHODS local_defaults FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltcl_new_package IMPLEMENTATION.
  METHOD normalization.
    DATA(ls_form) = zcl_ag2ui5_repo_service=>normalize_new_package( VALUE #(
      package = `  $test_new ` description = `  Keep   inner blanks  `
      software_component = ` local ` super_package = ` $tmp ` transport = ` a4hk900148 ` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `$TEST_NEW` act = ls_form-package ).
    cl_abap_unit_assert=>assert_equals( exp = `Keep   inner blanks` act = ls_form-description ).
    cl_abap_unit_assert=>assert_equals( exp = `LOCAL` act = ls_form-software_component ).
    cl_abap_unit_assert=>assert_equals( exp = `$TMP` act = ls_form-super_package ).
    cl_abap_unit_assert=>assert_equals( exp = `A4HK900148` act = ls_form-transport ).
  ENDMETHOD.
  METHOD required_fields.
    DATA(lt_errors) = zcl_ag2ui5_repo_service=>new_package_errors( VALUE #( ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_errors[ field = `package` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_errors[ field = `description` ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_errors[ field = `software_component` ] ) ) ).
  ENDMETHOD.
  METHOD no_truncation.
    DATA(lt_errors) = zcl_ag2ui5_repo_service=>new_package_errors( VALUE #(
      package = repeat( val = `Z` occ = 31 ) description = repeat( val = `X` occ = 61 )
      software_component = repeat( val = `X` occ = 21 ) transport_layer = `ABCDE`
      super_package = repeat( val = `X` occ = 31 ) transport = repeat( val = `X` occ = 21 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 6 act = lines( lt_errors ) ).
  ENDMETHOD.
  METHOD local_has_no_transport.
    DATA(ls_form) = VALUE zif_ag2ui5_repo_service=>ty_new_package(
      package = `$NEW` description = `Local` software_component = `LOCAL` super_package = `$TMP` ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_package_errors( ls_form ) ).
    ls_form-transport = `A4HK900148`.
    DATA(lt_errors) = zcl_ag2ui5_repo_service=>new_package_errors( ls_form ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_errors[ field = `transport` ] ) ) ).
    CLEAR ls_form-transport.
    ls_form-software_component = `HOME`.
    lt_errors = zcl_ag2ui5_repo_service=>new_package_errors( ls_form ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_errors[ field = `software_component` ] ) ) ).
  ENDMETHOD.
  METHOD transport_required.
    DATA(ls_form) = VALUE zif_ag2ui5_repo_service=>ty_new_package(
      package = `ZNEW` description = `Transportable` software_component = `HOME` transport_layer = `ZDEV` ).
    DATA(lt_errors) = zcl_ag2ui5_repo_service=>new_package_errors( ls_form ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_errors[ field = `transport` ] ) ) ).
    ls_form-transport = `A4HK900148`.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>new_package_errors( ls_form ) ).
  ENDMETHOD.
  METHOD invalid_does_not_create.
    DATA(li_service) = CAST zif_ag2ui5_repo_service( NEW zcl_ag2ui5_repo_service( ) ).
    DATA(ls_result) = li_service->create_package( VALUE #( package = `$AG2UI5_NEVER_CREATE` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `INVALID` act = ls_result-outcome ).
    cl_abap_unit_assert=>assert_false( zcl_abapgit_factory=>get_sap_package( '$AG2UI5_NEVER_CREATE' )->exists( ) ).
  ENDMETHOD.
  METHOD existing_is_refused.
    DATA(li_service) = CAST zif_ag2ui5_repo_service( NEW zcl_ag2ui5_repo_service( ) ).
    DATA(ls_result) = li_service->create_package( VALUE #( package = `$TMP` description = `Existing`
      software_component = `LOCAL` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `INVALID` act = ls_result-outcome ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( ls_result-errors[ field = `package` ] ) ) ).
  ENDMETHOD.
  METHOD local_defaults.
    DATA(li_service) = CAST zif_ag2ui5_repo_service( NEW zcl_ag2ui5_repo_service( ) ).
    DATA(ls_form) = li_service->package_defaults( ` $new ` ).
    cl_abap_unit_assert=>assert_equals( exp = `$NEW` act = ls_form-package ).
    cl_abap_unit_assert=>assert_equals( exp = `LOCAL` act = ls_form-software_component ).
    cl_abap_unit_assert=>assert_equals( exp = `$TMP` act = ls_form-super_package ).
    ls_form = li_service->package_defaults( iv_package = `$NEW` iv_abap_lang_vers = `cloudDevelopment` ).
    cl_abap_unit_assert=>assert_equals( exp = `ZLOCAL` act = ls_form-super_package ).
    cl_abap_unit_assert=>assert_equals( exp = `ZLOCAL` act = ls_form-software_component ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_semantic_diff DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS declarations FOR TESTING.
    METHODS implementations FOR TESTING.
    METHODS direction_and_ranges FOR TESTING.
    METHODS formatting_and_comments FOR TESTING.
    METHODS literal_case FOR TESTING.
    METHODS owners_and_visibility FOR TESTING.
    METHODS incomplete_source FOR TESTING.
    METHODS renamed_method FOR TESTING.
    METHODS macros_are_not_methods FOR TESTING.
ENDCLASS.

CLASS ltcl_semantic_diff IMPLEMENTATION.
  METHOD declarations.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( ( `INTERFACE zif_test PUBLIC.` )
        ( `METHODS: one IMPORTING iv_x TYPE i,` ) ( ` two RETURNING VALUE(rv_x) TYPE i.` ) ( `ENDINTERFACE.` ) )
      it_local = VALUE #( ( `INTERFACE zif_test PUBLIC.` )
        ( `METHODS: one IMPORTING iv_x TYPE string,` ) ( ` two RETURNING VALUE(rv_x) TYPE i.` )
        ( `CLASS-METHODS three.` ) ( `ENDINTERFACE.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-changes ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-name exp = `ONE` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-action exp = `changed` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 2 ]-action exp = `added` ).
  ENDMETHOD.

  METHOD implementations.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( ( `CLASS zcl_test IMPLEMENTATION.` )
        ( `METHOD one.` ) ( `rv_x = 1.` ) ( `ENDMETHOD.` ) ( `METHOD two.` ) ( `ENDMETHOD.` ) ( `ENDCLASS.` ) )
      it_local = VALUE #( ( `CLASS zcl_test IMPLEMENTATION.` )
        ( `METHOD one.` ) ( `rv_x = 2.` ) ( `ENDMETHOD.` ) ( `ENDCLASS.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-changes ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-component exp = `Implementation` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-action exp = `changed` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 2 ]-action exp = `removed` ).
  ENDMETHOD.

  METHOD direction_and_ranges.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff( iv_remote_is_new = abap_true
      it_local = VALUE #( )
      it_remote = VALUE #( ( `INTERFACE zif_test PUBLIC.` )
        ( `METHODS one` ) ( ` IMPORTING iv_x TYPE i.` ) ( `ENDINTERFACE.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-changes ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-action exp = `added` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-remote_from exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-remote_to exp = 3 ).
    cl_abap_unit_assert=>assert_initial( ls_result-changes[ 1 ]-local_from ).
  ENDMETHOD.

  METHOD formatting_and_comments.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( ( `CLASS zcl_test IMPLEMENTATION.` )
        ( `METHOD one.` ) ( `rv_x = 1.` ) ( `ENDMETHOD.` ) ( `ENDCLASS.` ) )
      it_local = VALUE #( ( `class zcl_test implementation.` )
        ( `method one.` ) ( `" METHOD fake.` ) ( `  rv_x    = 1. " comment` ) ( `endmethod.` ) ( `endclass.` ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_result-changes ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-note exp = `Method declarations*` ).
  ENDMETHOD.

  METHOD literal_case.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( ( `CLASS zcl_test IMPLEMENTATION.` )
        ( `METHOD one.` ) ( `rv_x = 'a. METHOD fake.'.` ) ( `ENDMETHOD.` ) ( `ENDCLASS.` ) )
      it_local = VALUE #( ( `CLASS zcl_test IMPLEMENTATION.` )
        ( `METHOD one.` ) ( `rv_x = 'A. METHOD fake.'.` ) ( `ENDMETHOD.` ) ( `ENDCLASS.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-changes ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-name exp = `ONE` ).
  ENDMETHOD.

  METHOD owners_and_visibility.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( ( `CLASS lcl_one DEFINITION.` ) ( `PUBLIC SECTION.` ) ( `METHODS run.` ) ( `ENDCLASS.` )
        ( `CLASS lcl_two DEFINITION.` ) ( `PUBLIC SECTION.` ) ( `METHODS run.` ) ( `ENDCLASS.` ) )
      it_local = VALUE #( ( `CLASS lcl_one DEFINITION.` ) ( `PROTECTED SECTION.` ) ( `METHODS run.` ) ( `ENDCLASS.` )
        ( `CLASS lcl_two DEFINITION.` ) ( `PUBLIC SECTION.` ) ( `CLASS-METHODS run.` ) ( `ENDCLASS.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-changes ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-owner exp = `LCL_ONE` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 2 ]-owner exp = `LCL_TWO` ).
  ENDMETHOD.

  METHOD incomplete_source.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( )
      it_local = VALUE #( ( `CLASS zcl_test IMPLEMENTATION.` ) ( `METHOD one.` ) ( `rv_x = 1.` ) ) ).
    cl_abap_unit_assert=>assert_initial( ls_result-changes ).
    cl_abap_unit_assert=>assert_char_cp( act = ls_result-note exp = `Structural summary unavailable*` ).
  ENDMETHOD.

  METHOD renamed_method.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( ( `INTERFACE zif_test PUBLIC.` ) ( `METHODS old_name.` ) ( `ENDINTERFACE.` ) )
      it_local = VALUE #( ( `INTERFACE zif_test PUBLIC.` ) ( `METHODS new_name.` ) ( `ENDINTERFACE.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-changes ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-action exp = `added` ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 2 ]-action exp = `removed` ).
  ENDMETHOD.

  METHOD macros_are_not_methods.
    DATA(ls_result) = zcl_ag2ui5_repo_service=>semantic_diff(
      it_remote = VALUE #( )
      it_local = VALUE #( ( `DEFINE fake.` ) ( `METHODS not_a_method.` ) ( `END-OF-DEFINITION.` )
        ( `CLASS lcl_test DEFINITION DEFERRED.` )
        ( `CLASS lcl_test DEFINITION.` ) ( `PUBLIC SECTION.` ) ( `METHODS run.` ) ( `ENDCLASS.` ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-changes ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-changes[ 1 ]-name exp = `RUN` ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_branch_links DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS display_refs FOR TESTING.
    METHODS github_nested_branch FOR TESTING.
    METHODS provider_urls FOR TESTING.
    METHODS reserved_characters FOR TESTING.
    METHODS unavailable_links FOR TESTING.
ENDCLASS.

CLASS ltcl_branch_links IMPLEMENTATION.
  METHOD display_refs.
    cl_abap_unit_assert=>assert_equals( exp = `feature/test1234`
      act = zcl_ag2ui5_repo_service=>branch_display( `refs/heads/feature/test1234` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `main`
      act = zcl_ag2ui5_repo_service=>branch_display( `main` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `Tag v1`
      act = zcl_ag2ui5_repo_service=>branch_display( `refs/tags/v1` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>branch_display( `` ) ).
  ENDMETHOD.

  METHOD github_nested_branch.
    cl_abap_unit_assert=>assert_equals( exp = `https://github.com/owner/repo/tree/feature%2ftest1234`
      act = to_lower( zcl_ag2ui5_repo_service=>branch_link(
        iv_url = `https://github.com/owner/repo.git/` iv_branch = `refs/heads/feature/test1234` ) ) ).
  ENDMETHOD.

  METHOD provider_urls.
    cl_abap_unit_assert=>assert_equals( exp = `https://gitlab.com/group/sub/repo/-/tree/main`
      act = zcl_ag2ui5_repo_service=>branch_link(
        iv_url = `https://gitlab.com/group/sub/repo.git` iv_branch = `refs/heads/main` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `https://bitbucket.org/owner/repo/src/main/`
      act = zcl_ag2ui5_repo_service=>branch_link(
        iv_url = `https://bitbucket.org/owner/repo` iv_branch = `refs/heads/main` ) ).
  ENDMETHOD.

  METHOD reserved_characters.
    cl_abap_unit_assert=>assert_equals( exp = `https://github.com/owner/repo/tree/feature%2fa%23b%25c`
      act = to_lower( zcl_ag2ui5_repo_service=>branch_link(
        iv_url = `https://github.com/owner/repo` iv_branch = `refs/heads/feature/a#b%c` ) ) ).
  ENDMETHOD.

  METHOD unavailable_links.
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>branch_link(
      iv_url = `` iv_branch = `refs/heads/main` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>branch_link(
      iv_url = `https://github.com/owner/repo` iv_branch = `` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `https://github.com/owner/repo/tree/v1` act = zcl_ag2ui5_repo_service=>branch_link(
      iv_url = `https://github.com/owner/repo` iv_branch = `refs/tags/v1` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>branch_link(
      iv_url = `javascript:alert(1)` iv_branch = `refs/heads/main` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>branch_link(
      iv_url = `https://github.com.evil.example/owner/repo` iv_branch = `refs/heads/main` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>branch_link(
      iv_url = `https://git.example.com/owner/repo` iv_branch = `refs/heads/main` ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_favorite_user DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_persist_user PARTIALLY IMPLEMENTED.
    DATA mt_favorites TYPE zif_abapgit_persist_user=>ty_favorites.
    DATA mv_writes TYPE i.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_favorite_user IMPLEMENTATION.
  METHOD zif_abapgit_persist_user~is_favorite_repo.
    rv_yes = xsdbool( line_exists( mt_favorites[ table_line = iv_repo_key ] ) ).
  ENDMETHOD.
  METHOD zif_abapgit_persist_user~toggle_favorite.
    IF mv_fail = abap_true.
      zcx_abapgit_exception=>raise( `Persistence failed` ).
    ENDIF.
    mv_writes = mv_writes + 1.
    IF line_exists( mt_favorites[ table_line = iv_repo_key ] ).
      DELETE mt_favorites WHERE table_line = iv_repo_key.
    ELSE.
      INSERT iv_repo_key INTO TABLE mt_favorites.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_favorite_mutation DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PUBLIC SECTION.
    " Test injections execute in the production seam context.
    CLASS-DATA mv_exists TYPE abap_bool.
    CLASS-DATA mv_authorized TYPE abap_bool.
  PRIVATE SECTION.
    DATA mo_user TYPE REF TO ltd_favorite_user.
    DATA mi_original TYPE REF TO zif_abapgit_persist_user.
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.
    METHODS setup.
    METHODS teardown.
    METHODS set_and_remove FOR TESTING RAISING zcx_abapgit_exception.
    METHODS repeated_set_is_noop FOR TESTING RAISING zcx_abapgit_exception.
    METHODS malformed_keys FOR TESTING.
    METHODS invalid_states FOR TESTING.
    METHODS missing_registration FOR TESTING.
    METHODS authorization_refused FOR TESTING.
    METHODS current_user_isolated FOR TESTING RAISING zcx_abapgit_exception.
    METHODS persistence_failure FOR TESTING.
    METHODS unrelated_favorites_retained FOR TESTING RAISING zcx_abapgit_exception.
    METHODS rejected IMPORTING iv_key TYPE string DEFAULT `42` iv_state TYPE string DEFAULT `X`.
ENDCLASS.

CLASS ltcl_favorite_mutation IMPLEMENTATION.
  METHOD setup.
    TEST-INJECTION favorite_authorization.
      IF ltcl_favorite_mutation=>mv_authorized = abap_false.
        zcx_abapgit_exception=>raise( `Not authorized` ).
      ENDIF.
    END-TEST-INJECTION.
    TEST-INJECTION favorite_registration.
      IF ltcl_favorite_mutation=>mv_exists = abap_false.
        zcx_abapgit_exception=>raise( `Repository no longer registered` ).
      ENDIF.
    END-TEST-INJECTION.
    mv_exists = abap_true.
    mv_authorized = abap_true.
    mo_user = NEW #( ).
    mi_original = zcl_abapgit_persist_factory=>get_user( ).
    zcl_abapgit_persist_injector=>set_current_user( mo_user ).
    mi_service = NEW zcl_ag2ui5_repo_service( ).
  ENDMETHOD.
  METHOD teardown.
    zcl_abapgit_persist_injector=>set_current_user( mi_original ).
  ENDMETHOD.
  METHOD rejected.
    TRY.
        mi_service->set_favorite( iv_key = iv_key iv_favorite = iv_state ).
        cl_abap_unit_assert=>fail( `Favorite request should be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( exp = 0 act = mo_user->mv_writes ).
  ENDMETHOD.
  METHOD set_and_remove.
    cl_abap_unit_assert=>assert_true( mi_service->set_favorite( iv_key = `42` iv_favorite = `X` ) ).
    cl_abap_unit_assert=>assert_false( mi_service->set_favorite( iv_key = `42` iv_favorite = ` ` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = mo_user->mv_writes ).
  ENDMETHOD.
  METHOD repeated_set_is_noop.
    mi_service->set_favorite( iv_key = `42` iv_favorite = `` ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = mo_user->mv_writes ).
    mi_service->set_favorite( iv_key = `42` iv_favorite = `X` ).
    mi_service->set_favorite( iv_key = `42` iv_favorite = `X` ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = mo_user->mv_writes ).
  ENDMETHOD.
  METHOD malformed_keys.
    rejected( iv_key = `` ).
    rejected( iv_key = `bad` ).
    rejected( iv_key = `42 ` ).
    rejected( iv_key = `000000000042extra` ).
    rejected( iv_key = `0000000000042` ).
  ENDMETHOD.
  METHOD invalid_states.
    rejected( iv_state = `true` ).
    rejected( iv_state = `false` ).
    rejected( iv_state = `XX` ).
    rejected( iv_state = `Xextra` ).
  ENDMETHOD.
  METHOD missing_registration.
    mv_exists = abap_false.
    rejected( ).
  ENDMETHOD.
  METHOD authorization_refused.
    mv_authorized = abap_false.
    rejected( ).
  ENDMETHOD.
  METHOD current_user_isolated.
    mi_service->set_favorite( iv_key = `42` iv_favorite = `X` ).
    DATA(lo_other) = NEW ltd_favorite_user( ).
    zcl_abapgit_persist_injector=>set_current_user( lo_other ).
    cl_abap_unit_assert=>assert_false( mi_service->set_favorite( iv_key = `42` iv_favorite = `` ) ).
    cl_abap_unit_assert=>assert_equals( exp = 0 act = lo_other->mv_writes ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_user->mt_favorites ) ).
  ENDMETHOD.
  METHOD persistence_failure.
    mo_user->mv_fail = abap_true.
    rejected( ).
    cl_abap_unit_assert=>assert_initial( mo_user->mt_favorites ).
  ENDMETHOD.
  METHOD unrelated_favorites_retained.
    INSERT CONV #( `7` ) INTO TABLE mo_user->mt_favorites.
    mi_service->set_favorite( iv_key = `42` iv_favorite = `X` ).
    mi_service->set_favorite( iv_key = `42` iv_favorite = `` ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( mo_user->mt_favorites ) ).
    cl_abap_unit_assert=>assert_equals( exp = `7` act = mo_user->mt_favorites[ 1 ] ).
  ENDMETHOD.
ENDCLASS.


"! abapGit's repository service: counts resets, asks for credentials on request
CLASS ltd_repo_srv DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo_srv PARTIALLY IMPLEMENTED.
    DATA mv_inits TYPE i.
    DATA mv_url_error TYPE string.
ENDCLASS.

CLASS ltd_repo_srv IMPLEMENTATION.
  METHOD zif_abapgit_repo_srv~init.
    mv_inits = mv_inits + 1.
  ENDMETHOD.
  METHOD zif_abapgit_repo_srv~validate_url.
    IF mv_url_error IS NOT INITIAL.
      zcx_abapgit_exception=>raise( mv_url_error ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

"! The session login: abapGit's error, the inputs, the expiry
CLASS ltcl_login DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    CONSTANTS c_url TYPE string VALUE `https://example.invalid/r.git`.
    METHODS setup.
    METHODS teardown.
    METHODS login_required_text FOR TESTING.
    METHODS url_host_cases FOR TESTING.
    METHODS login_refuses_empty FOR TESTING RAISING zcx_abapgit_exception.
    METHODS login_refuses_control_chars FOR TESTING RAISING zcx_abapgit_exception.
    METHODS login_sets_credentials FOR TESTING RAISING zcx_abapgit_exception.
    METHODS expiry_keeps FOR TESTING RAISING zcx_abapgit_exception.
    METHODS expiry_clears FOR TESTING RAISING zcx_abapgit_exception.
    METHODS logoff_clears FOR TESTING RAISING zcx_abapgit_exception.
    METHODS login_required_variants FOR TESTING.
    METHODS request_start_resets_cache FOR TESTING RAISING zcx_abapgit_exception.
    METHODS proxy_error_no_login FOR TESTING.
    METHODS login_refuses_url_controls FOR TESTING RAISING zcx_abapgit_exception.
    METHODS new_repo_login_raises FOR TESTING.
    "! Test values only - the login manager keeps them in this session's memory
    METHODS fixture
      RAISING
        zcx_abapgit_exception.
    METHODS refused
      IMPORTING
        iv_user  TYPE string
        iv_token TYPE string
        iv_url   TYPE string DEFAULT c_url
      RAISING
        zcx_abapgit_exception.
ENDCLASS.

CLASS ltcl_login IMPLEMENTATION.
  METHOD setup.
    zcl_abapgit_login_manager=>clear( ).
    CLEAR: zcl_ag2ui5_repo_service=>gv_last_use, zcl_ag2ui5_repo_service=>gv_now.
  ENDMETHOD.

  METHOD teardown.
    zcl_abapgit_login_manager=>clear( ).
    CLEAR: zcl_ag2ui5_repo_service=>gv_last_use, zcl_ag2ui5_repo_service=>gv_now.
    zcl_abapgit_repo_srv=>inject_instance( VALUE #( ) ).
  ENDMETHOD.

  METHOD login_required_variants.
    " rejected credentials come back as HTTP 401; newer abapGit raises its own class
    TRY.
        zcx_abapgit_exception=>raise( `Unauthorized access to resource (HTTP 401). Check your credentials` ).
      CATCH zcx_abapgit_exception INTO DATA(lx_401).
    ENDTRY.
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>login_required( lx_401 ) ).
    " created by name: older abapGit versions have no such class
    DATA lx_required TYPE REF TO zcx_abapgit_exception.
    TRY.
        CREATE OBJECT lx_required TYPE ('ZCX_ABAPGIT_AUTH_REQUIRED') EXPORTING iv_url = c_url.
      CATCH cx_sy_create_object_error.
        RETURN.
    ENDTRY.
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>login_required( lx_required ) ).
  ENDMETHOD.

  METHOD request_start_resets_cache.
    " a stateful session keeps abapGit's repository list: each request reads it
    " fresh once, and not again in the middle of an operation (an offline
    " repository carries its ZIP on its instance)
    DATA(lo_srv) = NEW ltd_repo_srv( ).
    zcl_abapgit_repo_srv=>inject_instance( lo_srv ).
    NEW zcl_ag2ui5_repo_service( )->assert_authorized( ).
    cl_abap_unit_assert=>assert_equals( act = lo_srv->mv_inits exp = 0 ).
    zcl_ag2ui5_repo_service=>request_start( ).
    cl_abap_unit_assert=>assert_equals( act = lo_srv->mv_inits exp = 1 ).
  ENDMETHOD.

  METHOD proxy_error_no_login.
    " a proxy wants credentials: a Git login cannot help
    TRY.
        zcx_abapgit_exception=>raise( `Proxy authentication required (HTTP 407). Check your credentials` ).
      CATCH zcx_abapgit_exception INTO DATA(lx_407).
    ENDTRY.
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>login_required( lx_407 ) ).
  ENDMETHOD.

  METHOD login_refuses_url_controls.
    refused( iv_user = `u` iv_token = `t` iv_url = |https://example.invalid/a{ cl_abap_char_utilities=>horizontal_tab }/r.git| ).
  ENDMETHOD.

  METHOD new_repo_login_raises.
    " a private repository: the app opens the login page instead of a URL error
    DATA(lo_srv) = NEW ltd_repo_srv( ).
    lo_srv->mv_url_error = `Unauthorized access. Check your credentials`.
    zcl_abapgit_repo_srv=>inject_instance( lo_srv ).
    DATA lt_errors TYPE zif_ag2ui5_repo_service=>ty_field_errors.
    TRY.
        NEW zcl_ag2ui5_repo_service( )->check_new_repo(
          EXPORTING is_repo   = VALUE #( kind = zif_ag2ui5_repo_service=>c_repo_kind-online url = c_url package = `$X` )
          CHANGING  ct_errors = lt_errors ).
        cl_abap_unit_assert=>fail( `Login required must leave check_new_repo` ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>login_required( lx_error ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD fixture.
    zcl_abapgit_login_manager=>set_basic( iv_uri = c_url iv_username = `u` iv_password = `p` ).
  ENDMETHOD.

  METHOD login_required_text.
    TRY.
        zcx_abapgit_exception=>raise( `Unauthorized access. Check your credentials` ).
      CATCH zcx_abapgit_exception INTO DATA(lx_auth).
    ENDTRY.
    TRY.
        zcx_abapgit_exception=>raise( `HTTP 401 Unauthorized` ).
      CATCH zcx_abapgit_exception INTO DATA(lx_other).
    ENDTRY.
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>login_required( lx_auth ) ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>login_required( lx_other ) ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>login_required( VALUE #( ) ) ).
  ENDMETHOD.

  METHOD url_host_cases.
    cl_abap_unit_assert=>assert_equals( exp = `github.com`
      act = zcl_ag2ui5_repo_service=>url_host( `https://github.com/a/b.git` ) ).
    cl_abap_unit_assert=>assert_equals( exp = `git.example.com:8443`
      act = zcl_ag2ui5_repo_service=>url_host( `https://git.example.com:8443/x` ) ).
    cl_abap_unit_assert=>assert_initial( zcl_ag2ui5_repo_service=>url_host( `` ) ).
  ENDMETHOD.

  METHOD refused.
    TRY.
        NEW zcl_ag2ui5_repo_service( )->zif_ag2ui5_repo_service~login(
          iv_url = iv_url iv_user = iv_user iv_token = iv_token ).
        cl_abap_unit_assert=>fail( |Login with "{ iv_user }" must be refused| ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_login_manager=>get( c_url ) ).
  ENDMETHOD.

  METHOD login_refuses_empty.
    refused( iv_user = `` iv_token = `t` ).
    refused( iv_user = `u` iv_token = `` ).
    refused( iv_user = `u` iv_token = `t` iv_url = `` ).
  ENDMETHOD.

  METHOD login_refuses_control_chars.
    refused( iv_user = |u{ cl_abap_char_utilities=>newline }x| iv_token = `t` ).
    refused( iv_user = `u` iv_token = |t{ cl_abap_char_utilities=>horizontal_tab }| ).
  ENDMETHOD.

  METHOD login_sets_credentials.
    NEW zcl_ag2ui5_repo_service( )->zif_ag2ui5_repo_service~login( iv_url = c_url iv_user = `u` iv_token = `p` ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_login_manager=>get( c_url ) ).
  ENDMETHOD.

  METHOD expiry_keeps.
    fixture( ).
    GET TIME STAMP FIELD zcl_ag2ui5_repo_service=>gv_now.
    zcl_ag2ui5_repo_service=>gv_last_use = cl_abap_tstmp=>subtractsecs( tstmp = zcl_ag2ui5_repo_service=>gv_now secs = 1799 ).
    NEW zcl_ag2ui5_repo_service( )->assert_authorized( ).
    cl_abap_unit_assert=>assert_not_initial( zcl_abapgit_login_manager=>get( c_url ) ).
  ENDMETHOD.

  METHOD expiry_clears.
    fixture( ).
    GET TIME STAMP FIELD zcl_ag2ui5_repo_service=>gv_now.
    zcl_ag2ui5_repo_service=>gv_last_use = cl_abap_tstmp=>subtractsecs( tstmp = zcl_ag2ui5_repo_service=>gv_now secs = 1801 ).
    NEW zcl_ag2ui5_repo_service( )->assert_authorized( ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_login_manager=>get( c_url ) ).
  ENDMETHOD.

  METHOD logoff_clears.
    fixture( ).
    NEW zcl_ag2ui5_repo_service( )->zif_ag2ui5_repo_service~logoff( ).
    cl_abap_unit_assert=>assert_initial( zcl_abapgit_login_manager=>get( c_url ) ).
  ENDMETHOD.
ENDCLASS.


"! Who changed an object: the owner of its first transport request, as abapGit shows it
CLASS ltcl_changed_by DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS first_owner_wins FOR TESTING.
    METHODS other_objects_ignored FOR TESTING.
    METHODS no_transport_unknown FOR TESTING.
    METHODS empty_owner_unknown FOR TESTING.
    METHODS local_user_wins FOR TESTING.
    METHODS git_only_file_owner FOR TESTING.
    METHODS empty_local_user_unknown FOR TESTING.
    METHODS deleted_in_sap_only_in_git FOR TESTING.
    METHODS added_in_git_only_in_git FOR TESTING.
    METHODS local_file_in_sap FOR TESTING.
ENDCLASS.

CLASS ltcl_changed_by IMPLEMENTATION.

  METHOD first_owner_wins.
    DATA(lt_owners) = VALUE zcl_ag2ui5_repo_service=>ty_object_owners(
      ( obj_type = `CLAS` obj_name = `ZCL_A` trkorr = `A4HK900001` as4user = `ALICE` )
      ( obj_type = `CLAS` obj_name = `ZCL_A` trkorr = `A4HK900002` as4user = `BOB` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>owner_of( it_owners = lt_owners iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` )
      exp = `ALICE` ).
  ENDMETHOD.

  METHOD other_objects_ignored.
    DATA(lt_owners) = VALUE zcl_ag2ui5_repo_service=>ty_object_owners(
      ( obj_type = `CLAS` obj_name = `ZCL_B` trkorr = `A4HK900003` as4user = `CAROL` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>owner_of( it_owners = lt_owners iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` )
      exp = `UNKNOWN` ).
  ENDMETHOD.

  METHOD no_transport_unknown.
    " local objects and packages without change recording have no transport
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>owner_of( it_owners = VALUE #( ) iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` )
      exp = `UNKNOWN` ).
  ENDMETHOD.

  METHOD empty_owner_unknown.
    DATA(lt_owners) = VALUE zcl_ag2ui5_repo_service=>ty_object_owners(
      ( obj_type = `CLAS` obj_name = `ZCL_A` trkorr = `A4HK900004` as4user = `` ) ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ag2ui5_repo_service=>owner_of( it_owners = lt_owners iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` )
      exp = `UNKNOWN` ).
  ENDMETHOD.

  METHOD local_user_wins.
    " a file in SAP: who changed the object last, not the transport owner
    DATA(lt_items) = VALUE zif_ag2ui5_repo_service=>ty_stage_items(
      ( path = `/src/` filename = `zcl_a.clas.abap` obj_type = `CLAS` obj_name = `ZCL_A` lstate = `M` rstate = `M` ) ).
    zcl_ag2ui5_repo_service=>assign_changed_by(
      EXPORTING it_local_users = VALUE #( ( path = `/src/` filename = `zcl_a.clas.abap` user = `BOB` ) )
                it_owners      = VALUE #( ( obj_type = `CLAS` obj_name = `ZCL_A` trkorr = `A4HK900001` as4user = `ALICE` ) )
      CHANGING  ct_items       = lt_items ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-changed_by exp = `BOB` ).
  ENDMETHOD.

  METHOD git_only_file_owner.
    " deleted in SAP, only in Git: the owner of the first request that holds it
    DATA(lt_items) = VALUE zif_ag2ui5_repo_service=>ty_stage_items(
      ( path = `/src/` filename = `zcl_a.clas.abap` obj_type = `CLAS` obj_name = `ZCL_A` lstate = `D` ) ).
    zcl_ag2ui5_repo_service=>assign_changed_by(
      EXPORTING it_local_users = VALUE #( )
                it_owners      = VALUE #( ( obj_type = `CLAS` obj_name = `ZCL_A` trkorr = `A4HK900001` as4user = `ALICE` ) )
      CHANGING  ct_items       = lt_items ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-changed_by exp = `ALICE` ).
  ENDMETHOD.

  METHOD empty_local_user_unknown.
    " every row gets a name, so the Stage filter can offer it
    DATA(lt_items) = VALUE zif_ag2ui5_repo_service=>ty_stage_items(
      ( path = `/` filename = `.abapgit.xml` lstate = `M` ) ).
    zcl_ag2ui5_repo_service=>assign_changed_by(
      EXPORTING it_local_users = VALUE #( ( path = `/` filename = `.abapgit.xml` user = `` ) )
                it_owners      = VALUE #( )
      CHANGING  ct_items       = lt_items ).
    cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-changed_by exp = `UNKNOWN` ).
  ENDMETHOD.

  METHOD deleted_in_sap_only_in_git.
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>only_in_git( iv_lstate = `D` iv_rstate = `` ) ).
  ENDMETHOD.

  METHOD added_in_git_only_in_git.
    " new in Git, never pulled: abapGit gives it no local state
    cl_abap_unit_assert=>assert_true( zcl_ag2ui5_repo_service=>only_in_git( iv_lstate = `` iv_rstate = `A` ) ).
  ENDMETHOD.

  METHOD local_file_in_sap.
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>only_in_git( iv_lstate = `M` iv_rstate = `M` ) ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>only_in_git( iv_lstate = `A` iv_rstate = `` ) ).
    cl_abap_unit_assert=>assert_false( zcl_ag2ui5_repo_service=>only_in_git( iv_lstate = `` iv_rstate = `M` ) ).
  ENDMETHOD.

ENDCLASS.

CLASS ltcl_create_tags DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS valid_tags FOR TESTING RAISING zcx_abapgit_exception.
    METHODS invalid_names FOR TESTING.
    METHODS annotation_identity FOR TESTING.
    METHODS duplicate_and_stale FOR TESTING.
    METHODS checked IMPORTING is_tag TYPE zif_ag2ui5_repo_service=>ty_new_tag
      RETURNING VALUE(rs_tag) TYPE zif_abapgit_git_definitions=>ty_git_tag RAISING zcx_abapgit_exception.
ENDCLASS.
CLASS ltcl_create_tags IMPLEMENTATION.
  METHOD checked.
    rs_tag = zcl_ag2ui5_repo_service=>checked_new_tag( is_tag = is_tag it_tags = VALUE #( )
      is_expected = VALUE #( ref = `refs/heads/main` sha1 = `1234` )
      is_actual = VALUE #( ref = `refs/heads/main` sha1 = `1234` ) ).
  ENDMETHOD.
  METHOD valid_tags.
    DATA(ls_light) = checked( VALUE #( name = `release/v1.0.0` kind = `LIGHTWEIGHT` ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_light-name exp = `refs/tags/release/v1.0.0` ).
    cl_abap_unit_assert=>assert_equals( act = ls_light-sha1 exp = `1234` ).
    cl_abap_unit_assert=>assert_equals( act = ls_light-type exp = zif_abapgit_git_definitions=>c_git_branch_type-lightweight_tag ).
    DATA(ls_annotated) = checked( VALUE #( name = `refs/tags/v2` kind = `ANNOTATED` message = `Release`
      tagger_name = `Alice` tagger_email = `alice@example.com` ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_annotated-message exp = `Release` ).
    cl_abap_unit_assert=>assert_equals( act = ls_annotated-type exp = zif_abapgit_git_definitions=>c_git_branch_type-annotated_tag ).
  ENDMETHOD.
  METHOD invalid_names.
    LOOP AT VALUE string_table( ( `` ) ( `a b` ) ( `a..b` ) ( `a/.b` ) ( `a.lock/b` ) ( `a//b` )
      ( `.hidden` ) ( `a/` ) ( `a.` ) ( `a~b` ) ( `a^b` ) ( `a:b` ) ( `a?b` ) ( `a*b` )
      ( `a[b` ) ( `a\b` ) ( `@` ) ( `a@{b` ) ( `refs/heads/x` ) ( |a{ cl_abap_char_utilities=>newline }b| ) ) INTO DATA(lv_name).
      TRY.
          checked( VALUE #( name = lv_name kind = `LIGHTWEIGHT` ) ).
          cl_abap_unit_assert=>fail( |Invalid tag accepted: { lv_name }| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.
  METHOD annotation_identity.
    DATA(ls_tag) = VALUE zif_ag2ui5_repo_service=>ty_new_tag( name = `v1` kind = `ANNOTATED` message = `Release`
      tagger_name = `Alice` tagger_email = `alice@example.com` ).
    DO 7 TIMES.
      DATA(ls_invalid) = ls_tag.
      CASE sy-index.
        WHEN 1. CLEAR ls_invalid-message.
        WHEN 2. CLEAR ls_invalid-tagger_name.
        WHEN 3. ls_invalid-tagger_email = `bad`.
        WHEN 4. ls_invalid-tagger_name = `A <B>`.
        WHEN 5. ls_invalid-tagger_email = |a@b{ cl_abap_char_utilities=>newline }|.
        WHEN 6. ls_invalid-tagger_name = |A{ cl_abap_char_utilities=>newline }|.
        WHEN 7. ls_invalid-kind = `FORGED`.
      ENDCASE.
      TRY.
          checked( ls_invalid ).
          cl_abap_unit_assert=>fail( |Invalid annotation accepted: { sy-index }| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDDO.
  ENDMETHOD.
  METHOD duplicate_and_stale.
    DO 5 TIMES.
      DATA(ls_actual) = VALUE zif_ag2ui5_repo_service=>ty_tag_target( ref = `refs/heads/main` sha1 = `1234` ).
      DATA(ls_expected) = ls_actual.
      DATA lt_tags TYPE zif_ag2ui5_repo_service=>ty_tags.
      CLEAR lt_tags.
      CASE sy-index.
        WHEN 1. lt_tags = VALUE #( ( name = `refs/tags/v1` ) ).
        WHEN 2. ls_actual-sha1 = `5678`.
        WHEN 3. ls_actual-ref = `refs/heads/other`.
        WHEN 4. CLEAR ls_expected-sha1.
        WHEN 5. CLEAR ls_actual-sha1. " A tree/blob target has no verified commit.
      ENDCASE.
      TRY.
          zcl_ag2ui5_repo_service=>checked_new_tag( is_tag = VALUE #( name = `v1` kind = `LIGHTWEIGHT` )
            it_tags = lt_tags is_expected = ls_expected is_actual = ls_actual ).
          cl_abap_unit_assert=>fail( `Duplicate or stale tag target accepted` ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDDO.
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_delete_tags DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    METHODS valid_raw_refs FOR TESTING RAISING zcx_abapgit_exception.
    METHODS reject_unsafe FOR TESTING.
    METHODS reannotation_is_changed FOR TESTING.
ENDCLASS.
CLASS ltcl_delete_tags IMPLEMENTATION.
  METHOD valid_raw_refs.
    DATA(lt_tags) = VALUE zif_ag2ui5_repo_service=>ty_tags(
      ( name = `refs/tags/light` sha1 = `commit` ref_sha1 = `commit` )
      ( name = `refs/tags/annotated` sha1 = `commit` ref_sha1 = `tagobject` )
      ( name = `refs/tags/unresolved` ref_sha1 = `otherobject` ) ).
    LOOP AT lt_tags INTO DATA(ls_tag).
      zcl_ag2ui5_repo_service=>assert_deletable_tag( iv_tag = ls_tag-name iv_ref_sha1 = ls_tag-ref_sha1 it_tags = lt_tags ).
    ENDLOOP.
  ENDMETHOD.
  METHOD reject_unsafe.
    DO 7 TIMES.
      DATA(lv_tag) = `refs/tags/v1`.
      DATA(lv_sha1) = `tagobject`.
      DATA(lt_tags) = VALUE zif_ag2ui5_repo_service=>ty_tags( ( name = lv_tag ref_sha1 = lv_sha1 ) ).
      CASE sy-index.
        WHEN 1. lv_tag = `refs/heads/v1`.
        WHEN 2. lv_tag = `refs/tags/v1^{}`.
        WHEN 3. lv_tag = `refs/tags/missing`.
        WHEN 4. CLEAR lv_sha1.
        WHEN 5. lt_tags[ 1 ]-current = abap_true.
        WHEN 6. lt_tags[ 1 ]-ref_sha1 = `moved`.
        WHEN 7. CLEAR lt_tags[ 1 ]-ref_sha1.
      ENDCASE.
      TRY.
          zcl_ag2ui5_repo_service=>assert_deletable_tag( iv_tag = lv_tag iv_ref_sha1 = lv_sha1 it_tags = lt_tags ).
          cl_abap_unit_assert=>fail( |Unsafe deletion accepted: { sy-index }| ).
        CATCH zcx_abapgit_exception ##NO_HANDLER.
      ENDTRY.
    ENDDO.
  ENDMETHOD.
  METHOD reannotation_is_changed.
    TRY.
        zcl_ag2ui5_repo_service=>assert_deletable_tag( iv_tag = `refs/tags/v1` iv_ref_sha1 = `oldtagobject`
          it_tags = VALUE #( ( name = `refs/tags/v1` sha1 = `samecommit` ref_sha1 = `newtagobject` ) ) ).
        cl_abap_unit_assert=>fail( `Changed annotation at the same commit must be refused` ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
