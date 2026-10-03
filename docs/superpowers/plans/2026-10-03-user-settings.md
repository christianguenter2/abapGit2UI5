# User Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every toggle of the three apps is stored per SAP user in table `ZAG2UI5_SETTING` and restored when the app opens.

**Architecture:** A new interface `ZIF_AG2UI5_SETTINGS` with `get`/`set`, implemented by `ZCL_AG2UI5_SETTINGS`, which checks every key and value against an allow-list and reaches the table through a local store interface (in-memory in tests). The apps read their settings when they start or are created and save in the toggle events; tests inject a double through `zcl_ag2ui5_settings=>inject( )`.

**Tech Stack:** ABAP 7.50 syntax (abaplint `v750`), abap2UI5 1.146, ABAP Unit on A4H25, sapcli over ADT, one abapGit pull through abapgit-agent.

**Spec:** `docs/superpowers/specs/2026-10-03-user-settings-design.md`

## Global Constraints

- Keys and allowed values, defaults (verbatim from the spec):
  `REPOS_LAYOUT` `LIST`/`TILES` default `LIST`; `STATUS_VIEW` `ALL`/`CHANGES`
  default `ALL`; `STATUS_SORT` `OBJECT`/`FILE`/`TYPE` default `OBJECT`;
  `STATUS_CHANGES_FIRST` `X`/blank default `X`; `DIFF_LAYOUT` `INLINE`/`SBS`
  default `INLINE`; `DIFF_SHOW_ALL` `X`/blank default blank.
- Table `ZAG2UI5_SETTING`: `MANDT` (key), `UNAME` `SYUNAME` (key), `SETTING`
  `CHAR 40` (key), `VALUE` `CHAR 40`; delivery class A; package `$ABAPGIT2UI5`.
- Always the current user (`sy-uname`); the client never sends a user.
- `set( )` ends with `COMMIT WORK` (abap2UI5 rolls back after `main( )`).
- Apps keep no reference to the settings object in an attribute.
- In patch mode the diff layout is neither read nor saved.
- abaplint allows only 7-bit ASCII in sources.
- Pushes and merges only on Chris's word; `ignore` mode of abapgit-agent only
  with Chris's OK at that moment.

## Review Focus

1. **A tampered toggle value** (`TILES2`, a 50-character string, an unknown
   key) must store nothing and must not dump: `set` returns `abap_false`.
   Pinned in Task 2 (`set_refuses_value`, `set_refuses_unknown_key`,
   `set_refuses_long_value`).
2. **A stored value that is no longer allowed** (an option removed later, or
   a row edited by hand) must give the default, not break the view. Pinned
   in Task 2 (`get_ignores_stale_value`).
3. **A stored blank boolean** must read as "off", not as "no row, use the
   default `X`". Pinned in Task 2 (`blank_boolean_is_stored`) and Task 3
   (status `create_reads_settings` with `STATUS_CHANGES_FIRST` blank).
4. **Patch mode** must keep the inline layout even when `SBS` is stored, and
   must not overwrite the stored layout. Pinned in Task 3
   (`patch_ignores_layout`).
5. **App tests must not depend on the tester's own stored settings**: every
   app test class injects a double in `setup` and restores the real instance
   in `teardown`. Pinned in Task 3 (the existing `ltcl_patch` and
   `ltcl_columns` get the injection too).

---

## File Structure

| File | Responsibility |
|---|---|
| `src/zag2ui5_setting.tabl.xml` (new) | The table, serialized by abapGit |
| `src/zif_ag2ui5_settings.intf.abap` + `.xml` (new) | Keys, `get`, `set` |
| `src/zcl_ag2ui5_settings.clas.abap` + `.xml` (new) | Allow-list, defaults, instance and injection |
| `src/zcl_ag2ui5_settings.clas.locals_def.abap` (new) | `lif_store` |
| `src/zcl_ag2ui5_settings.clas.locals_imp.abap` (new) | `lcl_db_store` (table access, commit) |
| `src/zcl_ag2ui5_settings.clas.testclasses.abap` (new) | Tests with `ltd_memory_store` |
| `src/zcl_ag2ui5_app_repos.clas.abap` (+ new test include) | Read at start, save on `LAYOUT` |
| `src/zcl_ag2ui5_app_status.clas.abap` (+ new test include) | Read in `create`, save on `VIEW` |
| `src/zcl_ag2ui5_app_diff.clas.abap` + test include | Read in `create`, save on `LAYOUT`/`TOGGLE` |

New test includes need the class XML flag `<WITH_UNIT_TESTS>X</WITH_UNIT_TESTS>`
and an abapGit pull (ADT cannot create a test include). All new objects are
therefore pulled once, in Task 4, with the settings class still a stub and
the apps unchanged, so every new test is seen failing on the system first.

---

### Task 1: Table ZAG2UI5_SETTING

**Files:**
- Create: `src/zag2ui5_setting.tabl.xml`

**Interfaces:**
- Produces: table `zag2ui5_setting` with fields `mandt`, `uname`, `setting`, `value`.

- [ ] **Step 1: Create the table on A4H25 over ADT**

Write the DDL to the scratchpad as `zag2ui5_setting.tabl.asddls`:

```
@EndUserText.label : 'abapGit2UI5: user settings'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zag2ui5_setting {
  key mandt   : mandt not null;
  key uname   : syuname not null;
  key setting : abap.char(40) not null;
  value       : abap.char(40);
}
```

