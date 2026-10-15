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
  - `switch_branch` checks the registered remote when another origin is
    switched in; do not validate the fork and then select on the original
  - Tags: `assert_tag_context` refuses fixed commits and switched origins;
    `assert_tag` checks fresh refs and `read_tag_commit` verifies a commit
    target. Creation checks the opening target against fresh refs; deletion
    uses `assert_deletable_tag` and the fresh unpeeled hash as expected old
    value, so a changed annotation cannot pass a stale confirmation
  - `save_labels`: validate labels and compare the opening labels with fresh
    local settings through `checked_labels` before writing
  - `apply_patch` and the fingerprint for picked lines: the diff is computed
    again, and a different fingerprint gives `changed`
  - `ZCL_AG2UI5_SETTINGS->set` for a toggle: key and value against an
    allow-list
  - `create_repo` for a new repository: `normalize_new_repo`,
    `new_repo_errors`, then abapGit's own checks and the self-update guard
    for the package. Nothing is written while one fails
  - `login`: user, token and URL non-empty, no control characters in any of
    them (header and request)
  - `create_package`: normalize and validate lengths before converting to SAP
    fields, refuse existing packages, check the parent and repository hierarchy,
    and validate the transport against a fresh workbench request list
  - `set_favorite`: validate raw key/state before fixed-length conversion,
    reload the registration and compare the requested state with current-user
    abapGit favorites; only write when it differs
  - `delete_repo`: reload metadata, recompute the preview and compare identity,
    action, objects and transport requirement with `assert_delete_preview`;
    validate keys before fixed-length conversion and require the exact package
    name for Uninstall
  - `ZCL_AG2UI5_APP_REPO_DIFF`: panel, Open and expand arguments are indexes
    into the PROTECTED file list from the status page; Open uses that row,
    never the posted panel data
- **Secrets:** abap2UI5 writes the app state after every round trip into its
  draft table `Z2UI5_T_01` as plain-text XML. `ZCL_AG2UI5_APP_LOGIN->main`
  therefore takes the token out of `mv_token` first, whenever `main` runs (with
  or without event, on the way back), and clears the Git user when the page
  is left; the app tests cover these. Remaining gap: abap2UI5's generic leave
  event `___ZZZ_NAL` saves the app without calling `main`. The login page
  never sends it, so only a hand-made request of the logged-on user could put
  that user's own token into that user's draft. `login( )` puts the credentials only into
  abapGit's login manager (static, keyed by host); the login app makes the
  session stateful so it survives the next request, and only when the request
  runs through `/sap/bc/zabapgit2ui5` (30 minute session timeout; A4H25 has
  none elsewhere). `ZCL_AG2UI5_HTTP` marks such requests on the server side
  (`is_own_node`); the path the browser reports does not count. The login
  page says so when opened elsewhere and offers no Log in. Credentials go
  after 30 minutes without a service call
  (`assert_authorized`), when the repository list is shown again
  (`logoff( )`), or with the session. No other app holds a token.
- **Stateful session:** abap2UI5 switches a session back to stateless only in
  the app that made it stateful. The list therefore sets stateful itself and
  switches off in the next round trip (`SESSION_END` via `start_timer`) when
  `zcl_ag2ui5_app_login=>is_stateful( )`. The node's handler calls
  `zcl_ag2ui5_repo_service=>request_start( )` once per request, which resets
  abapGit's repository service: a stateful session would otherwise keep
  abapGit's repository list and objects between requests. Never per service
  call: nested calls would drop an offline repository's ZIP mid-operation.
- **Login:** abapGit signals missing or rejected credentials only by text
  (`... Check your credentials`, not HTTP 407 of a proxy) or, in newer
  versions, by `zcx_abapgit_auth_required` (checked by name: older versions
  lack it); `login_required( )` checks both,
  and every app's `show_error( )` opens the login app for it. Back with
  `LOGGED_IN:<host>`, apps reload what failed to load; actions are not
  replayed (Stage keeps its selection and does not reload).
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
- **Single-file diffs:** Status and Stage rows carry `remote_sha1`. The
  apps keep it server-side (Stage `mt_remote`, Status `mt_status`, Repo
  diff `mt_source`) and pass it to `get_diff` with `iv_remote_known`, which
  fetches only that blob (`ZIF_AG2UI5_BLOB_SOURCE`), checks it with
  `checked_blob` and caches it per request. Refusals fall back to the full
  fetch; login errors do not. Commit/push and the object overview keep the
  full fetch.
