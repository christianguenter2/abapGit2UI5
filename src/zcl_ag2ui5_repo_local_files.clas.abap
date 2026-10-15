"! A repository whose local files were serialized beforehand (by a
"! background Status run); every other call goes to the repository itself.
"! zcl_abapgit_repo_status=>calculate( ) reads local files only through
"! zif_abapgit_repo, so it can be handed this wrapper
CLASS zcl_ag2ui5_repo_local_files DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_repo.

    METHODS constructor
      IMPORTING
        ii_repo  TYPE REF TO zif_abapgit_repo
        it_files TYPE zif_abapgit_definitions=>ty_files_item_tt.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mi_repo TYPE REF TO zif_abapgit_repo.
    DATA mt_files TYPE zif_abapgit_definitions=>ty_files_item_tt.
ENDCLASS.



CLASS zcl_ag2ui5_repo_local_files IMPLEMENTATION.

  METHOD constructor.
    mi_repo = ii_repo.
    mt_files = it_files.
    zif_abapgit_repo~ms_data = ii_repo->ms_data.
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_key.
    rv_key = mi_repo->get_key( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_name.
    rv_name = mi_repo->get_name( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~is_offline.
    rv_offline = mi_repo->is_offline( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_package.
    rv_package = mi_repo->get_package( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_local_settings.
    rs_settings = mi_repo->get_local_settings( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_tadir_objects.
    rt_tadir = mi_repo->get_tadir_objects( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_files_local_filtered.
    " get_status uses no object filter: abapGit serializes as usual
    rt_files = mi_repo->get_files_local_filtered( ii_obj_filter = ii_obj_filter
                                                 ii_log        = ii_log ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_files_local.
    rt_files = mt_files.
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_files_remote.
    rt_files = mi_repo->get_files_remote( ii_obj_filter   = ii_obj_filter
                                         iv_ignore_files = iv_ignore_files ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~refresh.
    mi_repo->refresh( iv_drop_cache = iv_drop_cache
                     iv_drop_log   = iv_drop_log ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_dot_abapgit.
    ro_dot_abapgit = mi_repo->get_dot_abapgit( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~set_dot_abapgit.
    mi_repo->set_dot_abapgit( io_dot_abapgit ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~find_remote_dot_abapgit.
    ro_dot = mi_repo->find_remote_dot_abapgit( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~deserialize.
    mi_repo->deserialize( is_checks = is_checks
                         ii_log    = ii_log ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~deserialize_checks.
    rs_checks = mi_repo->deserialize_checks( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~checksums.
    ri_checksums = mi_repo->checksums( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~has_remote_source.
    rv_yes = mi_repo->has_remote_source( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_log.
    ri_log = mi_repo->get_log( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~create_new_log.
    ri_log = mi_repo->create_new_log( iv_title ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_dot_apack.
    ro_dot_apack = mi_repo->get_dot_apack( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~delete_checks.
    rs_checks = mi_repo->delete_checks( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~set_files_remote.
    mi_repo->set_files_remote( it_files ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~set_local_settings.
    mi_repo->set_local_settings( is_settings ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~switch_repo_type.
    mi_repo->switch_repo_type( iv_offline ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~refresh_local_object.
    mi_repo->refresh_local_object( iv_obj_type = iv_obj_type
                                  iv_obj_name = iv_obj_name ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~refresh_local_objects.
    mi_repo->refresh_local_objects( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_data_config.
    ri_config = mi_repo->get_data_config( ).
  ENDMETHOD.

  METHOD zif_abapgit_repo~bind_listener.
    mi_repo->bind_listener( ii_listener ).
  ENDMETHOD.

ENDCLASS.
