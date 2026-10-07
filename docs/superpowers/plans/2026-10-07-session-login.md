# Git Login for the Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When abapGit's user exit supplies no credentials, the user logs in once per session; the credentials stay in abapGit's login manager in a stateful session's memory, expire after 30 minutes without use, and are dropped on the repository list.

**Architecture:** The service gets `login_required( )` (recognizes abapGit's error), `login( )`, `logoff( )`, `url_host( )` and an expiry check inside `assert_authorized( )`. A new app `ZCL_AG2UI5_APP_LOGIN` asks for user/token, logs in and switches the session to stateful. Every app routes its caught `zcx_abapgit_exception` through `show_error( )`, which opens the login app for login-required errors; back with `LOGGED_IN:<host>` the app reloads. Stage loses its token fields; the repository list logs off and goes stateless.

**Tech Stack:** ABAP on A4H25 (abapGit developer version, abap2UI5 1.146), ABAP Unit, abaplint + abap2ui5lint, abapgit-mcp for the new class.

**Spec:** `docs/superpowers/specs/2026-10-07-session-login-design.md`

## Global Constraints

- Credentials only in `zcl_abapgit_login_manager` (static); never in an app attribute that survives an event, never in DB or browser storage.
- The login app clears `mv_token` first, for every event.
- Expiry: 30 minutes since the last service call.
- The repository list: `logoff( )` + `set_session_stateful( abap_false )` on start and on return.
- No action is replayed after login; loads are repeated.
- Work in worktree `/home/chris/Projects/GIT/abapGit2UI5-icf`, branch `feature/session-login` (on top of `feature/icf-node`). Link `node_modules` from `../abapGit2UI5` for `npm run check`, remove the link afterwards.
- Deploy existing classes over ADT (`.sapcli/a4h25 class write|interface write ... --activate`); new class via abapgit-mcp `write_objects` (shell + placeholder test include, then ADT).
- Pushes/merges only on Chris's word.

## Review Focus

1. A token typed in the login app must never survive an event in the app state — test `token_cleared_every_event`.
2. Wrong credentials: abapGit removes them and raises the same error, so the login app opens again instead of looping silently — test `wrong_login_reopens` (service double raises again after login).
3. Expiry boundary: 29:59 keeps, 30:01 clears — tests `expiry_keeps`, `expiry_clears`.
4. An error that is not login-required must still show the message box (no regression) — test per app `other_error_message`.
5. The repository list must end the stateful session even when no login happened — test `list_goes_stateless`.

---

### Task 1: Service

**Files:** `src/zif_ag2ui5_repo_service.intf.abap`, `src/zcl_ag2ui5_repo_service.clas.abap`, its test include; test doubles implementing `commit_push` in `zcl_ag2ui5_app_stage.clas.testclasses.abap`.

**Produces:**
- `CLASS-METHODS login_required IMPORTING ix_error TYPE REF TO zcx_abapgit_exception RETURNING VALUE(rv_yes) TYPE abap_bool` (public, static, on the class).
- `CLASS-METHODS url_host IMPORTING iv_url TYPE string RETURNING VALUE(rv_host) TYPE string` (`github.com` from `https://github.com/a/b.git`; empty for empty).
- Interface: `METHODS login IMPORTING iv_key TYPE string OPTIONAL iv_url TYPE string OPTIONAL iv_user TYPE string iv_token TYPE string RAISING zcx_abapgit_exception` (URL from the repository when `iv_key` is given, else `iv_url`; raises on empty user/token/URL or control characters).
- Interface: `METHODS logoff`.
- Interface: `commit_push` without `iv_user` / `iv_token`.
- Expiry: `CLASS-DATA gv_last_use TYPE timestampl` and a test seam `CLASS-DATA gv_now TYPE timestampl` (0 = use `GET TIME STAMP`), checked in `assert_authorized( )`.

- [ ] **Step 1: Tests** in a new local test class `ltcl_login` (friend): `login_required_text` (true for `Unauthorized access. Check your credentials`, false for `HTTP 401 Unauthorized` and empty), `url_host_cases`, `login_refuses_empty` (user, token, URL), `login_refuses_control_chars`, `expiry_keeps` (set `gv_last_use` = now − 1799 s, call `assert_authorized`, then `zcl_abapgit_login_manager=>get( url )` still set), `expiry_clears` (now − 1801 s → cleared), `logoff_clears`. Use `zcl_abapgit_login_manager=>set_basic( iv_uri = `https://example.invalid/r.git` iv_username = `u` iv_password = `p` )` as fixture data in tests only (test values, not credentials) and `clear( )` in teardown.
- [ ] **Step 2: RED** — write test include; activation fails or tests fail.
- [ ] **Step 3: Implement**; remove the `set_basic`/`clear` block from `commit_push` (keep its TRY/CLEANUP structure only where still needed) and drop the two parameters; adjust Stage's call and its test double signature.
- [ ] **Step 4: GREEN** — deploy interface, class, test include; service suite and stage suite pass; `npm run check`.
- [ ] **Step 5: Commit** `Service: login for the session, expiry, no token on push`.

### Task 2: Login app

**Files:** create `src/zcl_ag2ui5_app_login.clas.{abap,testclasses.abap,xml}`.

**Produces:** `zcl_ag2ui5_app_login=>create( iv_key TYPE string OPTIONAL iv_url TYPE string OPTIONAL ) RETURNING ro_app`; public bound `mv_user`, `mv_token`, `mv_host`; protected `mi_service`; leaves with `r_data = |LOGGED_IN:{ host }|`.

- [ ] **Step 1: Tests** (client double with `set_session_stateful` recording the value, `nav_app_leave` recording `r_data`; service double recording `login` and failing on request): `token_cleared_every_event` (LOGIN, CANCEL, unknown), `login_calls_service` (user/token/key passed, stateful = X, left with `LOGGED_IN:github.com`), `cancel_leaves_plain`, `empty_input_stays` (no service call, message, not left), `service_error_stays` (message, not stateful, not left), `view_has_password_field`.
- [ ] **Step 2: RED** — create the class shell through abapgit-mcp (`$ABAPGIT2UI5`), write stub + tests over ADT, run.
- [ ] **Step 3: Implement** (page with OverflowToolbar header + Back = Cancel, SimpleForm: Git user, Token or password `type="Password"`, Text about memory/30 minutes, buttons Log in (Emphasized) and Cancel).
- [ ] **Step 4: GREEN**, lint.
- [ ] **Step 5: Commit** `Login app for the session`.

### Task 3: Apps route login-required errors

**Files:** `zcl_ag2ui5_app_status`, `_stage`, `_diff`, `_repo_diff`, `_new_repo`, `_repos` (+ test includes).

Per app: PROTECTED `METHODS show_error IMPORTING ix_error TYPE REF TO zcx_abapgit_exception`:
```abap
  METHOD show_error.
    IF zcl_ag2ui5_repo_service=>login_required( ix_error ) = abap_true.
      client->nav_app_call( zcl_ag2ui5_app_login=>create( iv_key = mv_key ) ).
      RETURN.
    ENDIF.
    client->message_box_display( text = ix_error->get_text( ) type = `error` ).
  ENDMETHOD.
```
(New repository passes `iv_url` from its form instead of a key; the repository list passes the row's key.) Replace every `client->message_box_display( text = lx_error->get_text( ) type = `error` )` in a CATCH of `zcx_abapgit_exception` with `show_error( lx_error )`. Repository diff: in `expand`'s CATCH, a login-required error opens the login app instead of setting the note.

On navigation back: read `r_event_data`; when it is `LOGGED_IN:*`, reload (status: `load_status( )`; stage: `load_stage( )`; diff: `load_diff( )`; repository diff: re-expand the expanded files without notes; repository list and new repository: nothing to reload) and toast `Logged in to <host> - repeat the action if it did not run`. The status page keeps its existing `PUSHED` handling.

Stage: remove `mv_user`, `mv_token`, the Git user / token form rows and the token handling in `push` / `on_event`; the existing token tests are replaced by `no_token_fields` (view has no `type="Password"`).

Repository list: on init and on navigation back call `service( )->logoff( )` and `client->set_session_stateful( abap_false )` (the client double records it).

- [ ] **Step 1: Tests** per app: `login_error_opens_login` (service double raises the abapGit text → `mo_called` is the login app, no message), `other_error_message`, `logged_in_reloads` (navigated with `LOGGED_IN:github.com` → load called again, toast); stage `no_token_fields`; repos `list_goes_stateless`.
- [ ] **Step 2: RED** per app, **Step 3: implement**, **Step 4: GREEN** all suites, lint. Commit per app or one commit `Apps: log in when abapGit asks for credentials`.

### Task 4: Docs and checks

- [ ] AGENTS.md: secrets rule moves from Stage to the login app; "checked again on the server" list gets `login` input checks; README authentication row and Stage paragraph (no token field); findings section.
- [ ] All suites, readbacks of every changed object, dumps, Chrome: Stage without token fields, repository list still works on `/sap/bc/zabapgit2ui5`, login page reachable through a simulated error only if Chris agrees.
- [ ] Commit `Docs: session login`.
