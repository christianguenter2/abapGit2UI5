# abapGit2UI5

A browser frontend for [abapGit](https://github.com/abapGit/abapGit), built with
[abap2UI5](https://github.com/abap2UI5/abap2UI5). It runs in any browser, so
it avoids the quirks of the SAP GUI HTML control (IE and Edge controls, SAP GUI
for Java, WebGUI).

It uses the same abapGit repositories and serialization, with a UI5 interface
for the workflows below.

**Status: experimental.** It is tested end to end on one SAP NetWeaver 7.5x
system (A4H). Other releases are untested.

## Feature comparison

This compares the conventional abapGit UI with the current abapGit2UI5
frontend, as of October 2026. Conventional abapGit features are described in
the [abapGit user guide](https://docs.abapgit.org/user-guide/).

| Feature | Conventional abapGit UI | abapGit2UI5 |
|---|---|---|
| User interface | [HTML control in SAP GUI](https://docs.abapgit.org/user-guide/setup/sapgui.html), including SAP GUI for HTML | SAPUI5 in a browser through abap2UI5 |
| Installation | Standalone program or developer version | Requires the abapGit developer version, abap2UI5 and its ICF service |
| Repository browsing | Repository list, labels and favorites | Searchable list or compact tiles, colored clickable labels, shared favorites and a remembered Favorites only filter |
| Status and object overview | Object groups with file details and change states | Files or Objects view, filters, sorting and changed/total file counts |
| Line diff | Unified or split diff with context and method/section markers; repository-wide diff page | Inline or side-by-side diff, context or whole file; **Diff** page with every changed file as a collapsible panel |
| Structural method review | Method/section markers in the line diff | Added, removed and changed declarations/implementations, with links to their source ranges |
| Stage, commit and push | File selection and line patches | File selection and **Pick lines**; push to the followed branch or to a new one |
| Pull decisions | Separate dialogs for overwrite, deletion, package and other checks | One dialog grouped by risk, with individual selections and abapGit's defaults |
| Ignore rules | Native `.abapgit.xml` rules | Same rules, with editable patterns and previews before saving or removing |
| Branches and tags | Switch, create, delete and merge branches; tag operations | Switch, create at the current head and delete branches; browse, select, create and delete tags; no merge UI |
| Authentication | [Username/password or token dialog](https://docs.abapgit.org/user-guide/projects/online/authentication.html) when credentials are needed | Credentials from an abapGit user exit, otherwise a login page when abapGit asks; kept in session memory for at most 30 minutes without use |
| Offline ZIPs | Import and export | Binary upload/download, status and diff against the uploaded ZIP, selective import |
| Repository and package lifecycle | Register repositories, create packages, remove and uninstall | Online/offline registration, package creation, Remove and guarded Uninstall with a deletion preview |
| Transports | SAP transport request dialogs; stage/export by transport and transport-to-branch tools | Select an existing request for pull, package creation or uninstall; no request creation or transport-based staging |
| Settings, checks and automation | Repository settings, Code Inspector/ATC, syntax and unit-test tools, [background mode](https://docs.abapgit.org/user-guide/repo-settings/background-mode.html) | Remembers display preferences per SAP user; these administration tools are not exposed |

abapGit2UI5 covers selected workflows rather than the full conventional UI.
Not part of it: branch merging, creating a transport request from a dialog,
interpreting a conventional `.gitignore`, repository settings, Code
Inspector/ATC, syntax and unit-test tools, and background mode. Use the
conventional abapGit UI for these. Repository labels can be edited here.

Pulling updates to abapGit, abap2UI5 or this frontend also requires
conventional abapGit, because the browser session is running that code.

## Screenshots

| Repository list | Repository tiles | Status |
|---|---|---|
| ![Repository list with favorites](docs/screenshots/repos.png) | ![Compact repository tiles](docs/screenshots/repos-tiles.png) | ![Status of a repository](docs/screenshots/status.png) |

| Diff | Pull | Stage |
|---|---|---|
| ![Diff of one file](docs/screenshots/diff.png) | ![Decision dialog](docs/screenshots/pull-dialog.png) | ![Staging page](docs/screenshots/stage.png) |

The screenshots are rendered with `abap2ui5lint --screenshot`, using data from
a real system.

## Prerequisites

- The abapGit **developer version**, meaning the `ZCL_ABAPGIT_*` classes. The
  standalone program `ZABAPGIT_STANDALONE` is not enough, because its classes
  are local to the program. Developed against the current developer version.
  Older versions lack `zcx_abapgit_auth_required`; missing credentials are then
  recognized by the error text.
- abap2UI5 1.146.0 or later, with its ICF service active.
- ABAP 7.50 or later.

## Installation

Install this repository with abapGit into a local package, for example
`$ABAPGIT2UI5`. It brings its own ICF node `/sap/bc/zabapgit2ui5`
(handler `ZCL_AG2UI5_HTTP`, which runs abap2UI5) with a session timeout of
30 minutes; activate it in SICF if your system installs nodes inactive. It also
brings the transaction `ZABAPGIT2UI5` (see Start).

## Start

```
https://<host>:<port>/sap/bc/zabapgit2ui5?sap-client=<client>&app_start=zcl_ag2ui5_app_repos
```

Or start transaction **ZABAPGIT2UI5** in SAP GUI: it opens this URL in the
default browser, using the SAP GUI logon language (`sap-language=sy-langu`).
It builds the URL from the node's location
(`cl_http_server=>get_location`). Where the server's own host name is not
reachable from the browser (for example a system in a container), add an entry
for `/sap/bc/zabapgit2ui5` in table `HTTPURLLOC` (SM30) with the host, port and
protocol the browser uses.

The abap2UI5 node `/sap/bc/z2ui5` works too, but has no session timeout of its
own, and the login page (see Credentials) is not available there.

Using the frontend requires abapGit's startup authorization (see
`ZCL_ABAPGIT_AUTH_EXIT`).

## Supported workflows

### Repositories

- **Repository list:** all abapGit repositories of the system, with a search,
  as a table or as compact tiles (one card per repository, with the favorite
  star in the top-right corner).
- **Favorites:** star repositories in either layout. Favorites are shared with
  classic abapGit for your SAP user and appear first. **Favorites only**
  combines with search and is remembered; new users start with All. Adding or
  removing a favorite shows a confirmation toast.
- **Repository labels:** colored labels appear in tiles, list rows and the
  repository header. Click a label to filter the overview to that exact label.
  abapGit's configured user colors map to the pill palette; labels without a
  configured color receive a stable automatic color. **Edit labels** in the
  repository header offers existing labels, removable tokens and a field to
  add new labels. Save updates local abapGit repository settings; Cancel
  discards changes. A concurrent label edit is refused so it is not
  overwritten.
- **New repository:** online (from a Git URL) or offline, with abapGit's
  settings and its own checks; each error is shown on its field. Credentials
  for a private repository come from abapGit's user exit (see Credentials).
  **Create package...** beside the package field creates a local or
  transportable package and returns its name to the form. Transportable
  packages need an existing workbench request; the server checks it again.
  Package creation is a separate step, so the package remains if repository
  creation later fails. An online repository may also bring its package along.
- **Remove / Uninstall:** available in both layouts, online and offline.
  Remove unregisters the repository and keeps its SAP objects. Uninstall
  previews the objects to delete, requires the package name to be typed, and
  asks for a workbench request when needed. The server checks the scope again
  and protects running code and other registered repositories. Partial
  failures retain registration and show the deletion log. SAP may retain
  packages until deletion transports are released. Neither action changes the
  remote Git repository.
- **Settings:** display preferences are remembered per SAP user: list or tiles,
  Favorites only, the status page's overview, filter, sort and "changes on
  top", and the diff's layout and "show all".

### Status and diff

- **Status:** every file of the repository. Changed files (in the system, in
  Git or both, or inactive) are marked yellow, with a bar and a light
  background; the Local and Remote columns tell which side changed. "Changes
  only" hides the rest. Sort by object, file or type; "Changes on top" (on by
  default) lists the changed files first.
- **Object overview:** switch from Files to Objects for one row per ABAP
  object, with changed/total file counts and combined Local/Remote states.
  Press the row to see all its files and open a diff; Back returns to that
  file list. Files without an object appear under "Repository files".
- **Diff:** pressing a file in the status list shows its line diff, inline or
  side by side, with changes in context or the whole file. As in abapGit, the
  side that changed is the "new" one, in green. Side by side keeps the system
  left and Git right in both directions, as abapGit does. Added lines have a
  light green background, removed ones light red, folded unchanged lines light
  grey.
- **All changes:** **Diff** in the status table's toolbar opens every changed
  file of the repository on one page, one collapsible panel each, in file
  order. The first three are open; others load when expanded (Expand all opens
  at most 25). Each panel has **Open** for the single-file diff.
- **Structural method review:** opening a class or interface in Objects shows
  added, removed and changed method declarations and implementations in its
  changed ABAP source files. Each summary opens that method's source range;
  **Show complete diff** restores the file. The diff page offers the same
  review. Summaries follow the diff direction and include local/test classes.
  Comments, formatting, XML metadata and other object types remain in the raw
  diffs. This reports structure, without predicting runtime behavior.
- **Object links:** object names in status, staging and pull decisions link to
  the local object in Eclipse/ADT. The diff page offers the same link. Objects
  that are missing locally or cannot be resolved stay as plain text. Enable
  the `adt` link handler in Eclipse under **General > Link Handlers** to open
  these links.

### Pull

- **Pull with decisions:** a dialog lists every change, grouped by risk, with
  abapGit's defaults preselected. Only what you tick is changed. For
  transportable packages it asks for one of your modifiable transport
  requests. Mark all and Unmark all apply across the change groups to enabled
  rows; transport choices and the Pull anyway acknowledgment stay separate.
  See "How a pull decides" below.
- **Offline repositories:** open an offline repository, import an abapGit or
  GitHub source ZIP through the same pull decision dialog, or export the
  current local files as a ZIP. Status and diff compare the uploaded ZIP
  with the system. Choose **Import ZIP**, select the file, and press
  **Upload**. Review the decisions and choose **Pull selected** to import.
  Canceling the decisions keeps the ZIP available for status and diff; Back
  discards it, and reopening the repository starts without a ZIP. **Export
  ZIP** downloads the local package as `repository.zip` (the button may be in
  the header's overflow menu). Branches and staging are available for online
  repositories only.

### Stage, commit, push

- **Stage:** select files that differ between SAP and Git, enter a commit
  message, then push. Credentials come from abapGit's user exit or the session
  login (see Credentials).
  - Staging commits the SAP version: it can also revert a Git-only change,
    restore a remotely deleted file or remove a file that exists only in Git.
  - Files changed in Git carry an explicit notice before selection; pulling
    first is optional, as in conventional abapGit.
  - **Pick lines** commits only some changes of a file: both halves of a
    changed line go together, as in abapGit.
  - The **Changed by** column shows who changed a file, as abapGit does: the
    owner of the transport request that contains the object, UNKNOWN without
    one. The Objects view has the same column per object.
  - An optional **New branch** creates that branch at the checked head,
    follows it and pushes there, as abapGit's commit page does.
  - After the last staged change is pushed, the app returns to the repository
    status; if changes remain, it stays on Stage.
- **Ignore:** staging respects abapGit's ignore rules and starting folder.
  These are abapGit's native `.abapgit.xml` rules, not a conventional
  `.gitignore` file.
  - A file's Ignore button opens its full path as an editable rule; use `*`
    for any sequence or `+` for one character. Preview the affected staging
    files, then save locally. Commit `.abapgit.xml` to share the change.
  - **Ignore rules** lists existing rules and lets you preview and remove
    them.
  - Ignoring a tracked file leaves its remote version in place.
  - Saving a rule reloads staging and clears file selections and picked
    lines; commit text and committer details stay.

### Branches and tags

The status page's button shows the followed branch or selected tag and opens
the **Branches and tags** dialog. Credentials come from abapGit's user exit or
the session login (see Credentials).

- **Branches:** a list of remote branches with their commits and
  default/followed markers. Each row offers **Switch** and **Delete** where
  allowed. Switching changes only the followed branch; status then shows what
  a pull would bring. **New branch** creates a branch at the current head.
  Deletion requires a confirmation; the default and followed branches cannot
  be deleted.
- **Tags:** the **Tags** tab is loaded from the remote on demand. It lists
  lightweight and annotated tags with resolved commits; annotated tag objects
  and their peeled refs appear as one row.
  - **Switch** selects the tag for status and diff without importing objects.
    Use Pull separately to review and import that version. Stage is disabled
    while a tag is selected; switch back to a branch to stage and push.
  - **New tag** creates a lightweight or annotated tag at the displayed remote
    commit. Annotated tags require a message and author details, prefilled
    from Git identity settings. Creation preserves the selected reference and
    local changes; existing names and changed targets are refused.
  - **Delete** removes an unselected remote tag after confirmation. Switch
    away from the selected tag first.
  - Targets are verified by a shallow Git fetch per distinct object; this can
    transfer trees/blobs and makes large tag lists slower. Tree/blob or
    unresolved targets have no Switch action, but remain deletable by raw ref.
  - Tag operations refuse fixed commits and switched origins; return to a
    reference on the registered remote first. Missing, moved or changed tags
    (including changed annotations at the same commit) are refused against
    fresh remote refs until the list is reopened.
- **Reference links:** branch labels omit `refs/heads/`; selected tags show
  `Tag <name>`. In the repository list, tiles and the dialog, click a branch
  or tag name to open it on the remote in a new tab. Links support GitHub,
  GitLab.com and Bitbucket Cloud; other hosts retain a plain short label.

## How a pull decides

Pull opens one dialog instead of abapGit's sequence of popups. Every object
appears once, in its most dangerous group:

| Group | Changes | Preselected |
|---|---|---|
| Data loss | Data would be lost, or a table with data would be deleted | no |
| Delete local objects | Objects that are not in the remote | no |
| Overwrite local changes | Objects changed in the system | no |
| Package change | Package moves, and objects in another package | no |
| Import | Added or changed only remotely, or deleted locally | yes (with a new namespace, only the namespace, as in abapGit) |
| Skipped | Object types abapGit does not support | cannot be selected |

"Pull selected" checks again before it imports. If the remote changed in
between, it imports nothing and asks you to review again. If requirements or
APACK dependencies are not met, you have to confirm "Pull anyway".

For transportable packages, the dialog asks for a transport request. It offers
your own modifiable requests of the required type (workbench or customizing),
and the server checks the choice again. Create the request in SE09 first;
creating one from the dialog is not supported.

Pulling a repository whose package contains abapGit, abap2UI5 or this
frontend is refused. It would replace code that is running in the same
session. Use abapGit in SAP GUI for those.

## Credentials

Credentials for private repositories come from an abapGit user exit. Without
one, a page asks for the Git user and token when abapGit needs them. This
works only through `/sap/bc/zabapgit2ui5`, whose sessions end after 30 minutes
without use.

- They stay in abapGit's login manager in this session's server memory only
  (the session becomes stateful for that). They are kept for at most 30
  minutes without a request, until you return to the repository list, or until
  the session ends.
- They are never stored. After a login, credentials that abapGit accepted from
  the user exit are kept for that session as well.
- The action that needed them is not repeated automatically; pages that could
  not load reload after the login.

## Security

- Everything the browser sends is checked again on the server against fresh
  abapGit data: pull decisions, transports, staged files, ignore rules,
  branches, tags, package and repository creation, and deletions.
- Only one class talks to abapGit, and it never calls abapGit's GUI popups.
  Every service call first checks abapGit's startup authorization.
- The self-update guard refuses pulling, uninstalling or registering a package
  tree that contains abapGit, abap2UI5 or this frontend. On a system where
  local packages have no super package, this also refuses `$TMP` as a
  repository root.
- abap2UI5 saves each app's state in its draft table `Z2UI5_T_01` as plain
  text. The login page therefore removes the token from the app state on every
  round trip. One gap remains: abap2UI5's generic leave event `___ZZZ_NAL` can
  save the app without running that code. This page never sends it, so only a
  hand-made request of the logged-on user could put that user's own token into
  that user's own draft.

## Development

```sh
npm install
npm run check   # abaplint + abap2UI5 linter, no SAP system needed
```

The local checks need network access to fetch their ABAP dependencies from
GitHub. They include UI5 property validation and headless rendering, but do not
execute ABAP Unit.

ABAP Unit runs on an SAP system, in the test include of each class in `src/`
(`*.clas.testclasses.abap`): the repository service, settings, login, HTTP
handler and every app class.

Further documents:

- `docs/superpowers/specs/` and `docs/superpowers/plans/`: design and plan of
  each slice.
- `docs/findings.md`: results of the end-to-end tests, review findings and
  open points.
- `docs/feature-ideas.md`: candidate features, not committed scope.
- `docs/upstream-notes.md` and `docs/upstream-drafts.md`: issues found in
  abapGit, abap2UI5 and related tools, not yet filed.

## License

[MIT](LICENSE)
