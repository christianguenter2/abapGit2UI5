"! Reads single Git objects by hash, without fetching the whole repository
INTERFACE zif_ag2ui5_blob_source
  PUBLIC.

  "! The objects the Git server sends for one wanted hash
  METHODS fetch
    IMPORTING
      iv_url            TYPE string
      iv_sha1           TYPE zif_abapgit_git_definitions=>ty_sha1
    RETURNING
      VALUE(rt_objects) TYPE zif_abapgit_definitions=>ty_objects_tt
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
