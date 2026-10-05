# Agent guide

These are the things about this repository that are easy to get wrong. For
building abap2UI5 apps, follow `docs/agents/building-apps.md` in the
[abap2UI5 repository](https://github.com/abap2UI5/abap2UI5). The local SAP
setup (system, fixtures, deployment) is in `AGENTS-LOCAL.md` if that file is
present. It is Git-ignored.

## Design rules

- Only `ZCL_AG2UI5_REPO_SERVICE` talks to abapGit, and it returns plain data.
  abap2UI5 serializes every attribute of an app on each round trip, so an app
  must never keep a reference to an abapGit object. Public attributes also go
  to the browser, so only bound data may be public; anything else goes in
  PROTECTED.
- There is no SAP GUI in an HTTP request. Never call abapGit's popups
  (`zcl_abapgit_services_repo`, `zcl_abapgit_ui_factory=>get_popups`). Every
  service method first installs `ZCL_AG2UI5_PROGRESS_SILENT` and checks
  abapGit's startup authorization.
- The self-update guard in `assert_pull_allowed` must stay. It refuses any
  package tree that contains abapGit, abap2UI5 or this repository, because that
  code is running in the session. On A4H25, local packages without a super
  package sit below `$TMP`, so `$TMP` is refused too.
- Anything the client sends is checked again on the server against fresh
  abapGit data:
  - `merge_decisions` for pull decisions (object **and** group)
  - `effective_transport` / `assert_transport` for transport requests
  - `check_selection` / `check_push_allowed` for staged files
  - `ignore_repo_preview` / `assert_ignore_preview` for saving ignore rules:
    fresh rules and affected files must match; previews never persist settings
  - `assert_branch` for a branch to switch to, against a fresh branch list
  - `assert_branch_name` / `assert_new_branch` for a new branch, after
    `branch_name` normalized it
  - `assert_deletable` for a branch to delete, against a fresh branch list;
    the commit sent to the remote comes from that list
  - `apply_patch` and the fingerprint for picked lines: the diff is computed
    again, and a different fingerprint gives `changed`
  - `ZCL_AG2UI5_SETTINGS->set` for a toggle: key and value against an
    allow-list
  - `create_repo` for a new repository: `normalize_new_repo`,
    `new_repo_errors`, then abapGit's own checks and the self-update guard
    for the package. Nothing is written while one fails
  - `create_package`: normalize and validate lengths before converting to SAP
    fields, refuse existing packages, check the parent and repository hierarchy,
    and validate the transport against a fresh workbench request list
  - `delete_repo`: reload metadata, recompute the preview and compare identity,
    action, objects and transport requirement with `assert_delete_preview`;
    validate keys before fixed-length conversion and require the exact package
    name for Uninstall
- **Secrets:** abap2UI5 writes the app state after every event into its draft
  table `Z2UI5_T_01` as plain-text XML. `ZCL_AG2UI5_APP_STAGE->on_event`
  therefore takes the token out of `mv_token` first, for every event, and the
  app tests cover every event. The service sets the credentials in abapGit's
  login manager for the one call and clears them in `CLEANUP`.
- After `push( )` the service calls `COMMIT WORK AND WAIT`, as abapGit does.
  abap2UI5 rolls back after `main( )`.
- **Package creation:** this is a separate action from repository registration.
  abapGit's package `create` leaves dialog suppression unset, so the service
  uses SAP's factory/save with `i_suppress_dialog = abap_true` and passes the
  checked transport explicitly. Commit after success; discard a new in-memory
  package after a failed save. `$TMP` and `ZLOCAL` are permitted as local
  containers, not as repository roots to bypass the self-update guard.
- **Ignore rules:** use abapGit's `.abapgit.xml` matcher, including starting
  folder exclusions and ordered negations; conventional `.gitignore` is not
  interpreted. `save_ignore` commits local configuration persistence too.
  Removal previews use an unregistered repository copy, never persist its
  settings. Keep online Stage reachable with no local changes so rules can
  still be removed after a commit. Saving rules clears stale selections and
  patches while retaining commit text and committer details.
- **Remove / Uninstall:** use repository-service `delete` / `purge`, never GUI
  services. Uninstall checks authorization, write protection, language, the
  running-code hierarchy guard and other registered repositories in scope.
  Validate transports against a fresh workbench request list. abapGit commits
  each object deletion: partial failures cannot be rolled back, so retain
  registration and return its log. Commit registration removal on success.
  Nonempty packages or pending transport entries may keep a package in SAP
  after its objects and registration have been removed.
- **Offline ZIPs:** the status and diff apps retain the original ZIP bytes
  in PROTECTED attributes. `get_repo` restores the offline remote files on
  every status, diff, preview and pull call; without a ZIP it clears them.
  Offline preview/pull without a ZIP is refused. `zip_files` checks raw ZIP
  entries before abapGit's loader (duplicate filenames can dump there),
  requires root `.abapgit.xml` and wraps invalid XML as an abapGit exception.
  Keep uploads and downloads binary; the framework's generic file popups
  convert through text. Export uses `encode_files`, never SAP GUI file APIs.
- **User settings** (the apps' toggles, table `ZAG2UI5_SETTING`) go through
  `ZCL_AG2UI5_SETTINGS`, not the service: they have nothing to do with
  abapGit. It always uses `sy-uname`, and its `set( )` commits itself. Apps
  call `get_instance( )` where they need it and keep no reference; tests
  replace it with `inject( )` and restore it in `teardown`.

## Logic without side effects (unit-tested; keep it that way)

| Area | Methods on `ZCL_AG2UI5_REPO_SERVICE` |
|---|---|
| Pull | `preview`, `merge_decisions`, `apply_decisions`, `effective_transport`, `assert_transport` |
| Status | `status_rows`, `sort_status_rows`, `object_status_rows`, `change_highlight`, `format_timestamp` |
| Diff | `map_diff`, `compact`, `to_side_by_side`, `remote_is_new`, `code_html`, `tinted_html`, `counts_text`, `visible` |
| Stage | `stage_candidates`, `check_selection`, `check_push_allowed`, `commit_message`, `change_ignore_rules`, `ignore_preview`, `assert_ignore_preview` |
| Patch | `apply_patch`, `patch_lstate`, `fingerprint`; patch IDs come from `map_diff` |
| Branch | `branch_rows`, `assert_branch`, `branch_name`, `assert_branch_name`, `assert_new_branch`, `assert_deletable` |
| New repository | `normalize_new_repo`, `new_repo_errors` |
| New package | `normalize_new_package`, `new_package_errors` |
| Remove / Uninstall | `assert_delete_preview` |
| Offline ZIP | `decode_zip`, `zip_files` |

The table in `README.md` ("How a pull decides") must match `preview`. Every
row of abapGit's four check tables needs a decision, or abapGit's
`checks_adjust` raises an exception.

## Checks

- `npm run check` runs abaplint and the abap2UI5 linter, including the render
  gate. It needs no system, and CI runs it too.
- ABAP Unit runs only on a system (`ZCL_AG2UI5_REPO_SERVICE`,
  `ZCL_AG2UI5_SETTINGS`, `ZCL_AG2UI5_APP_STAGE`, `ZCL_AG2UI5_APP_DIFF`,
  `ZCL_AG2UI5_APP_STATUS`, `ZCL_AG2UI5_APP_REPOS`, `ZCL_AG2UI5_APP_NEW_REPO`).
  A client double that is
  `PARTIALLY IMPLEMENTED` raises on the kernel for every method it leaves
  out: building a view needs `_bind` and `_event`.
- The headless screenshot (`abap2ui5lint --screenshot`) cannot follow values
  passed into helper methods (`group_display`, `transport_display`), and it
  renders every branch of an `IF`. Check dialogs on a system, or render a
  scratch copy with the helpers inlined.
- Page headers are an `OverflowToolbar` in `customHeader` (every page), not
  `headerContent`, which has no overflow and hides the back
  button on narrow screens. A control that gets `layoutData` must be opened
  with `ele( )`: after `tag( )` the chain is back on the toolbar.
- A toast sent in the same round trip as `nav_app_leave` is lost. Hand the
  message over with `nav_app_leave( r_data = ... )`; the list shows it from
  `get( )-r_event_data`.
- Event arguments arrive as abap2UI5 sends them: a boolean is `X` or space,
  not `true`. App tests with a client double must send the same values.
- `ObjectAttribute.customContent` accepts a Link or Text, not an HBox. Use
  a direct Link when an ADT URI exists and ordinary attribute text otherwise.
- For an editable rule with Preview/Save, an Input `change` server event can
  consume the next button click while its round trip runs. Use
  `valueLiveUpdate` and expressions built with `client->_bind` to hide stale
  previews and disable Save; compare the rule again on the server.
- Code reaches the browser through `sap.m.FormattedText` (`code_html`): it is
  escaped in ABAP, and UI5 sanitizes it too. Control characters must be
  replaced before they reach the model (`visible`): abap2UI5's JSON escaping
  does not cover them.

## Process

Each slice has a spec and a plan in `docs/superpowers/`. Its results, review
findings and open points are in `docs/findings.md`.
