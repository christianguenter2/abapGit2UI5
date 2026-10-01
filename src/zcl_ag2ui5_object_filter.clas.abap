"! abapGit object filter for one object, so that one file's diff does not
"! serialize the whole repository (abapGit's own diff page does the same)
CLASS zcl_ag2ui5_object_filter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_object_filter.

    METHODS constructor
      IMPORTING
        is_item TYPE zif_abapgit_definitions=>ty_item.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mt_filter TYPE zif_abapgit_definitions=>ty_tadir_tt.
ENDCLASS.



CLASS zcl_ag2ui5_object_filter IMPLEMENTATION.

  METHOD constructor.
    INSERT VALUE #( object = is_item-obj_type obj_name = is_item-obj_name ) INTO TABLE mt_filter.
  ENDMETHOD.

  METHOD zif_abapgit_object_filter~get_filter.
    rt_filter = mt_filter.
  ENDMETHOD.

ENDCLASS.
