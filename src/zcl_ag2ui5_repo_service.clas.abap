"! Talks to the abapGit developer version on behalf of the apps
CLASS zcl_ag2ui5_repo_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_repo_service.

    "! The decision dialog's content: one item per object, in its most
    "! dangerous group, with abapGit's defaults preselected
    CLASS-METHODS preview
      IMPORTING
        is_checks         TYPE zif_abapgit_definitions=>ty_deserialize_checks
      RETURNING
        VALUE(rs_preview) TYPE zif_ag2ui5_repo_service=>ty_preview.

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

    "! abapGit's rule for the diff direction: only when nothing changed locally
    "! and something changed remotely is the remote the new side
    CLASS-METHODS remote_is_new
      IMPORTING
        iv_lstate     TYPE string
        iv_rstate     TYPE string
      RETURNING
        VALUE(rv_yes) TYPE abap_bool.

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

    "! The line counts with + for the side that changed, - for the other
    CLASS-METHODS counts_text
      IMPORTING
        iv_local         TYPE i
        iv_remote        TYPE i
        iv_remote_is_new TYPE abap_bool
      RETURNING
        VALUE(rv_text)   TYPE string.

    "! Keeps the files that differ or are inactive
    CLASS-METHODS filter_status
      IMPORTING
        it_results     TYPE zif_abapgit_definitions=>ty_results_tt
      RETURNING
        VALUE(rt_rows) TYPE zif_ag2ui5_repo_service=>ty_status_rows.

    "! Date and time to the minute in the user's time zone, empty if initial
    CLASS-METHODS format_timestamp
      IMPORTING
        iv_timestamp   TYPE timestampl
        iv_timezone    TYPE tznzone DEFAULT sy-zonlo
      RETURNING
        VALUE(rv_text) TYPE string.

  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS silence_progress.

    "! abapGit's own startup authorization (its user exit can restrict it)
    METHODS assert_authorized
      RAISING
        zcx_abapgit_exception.

    METHODS get_online_repo
      IMPORTING
        iv_key         TYPE string
      RETURNING
        VALUE(ri_repo) TYPE REF TO zif_abapgit_repo_online
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

    "! Deletes the objects whose deletion was selected, as abapGit's
    "! delete_unnecessary_objects does before deserializing
    METHODS delete_selected
      IMPORTING
        ii_repo   TYPE REF TO zif_abapgit_repo
        is_checks TYPE zif_abapgit_definitions=>ty_deserialize_checks
        ii_log    TYPE REF TO zif_abapgit_log
      RAISING
        zcx_abapgit_exception.

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

    rs_preview-outcome = zif_ag2ui5_repo_service=>c_outcome-ready.

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

  METHOD zif_ag2ui5_repo_service~get_diff.

    DATA lv_local TYPE xstring.
    DATA lv_remote TYPE xstring.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).

    " only the file's object is serialized and read, as in abapGit's diff page
    zcl_abapgit_filename_logic=>file_to_object(
      EXPORTING iv_filename = iv_filename
                iv_path     = iv_path
                io_dot      = li_repo->zif_abapgit_repo~get_dot_abapgit( )
                iv_devclass = li_repo->zif_abapgit_repo~get_package( )
      IMPORTING es_item     = DATA(ls_item) ).
    DATA(li_filter) = CAST zif_abapgit_object_filter( NEW zcl_ag2ui5_object_filter( ls_item ) ).

    DATA(lv_found) = abap_false.
    LOOP AT li_repo->zif_abapgit_repo~get_files_local_filtered( li_filter ) INTO DATA(ls_local)
        WHERE file-path = iv_path AND file-filename = iv_filename.
      lv_local = ls_local-file-data.
      lv_found = abap_true.
      EXIT.
    ENDLOOP.
    LOOP AT li_repo->zif_abapgit_repo~get_files_remote( iv_ignore_files = abap_true
                                                        ii_obj_filter   = li_filter ) INTO DATA(ls_remote)
        WHERE path = iv_path AND filename = iv_filename.
      lv_remote = ls_remote-data.
      lv_found = abap_true.
      EXIT.
    ENDLOOP.
    IF lv_found = abap_false.
      zcx_abapgit_exception=>raise( |File not found: { iv_path }{ iv_filename }| ).
    ENDIF.

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
    rs_diff-lines = map_diff( it_diff = li_diff->get( ) iv_remote_is_new = iv_remote_is_new ).
    LOOP AT rs_diff-lines TRANSPORTING NO FIELDS WHERE kind = zif_ag2ui5_repo_service=>c_line_kind-local.
      rs_diff-local_count = rs_diff-local_count + 1.
    ENDLOOP.
    LOOP AT rs_diff-lines TRANSPORTING NO FIELDS WHERE kind = zif_ag2ui5_repo_service=>c_line_kind-remote.
      rs_diff-remote_count = rs_diff-remote_count + 1.
    ENDLOOP.

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

  METHOD code_html.

    " leading blanks would collapse in HTML; they carry the indentation
    DATA(lv_rest) = shift_left( iv_text ).
    DATA(lv_indent) = strlen( iv_text ) - strlen( lv_rest ).
    rv_html = |<code>{ repeat( val = `&nbsp;` occ = lv_indent ) }{ escape( val = lv_rest format = cl_abap_format=>e_xml_text ) }</code>|.

  ENDMETHOD.

  METHOD counts_text.
  ENDMETHOD.

  METHOD filter_status.

    LOOP AT it_results INTO DATA(ls_result) WHERE match = abap_false OR inactive = abap_true.
      INSERT VALUE #( obj_type = ls_result-obj_type
                      obj_name = ls_result-obj_name
                      path     = ls_result-path
                      filename = ls_result-filename
                      lstate   = ls_result-lstate
                      rstate   = ls_result-rstate
                      inactive = ls_result-inactive ) INTO TABLE rt_rows.
    ENDLOOP.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~list_repos.

    assert_authorized( ).
    DATA li_online TYPE REF TO zif_abapgit_repo_online.

    silence_progress( ).

    LOOP AT zcl_abapgit_repo_srv=>get_instance( )->list( ) INTO DATA(li_repo).
      DATA(ls_repo) = VALUE zif_ag2ui5_repo_service=>ty_repo(
        key     = li_repo->get_key( )
        name    = li_repo->get_name( )
        package = li_repo->get_package( )
        offline = li_repo->is_offline( ) ).

      ls_repo-deserialized_at = format_timestamp( li_repo->ms_data-deserialized_at ).

      IF ls_repo-offline = abap_false.
        li_online ?= li_repo.
        ls_repo-url    = li_online->get_url( ).
        ls_repo-branch = li_online->get_selected_branch( ).
      ENDIF.

      INSERT ls_repo INTO TABLE rt_repos.
    ENDLOOP.

    SORT rt_repos BY package.

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~get_status.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).

    rs_status-key           = iv_key.
    rs_status-name          = li_repo->zif_abapgit_repo~get_name( ).
    rs_status-package       = li_repo->zif_abapgit_repo~get_package( ).
    rs_status-url           = li_repo->get_url( ).
    rs_status-branch        = li_repo->get_selected_branch( ).
    rs_status-remote_commit = li_repo->get_current_remote( ).
    rs_status-rows          = filter_status( zcl_abapgit_repo_status=>calculate( li_repo ) ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~preview_pull.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    assert_pull_allowed( li_repo->zif_abapgit_repo~get_package( ) ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).

    rs_preview = preview( li_repo->zif_abapgit_repo~deserialize_checks( ) ).

  ENDMETHOD.

  METHOD zif_ag2ui5_repo_service~pull.

    assert_authorized( ).
    silence_progress( ).

    DATA(li_repo) = get_online_repo( iv_key ).
    assert_pull_allowed( li_repo->zif_abapgit_repo~get_package( ) ).
    li_repo->zif_abapgit_repo~refresh( iv_drop_cache = abap_true ).

    " check again - the remote or the system may have changed since the preview
    DATA(ls_checks)  = li_repo->zif_abapgit_repo~deserialize_checks( ).
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

    " abapGit refuses a pull with nothing selected; deserialize( ) would still
    " move the last-pull timestamp
    IF ls_checks-overwrite IS NOT INITIAL AND NOT line_exists( lt_items[ selected = abap_true ] ).
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
        delete_selected( ii_repo   = ii_repo
                         is_checks = is_checks
                         ii_log    = li_log ).
        ii_repo->deserialize( is_checks = is_checks
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

  METHOD delete_selected.

    DATA lt_tadir TYPE zif_abapgit_definitions=>ty_tadir_tt.
    DATA ls_delete_checks TYPE zif_abapgit_definitions=>ty_delete_checks.

    LOOP AT is_checks-overwrite INTO DATA(ls_change)
        WHERE ( action = zif_abapgit_objects=>c_deserialize_action-delete
             OR action = zif_abapgit_objects=>c_deserialize_action-delete_add )
          AND decision = zif_abapgit_definitions=>c_yes.
      INSERT VALUE #( pgmid    = 'R3TR'
                      object   = ls_change-obj_type
                      obj_name = ls_change-obj_name
                      devclass = ls_change-devclass ) INTO TABLE lt_tadir.
    ENDLOOP.

    IF lt_tadir IS INITIAL.
      RETURN.
    ENDIF.

    ls_delete_checks-transport = is_checks-transport.
    zcl_abapgit_objects=>delete( it_tadir  = lt_tadir
                                 is_checks = ls_delete_checks
                                 ii_log    = ii_log ).
    ii_repo->refresh( iv_drop_log = abap_false ).

  ENDMETHOD.

  METHOD assert_authorized.

    IF zcl_abapgit_auth=>is_allowed( zif_abapgit_auth=>c_authorization-startup ) = abap_false.
      zcx_abapgit_exception=>raise( `You are not authorized to use abapGit` ).
    ENDIF.

  ENDMETHOD.

  METHOD silence_progress.
    zcl_abapgit_progress=>set_instance( NEW zcl_ag2ui5_progress_silent( ) ).
  ENDMETHOD.

  METHOD get_online_repo.

    IF iv_key IS INITIAL.
      zcx_abapgit_exception=>raise( `No repository selected - start with zcl_ag2ui5_app_repos` ).
    ENDIF.

    DATA(li_repo) = zcl_abapgit_repo_srv=>get_instance( )->get( CONV #( iv_key ) ).

    IF li_repo->is_offline( ) = abap_true.
      zcx_abapgit_exception=>raise( |Repository { li_repo->get_name( ) } is offline - only online repositories are supported| ).
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

ENDCLASS.
