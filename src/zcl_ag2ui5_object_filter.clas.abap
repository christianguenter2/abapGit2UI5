"! abapGit object filter for one or a few objects, so that a diff or a commit
"! does not serialize the whole repository (abapGit's own pages do the same)
CLASS zcl_ag2ui5_object_filter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_abapgit_object_filter.

    "! One object (is_item) or several (it_items)
    METHODS constructor
      IMPORTING
        is_item  TYPE zif_abapgit_definitions=>ty_item OPTIONAL
        it_items TYPE zif_abapgit_definitions=>ty_items_tt OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA mt_filter TYPE zif_abapgit_definitions=>ty_tadir_tt.
ENDCLASS.



CLASS zcl_ag2ui5_object_filter IMPLEMENTATION.

  METHOD constructor.

    IF is_item IS NOT INITIAL.
      INSERT VALUE #( object = is_item-obj_type obj_name = is_item-obj_name ) INTO TABLE mt_filter.
    ENDIF.
    LOOP AT it_items INTO DATA(ls_item).
      INSERT VALUE #( object = ls_item-obj_type obj_name = ls_item-obj_name ) INTO TABLE mt_filter.
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_abapgit_object_filter~get_filter.
    rt_filter = mt_filter.
  ENDMETHOD.

ENDCLASS.