Run:
```sh
C=/home/chris/Projects/GIT/abapGit/.sapcli/a4h25
$C table create ZAG2UI5_SETTING "abapGit2UI5: user settings" '$ABAPGIT2UI5'
$C table write ZAG2UI5_SETTING <scratchpad>/zag2ui5_setting.tabl.asddls -a
```
Expected: `Activation has finished`, `Errors: 0`.

- [ ] **Step 2: Serialize it with abapGit into the repository**

Snippet (scratchpad, run with `$C abap run <file>`):

```abap
TRY.
    DATA(ls_item) = VALUE zif_abapgit_definitions=>ty_item(
      obj_type = 'TABL' obj_name = 'ZAG2UI5_SETTING' devclass = '$ABAPGIT2UI5' ).
    DATA(ls_files) = zcl_abapgit_objects=>serialize(
      is_item     = ls_item
      io_i18n_params = zcl_abapgit_i18n_params=>new( iv_main_language = sy-langu ) ).
    LOOP AT ls_files-files INTO DATA(ls_file).
      out->write( |FILE { ls_file-filename }| ).
      out->write( cl_abap_conv_codepage=>create_in( )->convert( ls_file-data ) ).
    ENDLOOP.
  CATCH cx_root INTO DATA(lx).
    out->write( |ERROR { lx->get_text( ) }| ).
ENDTRY.
```

