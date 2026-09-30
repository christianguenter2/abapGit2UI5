"! The one unit that talks to abapGit. Everything it returns is plain data -
"! never a reference to an abapGit object - so an app can keep it in its
"! attributes, which abap2UI5 serializes on every round trip.
INTERFACE zif_ag2ui5_repo_service PUBLIC.

  TYPES ty_outcome TYPE string.

  CONSTANTS:
    BEGIN OF c_outcome,
      "! Local and remote match - there is nothing to import
      nothing TYPE ty_outcome VALUE `NOTHING`,
      "! No rule blocks - the pull may import
      ready   TYPE ty_outcome VALUE `READY`,
      "! At least one rule blocks - nothing was imported
      blocked TYPE ty_outcome VALUE `BLOCKED`,
      "! Imported, the log has no errors
      pulled  TYPE ty_outcome VALUE `PULLED`,
      "! Imported, the log has errors
      failed  TYPE ty_outcome VALUE `FAILED`,
      "! The remote changed between preview and pull - nothing was imported
      changed TYPE ty_outcome VALUE `CHANGED`,
    END OF c_outcome.

  TYPES ty_group TYPE string.

  "! The groups of the decision dialog, most dangerous first
  CONSTANTS:
    BEGIN OF c_group,
      data_loss TYPE ty_group VALUE `DATA_LOSS`,
      delete    TYPE ty_group VALUE `DELETE`,
      overwrite TYPE ty_group VALUE `OVERWRITE`,
      package   TYPE ty_group VALUE `PACKAGE`,
      import    TYPE ty_group VALUE `IMPORT`,
      skipped   TYPE ty_group VALUE `SKIPPED`,
    END OF c_group.

  TYPES:
    BEGIN OF ty_repo,
      key             TYPE string,
      name            TYPE string,
      package         TYPE string,
      url             TYPE string,
      branch          TYPE string,
      deserialized_at TYPE string,
      offline         TYPE abap_bool,
    END OF ty_repo,
    ty_repos TYPE STANDARD TABLE OF ty_repo WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_status_row,
      obj_type TYPE string,
      obj_name TYPE string,
      path     TYPE string,
      filename TYPE string,
      lstate   TYPE string,
      rstate   TYPE string,
      inactive TYPE abap_bool,
    END OF ty_status_row,
    ty_status_rows TYPE STANDARD TABLE OF ty_status_row WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_status,
      key           TYPE string,
      name          TYPE string,
      package       TYPE string,
      url           TYPE string,
      branch        TYPE string,
      remote_commit TYPE string,
      rows          TYPE ty_status_rows,
    END OF ty_status.

  TYPES:
    BEGIN OF ty_message,
      type     TYPE string,
      text     TYPE string,
      obj_type TYPE string,
      obj_name TYPE string,
    END OF ty_message,
    ty_messages TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

  TYPES:
    "! One object in the decision dialog
    BEGIN OF ty_decision_item,
      obj_type   TYPE string,
      obj_name   TYPE string,
      group      TYPE ty_group,
      reason     TYPE string,
      selected   TYPE abap_bool,
      selectable TYPE abap_bool,
    END OF ty_decision_item,
    ty_decision_items TYPE STANDARD TABLE OF ty_decision_item WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_preview,
      outcome  TYPE ty_outcome,
      items    TYPE ty_decision_items,
      "! Set when requirements or APACK dependencies are not met - the pull
      "! then needs an explicit acknowledgement
      ack_text TYPE string,
      "! Why the pull is blocked, when it is
      blocked  TYPE string,
      "! Request type (trfunction) of the transport the pull needs - empty
      "! for local packages
      transport_type   TYPE string,
      "! The same for customizing (table contents)
      customizing_type TYPE string,
      "! A request abapGit already determined (repository setting or user
      "! exit) - used as is, the dialog then offers no choice
      transport_preset   TYPE string,
      customizing_preset TYPE string,
    END OF ty_preview.

  TYPES:
    BEGIN OF ty_transport,
      trkorr TYPE string,
      text   TYPE string,
    END OF ty_transport,
    ty_transports TYPE STANDARD TABLE OF ty_transport WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_pull_result,
      outcome  TYPE ty_outcome,
      messages TYPE ty_messages,
    END OF ty_pull_result.

  METHODS list_repos
    RETURNING
      VALUE(rt_repos) TYPE ty_repos
    RAISING
      zcx_abapgit_exception.

  "! Fetches the remote again and compares it with the system
  METHODS get_status
    IMPORTING
      iv_key           TYPE string
    RETURNING
      VALUE(rs_status) TYPE ty_status
    RAISING
      zcx_abapgit_exception.

  "! What a pull would do - imports nothing. Preselected are the changes that
  "! lose nothing local (abapGit itself preselects only additions)
  METHODS preview_pull
    IMPORTING
      iv_key            TYPE string
    RETURNING
      VALUE(rs_preview) TYPE ty_preview
    RAISING
      zcx_abapgit_exception.

  "! Pulls with the decisions of a preview. Checks again first: when anything
  "! differs from the preview (a new object, an object in another group, a
  "! ticked object that is gone) the outcome is changed and nothing happens
  METHODS pull
    IMPORTING
      iv_key           TYPE string
      it_items         TYPE ty_decision_items
      iv_acknowledged  TYPE abap_bool DEFAULT abap_false
      "! Required when the preview names a transport_type
      iv_transport     TYPE string OPTIONAL
      "! Required when the preview names a customizing_type
      iv_customizing   TYPE string OPTIONAL
    RETURNING
      VALUE(rs_result) TYPE ty_pull_result
    RAISING
      zcx_abapgit_exception.

  "! The current user's modifiable requests of that type (trfunction)
  METHODS list_transports
    IMPORTING
      iv_type              TYPE string
    RETURNING
      VALUE(rt_transports) TYPE ty_transports
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
