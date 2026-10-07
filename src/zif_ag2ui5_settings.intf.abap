"! Settings of the current user (toggles of the apps), stored on the server
INTERFACE zif_ag2ui5_settings
  PUBLIC.

  CONSTANTS:
    BEGIN OF c_key,
      repos_layout         TYPE string VALUE `REPOS_LAYOUT`,
      repos_favorites_only TYPE string VALUE `REPOS_FAVORITES_ONLY`,
      status_view          TYPE string VALUE `STATUS_VIEW`,
      status_overview      TYPE string VALUE `STATUS_OVERVIEW`,
      status_sort          TYPE string VALUE `STATUS_SORT`,
      status_changes_first TYPE string VALUE `STATUS_CHANGES_FIRST`,
      diff_layout          TYPE string VALUE `DIFF_LAYOUT`,
      diff_show_all        TYPE string VALUE `DIFF_SHOW_ALL`,
    END OF c_key.

  "! The stored value, or iv_default if none is stored or it is no longer allowed
  METHODS get
    IMPORTING
      iv_key          TYPE string
      iv_default      TYPE string
    RETURNING
      VALUE(rv_value) TYPE string.

  "! Stores the value; abap_false (and nothing stored) for an unknown key or a
  "! value that is not allowed
  METHODS set
    IMPORTING
      iv_key          TYPE string
      iv_value        TYPE string
    RETURNING
      VALUE(rv_saved) TYPE abap_bool.

ENDINTERFACE.
