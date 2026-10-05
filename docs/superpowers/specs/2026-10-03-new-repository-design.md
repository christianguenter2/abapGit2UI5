# New repository: design

Date: 2026-10-03. Status: approved in chat.

## Choices

- The repository list gets **"New repository"**. It creates an **online** or
  an **offline** repository, as abapGit's "New Online" and "New Offline" do.
- This is slice 1 of 2. Offline repositories stay greyed out in the list
  until slice 2 (offline support: open, import a ZIP through the pull
  dialog, export a ZIP). Creating one here is still useful: it registers
  the package in abapGit.
- The form has abapGit's full set of fields with abapGit's defaults; the
  rarely used ones sit in a collapsed panel.
- **No credentials.** Like status and stage, a private repository works
  only through abapGit's user exit. An empty remote (no commit, no default
  branch) is refused: abapGit would push a first branch, which needs a
  login.
- **No pull.** abapGit does not pull after creating a repository either.
  An online repository opens on its status page, where Pull imports.
- **Original slice: no package creation.** Superseded by the
  [package creation slice](2026-10-05-create-package-design.md).
  In the original slice, the package must exist, or (online only) the
  remote must contain a package file, which abapGit's rule allows: the
  first pull creates the package then.

## Page `ZCL_AG2UI5_APP_NEW_REPO`

A page of its own, reached from a "New repository" button in the header of
the repository list; Back returns to the list. Its header follows the rule
for page headers in `AGENTS.md` (overflow toolbar, back button
`NeverOverflow`).

| Field | Online | Offline | Default | Notes |
|---|---|---|---|---|
| Kind | switch | switch | Online | `SegmentedButton` ONLINE / OFFLINE |
| URL | required | – | | HTTPS address |
| Branch | optional | – | empty | empty: the remote's default branch |
| Name | – | required | | name of the offline repository |
| Package | required | required | | upper case, max. 30 |
| Display name | optional | optional | empty | |
| Folder logic | more | more | Prefix | Prefix / Full / Mixed |
| Labels | more | more | empty | comma-separated |
| Ignore subpackages | more | more | off | |
| Main language only | more | more | off | |
| ABAP language version | more | more | Any | Any / Ignore / Standard / Key user / Cloud |

"more" = in the collapsed panel "More settings".

- **Create** sends the form. On success:
  - online: the page is replaced by the status page of the new repository
    (`nav_app_leave` with the status app, so its Back returns to the list,
    which reloads in `check_on_navigated`);
  - offline: back to the list with a message toast, the list reloaded.
- **Errors** go to their field (`valueState Error` and `valueStateText`).
  An error without a field (authorization, a failed creation) goes to a
  `MessageStrip` above the form. Fields keep their values after an error.
- Nothing is remembered between visits; no user settings.

## Service

New in `ZIF_AG2UI5_REPO_SERVICE`:

```abap
TYPES:
  BEGIN OF ty_new_repo,
    kind           TYPE string,     " ONLINE / OFFLINE
    url            TYPE string,
    branch         TYPE string,
    name           TYPE string,
    package        TYPE string,
    display_name   TYPE string,
    folder_logic   TYPE string,
    labels         TYPE string,
    ign_subpackages TYPE abap_bool,
    main_lang_only TYPE abap_bool,
    abap_lang_vers TYPE string,
  END OF ty_new_repo.
TYPES:
  BEGIN OF ty_field_error,
    field TYPE string,              " a component of ty_new_repo; empty: no field
    text  TYPE string,
  END OF ty_field_error,
  ty_field_errors TYPE STANDARD TABLE OF ty_field_error WITH EMPTY KEY.
TYPES:
  BEGIN OF ty_new_repo_result,
    outcome TYPE ty_outcome,        " c_outcome-created / -invalid
    key     TYPE string,
    errors  TYPE ty_field_errors,
  END OF ty_new_repo_result.

METHODS create_repo
  IMPORTING is_repo          TYPE ty_new_repo
  RETURNING VALUE(rs_result) TYPE ty_new_repo_result
  RAISING   zcx_abapgit_exception.
```

`c_outcome` gets `created` and `invalid`.

`create_repo` runs in two steps. **Checks first**: every check runs and all
errors are collected; if there is one, nothing is written and the outcome
is `invalid`. **Then the creation.**

### Checks

Without side effects, unit-tested (`new_repo_errors`):

- `kind` is ONLINE or OFFLINE;
- online: `url` filled; offline: `name` filled;
- `package` filled;
- `folder_logic` is PREFIX, FULL or MIXED (abapGit's constants);
- `abap_lang_vers` is one of abapGit's values or empty;
- the values are trimmed; the package is upper-cased.

Against abapGit and the system:

- the authorization to create repositories
  (`zcl_abapgit_auth=>is_allowed( create_repo )`), error without field;
- online: `zcl_abapgit_repo_srv->validate_url`, the provider-specific
  check (`zcl_abapgit_git_url->validate_url`) and a connection check;
  errors on `url`;
- online: the remote has a default branch (or the given branch exists);
  otherwise "The repository has no commit yet. Push a first commit (for
  example a README), then try again." on `url` (or the branch error on
  `branch`);
- `validate_package` (name, SAP's own packages, a package already used by
  another repository, local and transportable mixed); errors on `package`;
- the self-update guard `assert_pull_allowed` for the package: no
  repository in or above the packages of abapGit, abap2UI5 or this
  repository (on A4H25 `$TMP` too); error on `package`;
- `zcl_abapgit_repo_labels=>validate`; errors on `labels`.

### Creation

The steps of `zcl_abapgit_services_repo=>new_online` / `new_offline`,
without their popups (that class stays forbidden):

- online: `zcl_abapgit_repo_srv->new_online( ... )`; then, in a `TRY`:
  the package must exist or the remote must contain a package file, and
  the checksums are rebuilt. If one of them fails, the repository is
  deleted again and the error is reported without field;
- offline: `zcl_abapgit_repo_srv->new_offline( ... )`;
- both: the repository becomes a favorite of the user, as in abapGit;
- `COMMIT WORK AND WAIT`; abap2UI5 rolls back after `main( )`.

The service installs `ZCL_AG2UI5_PROGRESS_SILENT` and checks abapGit's
startup authorization first, as every service method does.

## Tests

Written to fail first.

- Service (`ZCL_AG2UI5_REPO_SERVICE` test include): `new_repo_errors`
  for each rule above (online without URL, offline without name, missing
  package, unknown kind, folder logic, language version, trimming and
  upper case).
- App (new test include, service double):
  - Create with a valid form: online leaves the page for the status page
    (`nav_app_leave` with a status app), offline leaves it for the list
    with a toast;
  - Create with errors: the field gets `Error` and its text, the others
    are cleared; an error without field fills the message strip;
  - switching the kind keeps the shared fields;
  - Back leaves the page.
- `npm run check` with the render gate.
- On A4H25:
  - create a public online repository into a new `$` package (the remote
    has a package file), open it, pull it;
  - refused: a package already used, an invalid URL, an empty remote,
    `$TMP` and `$ABAPGIT`;
  - create an offline repository; its tile is greyed out;
  - delete the test repositories afterwards (and their packages).

## Deployment

The new app class needs a test include, so one abapGit pull of
`$ABAPGIT2UI5` is needed. If abapgit-agent reports its false conflicts,
`ignore` mode needs Chris's OK, asked at that point. Everything else goes
over ADT.
