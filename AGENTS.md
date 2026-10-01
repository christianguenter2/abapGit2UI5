# Agent guide

These are the things about this repository that are easy to get wrong. For
building abap2UI5 apps, follow `docs/agents/building-apps.md` in the
[abap2UI5 repository](https://github.com/abap2UI5/abap2UI5). Local SAP setup
is in `AGENTS-LOCAL.md` if that file is present. It is Git-ignored.

- Only `ZCL_AG2UI5_REPO_SERVICE` talks to abapGit, and it returns plain data.
  abap2UI5 serializes every attribute of an app on each round trip, so an app
  must never keep a reference to an abapGit object. Public attributes also go
  to the browser, so only bound data may be public.
- There is no SAP GUI in an HTTP request. Never call abapGit's popups
  (`zcl_abapgit_services_repo`, `zcl_abapgit_ui_factory=>get_popups`). Every
  service method first installs `ZCL_AG2UI5_PROGRESS_SILENT`.
- The self-update guard in `assert_pull_allowed` must stay. It refuses any
  package tree that contains abapGit, abap2UI5 or this repository, because that
  code is running in the session. On A4H25, local packages without a super
  package sit below `$TMP`, so `$TMP` is refused too.
- The pull decisions live in `preview( )` (groups and defaults) and
  `apply_decisions( )` (which writes a decision into every check table), both
  without side effects and covered by unit tests. The table in `README.md`
  must match them. Every row of the four check tables needs a decision, or
  abapGit's `checks_adjust` raises an exception.
- The headless screenshot (`abap2ui5lint --screenshot`) cannot follow values
  passed into `group_display( )`, so it renders the decision dialog empty. Test
  the dialog on a system.
- Checks: `npm run check` runs abaplint and the abap2UI5 linter, including the
  render gate. ABAP Unit only runs on a system.
- The push token must never reach the app state, which abap2UI5 writes to
  its draft table after every round trip. `ZCL_AG2UI5_APP_STAGE->push` takes
  it out of `mv_token` first, and the app tests check that on every path. The
  service sets it in abapGit's login manager for the one call and clears it
  again in every case.
