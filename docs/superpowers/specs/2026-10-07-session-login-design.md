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

- `CLASS-METHODS login_required( ix_error ) RETURNING abap_bool`: true only
  for abapGit's `Unauthorized access. Check your credentials`. The apps route
  every caught `zcx_abapgit_exception` through it; no new exception class and
  no wrapping of each service method is needed (revised 2026-10-07: same
  behavior, far less code).
- `login( iv_key | iv_url, iv_user, iv_token )`: authorization, inputs
  non-empty without control characters, then
  `zcl_abapgit_login_manager=>set_basic( repository URL )`. Nothing is checked
  against the remote here; the next remote call does, and abapGit removes
  rejected credentials and raises the same error again.
- `logoff( )`: `zcl_abapgit_login_manager=>clear( )`.
- Expiry (option 2): `assert_authorized( )`, which every service method calls
  first, clears the login manager when the static last-use time is older than
  30 minutes and then sets it to now. Time is injectable for tests.
- `commit_push` loses `iv_user` / `iv_token` and no longer clears the login
  manager.
- Host for texts: `CLASS-METHODS url_host( iv_url )`.

### New app `ZCL_AG2UI5_APP_LOGIN`

- `create( iv_key iv_url iv_host )`; page "Log in to <host>" with Git user,
  token or password (type Password), Log in, Cancel, and a text that the
  credentials stay in this session's server memory for at most 30 minutes
  without use and are never stored.
- `on_event` takes the token out of `mv_token` first, for every event. Log in:
  `service( )->login( )`, `client->set_session_stateful( abap_true )`,
  `nav_app_leave( r_data = |LOGGED_IN:<host>| )`. Cancel: `nav_app_leave( )`.
  Errors stay on the page.

### Apps

- Status, Stage, Diff, repository diff, New repository and the repository
  list send every caught `zcx_abapgit_exception` through one method
  `show_error( )`: login required opens the login app, anything else shows the
  message box as today.
- Back from the login app with `LOGGED_IN:<host>`, the app reloads its data
  (status, staging, the diff, branch list as applicable) and shows
  `Logged in to <host> - repeat the action if it did not run`. Actions are not
  replayed: abap2UI5 can raise a server event only by name, and the inputs and
  selection are still on the page.
- Stage: the Git user and token fields go; Commit & push needs only title and
  committer. The token rules in AGENTS.md move to the login app.
- Repository list (option 3): on start and on navigation back it calls
  `service( )->logoff( )` and `client->set_session_stateful( abap_false )`.

## Out of scope

Saving credentials anywhere; a log-off button (the list does it); SSH; per
repository accounts on the same host (the login manager is keyed by host, as in
abapGit).

## Tests

- Service: `login_required` maps the abapGit text and nothing else; `login`
  refuses empty or control-character input; expiry clears after 30 minutes and
  not before (time injected); `url_host`.
- Login app: token cleared on every event; Log in calls the service and leaves
  with `LOGGED_IN` and stateful; Cancel leaves without; empty input stays.
- Each app: a login-required error opens the login app (not a message box);
  back with `LOGGED_IN:<host>` reloads and shows the toast; other errors still
  show the message box.
- Stage: no token field; push without token.
- Repository list: logoff and stateless on start and on return.
- Live: a private repository on A4H25 without exit credentials is needed for an
  end-to-end check; if none exists, the live check covers the popup through a
  forced login-required (Chris decides).
