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
      "! The commit is in the remote
      pushed  TYPE ty_outcome VALUE `PUSHED`,
      "! The repository was created
      created TYPE ty_outcome VALUE `CREATED`,
      "! A check failed - nothing was created
      invalid TYPE ty_outcome VALUE `INVALID`,
      removed TYPE ty_outcome VALUE `REMOVED`,
      uninstalled TYPE ty_outcome VALUE `UNINSTALLED`,
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
    BEGIN OF ty_label,
      text TYPE string,
      color TYPE string,
    END OF ty_label,
    ty_labels TYPE STANDARD TABLE OF ty_label WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_repo,
      key             TYPE string,
      name            TYPE string,
      package         TYPE string,
      url             TYPE string,
      branch          TYPE string,
      branch_display  TYPE string,
      branch_link     TYPE string,
      deserialized_at TYPE string,
      offline         TYPE abap_bool,
      favorite        TYPE abap_bool,
      labels          TYPE ty_labels,
    END OF ty_repo,
    ty_repos TYPE STANDARD TABLE OF ty_repo WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_status_row,
      obj_type TYPE string,
      obj_name TYPE string,
      "! Local object in ADT; empty when unavailable
      object_link TYPE string,
      path     TYPE string,
      filename TYPE string,
      lstate   TYPE string,
      rstate   TYPE string,
      inactive TYPE abap_bool,
      "! Differs between system and Git, or is inactive
      changed  TYPE abap_bool,
      "! Who changed the object, see ty_stage_item-changed_by
      changed_by TYPE string,
      "! SHA1 of the file in Git; empty when it is not in Git or the
      "! repository is offline
      remote_sha1 TYPE string,
    END OF ty_status_row,
    ty_status_rows TYPE STANDARD TABLE OF ty_status_row WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_object_status,
      obj_type    TYPE string,
      obj_name    TYPE string,
      object_link TYPE string,
      lstate      TYPE string,
      rstate      TYPE string,
      inactive    TYPE abap_bool,
      changed     TYPE abap_bool,
      "! The owner of the object's first file that has one
      changed_by  TYPE string,
      file_count  TYPE i,
      changed_count TYPE i,
    END OF ty_object_status,
    ty_object_status_rows TYPE STANDARD TABLE OF ty_object_status WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_status,
      key           TYPE string,
      name          TYPE string,
      package       TYPE string,
      "! ADT link of the package; empty when ADT cannot map it
      package_link  TYPE string,
      url           TYPE string,
      branch        TYPE string,
      branch_display TYPE string,
      branch_link    TYPE string,
      remote_commit TYPE string,
      labels        TYPE ty_labels,
      offline       TYPE abap_bool,
      rows          TYPE ty_status_rows,
    END OF ty_status.

  "! States of a background Status run (ZAG2UI5_RUN)
  CONSTANTS:
    BEGIN OF c_run_state,
      running TYPE string VALUE `R`,
      done    TYPE string VALUE `D`,
      error   TYPE string VALUE `E`,
      "! No such run of this user and repository
      gone    TYPE string VALUE `G`,
    END OF c_run_state.

  TYPES:
    BEGIN OF ty_status_start,
      "! Empty: the task did not start; load synchronously
      run_id TYPE string,
      "! Status without rows and without remote commit
      head   TYPE ty_status,
    END OF ty_status_start.

  TYPES:
    BEGIN OF ty_run_state,
      state        TYPE string,
      done         TYPE i,
      total        TYPE i,
      message      TYPE string,
      "! Seconds since the row last changed
      idle_seconds TYPE i,
    END OF ty_run_state.

  TYPES:
    BEGIN OF ty_message,
      type     TYPE string,
      text     TYPE string,
      obj_type TYPE string,
      obj_name TYPE string,
    END OF ty_message,
    ty_messages TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_delete_object,
      obj_type TYPE string,
      obj_name TYPE string,
      package TYPE string,
    END OF ty_delete_object,
    ty_delete_objects TYPE STANDARD TABLE OF ty_delete_object WITH EMPTY KEY,
    BEGIN OF ty_delete_preview,
      key TYPE string,
      name TYPE string,
      package TYPE string,
      url TYPE string,
      offline TYPE abap_bool,
      action TYPE string,
      objects TYPE ty_delete_objects,
      transport_required TYPE abap_bool,
    END OF ty_delete_preview,
    BEGIN OF ty_delete_result,
      outcome TYPE ty_outcome,
      messages TYPE ty_messages,
    END OF ty_delete_result.

  METHODS preview_delete
    IMPORTING iv_key TYPE string iv_action TYPE string
    RETURNING VALUE(rs_preview) TYPE ty_delete_preview
    RAISING zcx_abapgit_exception.

  METHODS delete_repo
    IMPORTING is_preview TYPE ty_delete_preview
              iv_confirmation TYPE string OPTIONAL
              iv_transport TYPE string OPTIONAL
    RETURNING VALUE(rs_result) TYPE ty_delete_result
    RAISING zcx_abapgit_exception.

  TYPES:
    "! One object in the decision dialog
    BEGIN OF ty_decision_item,
      obj_type   TYPE string,
      obj_name   TYPE string,
      "! Local object in ADT; empty when unavailable
      object_link TYPE string,
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

  TYPES ty_line_kind TYPE string.

  CONSTANTS:
    BEGIN OF c_line_kind,
      same   TYPE ty_line_kind VALUE `SAME`,
      "! Only in this system
      local  TYPE ty_line_kind VALUE `LOCAL`,
      "! Only in Git
      remote TYPE ty_line_kind VALUE `REMOTE`,
      "! A run of unchanged lines that compact( ) left out
      gap    TYPE ty_line_kind VALUE `GAP`,
    END OF c_line_kind.

  TYPES:
    BEGIN OF ty_diff_line,
      local_num  TYPE string,
      remote_num TYPE string,
      text       TYPE string,
      kind       TYPE ty_line_kind,
      "! What a patch picks: N<new number> for an added line and for both
      "! halves of a changed one, O<old number> for a removed line; empty
      "! for unchanged lines and gaps
      patch_id   TYPE string,
    END OF ty_diff_line,
    ty_diff_lines TYPE STANDARD TABLE OF ty_diff_line WITH EMPTY KEY.

  TYPES:
    "! One row of the side-by-side view: the old version left, the new right
    BEGIN OF ty_sbs_row,
      old_num     TYPE string,
      old_text    TYPE string,
      old_changed TYPE abap_bool,
      new_num     TYPE string,
      new_text    TYPE string,
      new_changed TYPE abap_bool,
      gap         TYPE abap_bool,
    END OF ty_sbs_row,
    ty_sbs_rows TYPE STANDARD TABLE OF ty_sbs_row WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_semantic_change,
      id          TYPE string,
      owner       TYPE string,
      name        TYPE string,
      component   TYPE string,
      action      TYPE string,
      text        TYPE string,
      local_from  TYPE i,
      local_to    TYPE i,
      remote_from TYPE i,
      remote_to   TYPE i,
      path        TYPE string,
      filename    TYPE string,
    END OF ty_semantic_change,
    ty_semantic_changes TYPE STANDARD TABLE OF ty_semantic_change WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_semantic,
      changes TYPE ty_semantic_changes,
      note    TYPE string,
    END OF ty_semantic.

  TYPES:
    BEGIN OF ty_diff,
      "! The side that changed is "new": the remote when only Git changed,
      "! otherwise the system - as abapGit decides
      remote_is_new TYPE abap_bool,
      lines        TYPE ty_diff_lines,
      semantic     TYPE ty_semantic,
      "! Lines only in this system / only in Git
      local_count  TYPE i,
      remote_count TYPE i,
      binary       TYPE abap_bool,
      "! Identifies the two versions the lines were computed from; a patch
      "! is accepted only for the same fingerprint
      fingerprint  TYPE string,
    END OF ty_diff.

  TYPES ty_stage_action TYPE string.

  CONSTANTS:
    BEGIN OF c_stage_action,
      add TYPE ty_stage_action VALUE `ADD`,
      "! The file was deleted locally - it goes from the remote too
      rm  TYPE ty_stage_action VALUE `RM`,
    END OF c_stage_action.

  TYPES:
    BEGIN OF ty_stage_item,
      path     TYPE string,
      filename TYPE string,
      obj_type TYPE string,
      obj_name TYPE string,
      "! Local object in ADT; empty when unavailable
      object_link TYPE string,
      lstate   TYPE string,
      "! Set when Git changed the file too - it must be pulled first
      rstate   TYPE string,
      action   TYPE ty_stage_action,
      selected TYPE abap_bool,
      "! Who changed the object, as abapGit's Stage page shows it: for a file
      "! in SAP who changed the object last, for a file only in Git the owner
      "! of the first transport request that contains it; UNKNOWN without one
      changed_by  TYPE string,
      "! SHA1 of the file in Git; empty when it is not in Git or the
      "! repository is offline
      remote_sha1 TYPE string,
      "! The picked lines (patch IDs of get_diff); empty for the whole file
      patch_ids   TYPE string_table,
      "! get_diff's fingerprint the lines were picked on
      fingerprint TYPE string,
    END OF ty_stage_item,
    ty_stage_items TYPE STANDARD TABLE OF ty_stage_item WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_stage,
      items TYPE ty_stage_items,
      ignore_rules TYPE string_table,
      "! The committer abapGit remembers for this repository
      name  TYPE string,
      email TYPE string,
      "! The branch the repository follows, without refs/heads/
      branch TYPE string,
    END OF ty_stage.

  TYPES:
    BEGIN OF ty_ignore_preview,
      rule TYPE string,
      remove TYPE abap_bool,
      rules TYPE string_table,
      files TYPE ty_stage_items,
    END OF ty_ignore_preview.

  TYPES:
    BEGIN OF ty_commit,
      title TYPE string,
      body  TYPE string,
      name  TYPE string,
      email TYPE string,
      "! Optional: create this branch at the checked head and push there
      new_branch TYPE string,
    END OF ty_commit.

  TYPES:
    BEGIN OF ty_push_result,
      outcome TYPE ty_outcome,
      "! The remote head after the push, 7 characters
      commit  TYPE string,
      "! The branch pushed to, without refs/heads/
      branch  TYPE string,
    END OF ty_push_result.

  TYPES:
    BEGIN OF ty_branch,
      "! The full name, refs/heads/...
      name    TYPE string,
      display TYPE string,
      "! The remote's HEAD points here
      default TYPE abap_bool,
      "! The branch the repository follows now
      current TYPE abap_bool,
      "! The commit the branch points to
      sha1    TYPE string,
      link TYPE string,
    END OF ty_branch,
    ty_branches TYPE STANDARD TABLE OF ty_branch WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_tag,
      ref_sha1 TYPE string,
      name TYPE string,
      display TYPE string,
      sha1 TYPE string,
      current TYPE abap_bool,
      kind TYPE string,
      link TYPE string,
    END OF ty_tag,
    ty_tags TYPE STANDARD TABLE OF ty_tag WITH EMPTY KEY.

  CONSTANTS:
    BEGIN OF c_repo_kind,
      online  TYPE string VALUE `ONLINE`,
      offline TYPE string VALUE `OFFLINE`,
    END OF c_repo_kind.

  "! The form of a new repository, as the browser sends it
  TYPES:
    BEGIN OF ty_new_repo,
      "! c_repo_kind
      kind            TYPE string,
      "! online only
      url             TYPE string,
      "! online only; empty: the remote's default branch
      branch          TYPE string,
      "! offline only
      name            TYPE string,
      package         TYPE string,
      "! online only
      display_name    TYPE string,
      "! PREFIX, FULL or MIXED
      folder_logic    TYPE string,
      "! comma-separated
      labels          TYPE string,
      ign_subpackages TYPE abap_bool,
      main_lang_only  TYPE abap_bool,
      "! empty (any), ignore, standard, keyUser or cloudDevelopment
      abap_lang_vers  TYPE string,
    END OF ty_new_repo.

  TYPES:
    BEGIN OF ty_field_error,
      "! a component of ty_new_repo in lower case; empty: no field
      field TYPE string,
      text  TYPE string,
    END OF ty_field_error,
    ty_field_errors TYPE STANDARD TABLE OF ty_field_error WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_new_repo_result,
      "! c_outcome-created or -invalid
      outcome TYPE ty_outcome,
      "! the new repository's key, when created
      key     TYPE string,
      errors  TYPE ty_field_errors,
    END OF ty_new_repo_result.

  TYPES:
    BEGIN OF ty_new_package,
      package            TYPE string,
      description        TYPE string,
      software_component TYPE string,
      transport_layer    TYPE string,
      super_package      TYPE string,
      transport          TYPE string,
      abap_lang_vers     TYPE string,
    END OF ty_new_package,
    BEGIN OF ty_package_result,
      outcome TYPE ty_outcome,
      package TYPE string,
      errors  TYPE ty_field_errors,
    END OF ty_package_result.

  METHODS package_defaults
    IMPORTING
      iv_package       TYPE string
      iv_abap_lang_vers TYPE string OPTIONAL
    RETURNING
      VALUE(rs_package) TYPE ty_new_package
    RAISING
      zcx_abapgit_exception.

  "! Creates only a new package; repository creation remains a separate step
  METHODS create_package
    IMPORTING
      is_package TYPE ty_new_package
    RETURNING
      VALUE(rs_result) TYPE ty_package_result
    RAISING
      zcx_abapgit_exception.

  METHODS list_repos
    RETURNING
      VALUE(rt_repos) TYPE ty_repos
    RAISING
      zcx_abapgit_exception.

  "! Set the current user's favorite. String state is validated before conversion.
  METHODS set_favorite
    IMPORTING
      iv_key TYPE string
      iv_favorite TYPE string
    RETURNING
      VALUE(rv_favorite) TYPE abap_bool
    RAISING
      zcx_abapgit_exception.

  "! Save local labels only if the labels shown when editing still match.
  METHODS save_labels
    IMPORTING
      iv_key TYPE string
      iv_labels TYPE string
      iv_expected TYPE string
    RETURNING
      VALUE(rt_labels) TYPE ty_labels
    RAISING
      zcx_abapgit_exception.

  "! Starts serializing the local files in the background (aRFC); the
  "! status head comes from the registration, without a remote fetch
  METHODS start_status
    IMPORTING
      iv_key          TYPE string
    RETURNING
      VALUE(rs_start) TYPE ty_status_start
    RAISING
      zcx_abapgit_exception.

  "! State of a background run of this user and repository; else gone
  METHODS run_state
    IMPORTING
      iv_run_id       TYPE string
      iv_key          TYPE string
    RETURNING
      VALUE(rs_state) TYPE ty_run_state.

  "! Fetches the remote again and compares it with the system
  METHODS get_status
    IMPORTING
      iv_key           TYPE string
      "! Original uploaded ZIP; offline only, restored on every request
      iv_zip           TYPE xstring OPTIONAL
      "! Finished background run: its local files are used and deleted
      iv_run_id        TYPE string OPTIONAL
    RETURNING
      VALUE(rs_status) TYPE ty_status
    RAISING
      zcx_abapgit_exception.

  "! What a pull would do - imports nothing. Preselected are the changes that
  "! lose nothing local (abapGit itself preselects only additions)
  METHODS preview_pull
    IMPORTING
      iv_key            TYPE string
      "! Original uploaded ZIP; offline only, restored on every request
      iv_zip           TYPE xstring OPTIONAL
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
      "! Original uploaded ZIP; offline only, restored on every request
      iv_zip           TYPE xstring OPTIONAL
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

  "! Line diff of one file, the system's version against Git's
  METHODS get_diff
    IMPORTING
      iv_key         TYPE string
      iv_path        TYPE string
      iv_filename    TYPE string
      iv_remote_is_new TYPE abap_bool DEFAULT abap_false
      "! The file's SHA1 in Git from a status or stage row
      iv_remote_sha1   TYPE string OPTIONAL
      "! The caller knows the remote side from such a row: the file is
      "! fetched alone, and an empty iv_remote_sha1 means "not in Git"
      iv_remote_known  TYPE abap_bool DEFAULT abap_false
      "! Original uploaded ZIP; offline only, restored on every request
      iv_zip           TYPE xstring OPTIONAL
    RETURNING
      VALUE(rs_diff) TYPE ty_diff
    RAISING
      zcx_abapgit_exception.

  "! Files differing between SAP and Git that can be committed
  METHODS get_stage
    IMPORTING
      iv_key          TYPE string
    RETURNING
      VALUE(rs_stage) TYPE ty_stage
    RAISING
      zcx_abapgit_exception.

  "! Preview native .abapgit.xml ignore changes against fresh staging data
  METHODS preview_ignore
    IMPORTING iv_key TYPE string
              iv_rule TYPE string
              iv_remove TYPE abap_bool DEFAULT abap_false
    RETURNING VALUE(rs_preview) TYPE ty_ignore_preview
    RAISING zcx_abapgit_exception.

  "! Recompute the preview before persisting; refuse stale client data
  METHODS save_ignore
    IMPORTING iv_key TYPE string
              is_preview TYPE ty_ignore_preview
    RAISING zcx_abapgit_exception.

  "! Commits the selected files and pushes them, with the credentials of the
  "! user exit or of login( ). Outcome changed, and nothing is pushed,
  "! when a selected file is no longer changed locally as it was, or a
  "! patched file is no longer the version its lines were picked on
  METHODS commit_push
    IMPORTING
      iv_key           TYPE string
      it_items         TYPE ty_stage_items
      is_commit        TYPE ty_commit
    RETURNING
      VALUE(rs_result) TYPE ty_push_result
    RAISING
      zcx_abapgit_exception.

  "! Keeps user and token for the repository's host in abapGit's login
  "! manager - server memory of this session only, see assert_authorized for
  "! the expiry. The repository by key, or a URL for one not registered yet
  METHODS login
    IMPORTING
      iv_key   TYPE string OPTIONAL
      iv_url   TYPE string OPTIONAL
      iv_user  TYPE string
      iv_token TYPE string
    RAISING
      zcx_abapgit_exception.

  "! Drops every credential kept by login( )
  METHODS logoff.

  "! The remote's branches, the default one first
  METHODS list_branches
    IMPORTING
      iv_key             TYPE string
    RETURNING
      VALUE(rt_branches) TYPE ty_branches
    RAISING
      zcx_abapgit_exception.

  TYPES: BEGIN OF ty_tag_target,
           ref TYPE string,
           sha1 TYPE string,
           name TYPE string,
           email TYPE string,
         END OF ty_tag_target,
         BEGIN OF ty_new_tag,
           name TYPE string,
           kind TYPE string,
           message TYPE string,
           tagger_name TYPE string,
           tagger_email TYPE string,
         END OF ty_new_tag.

  METHODS tag_target
    IMPORTING iv_key TYPE string
    RETURNING VALUE(rs_target) TYPE ty_tag_target
    RAISING zcx_abapgit_exception.
  METHODS create_tag
    IMPORTING iv_key TYPE string is_tag TYPE ty_new_tag is_expected TYPE ty_tag_target
    RETURNING VALUE(rv_tag) TYPE string
    RAISING zcx_abapgit_exception.

  METHODS list_tags
    IMPORTING iv_key TYPE string
    RETURNING VALUE(rt_tags) TYPE ty_tags
    RAISING zcx_abapgit_exception.

  "! Delete only an unselected tag whose raw remote ref still matches.
  METHODS delete_tag
    IMPORTING iv_key TYPE string iv_tag TYPE string iv_ref_sha1 TYPE string
    RAISING zcx_abapgit_exception.

  "! Select a checked tag; imports no objects and writes no remote refs.
  METHODS switch_tag
    IMPORTING iv_key TYPE string iv_tag TYPE string iv_sha1 TYPE string
    RAISING zcx_abapgit_exception.

  "! Follows another branch of the remote, as abapGit does. No object in the
  "! system changes; the status then shows what a pull would bring
  METHODS switch_branch
    IMPORTING
      iv_key    TYPE string
      iv_branch TYPE string
    RAISING
      zcx_abapgit_exception.

  "! Creates a branch at the head of the branch the repository follows, and
  "! follows it. The name is normalized and checked; abapGit's exit supplies
  "! the credentials for the push of the new ref
  METHODS create_branch
    IMPORTING
      iv_key           TYPE string
      iv_name          TYPE string
    RETURNING
      VALUE(rv_branch) TYPE string
    RAISING
      zcx_abapgit_exception.

  "! Deletes a branch on the remote; not the default one, not the one the
  "! repository follows, and only while it still points to iv_sha1, the
  "! commit the user confirmed. Returns that commit
  METHODS delete_branch
    IMPORTING
      iv_key         TYPE string
      iv_branch      TYPE string
      iv_sha1        TYPE string
    RETURNING
      VALUE(rv_sha1) TYPE string
    RAISING
      zcx_abapgit_exception.

  "! Creates an online or offline repository. Every check runs first and
  "! all errors are returned per field; while one fails nothing is created
  "! and the outcome is invalid. No credentials: a private repository works
  "! only through abapGit's user exit, an empty remote is refused
  METHODS create_repo
    IMPORTING
      is_repo          TYPE ty_new_repo
    RETURNING
      VALUE(rs_result) TYPE ty_new_repo_result
    RAISING
      zcx_abapgit_exception.

  "! Serializes the local files of an offline repository, with no SAP GUI
  METHODS export_zip
    IMPORTING
      iv_key        TYPE string
    RETURNING
      VALUE(rv_zip) TYPE xstring
    RAISING
      zcx_abapgit_exception.

ENDINTERFACE.
