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
    END OF c_outcome.

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
    "! One object (or one repository-wide condition, then without object)
    "! that blocks the pull or is only reported
    BEGIN OF ty_item,
      obj_type TYPE string,
      obj_name TYPE string,
      reason   TYPE string,
    END OF ty_item,
    ty_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_message,
      type     TYPE string,
      text     TYPE string,
      obj_type TYPE string,
      obj_name TYPE string,
    END OF ty_message,
    ty_messages TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_classification,
      outcome  TYPE ty_outcome,
      "! The checks with every decision filled in, ready for deserialize( )
      checks   TYPE zif_abapgit_definitions=>ty_deserialize_checks,
      blocking TYPE ty_items,
      info     TYPE ty_items,
    END OF ty_classification.

  TYPES:
    BEGIN OF ty_pull_result,
      outcome  TYPE ty_outcome,
      blocking TYPE ty_items,
      info     TYPE ty_items,
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

  "! Pulls in abort mode: imports only when no local change would be lost
  METHODS pull
    IMPORTING
      iv_key           TYPE string
    RETURNING
      VALUE(rs_result) TYPE ty_pull_result
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
