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
- The abort-mode rule lives in `classify( )` and is covered by unit tests. The
  table in `README.md` must match it.
- Checks: `npm run check` runs abaplint and the abap2UI5 linter, including the
  render gate. ABAP Unit only runs on a system.
