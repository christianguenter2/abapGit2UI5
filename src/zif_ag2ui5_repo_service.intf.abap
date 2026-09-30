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
    END OF ty_preview.

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

  "! What a pull would do, with abapGit's defaults preselected - imports nothing
  METHODS preview_pull
    IMPORTING
      iv_key            TYPE string
    RETURNING
      VALUE(rs_preview) TYPE ty_preview
    RAISING
      zcx_abapgit_exception.

  "! Pulls with the decisions of a preview. Checks again first: an object the
  "! preview did not show ends in outcome changed, and nothing is imported
  METHODS pull
    IMPORTING
      iv_key           TYPE string
      it_items         TYPE ty_decision_items
      iv_acknowledged  TYPE abap_bool DEFAULT abap_false
    RETURNING
      VALUE(rs_result) TYPE ty_pull_result
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
