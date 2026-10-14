"! Fetches one object with abapGit's upload-pack request (want and the hash).
"! Smart HTTP servers (GitHub, GitLab, Bitbucket, Forgejo, plain Git) answer
"! it for any object they hold; others refuse and the caller falls back
CLASS zcl_ag2ui5_blob_source DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_blob_source.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_blob_source IMPLEMENTATION.

  METHOD zif_ag2ui5_blob_source~fetch.

    zcl_abapgit_git_transport=>upload_pack_by_commit(
      EXPORTING iv_url     = iv_url
                iv_hash    = iv_sha1
      IMPORTING et_objects = rt_objects ).

  ENDMETHOD.

ENDCLASS.
