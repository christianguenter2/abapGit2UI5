# Git login for the session

## Problem

Without credentials from abapGit's user exit, a private repository cannot be
read (status, diff, branches, pull) and pushing needs the user and token typed
on the Stage page for every single push. abapGit in SAP GUI asks once and keeps
the credentials in memory for the session.

## Decisions (Chris, 2026-10-07)

- Option 1: keep the credentials in server memory of a stateful session, in
  abapGit's login manager (`zcl_abapgit_login_manager`, static, keyed by host).
  Never in app attributes (abap2UI5 writes those to `Z2UI5_T_01` as plain
  text), never in the database, never in the browser.
- Plus option 2 (expiry in our code) and option 3 (back to stateless when the
  user returns to the repository list).
- Scope: every remote access, including push; the token field on Stage goes.
- Own ICF node `/sap/bc/zabapgit2ui5` with a 30 minute session timeout (done:
  `docs/findings.md`, "Own ICF node").

## How abapGit reports missing credentials

Without a GUI, abapGit's `acquire_login_details` asks the user exit
(`change_password_popup_username`) and the ADT backend for credentials; with
none it raises `zcx_abapgit_exception` with the text
`Unauthorized access. Check your credentials`. Credentials already in the login
manager are sent as a header before the request; rejected ones are removed
before that error. An exit that supplies credentials never reaches it.

## Behavior

### Service (`ZIF_AG2UI5_REPO_SERVICE`, `ZCL_AG2UI5_REPO_SERVICE`)

- New exception class `ZCX_AG2UI5_LOGIN_REQUIRED`, inheriting from
  `zcx_abapgit_exception` (existing CATCH blocks keep working), with the
  repository's display host as attribute `mv_host`. Every service method that
  reaches the remote (status, stage, diff, preview/pull, branch list, switch,
  create, delete, commit_push, new repository online checks) translates abapGit's
  `Unauthorized access. Check your credentials` into it. The text check is in
  one helper, `login_required( ix_error, iv_url )`, unit-tested.
- `login( iv_key, iv_user, iv_token )`: checks authorization and the inputs
  (both non-empty, no control characters), then
  `zcl_abapgit_login_manager=>set_basic( repository URL )`, and records
  `sy-datum/uzeit` as last use. Nothing is checked against the remote here; the
  retried action does that, and a 401 there removes the credentials again
  (abapGit) and raises login required anew.
- `logoff( )`: `zcl_abapgit_login_manager=>clear( )`.
- Expiry (option 2): a static last-use timestamp in the service. Every service
  call first checks it: older than 30 minutes → `clear( )`. Every successful
  remote call refreshes it.
- `commit_push` loses `iv_user` / `iv_token` and no longer clears the login
  manager; the credentials stay for the session.

### New app `ZCL_AG2UI5_APP_LOGIN`

- Opened with `nav_app_call` by any app that caught login required:
  `create( iv_key iv_host )`. Page: "Log in to <host>", Git user, token or
  password (type Password), Log in, Cancel. A short text says the credentials
  stay in this browser session's server memory for at most 30 minutes and are
  never stored.
- `on_event` takes the token out of `mv_token` first, for every event (as
  Stage does today). Log in: `service( )->login( )`, then
  `client->set_session_stateful( abap_true )`, then
  `nav_app_leave( r_data = `LOGGED_IN` )`. Cancel: `nav_app_leave( )`.
- Errors (empty fields) stay on the page with a message box.

### Apps

- Status, Stage, Diff, repository diff, New repository and the repository list
  catch `ZCX_AG2UI5_LOGIN_REQUIRED` before their generic `zcx_abapgit_exception`
  handling, remember the event and its arguments in PROTECTED `ms_pending`,
  and open the login app. On navigation back with `LOGGED_IN` they repeat the
  pending event once; without it (Cancel) they clear it and show
  `Not logged in - <action> was not done`.
- Stage: the Git user and token fields go; Commit & push needs only title and
  committer. The token rules in AGENTS.md move to the login app.
- Repository list (option 3): on start and on navigation back it calls
  `service( )->logoff( )` and `client->set_session_stateful( abap_false )`.
  Leaving a repository therefore ends the session's credentials.

## Out of scope

Saving credentials anywhere; a log-off button (the list does it); SSH; per
repository accounts on the same host (the login manager is keyed by host, as in
abapGit).

## Tests

- Service: `login_required` maps the abapGit text and nothing else; `login`
  refuses empty or control-character input; expiry clears after 30 minutes and
  not before (time injected); `commit_push` signature without token.
- Login app: token cleared on every event; Log in calls the service and leaves
  with `LOGGED_IN` and stateful; Cancel leaves without; empty input stays.
- Status app (representative for the catch/retry): an action raising login
  required opens the login app and keeps the pending event; `LOGGED_IN` retries
  it once; Cancel clears it.
- Stage: no token field; push without token.
- Repository list: logoff and stateless on start and on return.
- Live: a private repository on A4H25 without exit credentials is needed for an
  end-to-end check; if none exists, the live check covers the popup through a
  forced login-required (Chris decides).