If `serialize`'s signature differs in the installed abapGit, read it with
`grep -n "METHODS serialize" -A12 /home/chris/Projects/GIT/abapGit/src/objects/core/zcl_abapgit_objects.clas.abap`
and adjust. Save the XML part as `src/zag2ui5_setting.tabl.xml` (UTF-8 with
BOM, like the other XML files; undo sapcli's `&amp;` escaping if any).

- [ ] **Step 3: Check**

Run: `npm run check`
Expected: abaplint 0 issues, linter 0 failing.

- [ ] **Step 4: Commit**

```bash
git add src/zag2ui5_setting.tabl.xml
git commit -m "User settings: table ZAG2UI5_SETTING"
```

---

### Task 2: Interface, class stub and the class's tests

**Files:**
- Create: `src/zif_ag2ui5_settings.intf.abap`, `src/zif_ag2ui5_settings.intf.xml`
- Create: `src/zcl_ag2ui5_settings.clas.abap`, `.clas.xml`, `.clas.locals_def.abap`, `.clas.locals_imp.abap`, `.clas.testclasses.abap`

**Interfaces:**
- Consumes: table `zag2ui5_setting` (Task 1).
- Produces:
  - `zif_ag2ui5_settings=>c_key-repos_layout | status_view | status_sort | status_changes_first | diff_layout | diff_show_all` (TYPE string)
  - `zif_ag2ui5_settings~get( iv_key TYPE string iv_default TYPE string ) RETURNING VALUE(rv_value) TYPE string`
  - `zif_ag2ui5_settings~set( iv_key TYPE string iv_value TYPE string ) RETURNING VALUE(rv_saved) TYPE abap_bool`
  - `zcl_ag2ui5_settings=>get_instance( ) RETURNING VALUE(ri_settings) TYPE REF TO zif_ag2ui5_settings`
  - `zcl_ag2ui5_settings=>inject( ii_settings TYPE REF TO zif_ag2ui5_settings )` (unbound restores the real instance)

- [ ] **Step 1: The interface**

`src/zif_ag2ui5_settings.intf.abap`:

```abap
"! Settings of the current user (toggles of the apps), stored on the server
INTERFACE zif_ag2ui5_settings
  PUBLIC.

  CONSTANTS:
    BEGIN OF c_key,
      repos_layout         TYPE string VALUE `REPOS_LAYOUT`,
      status_view          TYPE string VALUE `STATUS_VIEW`,
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
```

`src/zif_ag2ui5_settings.intf.xml` (copy the format of `src/zif_ag2ui5_repo_service.intf.xml`, with `<CLSNAME>ZIF_AG2UI5_SETTINGS</CLSNAME>` and `<DESCRIPT>abapGit2UI5: user settings</DESCRIPT>`).

- [ ] **Step 2: The local store interface and the database store**

`src/zcl_ag2ui5_settings.clas.locals_def.abap`:

```abap
"! Where the settings live: the table, or memory in the tests
INTERFACE lif_store.
  METHODS read
    IMPORTING
      iv_user  TYPE syuname
      iv_key   TYPE string
    EXPORTING
      ev_found TYPE abap_bool
      ev_value TYPE string.
  METHODS write
    IMPORTING
      iv_user  TYPE syuname
      iv_key   TYPE string
      iv_value TYPE string.
ENDINTERFACE.
```

`src/zcl_ag2ui5_settings.clas.locals_imp.abap`:

```abap
CLASS lcl_db_store DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES lif_store.
ENDCLASS.

CLASS lcl_db_store IMPLEMENTATION.

  METHOD lif_store~read.

    CLEAR: ev_found, ev_value.
    SELECT SINGLE value FROM zag2ui5_setting
      WHERE uname = @iv_user AND setting = @iv_key
      INTO @DATA(lv_value).
    IF sy-subrc = 0.
      ev_found = abap_true.
      ev_value = lv_value.
    ENDIF.

  ENDMETHOD.

  METHOD lif_store~write.

    DATA(ls_row) = VALUE zag2ui5_setting( uname   = iv_user
                                          setting = iv_key
                                          value   = iv_value ).
    MODIFY zag2ui5_setting FROM @ls_row.
    " abap2UI5 rolls back after main( )
    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 3: The class as a stub**

`src/zcl_ag2ui5_settings.clas.abap` (stub: `get` always the default, `set` never saves; Task 5 fills them in):

```abap
"! Settings of the current user. Every key and value is checked against an
"! allow-list: the values come from the browser.
CLASS zcl_ag2ui5_settings DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_settings.

    CLASS-METHODS get_instance
      RETURNING
        VALUE(ri_settings) TYPE REF TO zif_ag2ui5_settings.

    "! Tests: replace the instance; an unbound reference restores the real one
    CLASS-METHODS inject
      IMPORTING
        ii_settings TYPE REF TO zif_ag2ui5_settings.

    METHODS constructor.

  PROTECTED SECTION.
  PRIVATE SECTION.
    CLASS-DATA gi_instance TYPE REF TO zif_ag2ui5_settings.
    DATA mi_store TYPE REF TO lif_store.

    "! The values a key may take; empty for an unknown key
    CLASS-METHODS allowed_values
      IMPORTING
        iv_key           TYPE string
      RETURNING
        VALUE(rt_values) TYPE string_table.
ENDCLASS.



CLASS zcl_ag2ui5_settings IMPLEMENTATION.

  METHOD constructor.
    mi_store = NEW lcl_db_store( ).
  ENDMETHOD.

  METHOD get_instance.
    IF gi_instance IS NOT BOUND.
      gi_instance = NEW zcl_ag2ui5_settings( ).
    ENDIF.
    ri_settings = gi_instance.
  ENDMETHOD.

  METHOD inject.
    gi_instance = ii_settings.
  ENDMETHOD.

  METHOD allowed_values.
    CLEAR rt_values.
  ENDMETHOD.

  METHOD zif_ag2ui5_settings~get.
    rv_value = iv_default.
  ENDMETHOD.

  METHOD zif_ag2ui5_settings~set.
    rv_saved = abap_false.
  ENDMETHOD.

ENDCLASS.
```

`src/zcl_ag2ui5_settings.clas.xml`: copy `src/zcl_ag2ui5_repo_service.clas.xml`, set `<CLSNAME>ZCL_AG2UI5_SETTINGS</CLSNAME>`, `<DESCRIPT>abapGit2UI5: user settings</DESCRIPT>`, keep `<WITH_UNIT_TESTS>X</WITH_UNIT_TESTS>`, and make sure `<CLSCCINCL>X</CLSCCINCL>` is there (locals_def).

- [ ] **Step 4: The tests**

`src/zcl_ag2ui5_settings.clas.testclasses.abap`:

```abap
"! In-memory store: what was written, and for which user
CLASS ltd_memory_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES lif_store.
    TYPES:
      BEGIN OF ty_row,
        user  TYPE syuname,
        key   TYPE string,
        value TYPE string,
      END OF ty_row.
    DATA mt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_memory_store IMPLEMENTATION.

  METHOD lif_store~read.
    CLEAR: ev_found, ev_value.
    READ TABLE mt_rows INTO DATA(ls_row) WITH KEY user = iv_user key = iv_key.
    IF sy-subrc = 0.
      ev_found = abap_true.
      ev_value = ls_row-value.
    ENDIF.
  ENDMETHOD.

  METHOD lif_store~write.
    DELETE mt_rows WHERE user = iv_user AND key = iv_key.
    INSERT VALUE #( user = iv_user key = iv_key value = iv_value ) INTO TABLE mt_rows.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_ag2ui5_settings.
    DATA mo_store TYPE REF TO ltd_memory_store.
    DATA mi_cut TYPE REF TO zif_ag2ui5_settings.

    METHODS setup.
    METHODS no_row_gives_default FOR TESTING.
    METHODS set_then_get FOR TESTING.
    METHODS blank_boolean_is_stored FOR TESTING.
    METHODS set_refuses_value FOR TESTING.
    METHODS set_refuses_unknown_key FOR TESTING.
    METHODS set_refuses_long_value FOR TESTING.
    METHODS get_ignores_stale_value FOR TESTING.
    METHODS row_carries_current_user FOR TESTING.
    METHODS every_key_has_values FOR TESTING.
ENDCLASS.

CLASS zcl_ag2ui5_settings DEFINITION LOCAL FRIENDS ltcl_settings.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    mo_store = NEW #( ).
    mo_cut->mi_store = mo_store.
    mi_cut = mo_cut.
  ENDMETHOD.

  METHOD no_row_gives_default.
    cl_abap_unit_assert=>assert_equals(
      exp = `LIST`
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_default = `LIST` ) ).
  ENDMETHOD.

  METHOD set_then_get.
    cl_abap_unit_assert=>assert_true(
      mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_value = `TILES` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `TILES`
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_default = `LIST` ) ).
  ENDMETHOD.

  METHOD blank_boolean_is_stored.
    " a stored blank is "off", not "nothing stored"
    cl_abap_unit_assert=>assert_true(
      mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-status_changes_first iv_value = `` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = ``
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-status_changes_first iv_default = `X` ) ).
  ENDMETHOD.

  METHOD set_refuses_value.
    cl_abap_unit_assert=>assert_false(
      mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-repos_layout iv_value = `TILES2` ) ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_rows ).
  ENDMETHOD.

  METHOD set_refuses_unknown_key.
    cl_abap_unit_assert=>assert_false( mi_cut->set( iv_key = `NO_SUCH_KEY` iv_value = `X` ) ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_rows ).
  ENDMETHOD.

  METHOD set_refuses_long_value.
    cl_abap_unit_assert=>assert_false(
      mi_cut->set( iv_key   = zif_ag2ui5_settings=>c_key-status_sort
                   iv_value = repeat( val = `A` occ = 50 ) ) ).
    cl_abap_unit_assert=>assert_initial( mo_store->mt_rows ).
  ENDMETHOD.

  METHOD get_ignores_stale_value.
    " an option removed later, or a row edited by hand
    INSERT VALUE #( user = sy-uname key = zif_ag2ui5_settings=>c_key-diff_layout value = `GONE` )
      INTO TABLE mo_store->mt_rows.
    cl_abap_unit_assert=>assert_equals(
      exp = `INLINE`
      act = mi_cut->get( iv_key = zif_ag2ui5_settings=>c_key-diff_layout iv_default = `INLINE` ) ).
  ENDMETHOD.

  METHOD row_carries_current_user.
    mi_cut->set( iv_key = zif_ag2ui5_settings=>c_key-status_view iv_value = `CHANGES` ).
    READ TABLE mo_store->mt_rows INTO DATA(ls_row) INDEX 1.
    cl_abap_unit_assert=>assert_subrc( ).
    cl_abap_unit_assert=>assert_equals( exp = sy-uname act = ls_row-user ).
  ENDMETHOD.

  METHOD every_key_has_values.
    " a key added to the interface but not to the allow-list could never be saved
    DATA(lt_keys) = VALUE string_table(
      ( zif_ag2ui5_settings=>c_key-repos_layout )
      ( zif_ag2ui5_settings=>c_key-status_view )
      ( zif_ag2ui5_settings=>c_key-status_sort )
      ( zif_ag2ui5_settings=>c_key-status_changes_first )
      ( zif_ag2ui5_settings=>c_key-diff_layout )
      ( zif_ag2ui5_settings=>c_key-diff_show_all ) ).
    LOOP AT lt_keys INTO DATA(lv_key).
      cl_abap_unit_assert=>assert_not_initial( act = zcl_ag2ui5_settings=>allowed_values( lv_key )
                                               msg = lv_key ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 5: Check offline**

Run: `npm run check`
Expected: abaplint 0 issues (fix any 7.50 syntax or ASCII finding), linter 0 failing.

- [ ] **Step 6: Commit**

```bash
git add src/zif_ag2ui5_settings.* src/zcl_ag2ui5_settings.*
git commit -m "Add failing tests: user settings (class still a stub)"
```

---

### Task 3: App tests

**Files:**
- Create: `src/zcl_ag2ui5_app_repos.clas.testclasses.abap`, `src/zcl_ag2ui5_app_status.clas.testclasses.abap`
- Modify: `src/zcl_ag2ui5_app_repos.clas.xml`, `src/zcl_ag2ui5_app_status.clas.xml` (add `<WITH_UNIT_TESTS>X</WITH_UNIT_TESTS>` after `<UNICODE>X</UNICODE>`)
- Modify: `src/zcl_ag2ui5_app_diff.clas.testclasses.abap`

**Interfaces:**
- Consumes: `zif_ag2ui5_settings` and `zcl_ag2ui5_settings=>inject( )` (Task 2); the apps' existing API: `zcl_ag2ui5_app_status=>create( iv_key )`, public `mv_view`, `mv_sort`, `mv_changes_first`; `zcl_ag2ui5_app_repos` public `mv_layout`, `z2ui5_if_app~main`; `zcl_ag2ui5_app_diff=>create( ... iv_patch )`, protected `mv_layout`, `mv_show_all`, `on_event`.
- Produces: nothing for later tasks; these tests define the behavior Task 6 implements.

Each test include has its own settings double (local classes are per include):

```abap
"! Settings double: preset values, and every set( ) call recorded
CLASS ltd_settings DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ag2ui5_settings.
    TYPES:
      BEGIN OF ty_pair,
        key   TYPE string,
        value TYPE string,
      END OF ty_pair,
      ty_pairs TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY.
    DATA mt_preset TYPE ty_pairs.
    DATA mt_saved TYPE ty_pairs.
    METHODS saved
      IMPORTING
        iv_key          TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.
ENDCLASS.

CLASS ltd_settings IMPLEMENTATION.

  METHOD zif_ag2ui5_settings~get.
    READ TABLE mt_preset INTO DATA(ls_pair) WITH KEY key = iv_key.
    rv_value = COND #( WHEN sy-subrc = 0 THEN ls_pair-value ELSE iv_default ).
  ENDMETHOD.

  METHOD zif_ag2ui5_settings~set.
    INSERT VALUE #( key = iv_key value = iv_value ) INTO TABLE mt_saved.
    rv_saved = abap_true.
  ENDMETHOD.

  METHOD saved.
    " the last value saved for the key; `?` if none was saved
    rv_value = `?`.
    LOOP AT mt_saved INTO DATA(ls_pair) WHERE key = iv_key.
      rv_value = ls_pair-value.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 1: Repository list tests**

`src/zcl_ag2ui5_app_repos.clas.testclasses.abap`: the `ltd_settings` block above, then:

```abap
"! abap2UI5 client: either the start (navigated) or one event
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_start TYPE abap_bool.
    DATA mv_event TYPE string.
ENDCLASS.

CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~check_on_navigated.
    result = mv_start.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_event.
    result = xsdbool( mv_start = abap_false ).
  ENDMETHOD.
  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.
  METHOD z2ui5_if_client~view_display ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~follow_up_action ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_box_display ##NEEDED.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_settings TYPE REF TO ltd_settings.
    DATA mo_client TYPE REF TO ltd_client.
    DATA mo_cut TYPE REF TO zcl_ag2ui5_app_repos.

    METHODS setup.
    METHODS teardown.
    METHODS start_reads_layout FOR TESTING.
    METHODS layout_event_saves FOR TESTING.
ENDCLASS.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_settings = NEW #( ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
    mo_client = NEW #( ).
    mo_cut = NEW #( ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD start_reads_layout.
    " the start also lists the repositories of the system; that only reads
    mo_settings->mt_preset = VALUE #( ( key = zif_ag2ui5_settings=>c_key-repos_layout value = `TILES` ) ).
    mo_client->mv_start = abap_true.
    mo_cut->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals( exp = `TILES` act = mo_cut->mv_layout ).
  ENDMETHOD.

  METHOD layout_event_saves.
    mo_cut->mv_layout = `TILES`.
    mo_client->mv_event = `LAYOUT`.
    mo_cut->z2ui5_if_app~main( mo_client ).
    cl_abap_unit_assert=>assert_equals(
      exp = `TILES`
      act = mo_settings->saved( zif_ag2ui5_settings=>c_key-repos_layout ) ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 2: Status tests**

`src/zcl_ag2ui5_app_status.clas.testclasses.abap`: the `ltd_settings` block, then:

```abap
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES z2ui5_if_client PARTIALLY IMPLEMENTED.
    DATA mv_event TYPE string.
ENDCLASS.

CLASS ltd_client IMPLEMENTATION.
  METHOD z2ui5_if_client~check_on_init.
    result = abap_false.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_navigated.
    result = abap_false.
  ENDMETHOD.
  METHOD z2ui5_if_client~check_on_event.
    result = abap_true.
  ENDMETHOD.
  METHOD z2ui5_if_client~get_event.
    result = mv_event.
  ENDMETHOD.
  METHOD z2ui5_if_client~view_display ##NEEDED.
  ENDMETHOD.
  METHOD z2ui5_if_client~message_box_display ##NEEDED.
  ENDMETHOD.
ENDCLASS.


CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_settings TYPE REF TO ltd_settings.

    METHODS setup.
    METHODS teardown.
    METHODS create_reads_settings FOR TESTING.
    METHODS create_without_settings FOR TESTING.
    METHODS view_event_saves FOR TESTING.
ENDCLASS.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_settings = NEW #( ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD create_reads_settings.
    " a stored blank for "changes on top" is off, not the default on
    mo_settings->mt_preset = VALUE #(
      ( key = zif_ag2ui5_settings=>c_key-status_view          value = `CHANGES` )
      ( key = zif_ag2ui5_settings=>c_key-status_sort          value = `FILE` )
      ( key = zif_ag2ui5_settings=>c_key-status_changes_first value = `` ) ).
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    cl_abap_unit_assert=>assert_equals( exp = `CHANGES` act = lo_app->mv_view ).
    cl_abap_unit_assert=>assert_equals( exp = `FILE` act = lo_app->mv_sort ).
    cl_abap_unit_assert=>assert_false( lo_app->mv_changes_first ).
  ENDMETHOD.

  METHOD create_without_settings.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    cl_abap_unit_assert=>assert_equals( exp = `ALL` act = lo_app->mv_view ).
    cl_abap_unit_assert=>assert_equals( exp = `OBJECT` act = lo_app->mv_sort ).
    cl_abap_unit_assert=>assert_true( lo_app->mv_changes_first ).
  ENDMETHOD.

  METHOD view_event_saves.
    DATA(lo_app) = zcl_ag2ui5_app_status=>create( `1` ).
    DATA(lo_client) = NEW ltd_client( ).
    lo_app->mv_view = `CHANGES`.
    lo_app->mv_sort = `TYPE`.
    lo_app->mv_changes_first = abap_false.
    lo_client->mv_event = `VIEW`.
    lo_app->z2ui5_if_app~main( lo_client ).
    cl_abap_unit_assert=>assert_equals(
      exp = `CHANGES` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_view ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `TYPE` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_sort ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-status_changes_first ) ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 3: Diff tests**

In `src/zcl_ag2ui5_app_diff.clas.testclasses.abap`:

1. Add `CLASS ltcl_settings DEFINITION DEFERRED.` and add `ltcl_settings` to the
   `LOCAL FRIENDS` list.
2. Insert the `ltd_settings` block after the `ltd_client` implementation.
3. In `ltcl_patch=>setup` add as the first line, and in `ltcl_columns=>app`
   before `create`:
   ```abap
   zcl_ag2ui5_settings=>inject( NEW ltd_settings( ) ).
   ```
   and give both classes a `teardown` (declared `METHODS teardown.`):
   ```abap
   METHOD teardown.
     zcl_ag2ui5_settings=>inject( VALUE #( ) ).
   ENDMETHOD.
   ```
4. Append:

```abap
CLASS ltcl_settings DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    DATA mo_settings TYPE REF TO ltd_settings.

    METHODS setup.
    METHODS teardown.
    METHODS create
      IMPORTING
        iv_patch      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(ro_app) TYPE REF TO zcl_ag2ui5_app_diff.
    METHODS fire
      IMPORTING
        io_app   TYPE REF TO zcl_ag2ui5_app_diff
        iv_event TYPE string.

    METHODS create_reads_settings FOR TESTING.
    METHODS patch_ignores_layout FOR TESTING.
    METHODS layout_event_saves FOR TESTING.
    METHODS toggle_event_saves FOR TESTING.
ENDCLASS.

CLASS ltcl_settings IMPLEMENTATION.

  METHOD setup.
    mo_settings = NEW #( ).
    mo_settings->mt_preset = VALUE #(
      ( key = zif_ag2ui5_settings=>c_key-diff_layout   value = `SBS` )
      ( key = zif_ag2ui5_settings=>c_key-diff_show_all value = `X` ) ).
    zcl_ag2ui5_settings=>inject( mo_settings ).
  ENDMETHOD.

  METHOD teardown.
    zcl_ag2ui5_settings=>inject( VALUE #( ) ).
  ENDMETHOD.

  METHOD create.
    ro_app = zcl_ag2ui5_app_diff=>create( iv_key = `1` iv_path = `/src/` iv_filename = `zcl_a.clas.abap`
                                          iv_obj_type = `CLAS` iv_obj_name = `ZCL_A` iv_patch = iv_patch ).
  ENDMETHOD.

  METHOD fire.
    DATA(lo_client) = NEW ltd_client( ).
    lo_client->mv_event = iv_event.
    io_app->z2ui5_if_app~main( lo_client ).
  ENDMETHOD.

  METHOD create_reads_settings.
    DATA(lo_app) = create( ).
    cl_abap_unit_assert=>assert_equals( exp = `SBS` act = lo_app->mv_layout ).
    cl_abap_unit_assert=>assert_true( lo_app->mv_show_all ).
  ENDMETHOD.

  METHOD patch_ignores_layout.
    " patch mode is always inline, and must not overwrite the stored layout
    DATA(lo_app) = create( abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = `INLINE` act = lo_app->mv_layout ).
    fire( io_app = lo_app iv_event = `TOGGLE` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `?` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-diff_layout ) ).
  ENDMETHOD.

  METHOD layout_event_saves.
    DATA(lo_app) = create( ).
    lo_app->mv_layout = `INLINE`.
    fire( io_app = lo_app iv_event = `LAYOUT` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `INLINE` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-diff_layout ) ).
  ENDMETHOD.

  METHOD toggle_event_saves.
    " the stored X is read, TOGGLE flips it and saves the new state
    DATA(lo_app) = create( ).
    fire( io_app = lo_app iv_event = `TOGGLE` ).
    cl_abap_unit_assert=>assert_equals(
      exp = `` act = mo_settings->saved( zif_ag2ui5_settings=>c_key-diff_show_all ) ).
  ENDMETHOD.

ENDCLASS.
```

- [ ] **Step 4: Check offline**

Run: `npm run check`
Expected: abaplint 0 issues, linter 0 failing. (`mv_layout`/`mv_show_all` are
protected; the friend declaration covers them.)

- [ ] **Step 5: Commit**

```bash
git add src/zcl_ag2ui5_app_*.clas.testclasses.abap src/zcl_ag2ui5_app_repos.clas.xml src/zcl_ag2ui5_app_status.clas.xml
git commit -m "Add failing tests: the apps read and save their settings"
```

---

### Task 4: Deploy the new objects and see the tests fail

**Files:** none changed.

- [ ] **Step 1: Push the branch and pull it into `$ABAPGIT2UI5`**

```sh
cd /home/chris/Projects/GIT/abapGit2UI5
/home/chris/Projects/GIT/abapGit/.sapcli/deploy-abapgit2ui5.sh
```

Read the `DEPLOY:` line. If it says "Pull aborted — n conflict(s)", **stop and
ask Chris** for `ignore` mode (`--conflict-mode ignore`); his OK is needed
every time. Pushing the feature branch itself is part of this script; Chris
agreed to this deploy path for feature branches.

- [ ] **Step 2: Compare with Git**

Run the `get_status( '000000000020' )` snippet from `AGENTS-LOCAL.md`.
Expected: only `.abapgit.xml` differs. The table already exists from Task 1
and must show no difference.

- [ ] **Step 3: Run the tests and see them fail**

```sh
cd /home/chris/Projects/GIT/abapGit
for f in zcl_ag2ui5_settings zcl_ag2ui5_app_repos zcl_ag2ui5_app_status zcl_ag2ui5_app_diff; do
  .sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/$f.clas.testclasses.abap
done
```

Expected failures: settings `set_then_get`, `blank_boolean_is_stored`,
`row_carries_current_user`, `get_ignores_stale_value` passes by accident
(the stub returns the default) — fine; `every_key_has_values` fails.
Repos: both fail. Status: `create_reads_settings`, `view_event_saves` fail.
Diff: `create_reads_settings`, `layout_event_saves`, `toggle_event_saves`
fail; the 11 existing tests pass. Record the counts in the ledger.

---

### Task 5: The settings class

**Files:**
- Modify: `src/zcl_ag2ui5_settings.clas.abap`

**Interfaces:**
- Consumes: `lif_store` (Task 2).
- Produces: the behavior the Task 2 tests describe.

- [ ] **Step 1: Implement**

Replace the three stub methods:

```abap
  METHOD allowed_values.

    CASE iv_key.
      WHEN zif_ag2ui5_settings=>c_key-repos_layout.
        rt_values = VALUE #( ( `LIST` ) ( `TILES` ) ).
      WHEN zif_ag2ui5_settings=>c_key-status_view.
        rt_values = VALUE #( ( `ALL` ) ( `CHANGES` ) ).
      WHEN zif_ag2ui5_settings=>c_key-status_sort.
        rt_values = VALUE #( ( `OBJECT` ) ( `FILE` ) ( `TYPE` ) ).
      WHEN zif_ag2ui5_settings=>c_key-diff_layout.
        rt_values = VALUE #( ( `INLINE` ) ( `SBS` ) ).
      WHEN zif_ag2ui5_settings=>c_key-status_changes_first
        OR zif_ag2ui5_settings=>c_key-diff_show_all.
        rt_values = VALUE #( ( `X` ) ( `` ) ).
    ENDCASE.

  ENDMETHOD.

  METHOD zif_ag2ui5_settings~get.

    DATA lv_found TYPE abap_bool.
    DATA lv_value TYPE string.

    rv_value = iv_default.
    DATA(lt_allowed) = allowed_values( iv_key ).
    IF lt_allowed IS INITIAL.
      RETURN.
    ENDIF.

    mi_store->read( EXPORTING iv_user  = sy-uname
                              iv_key   = iv_key
                    IMPORTING ev_found = lv_found
                              ev_value = lv_value ).
    " a value no longer allowed falls back to the default
    IF lv_found = abap_true AND line_exists( lt_allowed[ table_line = lv_value ] ).
      rv_value = lv_value.
    ENDIF.

  ENDMETHOD.

  METHOD zif_ag2ui5_settings~set.

    " key and value come from the browser
    DATA(lt_allowed) = allowed_values( iv_key ).
    IF NOT line_exists( lt_allowed[ table_line = iv_value ] ).
      rv_saved = abap_false.
      RETURN.
    ENDIF.

    mi_store->write( iv_user  = sy-uname
                     iv_key   = iv_key
                     iv_value = iv_value ).
    rv_saved = abap_true.

  ENDMETHOD.
```

- [ ] **Step 2: Check and deploy**

```sh
npm run check
cd /home/chris/Projects/GIT/abapGit
.sapcli/a4h25 class write ZCL_AG2UI5_SETTINGS /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_settings.clas.abap --activate
```
Expected: 0 issues; `Errors: 0`.

- [ ] **Step 3: Run the settings tests**

```sh
.sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/zcl_ag2ui5_settings.clas.testclasses.abap
```
Expected: 9/9 passed.

- [ ] **Step 4: Commit**

```bash
git add src/zcl_ag2ui5_settings.clas.abap
git commit -m "User settings: allow-list, get with fallback, set with check"
```

---

### Task 6: The apps read and save

**Files:**
- Modify: `src/zcl_ag2ui5_app_repos.clas.abap`, `src/zcl_ag2ui5_app_status.clas.abap`, `src/zcl_ag2ui5_app_diff.clas.abap`

**Interfaces:**
- Consumes: `zcl_ag2ui5_settings=>get_instance( )`, `zif_ag2ui5_settings=>c_key-*` (Task 2).

- [ ] **Step 1: Repository list**

In `z2ui5_if_app~main`, the start branch, before `load_repos( )`:

```abap
      mv_layout = zcl_ag2ui5_settings=>get_instance( )->get(
                    iv_key     = zif_ag2ui5_settings=>c_key-repos_layout
                    iv_default = `LIST` ).
```

In `view_display`, the `SegmentedButton` gets after `selectedKey`:

```abap
                )->a( n = `selectionChange` v = client->_event( `LAYOUT` )
```

In `on_event`:

```abap
      WHEN `LAYOUT`.
        " switching happens on the client; the server only remembers it
        zcl_ag2ui5_settings=>get_instance( )->set( iv_key   = zif_ag2ui5_settings=>c_key-repos_layout
                                                   iv_value = mv_layout ).
```

Update the comment on `mv_layout` to: `"! LIST or TILES; switched on the client, stored per user`.

- [ ] **Step 2: Status**

In `create`, after `ro_app->mv_key = iv_key.`:

```abap
    DATA(li_settings) = zcl_ag2ui5_settings=>get_instance( ).
    ro_app->mv_view = li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-status_view
                                        iv_default = `ALL` ).
    ro_app->mv_sort = li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-status_sort
                                        iv_default = `OBJECT` ).
    ro_app->mv_changes_first = xsdbool( li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-status_changes_first
                                                          iv_default = `X` ) = abap_true ).
```

In `on_event`, `WHEN `VIEW`.` becomes:

```abap
      WHEN `VIEW`.
        save_view_settings( ).
        rows_build( ).
```

New protected method `save_view_settings` (declare `METHODS save_view_settings.`):

```abap
  METHOD save_view_settings.

    DATA(li_settings) = zcl_ag2ui5_settings=>get_instance( ).
    li_settings->set( iv_key = zif_ag2ui5_settings=>c_key-status_view          iv_value = mv_view ).
    li_settings->set( iv_key = zif_ag2ui5_settings=>c_key-status_sort          iv_value = mv_sort ).
    li_settings->set( iv_key = zif_ag2ui5_settings=>c_key-status_changes_first iv_value = CONV #( mv_changes_first ) ).

  ENDMETHOD.
```

- [ ] **Step 3: Diff**

In `create`, after `ro_app->mt_picked = it_picked.`:

```abap
    DATA(li_settings) = zcl_ag2ui5_settings=>get_instance( ).
    ro_app->mv_show_all = xsdbool( li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-diff_show_all
                                                     iv_default = `` ) = abap_true ).
    " a patch is picked inline
    IF iv_patch = abap_false.
      ro_app->mv_layout = li_settings->get( iv_key     = zif_ag2ui5_settings=>c_key-diff_layout
                                            iv_default = `INLINE` ).
    ENDIF.
```

In `on_event`:

```abap
      WHEN `TOGGLE`.
        mv_show_all = xsdbool( mv_show_all = abap_false ).
        zcl_ag2ui5_settings=>get_instance( )->set( iv_key   = zif_ag2ui5_settings=>c_key-diff_show_all
                                                   iv_value = CONV #( mv_show_all ) ).
        rows_build( ).
```

```abap
      WHEN `LAYOUT`.
        zcl_ag2ui5_settings=>get_instance( )->set( iv_key   = zif_ag2ui5_settings=>c_key-diff_layout
                                                   iv_value = mv_layout ).
        " the layout changes the view's structure, not only its data
        view_display( ).
```

(Patch mode shows no layout switch, so `LAYOUT` never fires there.)

- [ ] **Step 4: Check, deploy, test**

```sh
npm run check
cd /home/chris/Projects/GIT/abapGit
for c in REPOS STATUS DIFF; do
  f=$(echo zcl_ag2ui5_app_$c | tr A-Z a-z)
  .sapcli/a4h25 class write ZCL_AG2UI5_APP_$c /home/chris/Projects/GIT/abapGit2UI5/src/$f.clas.abap --activate
done
for f in zcl_ag2ui5_settings zcl_ag2ui5_app_repos zcl_ag2ui5_app_status zcl_ag2ui5_app_diff zcl_ag2ui5_app_stage zcl_ag2ui5_repo_service; do
  .sapcli/venv/bin/python .sapcli/agent.py unit --files /home/chris/Projects/GIT/abapGit2UI5/src/$f.clas.testclasses.abap
done
```
Expected: abaplint 0, linter 0 failing; settings 9/9, repos 2/2, status 3/3,
diff 15/15, stage 12/12, service 113/113.

- [ ] **Step 5: Commit**

```bash
git add src/zcl_ag2ui5_app_repos.clas.abap src/zcl_ag2ui5_app_status.clas.abap src/zcl_ag2ui5_app_diff.clas.abap
git commit -m "Apps: read the user's settings, save every toggle"
```

---

### Task 7: Browser check and docs

**Files:**
- Modify: `AGENTS.md`, `README.md`, `docs/findings.md`; `AGENTS-LOCAL.md` (Git-ignored)

- [ ] **Step 1: Browser on A4H25**

Start URL from `AGENTS-LOCAL.md`. Switch the list to tiles, reload the page:
tiles. Open a repository, set "Changes only", sort by File, "Changes on
top" off; open another repository: the same. Open a diff, side by side and
"Show all"; open another file: the same. "Pick lines" on the staging page:
inline although side by side is stored, and afterwards a normal diff is
still side by side. Then set everything back to the defaults (Chris's own
settings). No console errors.

- [ ] **Step 2: Compare with Git**

`get_status( '000000000020' )`: only `.abapgit.xml` differs.

- [ ] **Step 3: Docs**

- `AGENTS.md`, "Anything the client sends is checked again": add the bullet
  `` - `ZCL_AG2UI5_SETTINGS->set` for a toggle: key and value against an allow-list ``.
  Under "Design rules", add: "User settings go through
  `ZCL_AG2UI5_SETTINGS`, not the service: it does not talk to abapGit. Its
  `set( )` commits, because abap2UI5 rolls back after `main( )`." Under
  "Checks", add `ZCL_AG2UI5_SETTINGS`, `ZCL_AG2UI5_APP_REPOS` and
  `ZCL_AG2UI5_APP_STATUS` to the ABAP Unit list.
- `README.md`: one bullet "Settings: every toggle is remembered per SAP user."
- `docs/findings.md`: a section "User settings (2026-10-03)" with what was
  built, the test counts, the deployment (pull, conflicts) and any minor
  review points.
- `AGENTS-LOCAL.md`: the four new unit test command lines and the counts.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md README.md docs/findings.md
git commit -m "Docs: user settings"
```

- [ ] **Step 5: Final review**

A fresh reviewer (most capable model) reads the spec, this plan and
`git diff main...feature/user-settings`, and reports findings; fix each with
a failing test first where it is a bug. Then report to Chris and ask
"merge and push?".
