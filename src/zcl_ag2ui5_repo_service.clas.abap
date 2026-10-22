"! Talks to the abapGit developer version on behalf of the apps
CLASS zcl_ag2ui5_repo_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service.

    CLASS-METHODS checked_labels
      IMPORTING iv_labels TYPE string iv_expected TYPE string iv_fresh TYPE string
      RETURNING VALUE(rv_labels) TYPE string
      RAISING zcx_abapgit_exception.
    "! Display-only labels with stable, checked categorical colors.
    CLASS-METHODS repo_labels
      IMPORTING iv_labels TYPE string iv_colors TYPE string OPTIONAL
      RETURNING VALUE(rt_labels) TYPE zif_ag2ui5_repo_service=>ty_labels
      RAISING zcx_abapgit_exception.

    "! The owner of an object's transport request, from E071 / E070
    TYPES:
      BEGIN OF ty_object_owner,
        obj_type TYPE string,
        obj_name TYPE string,
        trkorr   TYPE string,
        as4user  TYPE string,
      END OF ty_object_owner,
      ty_object_owners TYPE STANDARD TABLE OF ty_object_owner WITH EMPTY KEY.

    "! abapGit's name for an object without a transport owner
    CONSTANTS c_user_unknown TYPE string VALUE `UNKNOWN`.

    "! Who changed the object: the owner of the first transport request in
    "! it_owners for it, UNKNOWN when there is none or it has no owner
    CLASS-METHODS owner_of
      IMPORTING
        it_owners        TYPE ty_object_owners
        iv_obj_type      TYPE string
        iv_obj_name      TYPE string
      RETURNING
        VALUE(rv_user)   TYPE string.

    "! Who last changed a file in SAP, from abapGit's object handler
    TYPES:
      BEGIN OF ty_file_user,
        path     TYPE string,
        filename TYPE string,
        user     TYPE string,
      END OF ty_file_user,
      ty_file_users TYPE STANDARD TABLE OF ty_file_user WITH EMPTY KEY.

    "! Who changed each staging file, as abapGit's Stage page: for a file in
    "! SAP the object's last changer (it_local_users), for a file only in Git
    "! the owner of the object's first transport request; UNKNOWN without one
    CLASS-METHODS assign_changed_by
      IMPORTING
        it_local_users TYPE ty_file_users
        it_owners      TYPE ty_object_owners
      CHANGING
        ct_items       TYPE zif_ag2ui5_repo_service=>ty_stage_items.

    "! A status row whose file is in Git but not in SAP: deleted in SAP, or
    "! new in Git and never pulled
    CLASS-METHODS only_in_git
      IMPORTING
        iv_lstate          TYPE string
        iv_rstate          TYPE string
      RETURNING
        VALUE(rv_only_git) TYPE abap_bool.

    "! abapGit asks for credentials and neither its user exit nor login( )
    "! supplied any, or the remote rejected them
    CLASS-METHODS login_required
      IMPORTING
        ix_error      TYPE REF TO zcx_abapgit_exception
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! Start of an HTTP request on the own ICF node: after a login the session
    "! is stateful and would keep abapGit's repository list and objects; they
    "! are read fresh once per request, never in the middle of an operation
    CLASS-METHODS request_start.

    "! The host of a Git URL, for texts: github.com, git.example.com:8443
    CLASS-METHODS url_host
      IMPORTING
        iv_url         TYPE string
      RETURNING
        VALUE(rv_host) TYPE string.

    "! Display only: keep the full ref for all repository operations.
    CLASS-METHODS branch_display
      IMPORTING iv_branch TYPE string
      RETURNING VALUE(rv_display) TYPE string.

    "! Browser URL for supported remote hosts; empty if unavailable.
    CLASS-METHODS branch_link
      IMPORTING iv_url TYPE string iv_branch TYPE string
      RETURNING VALUE(rv_link) TYPE string.

    "! One row per object; files without an object share the empty key.
    "! Counts include every file; differing nonempty states become MIXED.
    CLASS-METHODS object_status_rows
      IMPORTING
        it_rows TYPE zif_ag2ui5_repo_service=>ty_status_rows
        iv_changes_first TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rt_rows) TYPE zif_ag2ui5_repo_service=>ty_object_status_rows.

    "! The decision dialog's content: one item per object, in its most
    "! dangerous group, with abapGit's defaults preselected
    CLASS-METHODS preview
      IMPORTING
        is_checks         TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RETURNING
        VALUE(rs_preview) TYPE zif_ag2ui5_repo_service=>ty_preview.

    "! Nothing to do: no object ticked. Without selectable objects (only
    "! unsupported types), changed repository files still make it a pull
    CLASS-METHODS pull_is_noop
      IMPORTING
        it_items       TYPE zif_ag2ui5_repo_service=>ty_decision_items
        iv_files       TYPE abap_bool
      RETURNING
        VALUE(rv_noop) TYPE abap_bool.

    "! The fresh preview's items with the user's ticks. Raises when anything
    "! differs from what the user saw: a new object, an object in another
    "! group now, or a ticked object that is gone
    CLASS-METHODS merge_decisions
      IMPORTING
        it_fresh        TYPE zif_ag2ui5_repo_service=>ty_decision_items
        it_posted       TYPE zif_ag2ui5_repo_service=>ty_decision_items
      RETURNING
        VALUE(rt_items) TYPE zif_ag2ui5_repo_service=>ty_decision_items
      RAISING
        zcx_abapgit_exception.

    "! Raises unless the request is one of the user's modifiable requests
    CLASS-METHODS assert_transport
      IMPORTING
        iv_transport  TYPE string
        it_transports TYPE zif_ag2ui5_repo_service=>ty_transports
      RAISING
        zcx_abapgit_exception.

    TYPES ty_request_use TYPE STANDARD TABLE OF e070use WITH EMPTY KEY.

    "! The request SAP would propose, if it is in the list: the valid standard
    "! request (fixtype S) of the category, else the last used one (U) of the
    "! type; empty otherwise
    CLASS-METHODS preferred_transport
      IMPORTING
        it_transports    TYPE zif_ag2ui5_repo_service=>ty_transports
        it_use           TYPE ty_request_use
        iv_type          TYPE string
        iv_client        TYPE mandt
        iv_today         TYPE d
      RETURNING
        VALUE(rv_trkorr) TYPE string.

    "! The request to record on: abapGit's own if it determined one, otherwise
    "! the user's choice, which must be one of their modifiable requests
    CLASS-METHODS effective_transport
      IMPORTING
        iv_preset        TYPE string
        iv_chosen        TYPE string
        it_transports    TYPE zif_ag2ui5_repo_service=>ty_transports
      RETURNING
        VALUE(rv_trkorr) TYPE string
      RAISING
        zcx_abapgit_exception.

    "! Writes the decisions into every check table an object is in. Raises
    "! when an object has no item (the remote changed since the preview) or
    "! when unmet requirements are not acknowledged
    CLASS-METHODS apply_decisions
      IMPORTING
        is_checks        TYPE zif_abapgit_definitions=>ty_deserialize_checks
        it_items         TYPE zif_ag2ui5_repo_service=>ty_decision_items
        iv_acknowledged  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_checks) TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RAISING
        zcx_abapgit_exception.

    "! Every change with iv_context unchanged lines around it; each longer
    "! unchanged run becomes one gap line
    CLASS-METHODS compact
      IMPORTING
        it_lines        TYPE zif_ag2ui5_repo_service=>ty_diff_lines
        iv_context      TYPE i DEFAULT 3
      RETURNING
        VALUE(rt_lines) TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    "! abapGit's diff as plain lines. abapGit's "new" is the system, or the
    "! remote when iv_remote_is_new is set
    CLASS-METHODS map_diff
      IMPORTING
        it_diff          TYPE zif_abapgit_definitions=>ty_diffs_tt
        iv_remote_is_new TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_lines) TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    "! Structural observations about method declarations and implementations.
    CLASS-METHODS semantic_diff
      IMPORTING
        it_local TYPE string_table
        it_remote TYPE string_table
        iv_remote_is_new TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_semantic) TYPE zif_ag2ui5_repo_service=>ty_semantic.

    "! abapGit's rule for the diff direction: only when nothing changed locally
    "! and something changed remotely is the remote the new side
    CLASS-METHODS remote_is_new
      IMPORTING
        iv_lstate     TYPE string
        iv_rstate     TYPE string
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

    "! The file's SHA1 in a remote file list, lower case; empty when the
    "! file is not in Git
    CLASS-METHODS remote_sha1
      IMPORTING
        it_remote      TYPE zif_abapgit_git_definitions=>ty_files_tt
        iv_path        TYPE string
        iv_filename    TYPE string
      RETURNING
        VALUE(rv_sha1) TYPE string.

    "! The one blob Git sent for iv_sha1, checked against the hash
    CLASS-METHODS checked_blob
      IMPORTING
        it_objects     TYPE zif_abapgit_definitions=>ty_objects_tt
        iv_sha1        TYPE string
      RETURNING
        VALUE(rv_data) TYPE xstring
      RAISING
        zcx_abapgit_exception.

    "! The same lines side by side: old left, new right; a changed block is
    "! paired line by line, the longer side padded with empty cells
    CLASS-METHODS to_side_by_side
      IMPORTING
        it_lines         TYPE zif_ag2ui5_repo_service=>ty_diff_lines
        iv_remote_is_new TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_rows)   TYPE zif_ag2ui5_repo_service=>ty_sbs_rows.

    "! Code for sap.m.FormattedText: escaped, monospace, indentation kept
    CLASS-METHODS code_html
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.

    "! The code on a background by what happened to the line: ADDED green,
    "! REMOVED red, GAP grey; any other tint leaves it as it is
    CLASS-METHODS tinted_html
      IMPORTING
        iv_html        TYPE string
        iv_tint        TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.

    "! The line counts with + for the side that changed, - for the other
    CLASS-METHODS counts_text
      IMPORTING
        iv_local         TYPE i
        iv_remote        TYPE i
        iv_remote_is_new TYPE abap_bool
      RETURNING
        VALUE(rv_text)   TYPE string.

    "! Identifies a pair of versions: the SHA1 of each side
    CLASS-METHODS fingerprint
      IMPORTING
        iv_local              TYPE xstring
        iv_remote             TYPE xstring
      RETURNING
        VALUE(rv_fingerprint) TYPE string
      RAISING
        zcx_abapgit_exception.

    "! abapGit's diff with patch_flag set for each picked patch ID. Raises
    "! when the list is empty or an ID names no changed line
    CLASS-METHODS apply_patch
      IMPORTING
        it_diff        TYPE zif_abapgit_definitions=>ty_diffs_tt
        it_ids         TYPE string_table
      RETURNING
        VALUE(rt_diff) TYPE zif_abapgit_definitions=>ty_diffs_tt
      RAISING
        zcx_abapgit_exception.

    "! How a patched file is staged, as abapGit's patch page does: D (rm)
    "! when every line of a deleted file is picked, A when every line of an
    "! added file is, M (add with the patch) otherwise
    CLASS-METHODS patch_lstate
      IMPORTING
        iv_lstate        TYPE string
        it_diff          TYPE zif_abapgit_definitions=>ty_diffs_tt
      RETURNING
        VALUE(rv_lstate) TYPE string.

    "! abapGit's branch list as rows: without empty names and the HEAD
    "! duplicate, default first, then by name - as abapGit's branch popup
    CLASS-METHODS branch_rows
      IMPORTING
        it_branches        TYPE zif_abapgit_git_definitions=>ty_git_branch_list_tt
        iv_head_symref     TYPE string
        iv_current         TYPE string
      RETURNING
        VALUE(rt_branches) TYPE zif_ag2ui5_repo_service=>ty_branches.

    CLASS-METHODS assert_tag_context
      IMPORTING iv_commit TYPE string iv_origin TYPE string
      RAISING zcx_abapgit_exception.
    CLASS-METHODS tag_commit
      IMPORTING iv_sha1 TYPE string it_objects TYPE zif_abapgit_definitions=>ty_objects_tt
      RETURNING VALUE(rv_sha1) TYPE string.
    CLASS-METHODS tag_rows
      IMPORTING it_tags TYPE zif_abapgit_git_definitions=>ty_git_branch_list_tt iv_current TYPE string
      RETURNING VALUE(rt_tags) TYPE zif_ag2ui5_repo_service=>ty_tags.
    CLASS-METHODS checked_new_tag
      IMPORTING is_tag TYPE zif_ag2ui5_repo_service=>ty_new_tag
                it_tags TYPE zif_ag2ui5_repo_service=>ty_tags
                is_expected TYPE zif_ag2ui5_repo_service=>ty_tag_target
                is_actual TYPE zif_ag2ui5_repo_service=>ty_tag_target
      RETURNING VALUE(rs_tag) TYPE zif_abapgit_git_definitions=>ty_git_tag
      RAISING zcx_abapgit_exception.
    CLASS-METHODS assert_deletable_tag
      IMPORTING iv_tag TYPE string iv_ref_sha1 TYPE string it_tags TYPE zif_ag2ui5_repo_service=>ty_tags
      RAISING zcx_abapgit_exception.
    CLASS-METHODS assert_tag
      IMPORTING iv_tag TYPE string iv_sha1 TYPE string it_tags TYPE zif_ag2ui5_repo_service=>ty_tags
      RAISING zcx_abapgit_exception.

    "! Raises unless the branch is one of the listed ones
    CLASS-METHODS assert_branch
      IMPORTING
        iv_branch   TYPE string
        it_branches TYPE zif_ag2ui5_repo_service=>ty_branches
      RAISING
        zcx_abapgit_exception.

    "! False only when the branch is selected on the registered remote and
    "! no commit is fixed: anything else still has to be reset
    CLASS-METHODS switch_needed
      IMPORTING
        iv_selected      TYPE string
        iv_branch        TYPE string
        iv_commit        TYPE string
        iv_origin        TYPE string
      RETURNING
        VALUE(rv_needed) TYPE abap_bool.

    "! The registered remote's URL, also while another origin is switched in
    "! (abapGit keeps it as <url>@<branch>, split at the last @)
    CLASS-METHODS registered_url
      IMPORTING
        iv_url              TYPE string
        iv_switched_origin  TYPE string
      RETURNING
        VALUE(rv_url)       TYPE string
      RAISING
        zcx_abapgit_exception.

    "! The full name of a new branch, as abapGit makes it: blanks at the
    "! ends removed, inner blanks as -, refs/heads/ added unless present
    CLASS-METHODS branch_name
      IMPORTING
        iv_name          TYPE string
      RETURNING
        VALUE(rv_branch) TYPE string.

    "! Raises unless the name after refs/heads/ follows Git's rules for a ref
    CLASS-METHODS assert_branch_name
      IMPORTING
        iv_branch TYPE string
      RAISING
        zcx_abapgit_exception.

    "! Raises if the branch is already on the remote
    CLASS-METHODS assert_new_branch
      IMPORTING
        iv_branch   TYPE string
        it_branches TYPE zif_ag2ui5_repo_service=>ty_branches
      RAISING
        zcx_abapgit_exception.

    "! The full name of the new branch for a push, or empty when none was
    "! entered. Normalized as branch_name( ), then checked as create_branch
    CLASS-METHODS push_branch
      IMPORTING
        iv_new_branch    TYPE string
        it_branches      TYPE zif_ag2ui5_repo_service=>ty_branches
      RETURNING
        VALUE(rv_branch) TYPE string
      RAISING
        zcx_abapgit_exception.

    "! Raises unless the branch is listed and is neither the remote's
    "! default nor the one the repository follows. With iv_sha1, also when
    "! the branch no longer points to that commit (it moved since shown)
    CLASS-METHODS assert_deletable
      IMPORTING
        iv_branch   TYPE string
        iv_sha1     TYPE string OPTIONAL
        it_branches TYPE zif_ag2ui5_repo_service=>ty_branches
      RAISING
        zcx_abapgit_exception.

    "! Files differing between SAP and Git, and what a commit does with each
    CLASS-METHODS stage_candidates
      IMPORTING
        it_results      TYPE zif_abapgit_definitions=>ty_results_tt
        is_dot TYPE zif_abapgit_dot_abapgit=>ty_dot_abapgit OPTIONAL
        is_files TYPE zif_abapgit_definitions=>ty_stage_files OPTIONAL
      RETURNING
        VALUE(rt_items) TYPE zif_ag2ui5_repo_service=>ty_stage_items.

    CLASS-METHODS change_ignore_rules
      IMPORTING is_dot TYPE zif_abapgit_dot_abapgit=>ty_dot_abapgit
                iv_rule TYPE string
                iv_remove TYPE abap_bool DEFAULT abap_false
      RETURNING VALUE(rs_dot) TYPE zif_abapgit_dot_abapgit=>ty_dot_abapgit
      RAISING zcx_abapgit_exception.

    CLASS-METHODS assert_ignore_preview
      IMPORTING is_expected TYPE zif_ag2ui5_repo_service=>ty_ignore_preview
                is_fresh TYPE zif_ag2ui5_repo_service=>ty_ignore_preview
      RAISING zcx_abapgit_exception.

    CLASS-METHODS ignore_preview
      IMPORTING it_results TYPE zif_abapgit_definitions=>ty_results_tt
                is_dot TYPE zif_abapgit_dot_abapgit=>ty_dot_abapgit
                iv_rule TYPE string
                iv_remove TYPE abap_bool DEFAULT abap_false
                is_files TYPE zif_abapgit_definitions=>ty_stage_files OPTIONAL
      RETURNING VALUE(rs_preview) TYPE zif_ag2ui5_repo_service=>ty_ignore_preview
      RAISING zcx_abapgit_exception.

    "! Raises when a selected file is no longer changed locally as it was
    CLASS-METHODS check_selection
      IMPORTING
        it_fresh    TYPE zif_ag2ui5_repo_service=>ty_stage_items
        it_selected TYPE zif_ag2ui5_repo_service=>ty_stage_items
      RAISING
        zcx_abapgit_exception.

    "! Refuses what abapGit's stage page refuses: a file Git changed too
    "! (pushing would overwrite that change), and an object moved to another
    "! folder whose old path is not removed in the same commit
    CLASS-METHODS check_push_allowed
      IMPORTING
        it_items TYPE zif_ag2ui5_repo_service=>ty_stage_items
      RAISING
        zcx_abapgit_exception.

    "! The title, and after an empty line the body, if there is one
    CLASS-METHODS commit_message
      IMPORTING
        iv_title       TYPE string
        iv_body        TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Every file, those that differ or are inactive marked as changed
    CLASS-METHODS status_rows
      IMPORTING
        it_results     TYPE zif_abapgit_definitions=>ty_results_tt
      RETURNING
        VALUE(rt_rows) TYPE zif_ag2ui5_repo_service=>ty_status_rows.

    "! The status rows in order: OBJECT (type, name, file), FILE (path, file)
    "! or TYPE (type, name); case is ignored. With iv_changes_first, the
    "! changed rows come first, in the same order among themselves
    CLASS-METHODS sort_status_rows
      IMPORTING
        it_rows          TYPE zif_ag2ui5_repo_service=>ty_status_rows
        iv_by            TYPE string
        iv_changes_first TYPE abap_bool
      RETURNING
        VALUE(rt_rows)   TYPE zif_ag2ui5_repo_service=>ty_status_rows.

    "! The row highlight of a status row: Indication03 (yellow) for any
    "! change or an inactive object, None otherwise
    CLASS-METHODS change_highlight
      IMPORTING
        iv_lstate           TYPE string
        iv_rstate           TYPE string
        iv_inactive         TYPE abap_bool
      RETURNING
        VALUE(rv_highlight) TYPE string.

    "! Date and time to the minute in the user's time zone, empty if initial
    CLASS-METHODS format_timestamp
      IMPORTING
        iv_timestamp   TYPE timestampl
        iv_timezone    TYPE tznzone DEFAULT sy-zonlo
      RETURNING
        VALUE(rv_text) TYPE string.


    "! The form as the checks see it: blanks around values removed, kind,
    "! package and folder logic in upper case, a branch as refs/heads/...,
    "! and the fields of the other kind cleared
    CLASS-METHODS normalize_new_repo
      IMPORTING
        is_repo        TYPE zif_ag2ui5_repo_service=>ty_new_repo
      RETURNING
        VALUE(rs_repo) TYPE zif_ag2ui5_repo_service=>ty_new_repo.

    "! The form's own errors, before anything asks abapGit: required fields
    "! and the allowed values. Expects a normalized form
    CLASS-METHODS new_repo_errors
      IMPORTING
        is_repo          TYPE zif_ag2ui5_repo_service=>ty_new_repo
      RETURNING
        VALUE(rt_errors) TYPE zif_ag2ui5_repo_service=>ty_field_errors.
    CLASS-METHODS normalize_new_package
      IMPORTING is_package TYPE zif_ag2ui5_repo_service=>ty_new_package
      RETURNING VALUE(rs_package) TYPE zif_ag2ui5_repo_service=>ty_new_package.

    CLASS-METHODS assert_delete_preview
      IMPORTING is_expected TYPE zif_ag2ui5_repo_service=>ty_delete_preview
                is_actual TYPE zif_ag2ui5_repo_service=>ty_delete_preview
                iv_confirmation TYPE string
      RAISING zcx_abapgit_exception.

    CLASS-METHODS new_package_errors
      IMPORTING is_package TYPE zif_ag2ui5_repo_service=>ty_new_package
      RETURNING VALUE(rt_errors) TYPE zif_ag2ui5_repo_service=>ty_field_errors.

    "! Binary upload, validated before the app replaces its previous ZIP
    CLASS-METHODS decode_zip
      IMPORTING
        iv_upload     TYPE string
      RETURNING
        VALUE(rv_zip) TYPE xstring
      RAISING
        zcx_abapgit_exception.

    "! Parses abapGit/GitHub ZIPs. A missing .abapgit.xml is never an empty remote
    CLASS-METHODS zip_files
      IMPORTING
        iv_zip          TYPE xstring
      RETURNING
        VALUE(rt_files) TYPE zif_abapgit_git_definitions=>ty_files_tt
      RAISING
        zcx_abapgit_exception.

  PROTECTED SECTION.
    "! The last service call of this session, for the expiry of login( )
    CLASS-DATA gv_last_use TYPE timestampl.
    "! Tests set the time; initial means now
    CLASS-DATA gv_now TYPE timestampl.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_blob,
        sha1 TYPE string,
        data TYPE xstring,
      END OF ty_blob,
      ty_blobs TYPE HASHED TABLE OF ty_blob WITH UNIQUE KEY sha1.
    "! Single files fetched in this request, cleared by request_start( )
    CLASS-DATA gt_blobs TYPE ty_blobs.
    "! Tests replace it
    CLASS-DATA gi_blob_source TYPE REF TO zif_ag2ui5_blob_source.

    CLASS-METHODS blob_source
      RETURNING
        VALUE(ri_source) TYPE REF TO zif_ag2ui5_blob_source.

    "! The file's remote side: fetched alone when a row gave its SHA1,
    "! otherwise (and when the server refuses) from the whole repository
    METHODS remote_file
      IMPORTING
        ii_repo         TYPE REF TO zif_abapgit_repo
        ii_filter       TYPE REF TO zif_abapgit_object_filter
        iv_path         TYPE string
        iv_filename     TYPE string
        iv_remote_sha1  TYPE string
        iv_remote_known TYPE abap_bool
      EXPORTING
        ev_data         TYPE xstring
        ev_found        TYPE abap_bool
      RAISING
        zcx_abapgit_exception.

    TYPES:
      BEGIN OF ty_component,
        owner TYPE string,
        name TYPE string,
        kind TYPE string,
        tokens TYPE string,
        first TYPE i,
        last TYPE i,
      END OF ty_component,
      ty_components TYPE SORTED TABLE OF ty_component WITH UNIQUE KEY owner kind name.

    CLASS-METHODS method_components
      IMPORTING it_source TYPE string_table
      EXPORTING et_components TYPE ty_components ev_supported TYPE abap_bool.

    CLASS-METHODS ignore_repo_preview
      IMPORTING ii_repo TYPE REF TO zif_abapgit_repo_online
                iv_rule TYPE string
                iv_remove TYPE abap_bool
      RETURNING VALUE(rs_preview) TYPE zif_ag2ui5_repo_service=>ty_ignore_preview
      RAISING zcx_abapgit_exception.
    TYPES:
      BEGIN OF ty_object_link,
        obj_type TYPE string,
        obj_name TYPE string,
        href     TYPE string,
      END OF ty_object_link,
      ty_object_links TYPE HASHED TABLE OF ty_object_link WITH UNIQUE KEY obj_type obj_name.

    "! Request-local cache, including objects that cannot be opened
    CLASS-METHODS object_link
      IMPORTING
        iv_obj_type TYPE string
        iv_obj_name TYPE string
      CHANGING
        ct_links TYPE ty_object_links
      RETURNING
        VALUE(rv_link) TYPE string.

    "! abapGit's own checks for a normalized form; adds to ct_errors. A
    "! field that already has an error is not checked again
    METHODS check_new_repo
      IMPORTING
        is_repo   TYPE zif_ag2ui5_repo_service=>ty_new_repo
      CHANGING
        ct_errors TYPE zif_ag2ui5_repo_service=>ty_field_errors
      RAISING
        zcx_abapgit_exception.

    "! Creates the checked repository as abapGit's services do, without
    "! their popups. A new repository that fails its last checks is deleted
    "! again
    METHODS add_repo
      IMPORTING
        is_repo        TYPE zif_ag2ui5_repo_service=>ty_new_repo
      RETURNING
        VALUE(ri_repo) TYPE REF TO zif_abapgit_repo
      RAISING
        zcx_abapgit_exception.

    "! The transport owners of the given objects (obj_type, obj_name), see changed_by
    METHODS transport_owners
      IMPORTING
        it_objects       TYPE ty_object_owners
      RETURNING
        VALUE(rt_owners) TYPE ty_object_owners.

    METHODS silence_progress.

    "! The status without remote commit and rows: registration data only
    METHODS status_head
      IMPORTING
        iv_key           TYPE string
        ii_repo          TYPE REF TO zif_abapgit_repo
      RETURNING
        VALUE(rs_status) TYPE zif_ag2ui5_repo_service=>ty_status
      RAISING
        zcx_abapgit_exception.

    "! abapGit's own startup authorization (its user exit can restrict it).
    "! Also the expiry of login( ): credentials unused for 30 minutes go
    METHODS assert_authorized
      RAISING
        zcx_abapgit_exception.

    "! Restores offline remote files from plain app data, never from session cache
    METHODS get_repo
      IMPORTING
        iv_key        TYPE string
        iv_zip        TYPE xstring OPTIONAL
      RETURNING
        VALUE(ri_repo) TYPE REF TO zif_abapgit_repo
      RAISING
        zcx_abapgit_exception.

    METHODS list_tag_refs
      IMPORTING iv_key TYPE string
      RETURNING VALUE(rt_tags) TYPE zif_ag2ui5_repo_service=>ty_tags
      RAISING zcx_abapgit_exception.
    METHODS read_tag_commit
      IMPORTING iv_url TYPE string iv_sha1 TYPE string
      RETURNING VALUE(rv_sha1) TYPE string
      RAISING zcx_abapgit_exception.

    METHODS get_online_repo
      IMPORTING
        iv_key         TYPE string
      RETURNING
        VALUE(ri_repo) TYPE REF TO zif_abapgit_repo_online
      RAISING
        zcx_abapgit_exception.

    "! Both versions of one file: the system's and Git's (empty when absent).
    "! Raises when neither exists
    METHODS read_file_pair
      IMPORTING
        ii_repo     TYPE REF TO zif_abapgit_repo
        iv_path     TYPE string
        iv_filename TYPE string
        iv_remote_sha1 TYPE string OPTIONAL
        iv_remote_known TYPE abap_bool DEFAULT abap_false
      EXPORTING
        ev_local    TYPE xstring
        ev_remote   TYPE xstring
      RAISING
        zcx_abapgit_exception.

    "! Refuses to replace code that runs in this very session
    METHODS assert_pull_allowed
      IMPORTING
        iv_package TYPE devclass
      RAISING
        zcx_abapgit_exception.

    "! Imports and turns the log into the result - also when the import
    "! raises half-way, which is when the log matters most
    METHODS deserialize_logged
      IMPORTING
        ii_repo          TYPE REF TO zif_abapgit_repo
        is_checks        TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RETURNING
        VALUE(rs_result) TYPE zif_ag2ui5_repo_service=>ty_pull_result.

    METHODS map_messages
      IMPORTING
        ii_log             TYPE REF TO zif_abapgit_log
      RETURNING
        VALUE(rt_messages) TYPE zif_ag2ui5_repo_service=>ty_messages.

    "! Control characters as visible text - raw ones break the JSON the
    "! frontend parses (only tab is legal there)
    CLASS-METHODS visible
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Adds the object, or moves it to the new group if that is more dangerous
    CLASS-METHODS add_item
      IMPORTING
        is_object     TYPE zif_abapgit_definitions=>ty_overwrite
        iv_group      TYPE zif_ag2ui5_repo_service=>ty_group
        iv_reason     TYPE string
        iv_selected   TYPE abap_bool DEFAULT abap_false
        iv_selectable TYPE abap_bool DEFAULT abap_true
      CHANGING
        ct_items      TYPE zif_ag2ui5_repo_service=>ty_decision_items.

    "! 1 is the most dangerous group
    CLASS-METHODS group_rank
      IMPORTING
        iv_group       TYPE zif_ag2ui5_repo_service=>ty_group
      RETURNING
        VALUE(rv_rank) TYPE i.

    CLASS-METHODS decide
      IMPORTING
        it_items           TYPE zif_ag2ui5_repo_service=>ty_decision_items
        is_object          TYPE zif_abapgit_definitions=>ty_overwrite
      RETURNING
        VALUE(rv_decision) TYPE zif_abapgit_definitions=>ty_yes_no
      RAISING
        zcx_abapgit_exception.

