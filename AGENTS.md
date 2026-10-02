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
  - `assert_branch` for a branch to switch to, against a fresh branch list
  - `assert_branch_name` / `assert_new_branch` for a new branch, after
    `branch_name` normalized it
  - `assert_deletable` for a branch to delete, against a fresh branch list;
    the commit sent to the remote comes from that list
  - `apply_patch` and the fingerprint for picked lines: the diff is computed
    again, and a different fingerprint gives `changed`
- **Secrets:** abap2UI5 writes the app state after every event into its draft
  table `Z2UI5_T_01` as plain-text XML. `ZCL_AG2UI5_APP_STAGE->on_event`
  therefore takes the token out of `mv_token` first, for every event, and the
  app tests cover every event. The service sets the credentials in abapGit's
  login manager for the one call and clears them in `CLEANUP`.
- After `push( )` the service calls `COMMIT WORK AND WAIT`, as abapGit does.
  abap2UI5 rolls back after `main( )`.

## Logic without side effects (unit-tested; keep it that way)

| Area | Methods on `ZCL_AG2UI5_REPO_SERVICE` |
|---|---|
| Pull | `preview`, `merge_decisions`, `apply_decisions`, `effective_transport`, `assert_transport` |
| Status | `status_rows`, `sort_status_rows`, `change_highlight`, `format_timestamp` |
| Diff | `map_diff`, `compact`, `to_side_by_side`, `remote_is_new`, `code_html`, `tinted_html`, `counts_text`, `visible` |
| Stage | `stage_candidates`, `check_selection`, `check_push_allowed`, `commit_message` |
| Patch | `apply_patch`, `patch_lstate`, `fingerprint`; patch IDs come from `map_diff` |
| Branch | `branch_rows`, `assert_branch`, `branch_name`, `assert_branch_name`, `assert_new_branch`, `assert_deletable` |

The table in `README.md` ("How a pull decides") must match `preview`. Every
row of abapGit's four check tables needs a decision, or abapGit's
`checks_adjust` raises an exception.

## Checks

- `npm run check` runs abaplint and the abap2UI5 linter, including the render
  gate. It needs no system, and CI runs it too.
- ABAP Unit runs only on a system (`ZCL_AG2UI5_REPO_SERVICE`,
  `ZCL_AG2UI5_APP_STAGE`, `ZCL_AG2UI5_APP_DIFF`).
- The headless screenshot (`abap2ui5lint --screenshot`) cannot follow values
  passed into helper methods (`group_display`, `transport_display`), and it
  renders every branch of an `IF`. Check dialogs on a system, or render a
  scratch copy with the helpers inlined.
- Event arguments arrive as abap2UI5 sends them: a boolean is `X` or space,
  not `true`. App tests with a client double must send the same values.
- Code reaches the browser through `sap.m.FormattedText` (`code_html`): it is
  escaped in ABAP, and UI5 sanitizes it too. Control characters must be
  replaced before they reach the model (`visible`): abap2UI5's JSON escaping
  does not cover them.

## Process

Each slice has a spec and a plan in `docs/superpowers/`. Its results, review
findings and open points are in `docs/findings.md`.
