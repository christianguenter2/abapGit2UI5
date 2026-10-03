# User settings: design

Date: 2026-10-03. Status: approved in chat.

## Choices

- Every toggle of the apps is remembered **per SAP user, on the server**, in
  a table of this repository (not abapGit's tables, not the browser).
- A change is saved **immediately**, in the toggle's event. There is no
  "save as default".
- Settings apply to the user across all repositories, not per repository.
- Without a stored value, today's default applies. Settings are not shared,
  not transported, and hold no secrets.

## The settings

| Key | App | Values | Default |
|---|---|---|---|
| `REPOS_LAYOUT` | Repository list | `LIST`, `TILES` | `LIST` |
| `STATUS_VIEW` | Status | `ALL`, `CHANGES` | `ALL` |
| `STATUS_SORT` | Status | `OBJECT`, `FILE`, `TYPE` | `OBJECT` |
| `STATUS_CHANGES_FIRST` | Status | `X`, blank | `X` |
| `DIFF_LAYOUT` | Diff | `INLINE`, `SBS` | `INLINE` |
| `DIFF_SHOW_ALL` | Diff | `X`, blank | blank |

## Storage

Table `ZAG2UI5_SETTING` in `$ABAPGIT2UI5`, delivery class A, no table
maintenance:

| Field | Type | Key |
|---|---|---|
| `MANDT` | `MANDT` | yes |
| `UNAME` | `SYUNAME` | yes |
| `SETTING` | `CHAR 40` | yes |
| `VALUE` | `CHAR 40` | |

One row per user and setting. A blank `VALUE` in an existing row is a stored
"off"; no row means the default.

abap2UI5 rolls back after every `main( )`, so `set( )` ends with
`COMMIT WORK`. The toggle events have nothing else pending.

## Interface and class

`ZIF_AG2UI5_SETTINGS`:

- constants `c_key-repos_layout`, `-status_view`, `-status_sort`,
  `-status_changes_first`, `-diff_layout`, `-diff_show_all` (the values of
  the table above);
- `get( iv_key iv_default ) RETURNING rv_value TYPE string`;
- `set( iv_key iv_value ) RETURNING rv_saved TYPE abap_bool`.

`ZCL_AG2UI5_SETTINGS`:

- Always the current user (`sy-uname`); the client never sends a user.
- Knows the allowed values per key (the table above).
- `set( )` writes nothing and returns `abap_false` for an unknown key or a
  value that is not allowed. The value comes from the browser, so this is
  the server-side check `AGENTS.md` asks for.
- `get( )` returns `iv_default` when there is no row, and also when the
  stored value is no longer allowed (an option removed later).
- `get_instance( )` returns the instance; `inject( )` (for tests) replaces
  it. Apps call `get_instance( )` where they need it and keep no reference
  in an attribute: abap2UI5 serializes every app on each round trip.
- The database access sits behind a local interface (`read`, `write`), so
  the class's own tests use an in-memory store and never touch the table.

The class does not talk to abapGit, so it stays apart from
`ZCL_AG2UI5_REPO_SERVICE`.

## Apps

- **Repository list:** `REPOS_LAYOUT` is read on the first start
  (`check_on_init`). The toggle gets `selectionChange` with a new event
  `LAYOUT`, which only saves; switching stays on the client.
- **Status:** `create( )` reads `STATUS_VIEW`, `STATUS_SORT` and
  `STATUS_CHANGES_FIRST`. The existing `VIEW` event saves all three.
- **Diff:** `create( )` reads `DIFF_LAYOUT` and `DIFF_SHOW_ALL`. `LAYOUT`
  saves the layout, `TOGGLE` saves "show all". In patch mode the layout
  stays inline and is neither read nor saved.

## Tests

Written to fail first.

- `ZCL_AG2UI5_SETTINGS` (new test include, in-memory store):
  - no row: the default;
  - `set` then `get`: the stored value, also a blank boolean;
  - unknown key, value not allowed: `set` returns `abap_false`, nothing
    stored;
  - a stored value that is no longer allowed: the default;
  - the row carries the current user.
- Apps, with an injected double that records `set` calls:
  - Diff (existing include): `create( )` takes the stored layout and "show
    all"; `LAYOUT` and `TOGGLE` save; patch mode ignores the stored layout.
  - Status and repository list (new includes): `create( )` / start takes the
    stored values; `VIEW` / `LAYOUT` save them.
- `npm run check` with the render gate.
- On A4H25: change each toggle, reload the page, open another repository:
  the settings stay. A second user is not needed: the key carries the user.

## Deployment

- The table is created through ADT (`table create` / `table write`) and
  serialized into the repository as `zag2ui5_setting.tabl.xml`.
- The interface and the class main sources go over ADT.
- New test includes cannot be created over ADT: one abapGit pull of
  `$ABAPGIT2UI5` is needed. If abapgit-agent reports its false conflicts,
  `ignore` mode needs Chris's OK, asked at that point.