ENDCLASS.



CLASS zcl_ag2ui5_repo_service IMPLEMENTATION.

  METHOD preview.

    IF is_checks-overwrite IS INITIAL AND is_checks-overwrite_files IS INITIAL.
      rs_preview-outcome = zif_ag2ui5_repo_service=>c_outcome-nothing.
      RETURN.
    ENDIF.

    " the dialog asks for a request of these types - unless abapGit already
    " determined one (repository setting, user exit), which is then used
    IF is_checks-transport-required = abap_true.
      IF is_checks-transport-type-request IS INITIAL AND is_checks-transport-transport IS INITIAL.
        rs_preview-outcome = zif_ag2ui5_repo_service=>c_outcome-blocked.
        rs_preview-blocked = `A transport request is required, but abapGit reports no request type`.
        RETURN.
      ENDIF.
      rs_preview-transport_type   = is_checks-transport-type-request.
      rs_preview-transport_preset = is_checks-transport-transport.
    ENDIF.
    IF is_checks-customizing-required = abap_true.
      IF is_checks-customizing-type-request IS INITIAL AND is_checks-customizing-transport IS INITIAL.
        rs_preview-outcome = zif_ag2ui5_repo_service=>c_outcome-blocked.
        rs_preview-blocked = `A customizing request is required, but abapGit reports no request type`.
        RETURN.
      ENDIF.
      rs_preview-customizing_type   = is_checks-customizing-type-request.
      rs_preview-customizing_preset = is_checks-customizing-transport.
    ENDIF.

    " as in abapGit's popup_decisions: a new namespace has to arrive before
    " the objects in it, so only the namespace is preselected then
    DATA(lv_new_namespace) = xsdbool( line_exists( is_checks-overwrite[
      obj_type = 'NSPC'
      action   = zif_abapgit_objects=>c_deserialize_action-add ] ) ).

    LOOP AT is_checks-overwrite INTO DATA(ls_change).
      DATA(lv_reason) = COND string( WHEN ls_change-text IS NOT INITIAL
                                     THEN ls_change-text
                                     ELSE |Action { ls_change-action }| ).
      CASE ls_change-action.
        WHEN zif_abapgit_objects=>c_deserialize_action-add
          OR zif_abapgit_objects=>c_deserialize_action-update.
          add_item( EXPORTING is_object   = ls_change
                              iv_group    = zif_ag2ui5_repo_service=>c_group-import
                              iv_reason   = lv_reason
                              iv_selected = xsdbool( lv_new_namespace = abap_false OR ls_change-obj_type = 'NSPC' )
                    CHANGING  ct_items    = rs_preview-items ).
        WHEN zif_abapgit_objects=>c_deserialize_action-delete
          OR zif_abapgit_objects=>c_deserialize_action-delete_add.
          add_item( EXPORTING is_object = ls_change
                              iv_group  = zif_ag2ui5_repo_service=>c_group-delete
                              iv_reason = lv_reason
                    CHANGING  ct_items  = rs_preview-items ).
        WHEN zif_abapgit_objects=>c_deserialize_action-packmove.
          add_item( EXPORTING is_object = ls_change
                              iv_group  = zif_ag2ui5_repo_service=>c_group-package
                              iv_reason = lv_reason
                    CHANGING  ct_items  = rs_preview-items ).
        WHEN zif_abapgit_objects=>c_deserialize_action-no_support.
          add_item( EXPORTING is_object     = ls_change
                              iv_group      = zif_ag2ui5_repo_service=>c_group-skipped
                              iv_reason     = `Object type not supported`
                              iv_selectable = abap_false
                    CHANGING  ct_items      = rs_preview-items ).
        WHEN OTHERS.
          " overwrite, and anything abapGit adds later: a local change is at stake
          add_item( EXPORTING is_object = ls_change
                              iv_group  = zif_ag2ui5_repo_service=>c_group-overwrite
                              iv_reason = lv_reason
                    CHANGING  ct_items  = rs_preview-items ).
      ENDCASE.
    ENDLOOP.

    LOOP AT is_checks-warning_package INTO ls_change.
      DATA(lv_package_note) = |Object is in package { ls_change-devclass }, outside this repository|.
      add_item( EXPORTING is_object = ls_change
                          iv_group  = zif_ag2ui5_repo_service=>c_group-package
                          iv_reason = lv_package_note
                CHANGING  ct_items  = rs_preview-items ).
      " when a more dangerous group wins, the foreign package must still show
      READ TABLE rs_preview-items ASSIGNING FIELD-SYMBOL(<ls_item>)
        WITH KEY obj_type = CONV string( ls_change-obj_type ) obj_name = CONV string( ls_change-obj_name ).
      IF sy-subrc = 0 AND <ls_item>-reason NS lv_package_note.
        <ls_item>-reason = |{ <ls_item>-reason } - { lv_package_note }|.
      ENDIF.
    ENDLOOP.
    LOOP AT is_checks-data_loss INTO ls_change.
      add_item( EXPORTING is_object = ls_change
                          iv_group  = zif_ag2ui5_repo_service=>c_group-data_loss
                          iv_reason = COND #( WHEN ls_change-text IS NOT INITIAL
                                              THEN ls_change-text
                                              ELSE `Data would be lost` )
                CHANGING  ct_items  = rs_preview-items ).
    ENDLOOP.
    LOOP AT is_checks-delete_tabl_with_data INTO ls_change.
      add_item( EXPORTING is_object = ls_change
                          iv_group  = zif_ag2ui5_repo_service=>c_group-data_loss
                          iv_reason = `Table with data would be deleted`
                CHANGING  ct_items  = rs_preview-items ).
    ENDLOOP.

    IF is_checks-requirements-met = zif_abapgit_definitions=>c_no.
      rs_preview-ack_text = `The system does not meet the requirements in .abapgit.xml.`.
    ENDIF.
    IF is_checks-dependencies-met = zif_abapgit_definitions=>c_no.
      rs_preview-ack_text = condense( |{ rs_preview-ack_text } APACK dependencies are not installed.| ).
    ENDIF.

    LOOP AT is_checks-overwrite_files INTO DATA(ls_file).
      INSERT VALUE #( path = ls_file-path filename = ls_file-filename ) INTO TABLE rs_preview-files.
    ENDLOOP.
    SORT rs_preview-files BY path filename.

    rs_preview-outcome = zif_ag2ui5_repo_service=>c_outcome-ready.

  ENDMETHOD.

  METHOD pull_is_noop.
    IF line_exists( it_items[ selected = abap_true ] ).
      rv_noop = abap_false.
    ELSEIF line_exists( it_items[ selectable = abap_true ] ).
      " objects left unticked: abapGit refuses this too
      rv_noop = abap_true.
    ELSE.
      rv_noop = xsdbool( iv_files = abap_false ).
    ENDIF.
  ENDMETHOD.

  METHOD add_item.

    READ TABLE ct_items ASSIGNING FIELD-SYMBOL(<ls_item>)
      WITH KEY obj_type = CONV string( is_object-obj_type )
               obj_name = CONV string( is_object-obj_name ).
    IF sy-subrc <> 0.
      INSERT VALUE #( obj_type   = is_object-obj_type
                      obj_name   = is_object-obj_name
                      group      = iv_group
                      reason     = iv_reason
                      selected   = iv_selected
                      selectable = iv_selectable ) INTO TABLE ct_items.
    ELSEIF group_rank( iv_group ) < group_rank( <ls_item>-group ).
      " a more dangerous group also takes the default of that group
      <ls_item>-group      = iv_group.
      <ls_item>-reason     = iv_reason.
      <ls_item>-selected   = iv_selected.
      <ls_item>-selectable = iv_selectable.
    ENDIF.

  ENDMETHOD.

  METHOD group_rank.

    rv_rank = SWITCH #( iv_group
                        WHEN zif_ag2ui5_repo_service=>c_group-data_loss THEN 1
                        WHEN zif_ag2ui5_repo_service=>c_group-delete    THEN 2
                        WHEN zif_ag2ui5_repo_service=>c_group-overwrite THEN 3
                        WHEN zif_ag2ui5_repo_service=>c_group-package   THEN 4
                        WHEN zif_ag2ui5_repo_service=>c_group-import    THEN 5
                        ELSE 6 ).

  ENDMETHOD.

  METHOD effective_transport.

    IF iv_preset IS NOT INITIAL.
      rv_trkorr = iv_preset.
      RETURN.
    ENDIF.

    assert_transport( iv_transport  = iv_chosen
                      it_transports = it_transports ).
    rv_trkorr = iv_chosen.

  ENDMETHOD.

  METHOD assert_transport.

    IF iv_transport IS INITIAL.
      zcx_abapgit_exception=>raise( `This package needs a transport request - choose one` ).
    ENDIF.
    IF NOT line_exists( it_transports[ trkorr = iv_transport ] ).
      zcx_abapgit_exception=>raise( |{ iv_transport } is not one of your modifiable requests of the required type| ).
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_transports.

    DATA lv_type TYPE e070-trfunction.

    assert_authorized( ).
    lv_type = iv_type.

    " The choice TRINT_ORDER_CHOICE offers in abapGit: requests of this client
    " the user owns (modifiable), and requests of others in which the user
    " has a task - also protected ones (L), since the task already exists
    SELECT e070~trkorr, e07t~as4text FROM e070
      INNER JOIN e070c ON e070c~trkorr = e070~trkorr
      LEFT OUTER JOIN e07t ON e07t~trkorr = e070~trkorr AND e07t~langu = @sy-langu
      WHERE e070~as4user    = @sy-uname
        AND e070~trfunction = @lv_type
        AND e070~trstatus   = 'D'
        AND e070c~client    = @sy-mandt
      ORDER BY e070~trkorr DESCENDING
      INTO TABLE @DATA(lt_own).
    IF sy-subrc <> 0.
      CLEAR lt_own.
    ENDIF.

    SELECT request~trkorr, e07t~as4text FROM e070 AS request
      INNER JOIN e070 AS task ON task~strkorr = request~trkorr
      INNER JOIN e070c ON e070c~trkorr = request~trkorr
      LEFT OUTER JOIN e07t ON e07t~trkorr = request~trkorr AND e07t~langu = @sy-langu
      WHERE task~as4user       = @sy-uname
        AND task~trstatus      = 'D'
        AND request~trfunction = @lv_type
        AND request~trstatus   IN ('D', 'L')
        AND e070c~client       = @sy-mandt
      ORDER BY request~trkorr DESCENDING
      INTO TABLE @DATA(lt_member).
    IF sy-subrc <> 0.
      CLEAR lt_member.
    ENDIF.

    LOOP AT lt_own INTO DATA(ls_request).
      INSERT VALUE #( trkorr = ls_request-trkorr text = ls_request-as4text ) INTO TABLE rt_transports.
    ENDLOOP.
    LOOP AT lt_member INTO ls_request.
      IF NOT line_exists( rt_transports[ trkorr = ls_request-trkorr ] ).
        INSERT VALUE #( trkorr = ls_request-trkorr text = ls_request-as4text ) INTO TABLE rt_transports.
      ENDIF.
    ENDLOOP.
    SORT rt_transports BY trkorr DESCENDING.

    DATA lt_use TYPE ty_request_use.
    SELECT username, trfunction, category, client, fixtype, ordernum, validity FROM e070use
      WHERE username = @sy-uname
      ORDER BY PRIMARY KEY
      INTO CORRESPONDING FIELDS OF TABLE @lt_use.
    IF sy-subrc <> 0.
      CLEAR lt_use.
    ENDIF.
    DATA(lv_preferred) = preferred_transport( it_transports = rt_transports
                                              it_use        = lt_use
                                              iv_type       = iv_type
                                              iv_client     = sy-mandt
                                              iv_today      = sy-datum ).
    IF lv_preferred IS NOT INITIAL.
      READ TABLE rt_transports INTO DATA(ls_preferred) WITH KEY trkorr = lv_preferred.
      IF sy-subrc = 0.
        DELETE rt_transports INDEX sy-tabix.
        INSERT ls_preferred INTO rt_transports INDEX 1.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD preferred_transport.
    " as TR_TASK_GET: a standard request has no type, only its category;
    " customizing ones are per client
    DATA(lv_category) = SWITCH trcateg( iv_type WHEN `K` THEN `SYST` WHEN `W` THEN `CUST` ).
    DATA(lv_client) = COND mandt( WHEN lv_category = `CUST` THEN iv_client ).
    IF lv_category IS NOT INITIAL.
      LOOP AT it_use INTO DATA(ls_use) WHERE fixtype = 'S' AND trfunction = space
          AND category = lv_category AND client = lv_client AND validity >= iv_today.
        IF line_exists( it_transports[ trkorr = ls_use-ordernum ] ).
          rv_trkorr = ls_use-ordernum.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDIF.
    LOOP AT it_use INTO ls_use WHERE fixtype = 'U' AND trfunction = iv_type
        AND ( client = iv_client OR client = space ).
      IF line_exists( it_transports[ trkorr = ls_use-ordernum ] ).
        rv_trkorr = ls_use-ordernum.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD merge_decisions.

    LOOP AT it_fresh INTO DATA(ls_fresh).
      READ TABLE it_posted INTO DATA(ls_posted)
        WITH KEY obj_type = ls_fresh-obj_type obj_name = ls_fresh-obj_name.
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( |{ ls_fresh-obj_type } { ls_fresh-obj_name } is new since the preview| ).
      ENDIF.
      " a tick given to an import must not turn into a delete or an overwrite
      IF ls_posted-group <> ls_fresh-group.
        zcx_abapgit_exception=>raise( |{ ls_fresh-obj_type } { ls_fresh-obj_name } is { ls_fresh-group } now, | &&
                                      |not { ls_posted-group }| ).
      ENDIF.
      " the server decides what can be ticked, not the client
      ls_fresh-selected = xsdbool( ls_posted-selected = abap_true AND ls_fresh-selectable = abap_true ).
      INSERT ls_fresh INTO TABLE rt_items.
    ENDLOOP.

    LOOP AT it_posted INTO ls_posted WHERE selected = abap_true.
      IF NOT line_exists( it_fresh[ obj_type = ls_posted-obj_type obj_name = ls_posted-obj_name ] ).
        zcx_abapgit_exception=>raise( |{ ls_posted-obj_type } { ls_posted-obj_name } is no longer part of the pull| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD apply_decisions.

    FIELD-SYMBOLS <ls_row> TYPE zif_abapgit_definitions=>ty_overwrite.

    rs_checks = is_checks.

    " every row of every table gets a decision, so abapGit's checks_adjust
    " never finds one without
    LOOP AT rs_checks-overwrite ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.
    LOOP AT rs_checks-warning_package ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.
    LOOP AT rs_checks-data_loss ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.
    LOOP AT rs_checks-delete_tabl_with_data ASSIGNING <ls_row>.
      <ls_row>-decision = decide( it_items = it_items is_object = <ls_row> ).
    ENDLOOP.

    IF rs_checks-requirements-met = zif_abapgit_definitions=>c_no
        OR rs_checks-dependencies-met = zif_abapgit_definitions=>c_no.
      IF iv_acknowledged = abap_false.
        zcx_abapgit_exception=>raise( `Requirements or dependencies are not met and were not acknowledged` ).
      ENDIF.
      rs_checks-requirements-decision = zif_abapgit_definitions=>c_yes.
      rs_checks-dependencies-decision = zif_abapgit_definitions=>c_yes.
    ENDIF.

  ENDMETHOD.

  METHOD decide.

    READ TABLE it_items INTO DATA(ls_item)
      WITH KEY obj_type = CONV string( is_object-obj_type )
               obj_name = CONV string( is_object-obj_name ).
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |{ is_object-obj_type } { is_object-obj_name } was not in the preview| ).
    ENDIF.

    " skipped items cannot be ticked in the dialog, so selected alone decides
    rv_decision = COND #( WHEN ls_item-selected = abap_true
                          THEN zif_abapgit_definitions=>c_yes
                          ELSE zif_abapgit_definitions=>c_no ).

  ENDMETHOD.

  METHOD compact.

    DATA lt_keep TYPE STANDARD TABLE OF abap_bool WITH EMPTY KEY.
    DATA lv_gap TYPE i.

    IF it_lines IS INITIAL.
      RETURN.
    ENDIF.

    " mark every change and its context
    DATA(lv_lines) = lines( it_lines ).
    DO lv_lines TIMES.
      INSERT abap_false INTO TABLE lt_keep.
    ENDDO.
    LOOP AT it_lines INTO DATA(ls_line) WHERE kind <> zif_ag2ui5_repo_service=>c_line_kind-same.
      DATA(lv_from) = nmax( val1 = 1        val2 = sy-tabix - iv_context ).
      DATA(lv_to)   = nmin( val1 = lv_lines val2 = sy-tabix + iv_context ).
      DATA(lv_index) = lv_from.
      WHILE lv_index <= lv_to.
        lt_keep[ lv_index ] = abap_true.
        lv_index = lv_index + 1.
      ENDWHILE.
    ENDLOOP.

    IF NOT line_exists( lt_keep[ table_line = abap_true ] ).
      INSERT VALUE #( text = |No differences ({ lv_lines } lines)|
                      kind = zif_ag2ui5_repo_service=>c_line_kind-gap ) INTO TABLE rt_lines.
      RETURN.
    ENDIF.

    " copy what is kept, fold each unkept run into one gap line
    LOOP AT it_lines INTO ls_line.
      IF lt_keep[ sy-tabix ] = abap_true.
        IF lv_gap > 0.
          INSERT VALUE #( text = |... { lv_gap } unchanged lines ...|
                          kind = zif_ag2ui5_repo_service=>c_line_kind-gap ) INTO TABLE rt_lines.
          lv_gap = 0.
        ENDIF.
        INSERT ls_line INTO TABLE rt_lines.
      ELSE.
        lv_gap = lv_gap + 1.
      ENDIF.
    ENDLOOP.
    IF lv_gap > 0.
      INSERT VALUE #( text = |... { lv_gap } unchanged lines ...|
                      kind = zif_ag2ui5_repo_service=>c_line_kind-gap ) INTO TABLE rt_lines.
    ENDIF.

  ENDMETHOD.

  METHOD map_diff.

    DATA lt_changed_old TYPE zif_ag2ui5_repo_service=>ty_diff_lines.
    DATA lt_changed_new TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    " which of our sides is abapGit's "new" and "old"
    DATA(lv_new_kind) = COND zif_ag2ui5_repo_service=>ty_line_kind(
      WHEN iv_remote_is_new = abap_true THEN zif_ag2ui5_repo_service=>c_line_kind-remote
      ELSE zif_ag2ui5_repo_service=>c_line_kind-local ).
    DATA(lv_old_kind) = COND zif_ag2ui5_repo_service=>ty_line_kind(
      WHEN iv_remote_is_new = abap_true THEN zif_ag2ui5_repo_service=>c_line_kind-local
      ELSE zif_ag2ui5_repo_service=>c_line_kind-remote ).

    LOOP AT it_diff INTO DATA(ls_diff).
      DATA(lv_new_num) = condense( CONV string( ls_diff-new_num ) ).
      DATA(lv_old_num) = condense( CONV string( ls_diff-old_num ) ).
      DATA(ls_new) = VALUE zif_ag2ui5_repo_service=>ty_diff_line( text = visible( ls_diff-new ) kind = lv_new_kind ).
      DATA(ls_old) = VALUE zif_ag2ui5_repo_service=>ty_diff_line( text = visible( ls_diff-old ) kind = lv_old_kind ).
      IF iv_remote_is_new = abap_true.
        ls_new-remote_num = lv_new_num.
        ls_old-local_num  = lv_old_num.
      ELSE.
        ls_new-local_num  = lv_new_num.
        ls_old-remote_num = lv_old_num.
      ENDIF.
      " the patch ID uses abapGit's numbers, which set_patch_new/_old use too
      ls_new-patch_id = COND #( WHEN ls_diff-result = zif_abapgit_definitions=>c_diff-insert
                                  OR ls_diff-result = zif_abapgit_definitions=>c_diff-update
                                THEN |N{ lv_new_num }| ).
      ls_old-patch_id = COND #( WHEN ls_diff-result = zif_abapgit_definitions=>c_diff-delete
                                THEN |O{ lv_old_num }|
                                WHEN ls_diff-result = zif_abapgit_definitions=>c_diff-update
                                THEN |N{ lv_new_num }| ).

      " a run of changed lines is shown as a block: all old lines, then all
      " new ones, as git and abapGit's unified view do
      IF ls_diff-result = zif_abapgit_definitions=>c_diff-update.
        INSERT ls_old INTO TABLE lt_changed_old.
        INSERT ls_new INTO TABLE lt_changed_new.
        CONTINUE.
      ENDIF.
      INSERT LINES OF lt_changed_old INTO TABLE rt_lines.
      INSERT LINES OF lt_changed_new INTO TABLE rt_lines.
      CLEAR: lt_changed_old, lt_changed_new.

      CASE ls_diff-result.
        WHEN zif_abapgit_definitions=>c_diff-insert.
          INSERT ls_new INTO TABLE rt_lines.
        WHEN zif_abapgit_definitions=>c_diff-delete.
          INSERT ls_old INTO TABLE rt_lines.
        WHEN OTHERS.
          ls_new-kind = zif_ag2ui5_repo_service=>c_line_kind-same.
          IF iv_remote_is_new = abap_true.
            ls_new-local_num = lv_old_num.
          ELSE.
            ls_new-remote_num = lv_old_num.
          ENDIF.
          INSERT ls_new INTO TABLE rt_lines.
      ENDCASE.
    ENDLOOP.
    INSERT LINES OF lt_changed_old INTO TABLE rt_lines.
    INSERT LINES OF lt_changed_new INTO TABLE rt_lines.

  ENDMETHOD.

  METHOD visible.

    rv_text = iv_text.

    " abapGit's diff appends a form feed when only one side ends in a newline
    DATA(lv_length) = strlen( rv_text ).
    IF lv_length > 0 AND substring( val = rv_text off = lv_length - 1 len = 1 ) = cl_abap_char_utilities=>form_feed.
      rv_text = |{ substring( val = rv_text len = lv_length - 1 ) } (no newline at end of file)|.
    ENDIF.

    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf(1) IN rv_text WITH `[CR]`.

    DO 32 TIMES.
      DATA(lv_code) = sy-index - 1.
      IF lv_code = 9.
        CONTINUE.
      ENDIF.
      DATA(lv_char) = cl_abap_conv_in_ce=>uccpi( lv_code ).
      REPLACE ALL OCCURRENCES OF lv_char IN rv_text WITH `?`.
    ENDDO.

  ENDMETHOD.

  METHOD method_components.

    DATA lt_tokens TYPE STANDARD TABLE OF stokesx WITH EMPTY KEY.
    DATA lt_statements TYPE STANDARD TABLE OF sstmnt WITH EMPTY KEY.
    DATA lv_owner TYPE string.
    DATA lv_visibility TYPE string.
    DATA ls_component TYPE ty_component.
    DATA lv_macro TYPE abap_bool.
    CLEAR: et_components, ev_supported.
    IF it_source IS INITIAL.
      ev_supported = abap_true.
      RETURN.
    ENDIF.
    SCAN ABAP-SOURCE it_source TOKENS INTO lt_tokens
      STATEMENTS INTO lt_statements WITH ANALYSIS WITHOUT TRMAC.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    LOOP AT lt_statements INTO DATA(ls_statement).
      READ TABLE lt_tokens INTO DATA(ls_first) INDEX ls_statement-from.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      READ TABLE lt_tokens INTO DATA(ls_last) INDEX ls_statement-to.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      DATA(lv_second_index) = ls_statement-from + 1.
      DATA(ls_second) = VALUE stokesx( lt_tokens[ lv_second_index ] OPTIONAL ).
      IF ls_first-str = 'DEFINE'.
        IF ls_component-name IS NOT INITIAL.
          RETURN.
        ENDIF.
        lv_macro = abap_true.
      ELSEIF ls_first-str = 'END-OF-DEFINITION'.
        lv_macro = abap_false.
        CONTINUE.
      ENDIF.
      IF lv_macro = abap_true.
        CONTINUE.
      ENDIF.
      CASE ls_first-str.
        WHEN 'CLASS' OR 'INTERFACE'.
          IF ls_component-name IS NOT INITIAL OR lv_owner IS NOT INITIAL.
            RETURN.
          ENDIF.
          " Forward declarations have no method scope.
          DATA(lv_forward) = abap_false.
          LOOP AT lt_tokens INTO DATA(ls_header_token) FROM ls_statement-from TO ls_statement-to.
            IF ls_header_token-str = 'DEFERRED' OR ls_header_token-str = 'LOAD'.
              lv_forward = abap_true.
            ENDIF.
          ENDLOOP.
          DATA(ls_fourth) = VALUE stokesx( lt_tokens[ ls_statement-from + 3 ] OPTIONAL ).
          DATA(ls_fifth) = VALUE stokesx( lt_tokens[ ls_statement-from + 4 ] OPTIONAL ).
          IF ls_fourth-str = 'LOCAL' AND ls_fifth-str = 'FRIENDS'.
            lv_forward = abap_true.
          ENDIF.
          IF lv_forward = abap_true.
            CONTINUE.
          ENDIF.
          lv_owner = ls_second-str.
          lv_visibility = COND #( WHEN ls_first-str = 'INTERFACE' THEN `PUBLIC` ELSE `PRIVATE` ).
        WHEN 'ENDCLASS' OR 'ENDINTERFACE'.
          IF ls_component-name IS NOT INITIAL OR lv_owner IS INITIAL.
            RETURN.
          ENDIF.
          CLEAR lv_owner.
        WHEN 'PUBLIC' OR 'PROTECTED' OR 'PRIVATE'.
          IF ls_second-str = 'SECTION'.
            lv_visibility = ls_first-str.
          ENDIF.
        WHEN 'METHODS' OR 'CLASS-METHODS' OR 'METHOD'.
          IF lv_owner IS INITIAL OR ls_component-name IS NOT INITIAL OR ls_second-str IS INITIAL.
            RETURN.
          ENDIF.
          ls_component = VALUE #( owner = lv_owner name = ls_second-str
            kind = COND #( WHEN ls_first-str = 'METHOD' THEN `Implementation` ELSE `Declaration` )
            first = COND #( WHEN ls_statement-prefixlen > 0 THEN ls_second-row ELSE ls_first-row ) last = ls_last-row ).
          IF ls_component-kind = `Declaration`.
            ls_component-tokens = lv_visibility.
          ENDIF.
        WHEN 'ENDMETHOD'.
          IF ls_component-name IS INITIAL OR ls_component-kind <> `Implementation`.
            RETURN.
          ENDIF.
      ENDCASE.
      IF ls_component-name IS INITIAL.
        CONTINUE.
      ENDIF.
      LOOP AT lt_tokens INTO DATA(ls_token) FROM ls_statement-from TO ls_statement-to.
        " Delimit by length: literals and escaped identifiers stay distinct.
        ls_component-tokens = |{ ls_component-tokens }{ strlen( ls_token-str ) }:{ ls_token-str };|.
      ENDLOOP.
      ls_component-last = ls_last-row.
      IF ls_component-kind = `Declaration` OR ls_first-str = 'ENDMETHOD'.
        INSERT ls_component INTO TABLE et_components.
        IF sy-subrc <> 0.
          RETURN.
        ENDIF.
        CLEAR ls_component.
      ENDIF.
    ENDLOOP.
    ev_supported = xsdbool( lv_owner IS INITIAL AND ls_component-name IS INITIAL AND lv_macro = abap_false ).

  ENDMETHOD.

  METHOD semantic_diff.

    method_components( EXPORTING it_source = it_local
      IMPORTING et_components = DATA(lt_local) ev_supported = DATA(lv_local_supported) ).
    method_components( EXPORTING it_source = it_remote
      IMPORTING et_components = DATA(lt_remote) ev_supported = DATA(lv_remote_supported) ).
    IF lv_local_supported = abap_false OR lv_remote_supported = abap_false.
      rs_semantic-note = `Structural summary unavailable for this source; review the raw diff.`.
      RETURN.
    ENDIF.
    DATA(lt_keys) = lt_local.
    LOOP AT lt_remote INTO DATA(ls_remote).
      IF NOT line_exists( lt_keys[ owner = ls_remote-owner kind = ls_remote-kind name = ls_remote-name ] ).
        INSERT ls_remote INTO TABLE lt_keys.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_keys INTO DATA(ls_key).
      DATA(ls_local) = VALUE ty_component( lt_local[ owner = ls_key-owner kind = ls_key-kind name = ls_key-name ] OPTIONAL ).
      ls_remote = VALUE #( lt_remote[ owner = ls_key-owner kind = ls_key-kind name = ls_key-name ] OPTIONAL ).
      IF ls_local-name IS NOT INITIAL AND ls_remote-name IS NOT INITIAL AND ls_local-tokens = ls_remote-tokens.
        CONTINUE.
      ENDIF.
      DATA(lv_new_exists) = COND abap_bool( WHEN iv_remote_is_new = abap_true
        THEN xsdbool( ls_remote-name IS NOT INITIAL ) ELSE xsdbool( ls_local-name IS NOT INITIAL ) ).
      DATA(lv_old_exists) = COND abap_bool( WHEN iv_remote_is_new = abap_true
        THEN xsdbool( ls_local-name IS NOT INITIAL ) ELSE xsdbool( ls_remote-name IS NOT INITIAL ) ).
      DATA(lv_action) = COND string( WHEN lv_old_exists = abap_false THEN `added`
        WHEN lv_new_exists = abap_false THEN `removed` ELSE `changed` ).
      DATA(lv_side) = COND string( WHEN iv_remote_is_new = abap_true THEN `Git` ELSE `this system` ).
      INSERT VALUE #( id = |{ ls_key-owner }/{ ls_key-kind }/{ ls_key-name }|
        owner = ls_key-owner name = ls_key-name component = ls_key-kind action = lv_action
        text = |{ ls_key-owner } / { ls_key-name }: { to_lower( ls_key-kind ) } { lv_action } in { lv_side }|
        local_from = ls_local-first local_to = ls_local-last
        remote_from = ls_remote-first remote_to = ls_remote-last ) INTO TABLE rs_semantic-changes.
    ENDLOOP.
    rs_semantic-note = `Method declarations and implementations only. Comments and formatting stay in the raw diff; summaries do not predict behavior.`.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_diff.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_repo( iv_key = iv_key iv_zip = iv_zip ).
    read_file_pair( EXPORTING ii_repo          = li_repo
                              iv_path          = iv_path
                              iv_filename      = iv_filename
                              iv_remote_sha1   = iv_remote_sha1
                              iv_remote_known  = iv_remote_known
                    IMPORTING ev_local         = DATA(lv_local)
                              ev_remote        = DATA(lv_remote) ).
    rs_diff-fingerprint = fingerprint( iv_local = lv_local iv_remote = lv_remote ).

    IF zcl_abapgit_utils=>is_binary( COND #( WHEN lv_local IS NOT INITIAL THEN lv_local ELSE lv_remote ) ) = abap_true.
      rs_diff-binary = abap_true.
      RETURN.
    ENDIF.

    " abapGit's convention: the side that changed is new - the remote when
    " only Git changed, otherwise the system
    rs_diff-remote_is_new = iv_remote_is_new.
    IF iv_remote_is_new = abap_true.
      DATA(li_diff) = zcl_abapgit_diff_factory=>get( )->create( iv_new = lv_remote iv_old = lv_local ).
    ELSE.
      li_diff = zcl_abapgit_diff_factory=>get( )->create( iv_new = lv_local iv_old = lv_remote ).
    ENDIF.
    IF to_lower( iv_filename ) CP '*.clas*.abap' OR to_lower( iv_filename ) CP '*.intf.abap'.
      DATA lt_local_source TYPE string_table.
      DATA lt_remote_source TYPE string_table.
      SPLIT zcl_abapgit_convert=>xstring_to_string_utf8( lv_local ) AT cl_abap_char_utilities=>newline INTO TABLE lt_local_source.
      SPLIT zcl_abapgit_convert=>xstring_to_string_utf8( lv_remote ) AT cl_abap_char_utilities=>newline INTO TABLE lt_remote_source.
      rs_diff-semantic = semantic_diff( it_local = lt_local_source it_remote = lt_remote_source iv_remote_is_new = iv_remote_is_new ).
      LOOP AT rs_diff-semantic-changes ASSIGNING FIELD-SYMBOL(<ls_change>).
        <ls_change>-path = iv_path.
        <ls_change>-filename = iv_filename.
        IF iv_zip IS NOT INITIAL AND iv_remote_is_new = abap_true.
          REPLACE FIRST OCCURRENCE OF ` in Git` IN <ls_change>-text WITH ` in ZIP`.
        ENDIF.
      ENDLOOP.
    ENDIF.
    rs_diff-lines = map_diff( it_diff = li_diff->get( ) iv_remote_is_new = iv_remote_is_new ).
    LOOP AT rs_diff-lines TRANSPORTING NO FIELDS WHERE kind = zif_ag2ui5_repo_service=>c_line_kind-local.
      rs_diff-local_count = rs_diff-local_count + 1.
    ENDLOOP.
    LOOP AT rs_diff-lines TRANSPORTING NO FIELDS WHERE kind = zif_ag2ui5_repo_service=>c_line_kind-remote.
      rs_diff-remote_count = rs_diff-remote_count + 1.
    ENDLOOP.

  ENDMETHOD.

  METHOD read_file_pair.

    CLEAR: ev_local, ev_remote.

    " only the file's object is serialized and read, as in abapGit's diff page
    zcl_abapgit_filename_logic=>file_to_object(
      EXPORTING iv_filename = iv_filename
                iv_path     = iv_path
                io_dot      = ii_repo->get_dot_abapgit( )
                iv_devclass = ii_repo->get_package( )
      IMPORTING es_item     = DATA(ls_item) ).
    DATA(li_filter) = CAST zif_abapgit_object_filter( NEW zcl_ag2ui5_object_filter( is_item = ls_item ) ).

    DATA(lv_found) = abap_false.
    LOOP AT ii_repo->get_files_local_filtered( li_filter ) INTO DATA(ls_local)
        WHERE file-path = iv_path AND file-filename = iv_filename.
      ev_local = ls_local-file-data.
      lv_found = abap_true.
      EXIT.
    ENDLOOP.
    remote_file( EXPORTING ii_repo         = ii_repo
                           ii_filter       = li_filter
                           iv_path         = iv_path
                           iv_filename     = iv_filename
                           iv_remote_sha1  = iv_remote_sha1
                           iv_remote_known = iv_remote_known
                 IMPORTING ev_data         = ev_remote
                           ev_found        = DATA(lv_remote_found) ).
    IF lv_remote_found = abap_true.
      lv_found = abap_true.
    ENDIF.
    IF lv_found = abap_false.
      zcx_abapgit_exception=>raise( |File not found: { iv_path }{ iv_filename }| ).
    ENDIF.

  ENDMETHOD.

  METHOD remote_file.

    CLEAR: ev_data, ev_found.

    IF iv_remote_known = abap_true AND ii_repo->is_offline( ) = abap_false.
      IF iv_remote_sha1 IS INITIAL.
        " the row says the file is only in the system
        RETURN.
      ENDIF.
      DATA(lv_sha1) = to_lower( iv_remote_sha1 ).
      IF strlen( lv_sha1 ) = 40 AND lv_sha1 CO `0123456789abcdef`.
        READ TABLE gt_blobs INTO DATA(ls_blob) WITH TABLE KEY sha1 = lv_sha1.
        IF sy-subrc = 0.
          ev_data  = ls_blob-data.
          ev_found = abap_true.
          RETURN.
        ENDIF.
        TRY.
            ev_data = checked_blob(
              it_objects = blob_source( )->fetch( iv_url  = CAST zif_abapgit_repo_online( ii_repo )->get_url( )
                                                  iv_sha1 = CONV #( lv_sha1 ) )
              iv_sha1    = lv_sha1 ).
            INSERT VALUE #( sha1 = lv_sha1 data = ev_data ) INTO TABLE gt_blobs.
            ev_found = abap_true.
            RETURN.
          CATCH zcx_abapgit_exception INTO DATA(lx_error).
            " the full fetch would ask for the same credentials
            IF login_required( lx_error ) = abap_true.
              RAISE EXCEPTION lx_error.
            ENDIF.
            " a server that refuses single objects: the whole repository
          CATCH cx_root.
            " malformed protocol or pack data can also raise runtime exceptions
        ENDTRY.
      ENDIF.
    ENDIF.

    LOOP AT ii_repo->get_files_remote( iv_ignore_files = abap_true
                                       ii_obj_filter   = ii_filter ) INTO DATA(ls_remote)
        USING KEY file_path WHERE path = iv_path AND filename = iv_filename.
      ev_data  = ls_remote-data.
      ev_found = abap_true.
      EXIT.
    ENDLOOP.

  ENDMETHOD.

  METHOD checked_blob.

    IF lines( it_objects ) <> 1.
      zcx_abapgit_exception=>raise( |Git sent { lines( it_objects ) } objects for { iv_sha1 }| ).
    ENDIF.
    DATA(ls_object) = it_objects[ 1 ].
    IF ls_object-type <> zif_abapgit_git_definitions=>c_type-blob
        OR to_lower( zcl_abapgit_hash=>sha1_blob( ls_object-data ) ) <> to_lower( iv_sha1 ).
      zcx_abapgit_exception=>raise( |Git sent another object for { iv_sha1 }| ).
    ENDIF.
    rv_data = ls_object-data.

  ENDMETHOD.

  METHOD blob_source.
    IF gi_blob_source IS NOT BOUND.
      gi_blob_source = NEW zcl_ag2ui5_blob_source( ).
    ENDIF.
    ri_source = gi_blob_source.
  ENDMETHOD.

  METHOD remote_sha1.
    READ TABLE it_remote INTO DATA(ls_file)
      WITH KEY file_path COMPONENTS path = iv_path filename = iv_filename.
    IF sy-subrc = 0.
      rv_sha1 = to_lower( ls_file-sha1 ).
    ENDIF.
  ENDMETHOD.

  METHOD remote_is_new.
    rv_yes = xsdbool( iv_lstate IS INITIAL AND iv_rstate IS NOT INITIAL ).
  ENDMETHOD.

  METHOD to_side_by_side.

    DATA lt_old TYPE zif_ag2ui5_repo_service=>ty_diff_lines.
    DATA lt_new TYPE zif_ag2ui5_repo_service=>ty_diff_lines.

    DATA(lv_old_kind) = COND zif_ag2ui5_repo_service=>ty_line_kind(
      WHEN iv_remote_is_new = abap_true THEN zif_ag2ui5_repo_service=>c_line_kind-local
      ELSE zif_ag2ui5_repo_service=>c_line_kind-remote ).

    " the trailing empty line flushes the last changed block
    DATA(lt_lines) = it_lines.
    INSERT VALUE #( kind = zif_ag2ui5_repo_service=>c_line_kind-gap ) INTO TABLE lt_lines.
    DATA(lv_last) = lines( lt_lines ).

    LOOP AT lt_lines INTO DATA(ls_line).
      DATA(lv_index) = sy-tabix.
      IF ls_line-kind <> zif_ag2ui5_repo_service=>c_line_kind-same
          AND ls_line-kind <> zif_ag2ui5_repo_service=>c_line_kind-gap.
        IF ls_line-kind = lv_old_kind.
          INSERT ls_line INTO TABLE lt_old.
        ELSE.
          INSERT ls_line INTO TABLE lt_new.
        ENDIF.
        CONTINUE.
      ENDIF.

      " pair the changed block line by line, the shorter side stays empty
      DO nmax( val1 = lines( lt_old ) val2 = lines( lt_new ) ) TIMES.
        DATA(ls_row) = VALUE zif_ag2ui5_repo_service=>ty_sbs_row( ).
        READ TABLE lt_old INTO DATA(ls_old) INDEX sy-index.
        IF sy-subrc = 0.
          ls_row-old_text    = ls_old-text.
          ls_row-old_num     = COND #( WHEN iv_remote_is_new = abap_true THEN ls_old-local_num ELSE ls_old-remote_num ).
          ls_row-old_changed = abap_true.
        ENDIF.
        READ TABLE lt_new INTO DATA(ls_new) INDEX sy-index.
        IF sy-subrc = 0.
          ls_row-new_text    = ls_new-text.
          ls_row-new_num     = COND #( WHEN iv_remote_is_new = abap_true THEN ls_new-remote_num ELSE ls_new-local_num ).
          ls_row-new_changed = abap_true.
        ENDIF.
        INSERT ls_row INTO TABLE rt_rows.
      ENDDO.
      CLEAR: lt_old, lt_new.

      IF lv_index = lv_last.
        EXIT.
      ENDIF.
      IF ls_line-kind = zif_ag2ui5_repo_service=>c_line_kind-gap.
        INSERT VALUE #( old_text = ls_line-text gap = abap_true ) INTO TABLE rt_rows.
      ELSE.
        INSERT VALUE #( old_num  = COND #( WHEN iv_remote_is_new = abap_true THEN ls_line-local_num ELSE ls_line-remote_num )
                        old_text = ls_line-text
                        new_num  = COND #( WHEN iv_remote_is_new = abap_true THEN ls_line-remote_num ELSE ls_line-local_num )
                        new_text = ls_line-text ) INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD tinted_html.

    " the colours of GitHub's diff; sap.m.FormattedText keeps this style
    DATA(lv_color) = SWITCH string( iv_tint
                                    WHEN `ADDED`   THEN `#e6ffec`
                                    WHEN `REMOVED` THEN `#ffebe9`
                                    WHEN `GAP`     THEN `#f6f8fa` ).
    rv_html = COND #( WHEN lv_color IS INITIAL THEN iv_html
                      ELSE |<span style="display:block;min-height:1em;background-color:{ lv_color }">{ iv_html }</span>| ).

  ENDMETHOD.

  METHOD code_html.

    " tabs as four blanks, then blanks that HTML would collapse as &nbsp;:
    " all leading ones (indentation), and inside the line every second one of
    " a run, so aligned columns survive and long lines can still wrap
    DATA(lv_text) = replace( val  = iv_text
                             sub  = cl_abap_char_utilities=>horizontal_tab
                             with = `    `
                             occ  = 0 ).
    DATA(lv_rest) = shift_left( lv_text ).
    DATA(lv_indent) = strlen( lv_text ) - strlen( lv_rest ).
    lv_rest = escape( val = lv_rest format = cl_abap_format=>e_xml_text ).
    WHILE lv_rest CS `  `.
      lv_rest = replace( val = lv_rest sub = `  ` with = `&nbsp; ` occ = 0 ).
    ENDWHILE.
    rv_html = |<code>{ repeat( val = `&nbsp;` occ = lv_indent ) }{ lv_rest }</code>|.

  ENDMETHOD.

  METHOD counts_text.

    rv_text = COND #( WHEN iv_remote_is_new = abap_true
                      THEN |+{ iv_remote } in Git, -{ iv_local } in this system|
                      ELSE |+{ iv_local } in this system, -{ iv_remote } in Git| ).

  ENDMETHOD.

  METHOD branch_display.
    rv_display = iv_branch.
    IF find( val = iv_branch sub = `refs/heads/` ) = 0.
      rv_display = substring( val = iv_branch off = 11 ).
    ELSEIF find( val = iv_branch sub = `refs/tags/` ) = 0.
      rv_display = |Tag { substring( val = iv_branch off = 10 ) }|.
    ENDIF.
  ENDMETHOD.

  METHOD branch_link.
    IF iv_branch IS INITIAL OR ( find( val = iv_branch sub = `refs/heads/` ) <> 0
                                AND find( val = iv_branch sub = `refs/tags/` ) <> 0 ).
      RETURN.
    ENDIF.
    DATA(lv_url) = iv_url.
    REPLACE REGEX `/+$` IN lv_url WITH `` ##REGEX_POSIX.
    REPLACE REGEX `\.git$` IN lv_url WITH `` ##REGEX_POSIX.
    " Match the authority exactly; never turn another URI scheme into a link.
    FIND REGEX `^https?://(www\.)?(github\.com|gitlab\.com|bitbucket\.org)/[^?#@]+$`
      IN lv_url IGNORING CASE ##REGEX_POSIX.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    DATA(lv_short) = substring( val = iv_branch off = COND i( WHEN iv_branch CP `refs/tags/*` THEN 10 ELSE 11 ) ).
    DATA(lv_branch) = cl_http_utility=>escape_url( lv_short ).
    DATA(lv_lower) = to_lower( lv_url ).
    IF lv_lower CP `*://gitlab.com/*` OR lv_lower CP `*://www.gitlab.com/*`.
      rv_link = |{ lv_url }/-/tree/{ lv_branch }|.
    ELSEIF lv_lower CP `*://bitbucket.org/*` OR lv_lower CP `*://www.bitbucket.org/*`.
      rv_link = |{ lv_url }/src/{ lv_branch }/|.
    ELSE.
      rv_link = |{ lv_url }/tree/{ lv_branch }|.
    ENDIF.
  ENDMETHOD.

  METHOD branch_rows.

    LOOP AT it_branches INTO DATA(ls_branch) WHERE name IS NOT INITIAL.
      " the remote's HEAD is listed next to the branch it points to
      IF ls_branch-is_head = abap_true AND iv_head_symref IS NOT INITIAL AND ls_branch-name <> iv_head_symref.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( name    = ls_branch-name
                      display = ls_branch-display_name
                      default = xsdbool( ls_branch-name = iv_head_symref
                                         OR ( iv_head_symref IS INITIAL AND ls_branch-is_head = abap_true ) )
                      current = xsdbool( ls_branch-name = iv_current )
                      sha1    = ls_branch-sha1 ) INTO TABLE rt_branches.
    ENDLOOP.
    SORT rt_branches BY default DESCENDING display ASCENDING.

  ENDMETHOD.

  METHOD assert_branch.

    IF iv_branch IS INITIAL OR NOT line_exists( it_branches[ name = iv_branch ] ).
      zcx_abapgit_exception=>raise( |Branch { iv_branch } is not on the remote| ).
    ENDIF.

  ENDMETHOD.

  METHOD switch_needed.
    rv_needed = xsdbool( iv_selected <> iv_branch OR iv_commit IS NOT INITIAL OR iv_origin IS NOT INITIAL ).
  ENDMETHOD.

  METHOD registered_url.

    IF iv_switched_origin IS INITIAL.
      rv_url = iv_url.
      RETURN.
    ENDIF.
    DATA(lv_offs) = find( val = reverse( iv_switched_origin ) sub = `@` ).
    IF lv_offs = -1 OR lv_offs = strlen( iv_switched_origin ) - 1.
      zcx_abapgit_exception=>raise( `Incorrect format of switched origin` ).
    ENDIF.
    rv_url = substring( val = iv_switched_origin len = strlen( iv_switched_origin ) - lv_offs - 1 ).

  ENDMETHOD.

  METHOD branch_name.

    " as abapGit's normalize_branch_name and complete_heads_branch_name
    rv_branch = condense( val = iv_name del = ` ` from = `` ).
    rv_branch = replace( val = rv_branch sub = ` ` with = `-` occ = 0 ).
    IF rv_branch NP `refs/heads/*`.
      rv_branch = |refs/heads/{ rv_branch }|.
    ENDIF.

  ENDMETHOD.

  METHOD assert_branch_name.

    DATA(lv_short) = COND string( WHEN iv_branch CP `refs/heads/*` THEN substring( val = iv_branch off = 11 ) ).
    IF lv_short IS INITIAL.
      zcx_abapgit_exception=>raise( `Enter a name for the new branch` ).
    ENDIF.
    " Git's rules for a ref name (git check-ref-format)
    FIND REGEX `\.\.|[~^:?*\[\\]|[[:cntrl:]]|^[/.]|[/.]$|//|\.lock$` IN lv_short.
    IF sy-subrc = 0.
      zcx_abapgit_exception=>raise( |{ lv_short } is no valid branch name: no .., ~ ^ : ? * [ \\, | &&
                                    |control characters or //, and it may not start or end with / or . or end with .lock| ).
    ENDIF.

  ENDMETHOD.

  METHOD assert_new_branch.

    IF line_exists( it_branches[ name = iv_branch ] ).
      zcx_abapgit_exception=>raise( |Branch { substring( val = iv_branch off = 11 ) } already exists| ).
    ENDIF.

  ENDMETHOD.

  METHOD push_branch.

    IF condense( iv_new_branch ) = ``.
      RETURN.
    ENDIF.
    rv_branch = branch_name( iv_new_branch ).
    assert_branch_name( rv_branch ).
    assert_new_branch( iv_branch = rv_branch it_branches = it_branches ).

  ENDMETHOD.

  METHOD assert_deletable.

    READ TABLE it_branches INTO DATA(ls_branch) WITH KEY name = iv_branch.
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( |Branch { iv_branch } is not on the remote| ).
    ENDIF.
    IF ls_branch-default = abap_true.
      zcx_abapgit_exception=>raise( |{ ls_branch-display } is the default branch and cannot be deleted| ).
    ENDIF.
    IF ls_branch-current = abap_true.
      zcx_abapgit_exception=>raise( |{ ls_branch-display } is the branch this repository follows - switch first| ).
    ENDIF.
    " the user confirmed this commit; somebody pushed since
    IF iv_sha1 IS NOT INITIAL AND iv_sha1 <> ls_branch-sha1.
      zcx_abapgit_exception=>raise( |{ ls_branch-display } has moved to { substring( val = ls_branch-sha1 len = 7 ) } | &&
                                    |since the list was loaded - nothing was deleted. Open the list again.| ).
    ENDIF.

  ENDMETHOD.

  METHOD assert_tag_context.
    IF iv_commit IS NOT INITIAL OR iv_origin IS NOT INITIAL.
      zcx_abapgit_exception=>raise( `Select a branch or tag on the registered remote before using Tags` ).
    ENDIF.
  ENDMETHOD.

  METHOD tag_commit.
    IF iv_sha1 IS NOT INITIAL AND line_exists( it_objects[
        sha1 = CONV zif_abapgit_git_definitions=>ty_sha1( iv_sha1 )
        type = zif_abapgit_git_definitions=>c_type-commit ] ).
      rv_sha1 = iv_sha1.
    ENDIF.
  ENDMETHOD.

  METHOD read_tag_commit.
    IF iv_sha1 IS INITIAL.
      RETURN.
    ENDIF.
    DATA lt_objects TYPE zif_abapgit_definitions=>ty_objects_tt.
    TRY.
        zcl_abapgit_git_transport=>upload_pack_by_commit(
          EXPORTING iv_url = iv_url iv_hash = CONV #( iv_sha1 ) iv_deepen_level = 1
          IMPORTING et_objects = lt_objects ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        IF login_required( lx_error ) = abap_true.
          RAISE EXCEPTION lx_error.
        ENDIF.
        " Unavailable/unverifiable objects remain deletable by their raw ref.
        RETURN.
    ENDTRY.
    rv_sha1 = tag_commit( iv_sha1 = iv_sha1 it_objects = lt_objects ).
  ENDMETHOD.

  METHOD tag_rows.
    LOOP AT it_tags INTO DATA(ls_tag) WHERE name IS NOT INITIAL.
      IF ls_tag-name NP `refs/tags/*` OR ls_tag-name CP `*^{}` OR strlen( ls_tag-name ) <= 10.
        CONTINUE.
      ENDIF.
      IF line_exists( rt_tags[ name = ls_tag-name ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_sha1) = CONV string( ls_tag-sha1 ).
      DATA(lv_kind) = `Lightweight`.
      READ TABLE it_tags INTO DATA(ls_peeled) WITH KEY name = |{ ls_tag-name }^\{\}|.
      IF sy-subrc = 0.
        lv_sha1 = ls_peeled-sha1.
        lv_kind = `Annotated`.
      ELSEIF ls_tag-type = zif_abapgit_git_definitions=>c_git_branch_type-annotated_tag.
        " Do not show a tag object's hash as a commit or switch an unresolved tag.
        CLEAR lv_sha1.
        lv_kind = `Annotated`.
      ENDIF.
      APPEND VALUE #( ref_sha1 = ls_tag-sha1 name = ls_tag-name display = substring( val = ls_tag-name off = 10 )
        sha1 = lv_sha1 kind = lv_kind current = xsdbool( ls_tag-name = iv_current ) ) TO rt_tags.
    ENDLOOP.
    SORT rt_tags BY display DESCENDING.
  ENDMETHOD.

  METHOD checked_new_tag.
    DATA(lv_name) = is_tag-name.
    IF lv_name CP `refs/tags/*`.
      lv_name = substring( val = lv_name off = 10 ).
    ENDIF.
    FIND REGEX `\.\.|[ ~^:?*\[\\]|[[:cntrl:]]|^[/.]|[/.]$|//|(^|/)\.|\.lock(/|$)` IN lv_name.
    IF sy-subrc = 0 OR lv_name IS INITIAL OR lv_name CP `refs/*` OR lv_name = `@` OR lv_name CS `@{`.
      zcx_abapgit_exception=>raise( `Enter a valid Git tag name, for example v1.0.0 (no spaces or special ref characters)` ).
    ENDIF.
    rs_tag-name = |refs/tags/{ lv_name }|.
    IF line_exists( it_tags[ name = rs_tag-name ] ).
      zcx_abapgit_exception=>raise( |Tag { lv_name } already exists| ).
    ENDIF.
    IF is_expected-ref IS INITIAL OR is_expected-sha1 IS INITIAL
        OR is_expected-ref <> is_actual-ref OR is_expected-sha1 <> is_actual-sha1.
      zcx_abapgit_exception=>raise( `The target changed. Go Back and reopen New tag to review the current commit.` ).
    ENDIF.
    rs_tag-sha1 = is_actual-sha1.
    CASE is_tag-kind.
      WHEN `LIGHTWEIGHT`.
        rs_tag-type = zif_abapgit_git_definitions=>c_git_branch_type-lightweight_tag.
      WHEN `ANNOTATED`.
        IF condense( is_tag-message ) = `` OR condense( is_tag-tagger_name ) = ``
            OR condense( is_tag-tagger_email ) = ``.
          zcx_abapgit_exception=>raise( `Annotated tags need a message, author name and email` ).
        ENDIF.
        FIND REGEX `[<>]|[[:cntrl:]]` IN is_tag-tagger_name.
        IF sy-subrc = 0.
          zcx_abapgit_exception=>raise( `Author name cannot contain angle brackets or control characters` ).
        ENDIF.
        FIND REGEX `[[:cntrl:]]` IN is_tag-tagger_email.
        IF sy-subrc = 0.
          zcx_abapgit_exception=>raise( `Author email cannot contain control characters` ).
        ENDIF.
        FIND REGEX `^[^ <>[:cntrl:]@]+@[^ <>[:cntrl:]@]+$` IN is_tag-tagger_email.
        IF sy-subrc <> 0.
          zcx_abapgit_exception=>raise( `Enter a valid author email` ).
        ENDIF.
        rs_tag-type = zif_abapgit_git_definitions=>c_git_branch_type-annotated_tag.
        rs_tag-message = is_tag-message.
        rs_tag-tagger_name = is_tag-tagger_name.
        rs_tag-tagger_email = is_tag-tagger_email.
      WHEN OTHERS.
        zcx_abapgit_exception=>raise( `Choose Lightweight or Annotated` ).
    ENDCASE.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~tag_target.
    silence_progress( ).
    assert_authorized( ).
    IF iv_key IS INITIAL OR iv_key CN `0123456789` OR strlen( iv_key ) > 12.
      zcx_abapgit_exception=>raise( `Choose a registered repository` ).
    ENDIF.
    DATA(li_repo) = get_online_repo( iv_key ).
    assert_tag_context( iv_commit = li_repo->get_selected_commit( ) iv_origin = li_repo->get_switched_origin( ) ).
    rs_target-ref = li_repo->get_selected_branch( ).
    DATA(li_list) = zcl_abapgit_git_factory=>get_git_transport( )->branches( li_repo->get_url( ) ).
    IF rs_target-ref CP `refs/tags/*`.
      DATA(lt_tags) = tag_rows( it_tags = li_list->get_tags_only( ) iv_current = rs_target-ref ).
      READ TABLE lt_tags INTO DATA(ls_tag) WITH KEY name = rs_target-ref.
      IF sy-subrc = 0.
        rs_target-sha1 = read_tag_commit( iv_url = li_repo->get_url( ) iv_sha1 = ls_tag-sha1 ).
      ENDIF.
    ELSEIF rs_target-ref CP `refs/heads/*`.
      DATA(lt_branches) = li_list->get_branches_only( ).
      READ TABLE lt_branches INTO DATA(ls_branch) WITH KEY name = rs_target-ref.
      IF sy-subrc = 0.
        rs_target-sha1 = ls_branch-sha1.
      ENDIF.
    ENDIF.
    IF rs_target-sha1 IS INITIAL.
      zcx_abapgit_exception=>raise( `The selected reference has no resolved remote commit` ).
    ENDIF.
    DATA(li_user) = zcl_abapgit_persist_factory=>get_user( ).
    rs_target-name = li_user->get_repo_git_user_name( li_repo->get_url( ) ).
    rs_target-email = li_user->get_repo_git_user_email( li_repo->get_url( ) ).
    IF rs_target-name IS INITIAL.
      rs_target-name = li_user->get_default_git_user_name( ).
    ENDIF.
    IF rs_target-email IS INITIAL.
      rs_target-email = li_user->get_default_git_user_email( ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~create_tag.
    silence_progress( ).
    assert_authorized( ).
    DATA(ls_actual) = zif_ag2ui5_repo_service~tag_target( iv_key ).
    DATA(ls_tag) = checked_new_tag( is_tag = is_tag is_expected = is_expected is_actual = ls_actual
      it_tags = list_tag_refs( iv_key ) ).
    zcl_abapgit_git_porcelain=>create_tag( iv_url = get_online_repo( iv_key )->get_url( ) is_tag = ls_tag ).
    COMMIT WORK AND WAIT.
    rv_tag = ls_tag-name.
  ENDMETHOD.

  METHOD assert_deletable_tag.
    IF iv_tag NP `refs/tags/*` OR iv_tag CP `*^{}`.
      zcx_abapgit_exception=>raise( `Choose a tag from the remote list` ).
    ENDIF.
    READ TABLE it_tags INTO DATA(ls_tag) WITH KEY name = iv_tag.
    IF sy-subrc <> 0 OR ls_tag-ref_sha1 IS INITIAL.
      zcx_abapgit_exception=>raise( `The tag is no longer available. Reopen Tags.` ).
    ENDIF.
    IF ls_tag-current = abap_true.
      zcx_abapgit_exception=>raise( `This repository follows the tag. Switch to another reference before deleting it.` ).
    ENDIF.
    IF iv_ref_sha1 IS INITIAL OR iv_ref_sha1 <> ls_tag-ref_sha1.
      zcx_abapgit_exception=>raise( `The tag changed since the list was loaded. Nothing was deleted. Reopen Tags.` ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~delete_tag.
    silence_progress( ).
    assert_authorized( ).
    DATA(lt_tags) = list_tag_refs( iv_key ).
    assert_deletable_tag( iv_tag = iv_tag iv_ref_sha1 = iv_ref_sha1 it_tags = lt_tags ).
    DATA(ls_tag) = lt_tags[ name = iv_tag ].
    " Always pass the unpeeled ref and its raw object hash. Porcelain then
    " uses that hash as receive-pack's expected old value for either tag type,
    " instead of refetching an annotated tag and losing the confirmation guard.
    zcl_abapgit_git_porcelain=>delete_tag( iv_url = get_online_repo( iv_key )->get_url( )
      is_tag = VALUE #( name = ls_tag-name sha1 = ls_tag-ref_sha1 ) ).
    COMMIT WORK AND WAIT.
  ENDMETHOD.

  METHOD assert_tag.
    IF iv_tag NP `refs/tags/*` OR iv_tag CP `*^{}`.
      zcx_abapgit_exception=>raise( `Choose a tag from the remote list` ).
    ENDIF.
    READ TABLE it_tags INTO DATA(ls_tag) WITH KEY name = iv_tag.
    IF sy-subrc <> 0 OR ls_tag-sha1 IS INITIAL.
      zcx_abapgit_exception=>raise( `The tag is no longer available as a resolved commit. Reopen Tags.` ).
    ENDIF.
    IF iv_sha1 <> ls_tag-sha1.
      zcx_abapgit_exception=>raise( `The tag moved since the list was loaded. Reopen Tags before switching.` ).
    ENDIF.
  ENDMETHOD.

  METHOD list_tag_refs.
    silence_progress( ).
    assert_authorized( ).
    IF iv_key IS INITIAL OR iv_key CN `0123456789` OR strlen( iv_key ) > 12.
      zcx_abapgit_exception=>raise( `Choose a registered repository` ).
    ENDIF.
    DATA(li_repo) = get_online_repo( iv_key ).
    assert_tag_context( iv_commit = li_repo->get_selected_commit( ) iv_origin = li_repo->get_switched_origin( ) ).
    DATA(li_list) = zcl_abapgit_git_factory=>get_git_transport( )->branches( li_repo->get_url( ) ).
    rt_tags = tag_rows( it_tags = li_list->get_tags_only( ) iv_current = li_repo->get_selected_branch( ) ).
    LOOP AT rt_tags ASSIGNING FIELD-SYMBOL(<ls_tag>).
      <ls_tag>-link = branch_link( iv_url = li_repo->get_url( ) iv_branch = <ls_tag>-name ).
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_tags.
    " The targets as the remote lists them: one fetch per tag made long lists
    " slow (31 tags: 19 s). switch_tag and tag_target verify the commit before
    " anything is written; a tag on a tree or blob is refused only there.
    rt_tags = list_tag_refs( iv_key ).
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~switch_tag.
    " Fresh remote refs are authoritative, including the peeled commit.
    assert_tag( iv_tag = iv_tag iv_sha1 = iv_sha1 it_tags = list_tag_refs( iv_key ) ).
    DATA(li_repo) = get_online_repo( iv_key ).
    IF read_tag_commit( iv_url = li_repo->get_url( ) iv_sha1 = iv_sha1 ) IS INITIAL.
      zcx_abapgit_exception=>raise( `The tag target is not a commit. Choose another tag.` ).
    ENDIF.
    li_repo->select_commit( '' ).
    li_repo->switch_origin( '' ).
    li_repo->select_branch( iv_tag ).
    COMMIT WORK AND WAIT.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_branches.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    DATA(li_list) = zcl_abapgit_git_factory=>get_git_transport( )->branches( li_repo->get_url( ) ).
    rt_branches = branch_rows( it_branches    = li_list->get_branches_only( )
                               iv_head_symref = li_list->get_head_symref( )
                               iv_current     = li_repo->get_selected_branch( ) ).
    IF rt_branches IS INITIAL.
      zcx_abapgit_exception=>raise( `The remote has no branches` ).
    ENDIF.

    LOOP AT rt_branches ASSIGNING FIELD-SYMBOL(<ls_branch>).
      <ls_branch>-link = branch_link( iv_url = li_repo->get_url( ) iv_branch = <ls_branch>-name ).
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~switch_branch.

    " The name comes from the browser and is checked against a fresh list.
    " With another origin switched in, list_branches would list the fork, but
    " the reset below selects the branch on the registered remote: check there
    assert_authorized( ).
    silence_progress( ).
    DATA(li_repo) = get_online_repo( iv_key ).
    DATA lt_branches TYPE zif_ag2ui5_repo_service=>ty_branches.
    IF li_repo->get_switched_origin( ) IS INITIAL.
      lt_branches = zif_ag2ui5_repo_service~list_branches( iv_key ).
    ELSE.
      DATA(lv_url) = registered_url( iv_url = li_repo->get_url( ) iv_switched_origin = li_repo->get_switched_origin( ) ).
      lt_branches = branch_rows(
        it_branches    = zcl_abapgit_git_factory=>get_git_transport( )->branches( lv_url )->get_branches_only( )
        iv_head_symref = ``
        iv_current     = `` ).
    ENDIF.
    assert_branch( iv_branch = iv_branch it_branches = lt_branches ).

    IF switch_needed( iv_selected = li_repo->get_selected_branch( ) iv_branch = iv_branch
        iv_commit = li_repo->get_selected_commit( ) iv_origin = li_repo->get_switched_origin( ) ) = abap_false.
      RETURN.
    ENDIF.

    " as abapGit's switch_branch: a fixed commit or another origin is reset
    li_repo->select_commit( '' ).
    li_repo->switch_origin( '' ).
    li_repo->select_branch( iv_branch ).
    " abap2UI5 rolls back after main( )
    COMMIT WORK AND WAIT.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~create_branch.

    assert_authorized( ).
    silence_progress( ).

    " the name comes from the browser
    rv_branch = branch_name( iv_name ).
    assert_branch_name( rv_branch ).
    assert_new_branch( iv_branch   = rv_branch
                       it_branches = zif_ag2ui5_repo_service~list_branches( iv_key ) ).

    " abapGit pushes the new ref at the current head and follows it
    get_online_repo( iv_key )->create_branch( rv_branch ).
    " abap2UI5 rolls back after main( )
    COMMIT WORK AND WAIT.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~delete_branch.

    assert_authorized( ).
    silence_progress( ).

    " the name comes from the browser; the commit comes from a fresh list
    DATA(lt_branches) = zif_ag2ui5_repo_service~list_branches( iv_key ).
    assert_deletable( iv_branch   = iv_branch
                      iv_sha1     = iv_sha1
                      it_branches = lt_branches ).
    DATA(ls_branch) = lt_branches[ name = iv_branch ].

    zcl_abapgit_git_porcelain=>delete_branch(
      iv_url    = get_online_repo( iv_key )->get_url( )
      is_branch = VALUE #( name = ls_branch-name sha1 = ls_branch-sha1 display_name = ls_branch-display ) ).
    rv_sha1 = ls_branch-sha1.

  ENDMETHOD.

  METHOD fingerprint.

    " each side hashed on its own, so no two pairs share a fingerprint
    rv_fingerprint = |{ zcl_abapgit_hash=>sha1_raw( iv_local ) }{ zcl_abapgit_hash=>sha1_raw( iv_remote ) }|.

  ENDMETHOD.

  METHOD apply_patch.

    IF it_ids IS INITIAL.
      zcx_abapgit_exception=>raise( `No lines picked` ).
    ENDIF.

    rt_diff = it_diff.
    LOOP AT it_ids INTO DATA(lv_id).
      " the IDs come from the browser
      IF strlen( lv_id ) < 2 OR NOT ( lv_id(1) = `N` OR lv_id(1) = `O` ).
        zcx_abapgit_exception=>raise( |Line { lv_id } is not a change| ).
      ENDIF.
      DATA(lv_side) = substring( val = lv_id len = 1 ).
      DATA(lv_num)  = substring( val = lv_id off = 1 ).
      DATA(lv_hit)  = abap_false.
      LOOP AT rt_diff ASSIGNING FIELD-SYMBOL(<ls_diff>).
        IF ( lv_side = `N` AND condense( CONV string( <ls_diff>-new_num ) ) = lv_num
             AND ( <ls_diff>-result = zif_abapgit_definitions=>c_diff-insert
                OR <ls_diff>-result = zif_abapgit_definitions=>c_diff-update ) )
        OR ( lv_side = `O` AND condense( CONV string( <ls_diff>-old_num ) ) = lv_num
             AND <ls_diff>-result = zif_abapgit_definitions=>c_diff-delete ).
          <ls_diff>-patch_flag = abap_true.
          lv_hit = abap_true.
        ENDIF.
      ENDLOOP.
      IF lv_hit = abap_false.
        zcx_abapgit_exception=>raise( |Line { lv_id } is not a change| ).
      ENDIF.
    ENDLOOP.

    " abapGit's diff marks a last line without newline with a form feed when
    " only one side has one; the patch is built from these texts, so the
    " marker would be committed
    LOOP AT rt_diff ASSIGNING <ls_diff>.
      <ls_diff>-old = replace( val = <ls_diff>-old regex = |{ cl_abap_char_utilities=>form_feed }$| with = `` ).
      <ls_diff>-new = replace( val = <ls_diff>-new regex = |{ cl_abap_char_utilities=>form_feed }$| with = `` ).
    ENDLOOP.

  ENDMETHOD.

  METHOD patch_lstate.

    " every row flagged, as abapGit's are_all_lines_patched counts: an added
    " or deleted file has no unchanged rows, so this is "every change picked"
    DATA(lv_all) = xsdbool( NOT line_exists( it_diff[ patch_flag = abap_false ] ) ).
    rv_lstate = COND #( WHEN lv_all = abap_true AND ( iv_lstate = `D` OR iv_lstate = `A` ) THEN iv_lstate
                        ELSE `M` ).

  ENDMETHOD.

  METHOD stage_candidates.

    DATA(lt_results) = it_results.
    IF is_files IS SUPPLIED.
      CLEAR lt_results.
      " Classic staging compares file contents, independently of the baseline.
      LOOP AT is_files-local INTO DATA(ls_local).
        DATA(ls_status) = VALUE zif_abapgit_definitions=>ty_result(
          it_results[ path = ls_local-file-path filename = ls_local-file-filename ] OPTIONAL ).
        ls_status-path = ls_local-file-path.
        ls_status-filename = ls_local-file-filename.
        ls_status-obj_type = ls_local-item-obj_type.
        ls_status-obj_name = ls_local-item-obj_name.
        ls_status-match = abap_false.
        ls_status-lstate = COND #( WHEN ls_status-rstate = `D` THEN `A`
          WHEN ls_status-lstate IS INITIAL THEN `M` ELSE ls_status-lstate ).
        INSERT ls_status INTO TABLE lt_results.
      ENDLOOP.
      LOOP AT is_files-remote INTO DATA(ls_remote).
        ls_status = VALUE #( it_results[ path = ls_remote-path filename = ls_remote-filename ] OPTIONAL ).
        ls_status-path = ls_remote-path.
        ls_status-filename = ls_remote-filename.
        ls_status-match = abap_false.
        ls_status-lstate = `D`.
        INSERT ls_status INTO TABLE lt_results.
      ENDLOOP.
    ENDIF.
    IF is_dot IS SUPPLIED.
      DATA(lo_dot) = NEW zcl_abapgit_dot_abapgit( is_dot ).
    ENDIF.
    LOOP AT lt_results INTO DATA(ls_result) WHERE match = abap_false.
      IF ls_result-lstate IS INITIAL AND ls_result-rstate IS INITIAL.
        CONTINUE.
      ENDIF.
      IF lo_dot IS BOUND AND lo_dot->is_ignored(
          iv_path = ls_result-path iv_filename = ls_result-filename ) = abap_true.
        CONTINUE.
      ENDIF.
      DATA(lv_remove) = xsdbool( ls_result-lstate = `D` OR ls_result-rstate = `A` ).
      IF is_files IS SUPPLIED.
        lv_remove = xsdbool( ls_result-lstate = `D` ).
      ENDIF.
      IF ls_result-path = `/` AND ls_result-filename = `.abapgit.xml` AND lv_remove = abap_true.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( path     = ls_result-path
                      filename = ls_result-filename
                      obj_type = ls_result-obj_type
                      obj_name = ls_result-obj_name
                      lstate   = ls_result-lstate
                      rstate   = ls_result-rstate
                      action   = COND #( WHEN lv_remove = abap_true
                                         THEN zif_ag2ui5_repo_service=>c_stage_action-rm
                                         ELSE zif_ag2ui5_repo_service=>c_stage_action-add ) )
        INTO TABLE rt_items.
    ENDLOOP.

  ENDMETHOD.

  METHOD assert_ignore_preview.
    IF is_expected <> is_fresh.
      zcx_abapgit_exception=>raise( `The files or ignore rules changed; preview again before saving` ).
    ENDIF.
  ENDMETHOD.

  METHOD change_ignore_rules.
    rs_dot = is_dot.
    IF iv_remove = abap_true.
      IF NOT line_exists( rs_dot-ignore[ table_line = iv_rule ] ).
        zcx_abapgit_exception=>raise( `The ignore rule no longer exists; reload the rules` ).
      ENDIF.
      DELETE rs_dot-ignore WHERE table_line = iv_rule.
      RETURN.
    ENDIF.
    IF iv_remove <> abap_false OR iv_rule IS INITIAL OR strlen( iv_rule ) > 255 OR iv_rule(1) <> `/`.
      zcx_abapgit_exception=>raise( `Enter a rule beginning with / (maximum 255 characters)` ).
    ENDIF.
    DO 33 TIMES.
      DATA(lv_code) = COND i( WHEN sy-index = 33 THEN 127 ELSE sy-index - 1 ).
      IF iv_rule CS cl_abap_conv_in_ce=>uccpi( lv_code ).
        zcx_abapgit_exception=>raise( `An ignore rule must be a single line without control characters` ).
      ENDIF.
    ENDDO.
    IF iv_rule = `/.abapgit.xml` OR iv_rule = `/.apack-manifest.xml`.
      zcx_abapgit_exception=>raise( `Repository metadata cannot be ignored` ).
    ENDIF.
    IF line_exists( rs_dot-ignore[ table_line = iv_rule ] ).
      zcx_abapgit_exception=>raise( `This ignore rule already exists` ).
    ENDIF.
    APPEND iv_rule TO rs_dot-ignore.
  ENDMETHOD.

  METHOD ignore_preview.
    DATA(ls_after) = change_ignore_rules( is_dot = is_dot iv_rule = iv_rule iv_remove = iv_remove ).
    rs_preview = VALUE #( rule = iv_rule remove = iv_remove rules = is_dot-ignore ).
    DATA lt_before TYPE zif_ag2ui5_repo_service=>ty_stage_items.
    DATA lt_after TYPE zif_ag2ui5_repo_service=>ty_stage_items.
    IF is_files IS SUPPLIED.
      lt_before = stage_candidates( it_results = it_results is_dot = is_dot is_files = is_files ).
      lt_after = stage_candidates( it_results = it_results is_dot = ls_after is_files = is_files ).
    ELSE.
      lt_before = stage_candidates( it_results = it_results is_dot = is_dot ).
      lt_after = stage_candidates( it_results = it_results is_dot = ls_after ).
    ENDIF.
    DATA(lt_source) = COND #( WHEN iv_remove = abap_true THEN lt_after ELSE lt_before ).
    DATA(lt_other) = COND #( WHEN iv_remove = abap_true THEN lt_before ELSE lt_after ).
    LOOP AT lt_source INTO DATA(ls_item).
      IF NOT line_exists( lt_other[ path = ls_item-path filename = ls_item-filename ] ).
        APPEND ls_item TO rs_preview-files.
      ENDIF.
    ENDLOOP.
    SORT rs_preview-files BY path filename.
    IF iv_remove = abap_false AND rs_preview-files IS INITIAL.
      zcx_abapgit_exception=>raise( `This rule does not exclude any current staging files` ).
    ENDIF.
  ENDMETHOD.

  METHOD ignore_repo_preview.
    DATA(ls_dot) = ii_repo->zif_abapgit_repo~get_dot_abapgit( )->get_data( ).
    DATA ls_files TYPE zif_abapgit_definitions=>ty_stage_files.
    IF iv_remove = abap_true.
      " Serialize previously hidden objects on an unregistered copy. No
      " setter, listener or persistence call is involved in this preview.
      DATA(ls_data) = ii_repo->zif_abapgit_repo~ms_data.
      ls_data-dot_abapgit = change_ignore_rules( is_dot = ls_dot iv_rule = iv_rule iv_remove = abap_true ).
      DATA(lo_copy) = NEW zcl_abapgit_repo_online( ls_data ).
      lo_copy->set_files_remote( ii_repo->zif_abapgit_repo~get_files_remote( ) ).
      ls_files = zcl_abapgit_stage_logic=>get_stage_logic( )->get( lo_copy ).
    ELSE.
      ls_files = zcl_abapgit_stage_logic=>get_stage_logic( )->get( ii_repo ).
    ENDIF.
    rs_preview = ignore_preview( it_results = CONV zif_abapgit_definitions=>ty_results_tt( ls_files-status ) is_dot = ls_dot iv_rule = iv_rule
      iv_remove = iv_remove is_files = ls_files ).
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~preview_ignore.
    assert_authorized( ).
    silence_progress( ).
    DATA(li_repo) = get_online_repo( iv_key ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).
    rs_preview = ignore_repo_preview( ii_repo = li_repo iv_rule = iv_rule iv_remove = iv_remove ).
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~save_ignore.
    assert_authorized( ).
    silence_progress( ).
    DATA(li_repo) = get_online_repo( iv_key ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).
    DATA(ls_dot) = li_repo->zif_abapgit_repo~get_dot_abapgit( )->get_data( ).
    DATA(ls_fresh) = ignore_repo_preview( ii_repo = li_repo
      iv_rule = is_preview-rule iv_remove = is_preview-remove ).
    assert_ignore_preview( is_expected = is_preview is_fresh = ls_fresh ).
    DATA(ls_after) = change_ignore_rules( is_dot = ls_dot iv_rule = is_preview-rule iv_remove = is_preview-remove ).
    li_repo->zif_abapgit_repo~set_dot_abapgit( NEW zcl_abapgit_dot_abapgit( ls_after ) ).
    COMMIT WORK AND WAIT.
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).
  ENDMETHOD.

  METHOD check_selection.

    LOOP AT it_selected INTO DATA(ls_selected) WHERE selected = abap_true.
      READ TABLE it_fresh INTO DATA(ls_fresh)
        WITH KEY path = ls_selected-path filename = ls_selected-filename.
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( |{ ls_selected-filename } no longer differs between SAP and Git| ).
      ENDIF.
      IF ls_fresh-action <> ls_selected-action OR ls_fresh-rstate <> ls_selected-rstate.
        zcx_abapgit_exception=>raise( |{ ls_selected-filename } changed again since the page was loaded| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD check_push_allowed.

    LOOP AT it_items INTO DATA(ls_item) WHERE selected = abap_true.
      " as abapGit's stage page: a file added in one folder while it still
      " exists in another must be removed there in the same commit - wholly,
      " a removal with only some lines picked keeps the file
      IF ls_item-action = zif_ag2ui5_repo_service=>c_stage_action-add.
        LOOP AT it_items INTO DATA(ls_other)
            WHERE filename = ls_item-filename AND path <> ls_item-path
              AND NOT ( selected = abap_true AND action = zif_ag2ui5_repo_service=>c_stage_action-rm
                        AND patch_ids IS INITIAL ).
          zcx_abapgit_exception=>raise( |{ ls_item-filename } also exists in { ls_other-path } - | &&
                                        |select its removal too| ).
        ENDLOOP.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD commit_message.

    rv_text = COND #( WHEN iv_body IS INITIAL
                      THEN iv_title
                      ELSE |{ iv_title }{ cl_abap_char_utilities=>newline }{ cl_abap_char_utilities=>newline }{ iv_body }| ).

  ENDMETHOD.

  METHOD owner_of.

    " as abapGit's read_user: the first request that holds the object
    READ TABLE it_owners INTO DATA(ls_owner)
      WITH KEY obj_type = iv_obj_type obj_name = iv_obj_name.
    rv_user = COND #( WHEN sy-subrc = 0 AND ls_owner-as4user IS NOT INITIAL
                      THEN ls_owner-as4user
                      ELSE c_user_unknown ).

  ENDMETHOD.

  METHOD assign_changed_by.

    LOOP AT ct_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      READ TABLE it_local_users INTO DATA(ls_local)
        WITH KEY path = <ls_item>-path filename = <ls_item>-filename.
      IF sy-subrc = 0.
        <ls_item>-changed_by = COND #( WHEN ls_local-user IS NOT INITIAL THEN ls_local-user ELSE c_user_unknown ).
      ELSE.
        <ls_item>-changed_by = owner_of( it_owners   = it_owners
                                         iv_obj_type = <ls_item>-obj_type
                                         iv_obj_name = <ls_item>-obj_name ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD only_in_git.

    rv_only_git = xsdbool( iv_lstate = zif_abapgit_definitions=>c_state-deleted
                           OR ( iv_lstate IS INITIAL AND iv_rstate = zif_abapgit_definitions=>c_state-added ) ).

  ENDMETHOD.

  METHOD transport_owners.

    " only the files that also exist in Git: abapGit looks up only those
    DATA lt_objects TYPE ty_object_owners.
    DATA lr_names TYPE RANGE OF e071-obj_name.
    lt_objects = it_objects.
    LOOP AT lt_objects INTO DATA(ls_object).
      INSERT VALUE #( sign = 'I' option = 'EQ' low = CONV e071-obj_name( ls_object-obj_name ) ) INTO TABLE lr_names.
    ENDLOOP.
    IF lr_names IS NOT INITIAL.
      " one read for all of them, ordered by request: the first row found for
      " an object is its first request; the type is checked here
      SELECT e071~object AS obj_type, e071~obj_name AS obj_name,
             e071~trkorr AS trkorr, e070~as4user AS as4user
        FROM e071
        INNER JOIN e070 ON e070~trkorr = e071~trkorr
        WHERE e071~pgmid    = 'R3TR'
          AND e071~obj_name IN @lr_names
        ORDER BY e071~trkorr ASCENDING
        INTO TABLE @DATA(lt_found) ##SUBRC_OK.
      LOOP AT lt_found INTO DATA(ls_found).
        CHECK line_exists( lt_objects[ obj_type = ls_found-obj_type obj_name = ls_found-obj_name ] ).
        CHECK NOT line_exists( rt_owners[ obj_type = ls_found-obj_type obj_name = ls_found-obj_name ] ).
        INSERT VALUE #( obj_type = ls_found-obj_type obj_name = ls_found-obj_name
                        trkorr = ls_found-trkorr as4user = ls_found-as4user ) INTO TABLE rt_owners.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_stage.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).
    IF li_repo->get_selected_branch( ) CP `refs/tags/*`.
      zcx_abapgit_exception=>raise( `Switch to a branch before staging or pushing changes` ).
    ENDIF.
    rs_stage-branch = branch_display( li_repo->get_selected_branch( ) ).

    DATA(ls_files) = zcl_abapgit_stage_logic=>get_stage_logic( )->get( li_repo ).
    rs_stage-items = stage_candidates( it_results = CONV zif_abapgit_definitions=>ty_results_tt( ls_files-status ) is_files = ls_files
      is_dot = li_repo->zif_abapgit_repo~get_dot_abapgit( )->get_data( ) ).
    rs_stage-ignore_rules = li_repo->zif_abapgit_repo~get_dot_abapgit( )->get_data( )-ignore.
    " as abapGit: a file in SAP names the object's last changer, a file only
    " in Git the owner of the object's first transport request
    DATA lt_local_users TYPE ty_file_users.
    LOOP AT ls_files-local INTO DATA(ls_local) WHERE item IS NOT INITIAL.
      INSERT VALUE #( path = ls_local-file-path filename = ls_local-file-filename
                      user = zcl_abapgit_objects=>changed_by( is_item     = ls_local-item
                                                              iv_filename = ls_local-file-filename ) )
        INTO TABLE lt_local_users.
    ENDLOOP.
    DATA lt_remote_objects TYPE ty_object_owners.
    LOOP AT rs_stage-items INTO DATA(ls_item) WHERE obj_type IS NOT INITIAL.
      IF NOT line_exists( lt_local_users[ path = ls_item-path filename = ls_item-filename ] ).
        INSERT VALUE #( obj_type = ls_item-obj_type obj_name = ls_item-obj_name ) INTO TABLE lt_remote_objects.
      ENDIF.
    ENDLOOP.
    assign_changed_by( EXPORTING it_local_users = lt_local_users
                                 it_owners      = transport_owners( lt_remote_objects )
                       CHANGING  ct_items       = rs_stage-items ).
    " stage logic fetched and cached the full list; its remote list omits local files
    DATA(lt_remote) = li_repo->zif_abapgit_repo~get_files_remote( iv_ignore_files = abap_true ).
    DATA lt_links TYPE ty_object_links.
    LOOP AT rs_stage-items ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-remote_sha1 = remote_sha1( it_remote = lt_remote iv_path = <ls_row>-path
                                          iv_filename = <ls_row>-filename ).

      <ls_row>-object_link = object_link( EXPORTING iv_obj_type = <ls_row>-obj_type
                                                   iv_obj_name = <ls_row>-obj_name
                                         CHANGING ct_links = lt_links ).
    ENDLOOP.

    " the committer abapGit remembers for this repository, else the user's default
    DATA(li_user) = zcl_abapgit_persist_factory=>get_user( ).
    rs_stage-name  = li_user->get_repo_git_user_name( li_repo->get_url( ) ).
    rs_stage-email = li_user->get_repo_git_user_email( li_repo->get_url( ) ).
    IF rs_stage-name IS INITIAL.
      rs_stage-name = li_user->get_default_git_user_name( ).
    ENDIF.
    IF rs_stage-email IS INITIAL.
      rs_stage-email = li_user->get_default_git_user_email( ).
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~commit_push.

    DATA lt_objects TYPE zif_abapgit_definitions=>ty_items_tt.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    IF li_repo->get_selected_branch( ) CP `refs/tags/*`.
      zcx_abapgit_exception=>raise( `Switch to a branch before staging or pushing changes` ).
    ENDIF.

    " the name comes from the browser: checked against a fresh list
    " before anything is written
    DATA(lv_new_branch) = COND string(
      WHEN is_commit-new_branch IS NOT INITIAL
      THEN push_branch( iv_new_branch = is_commit-new_branch
                        it_branches   = zif_ag2ui5_repo_service~list_branches( iv_key ) ) ).

    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).
    " the head the selection is checked against; a new branch starts here
    DATA(lv_head) = li_repo->get_current_remote( ).
    DATA(ls_files) = zcl_abapgit_stage_logic=>get_stage_logic( )->get( li_repo ).
    DATA(lt_fresh) = stage_candidates( it_results = CONV zif_abapgit_definitions=>ty_results_tt( ls_files-status ) is_files = ls_files
      is_dot = li_repo->zif_abapgit_repo~get_dot_abapgit( )->get_data( ) ).

    " check again - the system or the remote may have changed since the page loaded
    TRY.
        check_selection( it_fresh    = lt_fresh
                         it_selected = it_items ).
      CATCH zcx_abapgit_exception.
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-changed.
        RETURN.
    ENDTRY.

    " from here on only the fresh state counts, the client's rows only say
    " which files are selected
    LOOP AT lt_fresh ASSIGNING FIELD-SYMBOL(<ls_fresh>).
      READ TABLE it_items INTO DATA(ls_posted)
        WITH KEY path = <ls_fresh>-path filename = <ls_fresh>-filename selected = abap_true.
      <ls_fresh>-selected = xsdbool( sy-subrc = 0 ).
      IF sy-subrc = 0.
        <ls_fresh>-patch_ids   = ls_posted-patch_ids.
        <ls_fresh>-fingerprint = ls_posted-fingerprint.
      ENDIF.
    ENDLOOP.
    check_push_allowed( lt_fresh ).

    " read only the selected objects' files
    LOOP AT lt_fresh INTO DATA(ls_item) WHERE selected = abap_true AND obj_type IS NOT INITIAL.
      INSERT VALUE #( obj_type = ls_item-obj_type obj_name = ls_item-obj_name ) INTO TABLE lt_objects.
    ENDLOOP.
    DATA(lt_local) = li_repo->zif_abapgit_repo~get_files_local_filtered(
      NEW zcl_ag2ui5_object_filter( it_items = lt_objects ) ).

    DATA(lo_stage) = NEW zcl_abapgit_stage( ).
    LOOP AT lt_fresh INTO ls_item WHERE selected = abap_true.
      IF ls_item-patch_ids IS NOT INITIAL.
        read_file_pair( EXPORTING ii_repo     = li_repo
                                  iv_path     = ls_item-path
                                  iv_filename = ls_item-filename
                        IMPORTING ev_local    = DATA(lv_local)
                                  ev_remote   = DATA(lv_remote) ).
        " the lines were picked on another version of the file
        IF fingerprint( iv_local = lv_local iv_remote = lv_remote ) <> ls_item-fingerprint.
          rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-changed.
            RETURN.
        ENDIF.
        DATA(lt_diff) = apply_patch(
          it_diff = zcl_abapgit_diff_factory=>get( )->create( iv_new = lv_local iv_old = lv_remote )->get( )
          it_ids  = ls_item-patch_ids ).
        DATA(lv_lstate) = patch_lstate( iv_lstate = ls_item-lstate it_diff = lt_diff ).
        IF lv_lstate = zif_abapgit_definitions=>c_state-deleted.
          lo_stage->rm( iv_path     = CONV #( ls_item-path )
                        iv_filename = CONV #( ls_item-filename )
                        is_status   = VALUE #( lstate = lv_lstate ) ).
        ELSE.
          lo_stage->add( iv_path     = CONV #( ls_item-path )
                         iv_filename = CONV #( ls_item-filename )
                         is_status   = VALUE #( lstate = lv_lstate )
                         iv_data     = NEW zcl_abapgit_git_add_patch( lt_diff )->get_patch_binary( ) ).
        ENDIF.
      ELSEIF ls_item-action = zif_ag2ui5_repo_service=>c_stage_action-rm.
        lo_stage->rm( iv_path = CONV #( ls_item-path ) iv_filename = CONV #( ls_item-filename ) ).
      ELSE.
        READ TABLE lt_local INTO DATA(ls_local)
          WITH KEY file-path = ls_item-path file-filename = ls_item-filename.
        IF sy-subrc <> 0.
          zcx_abapgit_exception=>raise( |File not found: { ls_item-path }{ ls_item-filename }| ).
        ENDIF.
        lo_stage->add( iv_path     = ls_local-file-path
                       iv_filename = ls_local-file-filename
                       iv_data     = ls_local-file-data ).
      ENDIF.
    ENDLOOP.

    DATA(li_user) = zcl_abapgit_persist_factory=>get_user( ).
    li_user->set_repo_git_user_name( iv_url = li_repo->get_url( ) iv_username = is_commit-name ).
    li_user->set_repo_git_user_email( iv_url = li_repo->get_url( ) iv_email = is_commit-email ).

    DATA(ls_comment) = VALUE zif_abapgit_git_definitions=>ty_comment(
      committer = VALUE #( name = is_commit-name email = is_commit-email )
      author    = VALUE #( name = is_commit-name email = is_commit-email )
      comment   = commit_message( iv_title = is_commit-title iv_body = is_commit-body ) ).

    IF lv_new_branch IS NOT INITIAL.
      " as abapGit's commit page: the repository follows the new branch
      li_repo->create_branch( iv_name = lv_new_branch iv_from = lv_head ).
    ENDIF.

    " abapGit's push without UI: exit, push, commit work, exit
    TRY.
        zcl_abapgit_repo_factory=>get_repo_push( li_repo )->push( is_comment = ls_comment
                                                                 io_stage   = lo_stage ).
      CATCH zcx_abapgit_exception INTO DATA(lx_push).
        IF lv_new_branch IS INITIAL.
          RAISE EXCEPTION lx_push.
        ENDIF.
        " the remote has the branch: keep abapGit's record of following it,
        " abap2UI5 would roll it back after main( )
        COMMIT WORK AND WAIT.
        zcx_abapgit_exception=>raise(
          |Branch { branch_display( lv_new_branch ) } was created and is now followed, | &&
          |but nothing was pushed: { lx_push->get_text( ) }| ).
    ENDTRY.
    " push( ) commits without waiting; abap2UI5 rolls back after main( )
    COMMIT WORK AND WAIT.

    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-pushed.
    rs_result-commit  = substring( val = li_repo->get_current_remote( ) len = 7 ).
    rs_result-branch  = branch_display( li_repo->get_selected_branch( ) ).

  ENDMETHOD.

  METHOD object_status_rows.

    DATA(lt_files) = it_rows.
    LOOP AT lt_files ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE obj_type IS INITIAL OR obj_name IS INITIAL.
      CLEAR: <ls_file>-obj_type, <ls_file>-obj_name, <ls_file>-object_link.
    ENDLOOP.
    lt_files = sort_status_rows( it_rows = lt_files iv_by = `OBJECT` iv_changes_first = iv_changes_first ).
    LOOP AT lt_files INTO DATA(ls_file)
        GROUP BY ( obj_type = ls_file-obj_type obj_name = ls_file-obj_name ) INTO DATA(ls_group).
      DATA(ls_object) = VALUE zif_ag2ui5_repo_service=>ty_object_status(
        obj_type = ls_group-obj_type obj_name = ls_group-obj_name ).
      LOOP AT GROUP ls_group INTO DATA(ls_member).
        ls_object-file_count = ls_object-file_count + 1.
        IF ls_member-changed = abap_true.
          ls_object-changed_count = ls_object-changed_count + 1.
          ls_object-changed = abap_true.
        ENDIF.
        IF ls_member-inactive = abap_true.
          ls_object-inactive = abap_true.
        ENDIF.
        IF ls_object-changed_by IS INITIAL.
          ls_object-changed_by = ls_member-changed_by.
        ENDIF.
        IF ls_object-object_link IS INITIAL.
          ls_object-object_link = ls_member-object_link.
        ENDIF.
        IF ls_member-lstate IS NOT INITIAL.
          ls_object-lstate = COND #( WHEN ls_object-lstate IS INITIAL THEN ls_member-lstate
                                    WHEN ls_object-lstate = ls_member-lstate THEN ls_object-lstate
                                    ELSE `MIXED` ).
        ENDIF.
        IF ls_member-rstate IS NOT INITIAL.
          ls_object-rstate = COND #( WHEN ls_object-rstate IS INITIAL THEN ls_member-rstate
                                    WHEN ls_object-rstate = ls_member-rstate THEN ls_object-rstate
                                    ELSE `MIXED` ).
        ENDIF.
      ENDLOOP.
      INSERT ls_object INTO TABLE rt_rows.
    ENDLOOP.

  ENDMETHOD.

  METHOD status_rows.

    LOOP AT it_results INTO DATA(ls_result).
      INSERT VALUE #( obj_type = ls_result-obj_type
                      obj_name = ls_result-obj_name
                      path     = ls_result-path
                      filename = ls_result-filename
                      lstate   = ls_result-lstate
                      rstate   = ls_result-rstate
                      inactive = ls_result-inactive
                      changed  = xsdbool( ls_result-match = abap_false OR ls_result-inactive = abap_true ) )
        INTO TABLE rt_rows.
    ENDLOOP.

  ENDMETHOD.

  METHOD sort_status_rows.

    TYPES:
      BEGIN OF ty_keyed,
        unchanged TYPE abap_bool,
        key1      TYPE string,
        key2      TYPE string,
        key3      TYPE string,
        row       TYPE zif_ag2ui5_repo_service=>ty_status_row,
      END OF ty_keyed.
    DATA lt_keyed TYPE STANDARD TABLE OF ty_keyed WITH EMPTY KEY.

    LOOP AT it_rows INTO DATA(ls_row).
      " case is ignored: the keys are upper case
      INSERT VALUE #( unchanged = xsdbool( iv_changes_first = abap_true AND ls_row-changed = abap_false )
                      key1      = to_upper( COND #( WHEN iv_by = `FILE` THEN ls_row-path ELSE ls_row-obj_type ) )
                      key2      = to_upper( COND #( WHEN iv_by = `FILE` THEN ls_row-filename ELSE ls_row-obj_name ) )
                      key3      = to_upper( COND #( WHEN iv_by = `OBJECT` THEN ls_row-filename ) )
                      row       = ls_row ) INTO TABLE lt_keyed.
    ENDLOOP.
    SORT lt_keyed STABLE BY unchanged key1 key2 key3.

    rt_rows = VALUE #( FOR ls_keyed IN lt_keyed ( ls_keyed-row ) ).

  ENDMETHOD.

  METHOD change_highlight.

    " one colour for every change; the Local and Remote columns tell the sides apart
    rv_highlight = COND #( WHEN iv_lstate IS NOT INITIAL OR iv_rstate IS NOT INITIAL OR iv_inactive = abap_true
                           THEN `Indication03`
                           ELSE `None` ).

  ENDMETHOD.

  METHOD checked_labels.
    zcl_abapgit_repo_labels=>validate( iv_labels ).
    IF zcl_abapgit_repo_labels=>normalize( iv_expected ) <> zcl_abapgit_repo_labels=>normalize( iv_fresh ).
      zcx_abapgit_exception=>raise( `Labels changed since this dialog was opened. Cancel and reopen Edit labels.` ).
    ENDIF.
    rv_labels = zcl_abapgit_repo_labels=>normalize( iv_labels ).
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~save_labels.
    silence_progress( ).
    assert_authorized( ).
    IF iv_key IS INITIAL OR iv_key CN `0123456789` OR strlen( iv_key ) > 12.
      zcx_abapgit_exception=>raise( `Choose a registered repository` ).
    ENDIF.
    DATA(lv_key) = CONV zif_abapgit_persistence=>ty_repo-key( iv_key ).
    DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->reload( lv_key ).
    DATA(ls_local) = li_repo->get_local_settings( ).
    DATA(lv_labels) = checked_labels( iv_labels = iv_labels iv_expected = iv_expected iv_fresh = ls_local-labels ).
    IF ls_local-labels <> lv_labels.
      ls_local-labels = lv_labels.
      li_repo->set_local_settings( ls_local ).
      COMMIT WORK AND WAIT.
    ENDIF.
    DATA(ls_settings) = zcl_abapgit_persist_factory=>get_settings( )->read( )->get_user_settings( ).
    rt_labels = repo_labels( iv_labels = lv_labels iv_colors = ls_settings-label_colors ).
  ENDMETHOD.

  METHOD repo_labels.

    TYPES: BEGIN OF ty_color,
             name TYPE string,
             r TYPE i,
             g TYPE i,
             b TYPE i,
           END OF ty_color,
           ty_colors TYPE STANDARD TABLE OF ty_color WITH EMPTY KEY.
    DATA(lt_palette) = VALUE ty_colors(
      ( name = `blue`   r = 40  g = 110 b = 200 )
      ( name = `teal`   r = 0   g = 140 b = 120 )
      ( name = `purple` r = 125 g = 65  b = 180 )
      ( name = `rose`   r = 195 g = 55  b = 115 )
      ( name = `amber`  r = 205 g = 145 b = 0   )
      ( name = `slate`  r = 95  g = 110 b = 130 ) ).
    DATA(lt_colors) = zcl_abapgit_repo_labels=>split_colors( iv_colors ).
    LOOP AT zcl_abapgit_repo_labels=>split( iv_labels ) INTO DATA(lv_label).
      lv_label = condense( visible( lv_label ) ).
      IF lv_label IS INITIAL OR line_exists( rt_labels[ text = lv_label ] ).
        CONTINUE.
      ENDIF.
      DATA(lv_bytes) = zcl_abapgit_convert=>string_to_xstring_utf8( to_lower( lv_label ) ).
      DATA(lv_hash) = 0.
      DO xstrlen( lv_bytes ) TIMES.
        DATA(lv_offset) = sy-index - 1.
        lv_hash = ( lv_hash * 31 + CONV i( lv_bytes+lv_offset(1) ) ) MOD 65521.
      ENDDO.
      DATA(lv_color) = lt_palette[ lv_hash MOD lines( lt_palette ) + 1 ]-name.
      READ TABLE lt_colors INTO DATA(ls_config) WITH KEY label = lv_label.
      IF sy-subrc = 0.
        TRY.
            " Do not pass arbitrary abapGit class names or CSS into the browser.
            zcl_abapgit_repo_labels=>validate_colors( |{ ls_config-label }:{ ls_config-color }| ).
            CASE to_lower( ls_config-color ).
              WHEN `blue` OR `blue-set` OR `lightblue` OR `darkblue` OR `white-b` OR `dark-b`. lv_color = `blue`.
              WHEN `teal` OR `green` OR `success` OR `green-filled-set` OR `lightgreen` OR `darkgreen`. lv_color = `teal`.
              WHEN `purple` OR `violet` OR `darkviolet`. lv_color = `purple`.
              WHEN `red` OR `pink` OR `rose` OR `error` OR `red-filled-set`
                OR `lightred` OR `darkred` OR `white-r` OR `dark-r`. lv_color = `rose`.
              WHEN `yellow` OR `orange` OR `amber` OR `warning` OR `yellow-filled-set`
                OR `darkyellow` OR `dark-y` OR `brown`. lv_color = `amber`.
              WHEN `grey` OR `gray` OR `white` OR `grey-set` OR `slate` OR `dark-w`. lv_color = `slate`.
              WHEN OTHERS.
                DATA(ls_parsed) = zcl_abapgit_repo_labels=>parse_color( ls_config-color ).
                DATA(lv_rgb) = COND string( WHEN ls_parsed-bg IS NOT INITIAL THEN ls_parsed-bg ELSE ls_parsed-fg ).
                IF strlen( lv_rgb ) = 3.
                  lv_rgb = |{ lv_rgb+0(1) }{ lv_rgb+0(1) }{ lv_rgb+1(1) }{ lv_rgb+1(1) }{ lv_rgb+2(1) }{ lv_rgb+2(1) }|.
                ENDIF.
                IF strlen( lv_rgb ) = 6.
                  DATA lv_rgb_bytes TYPE x LENGTH 3.
                  " ABAP's character-to-hex conversion expects uppercase digits.
                  lv_rgb_bytes = to_upper( lv_rgb ).
                  DATA(lv_r) = CONV i( lv_rgb_bytes+0(1) ).
                  DATA(lv_g) = CONV i( lv_rgb_bytes+1(1) ).
                  DATA(lv_b) = CONV i( lv_rgb_bytes+2(1) ).
                  DATA(lv_best) = 200000.
                  LOOP AT lt_palette INTO DATA(ls_color).
                    DATA(lv_distance) = ( lv_r - ls_color-r ) ** 2 + ( lv_g - ls_color-g ) ** 2 + ( lv_b - ls_color-b ) ** 2.
                    IF lv_distance < lv_best.
                      lv_best = lv_distance.
                      lv_color = ls_color-name.
                    ENDIF.
                  ENDLOOP.
                  IF abs( lv_r - lv_g ) < 30 AND abs( lv_g - lv_b ) < 30 AND abs( lv_r - lv_b ) < 30.
                    lv_color = `slate`.
                  ENDIF.
                ENDIF.
            ENDCASE.
          CATCH zcx_abapgit_exception ##NO_HANDLER.
            " Invalid legacy color settings retain the automatic color.
        ENDTRY.
      ENDIF.
      INSERT VALUE #( text = lv_label color = lv_color ) INTO TABLE rt_labels.
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_repos.

    silence_progress( ).
    assert_authorized( ).
    DATA li_online TYPE REF TO zif_abapgit_repo_online.

    DATA(lt_favorites) = zcl_abapgit_persist_factory=>get_user( )->get_favorites( ).
    DATA(ls_settings) = zcl_abapgit_persist_factory=>get_settings( )->read( )->get_user_settings( ).

    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( ) INTO DATA(li_repo).
      DATA(ls_repo) = VALUE zif_ag2ui5_repo_service=>ty_repo(
        key     = li_repo->get_key( )
        name    = li_repo->get_name( )
        package = li_repo->get_package( )
        offline = li_repo->is_offline( )
        favorite = xsdbool( line_exists( lt_favorites[ table_line = li_repo->get_key( ) ] ) ) ).

      ls_repo-deserialized_at = format_timestamp( li_repo->ms_data-deserialized_at ).
      ls_repo-labels = repo_labels( iv_labels = li_repo->ms_data-local_settings-labels iv_colors = ls_settings-label_colors ).

      IF ls_repo-offline = abap_false.
        li_online ?= li_repo.
        ls_repo-url    = li_online->get_url( ).
        ls_repo-branch = li_online->get_selected_branch( ).
        ls_repo-branch_display = branch_display( ls_repo-branch ).
        ls_repo-branch_link = branch_link( iv_url = ls_repo-url iv_branch = ls_repo-branch ).
      ENDIF.

      INSERT ls_repo INTO TABLE rt_repos.
    ENDLOOP.

    SORT rt_repos BY package.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~set_favorite.

    TEST-SEAM favorite_authorization.
      silence_progress( ).
      assert_authorized( ).
    END-TEST-SEAM.
    " Validate strings before the fixed-length key/state conversions.
    IF iv_key IS INITIAL OR iv_key CN `0123456789` OR strlen( iv_key ) > 12.
      zcx_abapgit_exception=>raise( `Choose a registered repository` ).
    ENDIF.
    IF iv_favorite <> `X` AND iv_favorite <> `` AND iv_favorite <> ` `.
      zcx_abapgit_exception=>raise( `Favorite must be on or off` ).
    ENDIF.
    DATA(lv_key) = CONV zif_abapgit_persistence=>ty_repo-key( iv_key ).
    TEST-SEAM favorite_registration.
      " Reload persisted registration, rather than trusting a displayed row.
      zcl_abapgit_repo_srv=>get_instance( )->reload( lv_key ).
    END-TEST-SEAM.
    DATA(li_user) = zcl_abapgit_persist_factory=>get_user( ).
    DATA(lv_current) = li_user->is_favorite_repo( lv_key ).
    IF lv_current <> CONV abap_bool( iv_favorite ).
      " abapGit's user persistence commits this change itself.
      li_user->toggle_favorite( lv_key ).
    ENDIF.
    rv_favorite = li_user->is_favorite_repo( lv_key ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~start_status.

    silence_progress( ).
    assert_authorized( ).

    DATA(li_repo) = get_repo( iv_key ).
    rs_start-head = status_head( iv_key = iv_key ii_repo = li_repo ).
    rs_start-run_id = zcl_ag2ui5_status_run=>create( iv_key ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~run_state.
    rs_state = zcl_ag2ui5_status_run=>state( iv_run_id = iv_run_id
                                             iv_key    = iv_key ).
  ENDMETHOD.

  METHOD status_head.

    rs_status-key     = iv_key.
    rs_status-name    = ii_repo->get_name( ).
    rs_status-package = ii_repo->get_package( ).
    rs_status-offline = ii_repo->is_offline( ).
    DATA(ls_settings) = zcl_abapgit_persist_factory=>get_settings( )->read( )->get_user_settings( ).
    rs_status-labels = repo_labels( iv_labels = ii_repo->ms_data-local_settings-labels
                                   iv_colors = ls_settings-label_colors ).
    IF rs_status-offline = abap_false.
      DATA(li_online) = CAST zif_abapgit_repo_online( ii_repo ).
      rs_status-url            = li_online->get_url( ).
      rs_status-branch         = li_online->get_selected_branch( ).
      rs_status-branch_display = branch_display( rs_status-branch ).
      rs_status-branch_link    = branch_link( iv_url = rs_status-url iv_branch = rs_status-branch ).
    ENDIF.
    DATA lt_links TYPE ty_object_links.
    rs_status-package_link = object_link( EXPORTING iv_obj_type = `DEVC`
                                                    iv_obj_name = rs_status-package
                                          CHANGING ct_links = lt_links ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_status.

    assert_authorized( ).
    silence_progress( ).

    DATA lt_files TYPE zif_abapgit_definitions=>ty_files_item_tt.
    IF iv_run_id IS NOT INITIAL.
      lt_files = zcl_ag2ui5_status_run=>take_files( iv_run_id = iv_run_id iv_key = iv_key ).
    ENDIF.

    DATA(li_repo) = get_repo( iv_key = iv_key iv_zip = iv_zip ).
    li_repo->refresh( iv_drop_cache = abap_true ).

    rs_status = status_head( iv_key = iv_key ii_repo = li_repo ).
    IF rs_status-offline = abap_false.
      rs_status-remote_commit = CAST zif_abapgit_repo_online( li_repo )->get_current_remote( ).
    ENDIF.
    DATA li_status_repo TYPE REF TO zif_abapgit_repo.
    li_status_repo = li_repo.
    IF iv_run_id IS NOT INITIAL.
      li_status_repo = NEW zcl_ag2ui5_repo_local_files( ii_repo = li_repo it_files = lt_files ).
    ENDIF.
    rs_status-rows = status_rows( zcl_abapgit_repo_status=>calculate( li_status_repo ) ).
    DATA lt_links TYPE ty_object_links.
    " calculate( ) fetched the remote files already: no second request
    DATA lt_remote TYPE zif_abapgit_git_definitions=>ty_files_tt.
    IF rs_status-offline = abap_false.
      lt_remote = li_repo->get_files_remote( iv_ignore_files = abap_true ).
    ENDIF.

    LOOP AT rs_status-rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-remote_sha1 = remote_sha1( it_remote = lt_remote iv_path = <ls_row>-path
                                          iv_filename = <ls_row>-filename ).

      <ls_row>-object_link = object_link( EXPORTING iv_obj_type = <ls_row>-obj_type
                                                   iv_obj_name = <ls_row>-obj_name
                                         CHANGING ct_links = lt_links ).
    ENDLOOP.
    " who changed each changed file, by the Stage page's rule (assign_changed_by);
    " unchanged files get no name: asking every object handler takes too long
    DATA lt_changed TYPE zif_ag2ui5_repo_service=>ty_stage_items.
    DATA lt_local_users TYPE ty_file_users.
    DATA lt_status_objects TYPE ty_object_owners.
    LOOP AT rs_status-rows INTO DATA(ls_status_row) WHERE changed = abap_true.
      APPEND CORRESPONDING #( ls_status_row ) TO lt_changed.
      IF only_in_git( iv_lstate = ls_status_row-lstate iv_rstate = ls_status_row-rstate ) = abap_false.
        INSERT VALUE #( path = ls_status_row-path filename = ls_status_row-filename
                        user = COND #( WHEN ls_status_row-obj_type IS NOT INITIAL
                                       THEN zcl_abapgit_objects=>changed_by(
                                              is_item     = VALUE #( obj_type = ls_status_row-obj_type
                                                                     obj_name = ls_status_row-obj_name )
                                              iv_filename = ls_status_row-filename ) ) )
          INTO TABLE lt_local_users.
      ELSEIF ls_status_row-obj_type IS NOT INITIAL.
        INSERT VALUE #( obj_type = ls_status_row-obj_type obj_name = ls_status_row-obj_name ) INTO TABLE lt_status_objects.
      ENDIF.
    ENDLOOP.
    assign_changed_by( EXPORTING it_local_users = lt_local_users
                                 it_owners      = transport_owners( lt_status_objects )
                       CHANGING  ct_items       = lt_changed ).
    LOOP AT lt_changed INTO DATA(ls_changed).
      READ TABLE rs_status-rows ASSIGNING FIELD-SYMBOL(<ls_status>)
        WITH KEY path = ls_changed-path filename = ls_changed-filename.
      IF sy-subrc = 0.
        <ls_status>-changed_by = ls_changed-changed_by.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~preview_pull.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_repo( iv_key = iv_key iv_zip = iv_zip ).
    IF li_repo->is_offline( ) = abap_true AND iv_zip IS INITIAL.
      zcx_abapgit_exception=>raise( `Upload a ZIP before importing an offline repository` ).
    ENDIF.
    assert_pull_allowed( li_repo->get_package( ) ).
    li_repo->refresh( iv_drop_cache = abap_true ).

    rs_preview = preview( zcl_abapgit_repo_factory=>get_repo_pull( li_repo )->checks( ) ).
    DATA lt_links TYPE ty_object_links.
    LOOP AT rs_preview-items ASSIGNING FIELD-SYMBOL(<ls_row>).
      <ls_row>-object_link = object_link( EXPORTING iv_obj_type = <ls_row>-obj_type
                                                   iv_obj_name = <ls_row>-obj_name
                                         CHANGING ct_links = lt_links ).
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~pull.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_repo( iv_key = iv_key iv_zip = iv_zip ).
    IF li_repo->is_offline( ) = abap_true AND iv_zip IS INITIAL.
      zcx_abapgit_exception=>raise( `Upload a ZIP before importing an offline repository` ).
    ENDIF.
    assert_pull_allowed( li_repo->get_package( ) ).
    li_repo->refresh( iv_drop_cache = abap_true ).

    " check again - the remote or the system may have changed since the preview
    DATA(ls_checks)  = zcl_abapgit_repo_factory=>get_repo_pull( li_repo )->checks( ).
    DATA(ls_preview) = preview( ls_checks ).

    CASE ls_preview-outcome.
      WHEN zif_ag2ui5_repo_service=>c_outcome-nothing.
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-nothing.
        RETURN.
      WHEN zif_ag2ui5_repo_service=>c_outcome-blocked.
        zcx_abapgit_exception=>raise( ls_preview-blocked ).
    ENDCASE.

    " a chosen request comes from the client, so it is checked against the
    " user's own modifiable requests before anything is written to it
    DATA lv_transport TYPE string.
    DATA lv_customizing TYPE string.
    IF ls_checks-transport-required = abap_true.
      lv_transport = effective_transport(
        iv_preset     = ls_preview-transport_preset
        iv_chosen     = iv_transport
        it_transports = COND #( WHEN ls_preview-transport_preset IS INITIAL
                                THEN zif_ag2ui5_repo_service~list_transports( ls_preview-transport_type ) ) ).
    ENDIF.
    IF ls_checks-customizing-required = abap_true.
      lv_customizing = effective_transport(
        iv_preset     = ls_preview-customizing_preset
        iv_chosen     = iv_customizing
        it_transports = COND #( WHEN ls_preview-customizing_preset IS INITIAL
                                THEN zif_ag2ui5_repo_service~list_transports( ls_preview-customizing_type ) ) ).
    ENDIF.

    IF ls_preview-ack_text IS NOT INITIAL AND iv_acknowledged = abap_false.
      zcx_abapgit_exception=>raise( |{ ls_preview-ack_text } - confirm "Pull anyway" to continue| ).
    ENDIF.

    TRY.
        DATA(lt_items) = merge_decisions( it_fresh  = ls_preview-items
                                          it_posted = it_items ).
      CATCH zcx_abapgit_exception.
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-changed.
        RETURN.
    ENDTRY.

    " abapGit refuses a pull with nothing selected, but lets unsupported rows be
    " ticked; here they cannot be, so files alone make it a pull
    IF ls_checks-overwrite IS NOT INITIAL
        AND pull_is_noop( it_items = lt_items
                          iv_files = xsdbool( ls_checks-overwrite_files IS NOT INITIAL ) ) = abap_true.
      rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-nothing.
      RETURN.
    ENDIF.

    DATA(ls_decided) = apply_decisions( is_checks       = ls_checks
                                        it_items        = lt_items
                                        iv_acknowledged = iv_acknowledged ).
    " deletion and deserialize both record their objects on these requests
    IF lv_transport IS NOT INITIAL.
      ls_decided-transport-transport = lv_transport.
    ENDIF.
    IF lv_customizing IS NOT INITIAL.
      ls_decided-customizing-transport = lv_customizing.
    ENDIF.

    rs_result = deserialize_logged( ii_repo   = li_repo
                                    is_checks = ls_decided ).

  ENDMETHOD.

  METHOD format_timestamp.

    DATA lv_date TYPE d.
    DATA lv_time TYPE t.

    IF iv_timestamp IS INITIAL.
      RETURN.
    ENDIF.

    CONVERT TIME STAMP iv_timestamp TIME ZONE iv_timezone INTO DATE lv_date TIME lv_time.
    rv_text = |{ lv_date DATE = ISO } { lv_time(2) }:{ lv_time+2(2) }|.

  ENDMETHOD.

  METHOD deserialize_logged.

    DATA(li_log) = ii_repo->create_new_log( `Pull Log` ).

    TRY.
        " abapGit's own pull steps: delete the confirmed objects, then deserialize
        zcl_abapgit_repo_factory=>get_repo_pull( ii_repo )->pull( is_checks = is_checks
                                                             ii_log    = li_log ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        " objects may already be imported - the log says which
        li_log->add_exception( lx_error ).
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-failed.
    ENDTRY.

    rs_result-messages = map_messages( li_log ).
    IF rs_result-outcome IS INITIAL.
      rs_result-outcome = COND #( WHEN li_log->get_status( ) = zif_abapgit_log=>c_status-error
                                  THEN zif_ag2ui5_repo_service=>c_outcome-failed
                                  ELSE zif_ag2ui5_repo_service=>c_outcome-pulled ).
    ENDIF.

  ENDMETHOD.

  METHOD object_link.

    READ TABLE ct_links INTO DATA(ls_link)
      WITH TABLE KEY obj_type = iv_obj_type obj_name = iv_obj_name.
    IF sy-subrc = 0.
      rv_link = ls_link-href.
      RETURN.
    ENDIF.

    DATA lo_factory TYPE REF TO object.
    DATA lo_mapper TYPE REF TO object.
    DATA lo_ref TYPE REF TO object.
    DATA lo_wb TYPE REF TO cl_wb_object.
    FIELD-SYMBOLS <lv_uri> TYPE string.

    " Never invent a URI for a remote-only object or truncate a transport key
    IF iv_obj_type IS NOT INITIAL AND strlen( iv_obj_type ) <= 4
        AND iv_obj_name IS NOT INITIAL AND strlen( iv_obj_name ) <= 40.
      TRY.
          DATA(ls_item) = VALUE zif_abapgit_definitions=>ty_item(
            obj_type = iv_obj_type obj_name = iv_obj_name ).
          IF zcl_abapgit_objects=>exists( ls_item ) = abap_true.
            cl_wb_object=>create_from_transport_key(
              EXPORTING p_object = CONV trobjtype( iv_obj_type )
                        p_obj_name = CONV trobj_name( iv_obj_name )
              RECEIVING p_wb_object = lo_wb
              EXCEPTIONS OTHERS = 1 ).
            IF sy-subrc = 0.
              CALL METHOD ('CL_ADT_TOOLS_CORE_FACTORY')=>('GET_INSTANCE')
                RECEIVING result = lo_factory.
              CALL METHOD lo_factory->('IF_ADT_TOOLS_CORE_FACTORY~GET_URI_MAPPER')
                RECEIVING result = lo_mapper.
              CALL METHOD lo_mapper->('IF_ADT_URI_MAPPER~MAP_WB_OBJECT_TO_OBJREF')
                EXPORTING wb_object = lo_wb RECEIVING result = lo_ref.
              ASSIGN ('LO_REF->REF_DATA-URI') TO <lv_uri>.
              IF sy-subrc = 0 AND <lv_uri> CP '/sap/bc/adt/*'.
                rv_link = |adt://{ sy-sysid }{ <lv_uri> }|.
              ENDIF.
            ENDIF.
          ENDIF.
        CATCH cx_root.
          " A navigation failure must not prevent status, staging or pull
          CLEAR rv_link.
      ENDTRY.
    ENDIF.
    INSERT VALUE #( obj_type = iv_obj_type obj_name = iv_obj_name href = rv_link ) INTO TABLE ct_links.

  ENDMETHOD.

  METHOD assert_authorized.

    IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-startup ) = abap_false.
      zcx_abapgit_exception=>raise( `You are not authorized to use abapGit` ).
    ENDIF.

    DATA(lv_now) = gv_now.
    IF lv_now IS INITIAL.
      GET TIME STAMP FIELD lv_now.
    ENDIF.
    " credentials of login( ) live in this session's memory; unused for 30
    " minutes they go, as the ICF node's session timeout would end the session
    IF gv_last_use IS NOT INITIAL AND cl_abap_tstmp=>subtract( tstmp1 = lv_now tstmp2 = gv_last_use ) > 1800.
      zcl_abapgit_login_manager=>clear( ).
    ENDIF.
    gv_last_use = lv_now.

  ENDMETHOD.

  METHOD request_start.
    zcl_abapgit_repo_srv=>get_instance( )->init( ).
    CLEAR gt_blobs.
  ENDMETHOD.

  METHOD login_required.
    " no credentials: "Unauthorized access. Check your credentials"; rejected
    " ones: "Unauthorized access to resource (HTTP 401). Check your
    " credentials"; newer abapGit raises its own class
    " by name: older abapGit versions have no such class. A proxy asking
    " for credentials (HTTP 407) is no case for a Git login
    IF ix_error IS NOT BOUND.
      RETURN.
    ENDIF.
    DATA(lv_text) = ix_error->get_text( ).
    rv_yes = xsdbool( cl_abap_typedescr=>describe_by_object_ref( ix_error )->get_relative_name( ) = `ZCX_ABAPGIT_AUTH_REQUIRED`
                      OR ( lv_text CS `Check your credentials` AND lv_text NS `HTTP 407` ) ).
  ENDMETHOD.

  METHOD url_host.
    FIND REGEX `^[a-zA-Z][a-zA-Z0-9+.-]*://(?:[^@/?#]*@)?([^/?#]+)` IN iv_url SUBMATCHES rv_host ##REGEX_POSIX.
    IF sy-subrc <> 0.
      CLEAR rv_host.
    ENDIF.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~login.

    assert_authorized( ).
    DATA(lv_url) = COND string( WHEN iv_key IS NOT INITIAL THEN get_online_repo( iv_key )->get_url( ) ELSE iv_url ).
    IF lv_url IS INITIAL OR iv_user IS INITIAL OR iv_token IS INITIAL.
      zcx_abapgit_exception=>raise( `Enter the Git user and the token or password` ).
    ENDIF.
    " user and token go into an HTTP header, the URL into the request
    FIND REGEX `[[:cntrl:]]` IN iv_user && iv_token && lv_url.
    IF sy-subrc = 0.
      zcx_abapgit_exception=>raise( `User and token may not contain control characters` ).
    ENDIF.
    zcl_abapgit_login_manager=>set_basic( iv_uri      = lv_url
                                          iv_username = iv_user
                                          iv_password = iv_token ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~logoff.
    zcl_abapgit_login_manager=>clear( ).
  ENDMETHOD.

  METHOD silence_progress.
    zcl_abapgit_progress=>set_instance( NEW zcl_ag2ui5_progress_silent( ) ).
  ENDMETHOD.

  METHOD decode_zip.

    DATA lv_metadata TYPE string.
    DATA lv_base64 TYPE string.
    SPLIT iv_upload AT `,` INTO lv_metadata lv_base64.
    IF lv_metadata NP `data:*;base64` OR lv_base64 IS INITIAL.
      zcx_abapgit_exception=>raise( `Choose a ZIP file to upload` ).
    ENDIF.
    rv_zip = cl_http_utility=>decode_x_base64( lv_base64 ).
    zip_files( rv_zip ).

  ENDMETHOD.

  METHOD zip_files.

    DATA lt_paths TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    IF iv_zip IS INITIAL.
      zcx_abapgit_exception=>raise( `Choose a non-empty ZIP file` ).
    ENDIF.
    " abapGit's loader dumps on duplicate filenames after lower-casing them.
    " Inspect directory entries first, before its table's unique key is filled.
    DATA(lo_zip) = NEW cl_abap_zip( ).
    lo_zip->load( EXPORTING zip = iv_zip
                  EXCEPTIONS zip_parse_error = 1 OTHERS = 2 ).
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise( `The file is not a valid ZIP` ).
    ENDIF.
    LOOP AT lo_zip->files INTO DATA(ls_entry) WHERE name IS NOT INITIAL.
      IF ls_entry-name CP `*/`.
        CONTINUE.
      ENDIF.
      DATA(lv_name) = `/` && ls_entry-name.
      IF lv_name CS `/../` OR lv_name CS `/./` OR lv_name CS `\`.
        zcx_abapgit_exception=>raise( `The ZIP contains an invalid path` ).
      ENDIF.
      INSERT to_lower( ls_entry-name ) INTO TABLE lt_paths.
      IF sy-subrc <> 0.
        zcx_abapgit_exception=>raise( `The ZIP contains duplicate file paths` ).
      ENDIF.
    ENDLOOP.
    rt_files = zcl_abapgit_zip=>load( iv_zip ).
    IF NOT line_exists( rt_files[ path = `/` filename = `.abapgit.xml` ] ).
      zcx_abapgit_exception=>raise( `The ZIP must contain .abapgit.xml at its root` ).
    ENDIF.
    TRY.
        zcl_abapgit_dot_abapgit=>deserialize( rt_files[ path = `/` filename = `.abapgit.xml` ]-data ).
      CATCH cx_root INTO DATA(lx_xml).
        zcx_abapgit_exception=>raise( |Invalid .abapgit.xml in the ZIP: { lx_xml->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

  METHOD get_repo.

    IF iv_key IS INITIAL.
      zcx_abapgit_exception=>raise( `No repository selected - start with zcl_ag2ui5_app_repos` ).
    ENDIF.
    ri_repo = zcl_abapgit_repo_srv=>get_instance( )->get( CONV #( iv_key ) ).
    IF ri_repo->is_offline( ) = abap_true.
      DATA lt_files TYPE zif_abapgit_git_definitions=>ty_files_tt.
      IF iv_zip IS NOT INITIAL.
        lt_files = zip_files( iv_zip ).
      ENDIF.
      ri_repo->set_files_remote( lt_files ).
    ELSEIF iv_zip IS NOT INITIAL.
      zcx_abapgit_exception=>raise( `ZIP import is only available for offline repositories` ).
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~export_zip.

    assert_authorized( ).
    silence_progress( ).
    DATA(li_repo) = get_repo( iv_key ).
    IF li_repo->is_offline( ) = abap_false.
      zcx_abapgit_exception=>raise( `ZIP export is only available for offline repositories` ).
    ENDIF.
    li_repo->refresh( iv_drop_cache = abap_true ).
    rv_zip = zcl_abapgit_zip=>encode_files( li_repo->get_files_local( ) ).

  ENDMETHOD.

  METHOD get_online_repo.

    IF iv_key IS INITIAL.
      zcx_abapgit_exception=>raise( `No repository selected - start with zcl_ag2ui5_app_repos` ).
    ENDIF.

    DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->get( CONV #( iv_key ) ).

    IF li_repo->is_offline( ) = abap_true.
      zcx_abapgit_exception=>raise( |Repository { li_repo->get_name( ) } is offline - this operation requires an online repository| ).
    ENDIF.

    ri_repo ?= li_repo.

  ENDMETHOD.

  METHOD assert_pull_allowed.

    " Decided by where the code serving this request lives, not by the URL: a
    " pull into any of these packages replaces classes this very request is
    " still executing (abapGit's check_self_update only covers ZABAPGIT)
    SELECT obj_name, devclass FROM tadir
      WHERE pgmid = 'R3TR'
        AND ( ( object = 'CLAS' AND obj_name = 'ZCL_ABAPGIT_REPO' )
           OR ( object = 'INTF' AND obj_name = 'Z2UI5_IF_APP' )
           OR ( object = 'CLAS' AND obj_name = 'ZCL_AG2UI5_REPO_SERVICE' ) )
      ORDER BY obj_name
      INTO TABLE @DATA(lt_running).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lt_tree) = zcl_abapgit_factory=>get_sap_package( iv_package )->list_subpackages( ).
    INSERT iv_package INTO TABLE lt_tree.

    LOOP AT lt_running INTO DATA(ls_running) WHERE devclass IS NOT INITIAL.
      IF line_exists( lt_tree[ table_line = ls_running-devclass ] ).
        zcx_abapgit_exception=>raise( |Pulling package { iv_package } would replace { ls_running-obj_name }, | &&
                                      |which is running in this session. Pull it with abapGit in SAP GUI.| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD map_messages.

    LOOP AT ii_log->get_messages( ) INTO DATA(ls_message).
      INSERT VALUE #( type     = ls_message-type
                      text     = ls_message-text
                      obj_type = ls_message-obj_type
                      obj_name = ls_message-obj_name ) INTO TABLE rt_messages.
    ENDLOOP.

  ENDMETHOD.

  METHOD assert_delete_preview.

    IF is_actual-key IS INITIAL OR is_actual-key CN `0123456789` OR strlen( is_actual-key ) > 12 OR
       is_actual-package IS INITIAL OR
       ( is_actual-action <> `REMOVE` AND is_actual-action <> `UNINSTALL` ).
      zcx_abapgit_exception=>raise( `Choose Remove or Uninstall for a repository` ).
    ENDIF.
    IF is_expected <> is_actual.
      zcx_abapgit_exception=>raise( `Repository or deletion scope changed. Cancel and open a new preview.` ).
    ENDIF.
    IF is_actual-action = `UNINSTALL` AND iv_confirmation <> is_actual-package.
      zcx_abapgit_exception=>raise( |Type { is_actual-package } to confirm uninstall| ).
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~preview_delete.

    silence_progress( ).
    assert_authorized( ).
    IF iv_key IS INITIAL OR iv_key CN `0123456789` OR strlen( iv_key ) > 12 OR
       ( iv_action <> `REMOVE` AND iv_action <> `UNINSTALL` ).
      zcx_abapgit_exception=>raise( `Choose Remove or Uninstall for a repository` ).
    ENDIF.
    " Reload persisted metadata, not only an object cached in this session.
    DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->reload( CONV #( iv_key ) ).
    rs_preview = VALUE #( key = li_repo->get_key( ) name = li_repo->get_name( )
      package = li_repo->get_package( ) offline = li_repo->is_offline( ) action = iv_action ).
    IF li_repo->is_offline( ) = abap_false.
      rs_preview-url = CAST zif_abapgit_repo_online( li_repo )->get_url( ).
    ENDIF.
    IF iv_action = `REMOVE`.
      RETURN.
    ENDIF.

    IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-uninstall ) = abap_false.
      zcx_abapgit_exception=>raise( `You are not authorized to uninstall repositories` ).
    ENDIF.
    TRY.
        assert_pull_allowed( li_repo->get_package( ) ).
      CATCH zcx_abapgit_exception INTO DATA(lx_guard).
        zcx_abapgit_exception=>raise( `Cannot uninstall code running in this session. ` && lx_guard->get_text( ) ).
    ENDTRY.
    DATA(ls_checks) = li_repo->delete_checks( ).
    rs_preview-transport_required = ls_checks-transport-required.
    LOOP AT li_repo->get_tadir_objects( ) INTO DATA(ls_object).
      INSERT VALUE #( obj_type = ls_object-object obj_name = ls_object-obj_name
        package = ls_object-devclass ) INTO TABLE rs_preview-objects.
    ENDLOOP.
    SORT rs_preview-objects BY obj_type obj_name package.
    " Never uninstall a nested repository as a side effect of its parent.
    LOOP AT zcl_abapgit_persist_factory=>get_repo( )->list( ) INTO DATA(ls_other).
      IF ls_other-key = li_repo->get_key( ).
        CONTINUE.
      ENDIF.
      DATA(lv_other_package) = CONV string( ls_other-package ).
      IF line_exists( rs_preview-objects[ package = lv_other_package ] ) OR
         line_exists( rs_preview-objects[ obj_type = `DEVC` obj_name = lv_other_package ] ).
        zcx_abapgit_exception=>raise( |Deletion scope contains another repository in { lv_other_package }| ).
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~delete_repo.

    silence_progress( ).
    assert_authorized( ).
    DATA(ls_fresh) = zif_ag2ui5_repo_service~preview_delete(
      iv_key = is_preview-key iv_action = is_preview-action ).
    assert_delete_preview( is_expected = is_preview is_actual = ls_fresh iv_confirmation = iv_confirmation ).
    DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->get( CONV #( ls_fresh-key ) ).
    IF ls_fresh-action = `REMOVE`.
      zcl_abapgit_repo_srv=>get_instance( )->delete( li_repo ).
      COMMIT WORK AND WAIT.
      rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-removed.
      RETURN.
    ENDIF.

    DATA(ls_checks) = li_repo->delete_checks( ).
    IF ls_checks-transport-required = abap_true.
      ls_checks-transport-transport = effective_transport(
        iv_preset = `` iv_chosen = iv_transport
        it_transports = zif_ag2ui5_repo_service~list_transports( `K` ) ).
    ENDIF.
    " Deletions commit individually inside abapGit; preserve its partial log.
    TRY.
        DATA(li_log) = zcl_abapgit_repo_srv=>get_instance( )->purge(
          ii_repo = li_repo is_checks = ls_checks ).
        COMMIT WORK AND WAIT.
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-uninstalled.
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        li_log = li_repo->get_log( ).
        rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-failed.
        INSERT VALUE #( type = `E` text = lx_error->get_text( ) ) INTO TABLE rs_result-messages.
    ENDTRY.
    IF li_log IS BOUND.
      INSERT LINES OF map_messages( li_log ) INTO TABLE rs_result-messages.
    ENDIF.

  ENDMETHOD.

  METHOD normalize_new_package.
    rs_package = is_package.
    rs_package-package = to_upper( condense( is_package-package ) ).
    rs_package-description = shift_right( shift_left( is_package-description ) ).
    rs_package-software_component = to_upper( condense( is_package-software_component ) ).
    rs_package-transport_layer = to_upper( condense( is_package-transport_layer ) ).
    rs_package-super_package = to_upper( condense( is_package-super_package ) ).
    rs_package-transport = to_upper( condense( is_package-transport ) ).
    rs_package-abap_lang_vers = condense( is_package-abap_lang_vers ).
  ENDMETHOD.

  METHOD new_package_errors.
    TYPES: BEGIN OF ty_limit,
             field TYPE string,
             length TYPE i,
           END OF ty_limit.
    DATA lt_limits TYPE STANDARD TABLE OF ty_limit WITH EMPTY KEY.
    lt_limits = VALUE #( ( field = `package` length = 30 ) ( field = `description` length = 60 )
      ( field = `software_component` length = 20 ) ( field = `transport_layer` length = 4 )
      ( field = `super_package` length = 30 ) ( field = `transport` length = 20 ) ).
    LOOP AT lt_limits INTO DATA(ls_limit).
      ASSIGN COMPONENT to_upper( ls_limit-field ) OF STRUCTURE is_package TO FIELD-SYMBOL(<lv_value>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF strlen( <lv_value> ) > ls_limit-length.
        INSERT VALUE #( field = ls_limit-field text = |Maximum length is { ls_limit-length } characters| ) INTO TABLE rt_errors.
      ELSE.
        FIND REGEX `[[:cntrl:]]` IN <lv_value>.
        IF sy-subrc = 0.
          INSERT VALUE #( field = ls_limit-field text = `Control characters are not allowed` ) INTO TABLE rt_errors.
        ENDIF.
      ENDIF.
    ENDLOOP.
    IF is_package-package IS INITIAL.
      INSERT VALUE #( field = `package` text = `Enter a package` ) INTO TABLE rt_errors.
    ENDIF.
    IF is_package-description IS INITIAL.
      INSERT VALUE #( field = `description` text = `Enter a description` ) INTO TABLE rt_errors.
    ENDIF.
    IF is_package-software_component IS INITIAL.
      INSERT VALUE #( field = `software_component` text = `Enter a software component` ) INTO TABLE rt_errors.
    ENDIF.
    IF is_package-package CP '$*'.
      IF is_package-software_component <> `LOCAL` AND is_package-software_component <> `ZLOCAL`.
        INSERT VALUE #( field = `software_component` text = `A local package needs LOCAL or ZLOCAL` ) INTO TABLE rt_errors.
      ENDIF.
      IF is_package-transport IS NOT INITIAL OR is_package-transport_layer IS NOT INITIAL.
        INSERT VALUE #( field = `transport` text = `A local package does not use a transport request or layer` ) INTO TABLE rt_errors.
      ENDIF.
    ELSEIF is_package-package IS NOT INITIAL.
      IF is_package-software_component = `LOCAL` OR is_package-software_component = `ZLOCAL`.
        INSERT VALUE #( field = `software_component` text = `Use a transportable software component, for example HOME` ) INTO TABLE rt_errors.
      ENDIF.
      IF is_package-transport IS INITIAL.
        INSERT VALUE #( field = `transport` text = `Choose a workbench transport request` ) INTO TABLE rt_errors.
      ENDIF.
    ENDIF.
    IF is_package-abap_lang_vers IS NOT INITIAL AND is_package-abap_lang_vers <> `ignore`
        AND is_package-abap_lang_vers <> `standard` AND is_package-abap_lang_vers <> `keyUser`
        AND is_package-abap_lang_vers <> `cloudDevelopment`.
      INSERT VALUE #( text = `Unknown ABAP language version` ) INTO TABLE rt_errors.
    ENDIF.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~package_defaults.
    silence_progress( ).
    assert_authorized( ).
    rs_package-package = to_upper( condense( iv_package ) ).
    rs_package-description = rs_package-package.
    rs_package-abap_lang_vers = iv_abap_lang_vers.
    IF rs_package-package CP '$*'.
      rs_package-software_component = COND #( WHEN iv_abap_lang_vers = `cloudDevelopment` THEN `ZLOCAL` ELSE `LOCAL` ).
      rs_package-super_package = COND #( WHEN iv_abap_lang_vers = `cloudDevelopment` THEN `ZLOCAL` ELSE `$TMP` ).
    ELSE.
      rs_package-software_component = COND #( WHEN iv_abap_lang_vers = `cloudDevelopment` THEN `ZCUSTOM_DEVELOPMENT` ELSE `HOME` ).
      rs_package-super_package = COND #( WHEN iv_abap_lang_vers = `cloudDevelopment` THEN `ZCUSTOM_DEVELOPMENT` ).
      rs_package-transport_layer = zcl_abapgit_factory=>get_sap_package( 'DUMMY' )->get_default_transport_layer( ).
    ENDIF.
  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~create_package.
    silence_progress( ).
    assert_authorized( ).
    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-invalid.
    DATA(ls_form) = normalize_new_package( is_package ).
    rs_result-errors = new_package_errors( ls_form ).
    IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-create_repo ) = abap_false.
      INSERT VALUE #( text = `You are not authorized to create repositories` ) INTO TABLE rs_result-errors.
    ENDIF.
    IF rs_result-errors IS NOT INITIAL.
      RETURN.
    ENDIF.

    TRY.
        DATA(li_sap_package) = zcl_abapgit_factory=>get_sap_package( CONV #( ls_form-package ) ).
        li_sap_package->validate_name( ).
        IF li_sap_package->exists( ) = abap_true.
          zcx_abapgit_exception=>raise( |Package { ls_form-package } already exists| ).
        ENDIF.
        zcl_abapgit_repo_srv=>get_instance( )->validate_package( CONV #( ls_form-package ) ).
        assert_pull_allowed( CONV #( ls_form-package ) ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        INSERT VALUE #( field = `package` text = lx_error->get_text( ) ) INTO TABLE rs_result-errors.
    ENDTRY.

    IF ls_form-super_package IS NOT INITIAL.
      TRY.
          DATA(li_parent) = zcl_abapgit_factory=>get_sap_package( CONV #( ls_form-super_package ) ).
          IF li_parent->exists( ) = abap_false OR ls_form-super_package = ls_form-package.
            zcx_abapgit_exception=>raise( `Choose an existing, different superpackage` ).
          ENDIF.
          " $TMP and ZLOCAL are containers, not repository roots to pull into
          IF ls_form-super_package <> `$TMP` AND ls_form-super_package <> `ZLOCAL`.
            assert_pull_allowed( CONV #( ls_form-super_package ) ).
            zcl_abapgit_repo_srv=>get_instance( )->validate_package(
              iv_package = CONV #( ls_form-super_package ) iv_ign_subpkg = abap_true ).
          ENDIF.
          DATA(ls_parent) = li_parent->get( ).
          IF ls_parent-dlvunit <> ls_form-software_component.
            zcx_abapgit_exception=>raise( `The software component must match the superpackage` ).
          ENDIF.
          IF ls_form-package CP '$*' AND li_parent->are_changes_recorded_in_tr_req( ) = abap_true.
            zcx_abapgit_exception=>raise( `A local package needs a local superpackage` ).
          ELSEIF ls_form-package NP '$*' AND li_parent->are_changes_recorded_in_tr_req( ) = abap_false.
            zcx_abapgit_exception=>raise( `A transportable package needs a transportable superpackage` ).
          ENDIF.
        CATCH zcx_abapgit_exception INTO lx_error.
          INSERT VALUE #( field = `super_package` text = lx_error->get_text( ) ) INTO TABLE rs_result-errors.
      ENDTRY.
    ENDIF.
    IF ls_form-package NP '$*'.
      TRY.
          assert_transport( iv_transport = ls_form-transport
            it_transports = zif_ag2ui5_repo_service~list_transports( `K` ) ).
        CATCH zcx_abapgit_exception INTO lx_error.
          INSERT VALUE #( field = `transport` text = lx_error->get_text( ) ) INTO TABLE rs_result-errors.
      ENDTRY.
    ENDIF.
    IF rs_result-errors IS NOT INITIAL.
      RETURN.
    ENDIF.

    DATA ls_data TYPE scompkdtln.
    DATA li_package TYPE REF TO if_package.
    ls_data-devclass = ls_form-package.
    ls_data-ctext = ls_form-description.
    ls_data-dlvunit = ls_form-software_component.
    ls_data-pdevclass = ls_form-transport_layer.
    ls_data-parentcl = ls_form-super_package.
    ls_data-as4user = sy-uname.
    ls_data-korrflag = xsdbool( ls_form-package NP '$*' ).
    ls_data-packkind = SWITCH #( ls_form-abap_lang_vers WHEN `keyUser` THEN '2' WHEN `cloudDevelopment` THEN '5' ELSE space ).

    cl_package_factory=>create_new_package(
      EXPORTING i_reuse_deleted_object = abap_true i_suppress_dialog = abap_true
      IMPORTING e_package = li_package
      CHANGING c_package_data = ls_data
      EXCEPTIONS object_already_existing = 1 object_just_created = 2 not_authorized = 3
        wrong_name_prefix = 4 undefined_name = 5 reserved_local_name = 6 invalid_package_name = 7
        short_text_missing = 8 software_component_invalid = 9 layer_invalid = 10 author_not_existing = 11
        component_not_existing = 12 component_missing = 13 prefix_in_use = 14 unexpected_error = 15 intern_err = 16
        OTHERS = 17 ).
    IF sy-subrc <> 0.
      zcx_abapgit_exception=>raise_t100( ).
    ENDIF.
    li_package->save(
      EXPORTING i_transport_request = CONV #( ls_form-transport ) i_suppress_dialog = abap_true
      EXCEPTIONS object_invalid = 1 object_not_changeable = 2 cancelled_in_corr = 3 permission_failure = 4
        unexpected_error = 5 intern_err = 6 OTHERS = 7 ).
    IF sy-subrc <> 0.
      DATA lv_error TYPE string.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO lv_error.
      li_package->delete( EXPORTING i_suppress_dialog = abap_true
        EXCEPTIONS object_not_empty = 1 object_not_changeable = 2 object_invalid = 3 intern_err = 4 OTHERS = 5 ).
      IF sy-subrc <> 0.
        lv_error = |{ lv_error } (The failed package could not be discarded; retry in a new session.)|.
      ENDIF.
      ROLLBACK WORK.
      zcx_abapgit_exception=>raise( lv_error ).
    ENDIF.
    li_package->set_changeable( EXPORTING i_changeable = abap_false i_suppress_dialog = abap_true
      EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      " Creation succeeded; commit it even if SAP could not release its lock
      COMMIT WORK AND WAIT.
      zcx_abapgit_exception=>raise( |Package { ls_form-package } was created, but SAP could not release its lock| ).
    ENDIF.
    COMMIT WORK AND WAIT.
    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-created.
    rs_result-package = ls_form-package.
  ENDMETHOD.

  METHOD normalize_new_repo.

    rs_repo = is_repo.
    " single values: condense also takes inner blanks, which they never have
    rs_repo-kind         = to_upper( condense( is_repo-kind ) ).
    rs_repo-url          = condense( is_repo-url ).
    rs_repo-package      = to_upper( condense( is_repo-package ) ).
    rs_repo-folder_logic = to_upper( condense( is_repo-folder_logic ) ).
    " abapGit's language versions are case-sensitive (keyUser)
    rs_repo-abap_lang_vers = condense( is_repo-abap_lang_vers ).
    " names keep their inner blanks
    rs_repo-name         = shift_right( shift_left( is_repo-name ) ).
    rs_repo-display_name = shift_right( shift_left( is_repo-display_name ) ).
    rs_repo-labels       = shift_right( shift_left( is_repo-labels ) ).
    rs_repo-branch       = COND #( WHEN condense( is_repo-branch ) <> ``
                                   THEN branch_name( is_repo-branch ) ).

    " the browser keeps what was typed for the other kind
    IF rs_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-online.
      CLEAR rs_repo-name.
    ELSE.
      CLEAR: rs_repo-url, rs_repo-branch, rs_repo-display_name.
    ENDIF.

  ENDMETHOD.

  METHOD new_repo_errors.

    CASE is_repo-kind.
      WHEN zif_ag2ui5_repo_service=>c_repo_kind-online.
        IF is_repo-url IS INITIAL.
          INSERT VALUE #( field = `url` text = `Enter the URL of the Git repository` ) INTO TABLE rt_errors.
        ENDIF.
      WHEN zif_ag2ui5_repo_service=>c_repo_kind-offline.
        IF is_repo-name IS INITIAL.
          INSERT VALUE #( field = `name` text = `Enter a name for the repository` ) INTO TABLE rt_errors.
        ENDIF.
      WHEN OTHERS.
        INSERT VALUE #( text = |Unknown kind of repository "{ is_repo-kind }"| ) INTO TABLE rt_errors.
    ENDCASE.

    IF is_repo-package IS INITIAL.
      INSERT VALUE #( field = `package` text = `Enter a package` ) INTO TABLE rt_errors.
    ENDIF.

    IF is_repo-folder_logic <> zif_abapgit_dot_abapgit=>c_folder_logic-prefix
        AND is_repo-folder_logic <> zif_abapgit_dot_abapgit=>c_folder_logic-full
        AND is_repo-folder_logic <> zif_abapgit_dot_abapgit=>c_folder_logic-mixed.
      INSERT VALUE #( field = `folder_logic` text = `Choose Prefix, Full or Mixed` ) INTO TABLE rt_errors.
    ENDIF.

    " empty is abapGit's "Any"; undefined is its internal name for it
    IF is_repo-abap_lang_vers IS NOT INITIAL
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-ignore
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-standard
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-key_user
        AND is_repo-abap_lang_vers <> zif_abapgit_dot_abapgit=>c_abap_language_version-cloud_development.
      INSERT VALUE #( field = `abap_lang_vers` text = `Choose an ABAP language version` ) INTO TABLE rt_errors.
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~create_repo.

    assert_authorized( ).
    silence_progress( ).

    " the form comes from the browser: every check runs, all errors are
    " collected, and nothing is written while one fails
    DATA(ls_repo) = normalize_new_repo( is_repo ).
    rs_result-errors = new_repo_errors( ls_repo ).
    IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-create_repo ) = abap_false.
      INSERT VALUE #( text = `You are not authorized to create repositories` ) INTO TABLE rs_result-errors.
    ENDIF.
    check_new_repo( EXPORTING is_repo   = ls_repo
                    CHANGING  ct_errors = rs_result-errors ).
    IF rs_result-errors IS NOT INITIAL.
      rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-invalid.
      RETURN.
    ENDIF.

    DATA(li_repo) = add_repo( ls_repo ).
    " as abapGit: a new repository is one of the user's favorites
    zcl_abapgit_persist_factory=>get_user( )->toggle_favorite( li_repo->get_key( ) ).
    " abap2UI5 rolls back after main( )
    COMMIT WORK AND WAIT.

    rs_result-outcome = zif_ag2ui5_repo_service=>c_outcome-created.
    rs_result-key     = li_repo->get_key( ).

  ENDMETHOD.

  METHOD check_new_repo.

    DATA lx_error TYPE REF TO zcx_abapgit_exception.

    IF is_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-online AND NOT line_exists( ct_errors[ field = `url` ] ).
      TRY.
          zcl_abapgit_repo_srv=>get_instance( )->validate_url( is_repo-url ).
          NEW zcl_abapgit_git_url( )->validate_url( is_repo-url ).
          " connects: HTTP, SSL and login errors end up on the URL
          DATA(li_branches) = zcl_abapgit_git_factory=>get_git_transport( )->branches( is_repo-url ).
          IF is_repo-branch IS INITIAL AND li_branches->get_head_symref( ) IS INITIAL.
            " abapGit would push a first branch, which needs a login
            INSERT VALUE #( field = `url`
                            text  = `The repository has no commit yet. Push a first commit ` &&
                                    `(for example a README), then try again.` ) INTO TABLE ct_errors.
          ELSEIF is_repo-branch IS NOT INITIAL.
            TRY.
                li_branches->find_by_name( is_repo-branch ).
              CATCH zcx_abapgit_exception.
                INSERT VALUE #( field = `branch`
                                text  = |Branch { is_repo-branch } is not on the remote| ) INTO TABLE ct_errors.
            ENDTRY.
          ENDIF.
        CATCH zcx_abapgit_exception INTO lx_error.
          " a private repository: the app opens the login page
          IF login_required( lx_error ) = abap_true.
            RAISE EXCEPTION lx_error.
          ENDIF.
          INSERT VALUE #( field = `url` text = lx_error->get_text( ) ) INTO TABLE ct_errors.
      ENDTRY.
    ENDIF.

    IF NOT line_exists( ct_errors[ field = `package` ] ).
      TRY.
          " name, SAP's own packages, used by another repository, local and
          " transportable mixed
          zcl_abapgit_repo_srv=>get_instance( )->validate_package(
            iv_package    = CONV #( is_repo-package )
            iv_ign_subpkg = is_repo-ign_subpackages ).
          assert_pull_allowed( CONV #( is_repo-package ) ).
          " an online repository may bring its package along; an offline one cannot
          IF is_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline
              AND zcl_abapgit_factory=>get_sap_package( CONV #( is_repo-package ) )->exists( ) = abap_false.
            zcx_abapgit_exception=>raise( |Package { is_repo-package } does not exist| ).
          ENDIF.
        CATCH zcx_abapgit_exception INTO lx_error.
          INSERT VALUE #( field = `package` text = lx_error->get_text( ) ) INTO TABLE ct_errors.
      ENDTRY.
    ENDIF.

    TRY.
        zcl_abapgit_repo_labels=>validate( is_repo-labels ).
      CATCH zcx_abapgit_exception INTO lx_error.
        INSERT VALUE #( field = `labels` text = lx_error->get_text( ) ) INTO TABLE ct_errors.
    ENDTRY.

  ENDMETHOD.

  METHOD add_repo.

    DATA(li_repo_srv) = zcl_abapgit_repo_srv=>get_instance( ).

    IF is_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-offline.
      ri_repo = li_repo_srv->new_offline( iv_name           = is_repo-name
                                          iv_package        = CONV #( is_repo-package )
                                          iv_folder_logic   = is_repo-folder_logic
                                          iv_labels         = is_repo-labels
                                          iv_ign_subpkg     = is_repo-ign_subpackages
                                          iv_main_lang_only = is_repo-main_lang_only
                                          iv_abap_lang_vers = is_repo-abap_lang_vers ).
    ELSE.
      ri_repo = li_repo_srv->new_online( iv_url            = is_repo-url
                                         iv_branch_name    = is_repo-branch
                                         iv_display_name   = is_repo-display_name
                                         iv_package        = CONV #( is_repo-package )
                                         iv_folder_logic   = is_repo-folder_logic
                                         iv_labels         = is_repo-labels
                                         iv_ign_subpkg     = is_repo-ign_subpackages
                                         iv_main_lang_only = is_repo-main_lang_only
                                         iv_abap_lang_vers = is_repo-abap_lang_vers ).
    ENDIF.

    TRY.
        " the steps of abapGit's services after new_online / new_offline
        IF is_repo-kind = zif_ag2ui5_repo_service=>c_repo_kind-online
            AND zcl_abapgit_factory=>get_sap_package( CONV #( is_repo-package ) )->exists( ) = abap_false.
          DATA(lt_remote) = ri_repo->get_files_remote( ).
          READ TABLE lt_remote TRANSPORTING NO FIELDS
            WITH KEY file COMPONENTS filename = zcl_abapgit_filename_logic=>c_package_file.
          IF sy-subrc <> 0.
            zcx_abapgit_exception=>raise( |Package { is_repo-package } does not exist and the repository | &&
                                          |contains no package. Choose an existing package.| ).
          ENDIF.
        ENDIF.
        " no leftovers of an earlier repository; also checks the folder logic
        ri_repo->checksums( )->rebuild( ).
      CATCH zcx_abapgit_exception INTO DATA(lx_error).
        li_repo_srv->delete( ri_repo ).
        COMMIT WORK.
        RAISE EXCEPTION lx_error.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