- **Background Status runs:** Status calls `start_status`, which writes a
  row in `ZAG2UI5_RUN` and starts `Z_AG2UI5_SERIALIZE_LOCAL` as aRFC
  (`ZCL_AG2UI5_RUN_STARTER`, no callback). The task only serializes local
  files (`ZCL_AG2UI5_STATUS_RUN=>serialize`): never Git, never credentials,
  since the login lives in the HTTP session. Status polls with
  `start_timer` (`RUN_POLL:<run id>`, the run ID stays PROTECTED) and re-arms
  the timer at the end of every round trip that stays on the page, because
  abap2UI5 cancels the timer on every round trip. When the run is done,
  `get_status( iv_run_id )` takes the files (rows are read, updated and
  deleted only for `sy-uname` and the repository key), fetches the remote
  and calculates through `ZCL_AG2UI5_REPO_LOCAL_FILES`. No task start: Status
  loads synchronously. Status only displays; pull, push, previews and Stage
  load fresh and synchronously.
- **User settings** (the apps' toggles, table `ZAG2UI5_SETTING`) go through
  `ZCL_AG2UI5_SETTINGS`, not the service: they have nothing to do with
  abapGit. It always uses `sy-uname`, and its `set( )` commits itself. Apps
  call `get_instance( )` where they need it and keep no reference; tests
  replace it with `inject( )` and restore it in `teardown`.
- **Routes:** the apps own list (`#`), Status (`#/repo/<12-digit key>`) and
  repository Diff (`.../diff`) URLs. `resolve_route` validates the shape and
  reloads registrations; cold starts load fresh data and replay no action.
  `write_route` registers `ROUTE_CHANGED` on every response and uses
  `hash_replace`, with DEFAULT framework routing and inactive app-state.
  Keep Back working without a caller. Other pages retain their parent route;
  uploaded ZIPs and temporary edits are not restored by URLs. Login must clear
  its token and user before dispatching a route change.

## Logic without side effects (unit-tested; keep it that way)

| Area | Methods on `ZCL_AG2UI5_REPO_SERVICE` |
|---|---|
| Pull | `preview`, `merge_decisions`, `apply_decisions`, `effective_transport`, `assert_transport` |
| Status | `status_rows`, `sort_status_rows`, `object_status_rows`, `change_highlight`, `format_timestamp` |
| Diff | `map_diff`, `compact`, `to_side_by_side`, `remote_is_new`, `code_html`, `tinted_html`, `counts_text`, `visible`, `remote_sha1`, `checked_blob` |
| Stage | `stage_candidates`, `check_selection`, `check_push_allowed`, `commit_message`, `change_ignore_rules`, `ignore_preview`, `assert_ignore_preview` |
| Patch | `apply_patch`, `patch_lstate`, `fingerprint`; patch IDs come from `map_diff` |
| Branch | `branch_rows`, `assert_branch`, `branch_name`, `assert_branch_name`, `assert_new_branch`, `assert_deletable` |
| Tags | `tag_rows`, `tag_commit`, `assert_tag`, `assert_tag_context`, `assert_deletable_tag`, `checked_new_tag` |
| Labels | `repo_labels`, `checked_labels` |
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
  `ZCL_AG2UI5_APP_STATUS`, `ZCL_AG2UI5_APP_REPOS`, `ZCL_AG2UI5_APP_NEW_REPO`,
  `ZCL_AG2UI5_APP_REPO_DIFF`, `ZCL_AG2UI5_APP_LOGIN`, `ZCL_AG2UI5_HTTP`,
  `ZCL_AG2UI5_STATUS_RUN`, `ZCL_AG2UI5_PROGRESS_RUN`,
  `ZCL_AG2UI5_REPO_LOCAL_FILES`).
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
  `get( )-r_event_data`. Stage hands `PUSHED` (Back after a push) or
  `PUSHED:<message>` (it left by itself because nothing was left to stage) to
  the status page, which reloads and shows the message.
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

Keep a spec and plan for each active slice in `docs/superpowers/`. Remove
them once the slice is merged; Git history retains the completed work.
`docs/findings.md` holds current open points and known limits, not a log of
finished slices.
