"! Creates an online or offline abapGit repository from a form
CLASS zcl_ag2ui5_app_new_repo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES z2ui5_if_app.

    TYPES:
      "! the error text per field of the form; empty: no error
      BEGIN OF ty_error_texts,
        url            TYPE string,
        branch         TYPE string,
        name           TYPE string,
        package        TYPE string,
        display_name   TYPE string,
        folder_logic   TYPE string,
        labels         TYPE string,
        abap_lang_vers TYPE string,
      END OF ty_error_texts.

    CLASS-METHODS create
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_new_repo.

    DATA ms_repo TYPE zif_ag2ui5_repo_service=>ty_new_repo.
    DATA ms_error_text TYPE ty_error_texts.
    "! an error that belongs to no field
    DATA mv_message TYPE string.

  PROTECTED SECTION.
    DATA client TYPE REF TO z2ui5_if_client.
    "! Set only by unit tests; the real service otherwise
    DATA mi_service TYPE REF TO zif_ag2ui5_repo_service.

    METHODS view_display.
    METHODS on_event.
    METHODS create_repo.
    METHODS show_errors
      IMPORTING
        it_errors TYPE zif_ag2ui5_repo_service=>ty_field_errors.
    METHODS service
      RETURNING
        VALUE(ri_service) TYPE REF TO zif_ag2ui5_repo_service.

  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_ag2ui5_app_new_repo IMPLEMENTATION.

  METHOD create.
    ro_app = NEW #( ).
  ENDMETHOD.

  METHOD z2ui5_if_app~main ##NEEDED.
  ENDMETHOD.

  METHOD view_display ##NEEDED.
  ENDMETHOD.

  METHOD on_event ##NEEDED.
  ENDMETHOD.

  METHOD create_repo ##NEEDED.
  ENDMETHOD.

  METHOD show_errors ##NEEDED.
  ENDMETHOD.

  METHOD service.
    ri_service = COND #( WHEN mi_service IS BOUND THEN mi_service ELSE NEW zcl_ag2ui5_repo_service( ) ).
  ENDMETHOD.

ENDCLASS.
