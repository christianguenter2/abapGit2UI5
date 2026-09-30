"! abapGit's progress indicator calls SAPGUI_PROGRESS_INDICATOR, which has no
"! SAP GUI to talk to in an HTTP request. This one does nothing.
CLASS zcl_ag2ui5_progress_silent DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_progress.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_progress_silent IMPLEMENTATION.

  METHOD zif_abapgit_progress~show ##NEEDED.
  ENDMETHOD.

  METHOD zif_abapgit_progress~set_total ##NEEDED.
  ENDMETHOD.

  METHOD zif_abapgit_progress~off ##NEEDED.
  ENDMETHOD.

ENDCLASS.
