# Stage, commit, push (first slice): design

Date: 2026-10-01. Status: approved in chat.

## Choices

- A staging page like abapGit's, simplified: a checkbox per locally changed
  file, a commit form, then "Commit & push". Patch (single lines) comes in a
  later slice.
- Credentials (user plus token) are entered on **every** push. They are never
  stored: they are set in abapGit's login manager for that one request, and
  the token field is cleared in the handler before abap2UI5 saves the app
  state. If abapGit's exit class `ZCL_ABAPGIT_DEFAULT_AUTH_INFO` exists,
  abapGit uses it by itself.
- Testing: the agent tests everything up to a push with a wrong token. Chris
  runs the one real push to a test repository of his.

## Service

- `get_stage( iv_key ) RETURNING ty_stage`, where `ty_stage` holds:
  - `items`: the locally changed files from `zcl_abapgit_repo_status=>calculate`
  - `name`, `email`: the committer for this repository from abapGit's user
    settings, falling back to the user's defaults
- `commit_push( iv_key, it_items, is_commit, iv_user, iv_token ) RETURNING
  ty_push_result`:
  1. The authorization check and the silent progress indicator.
  2. Fetch again, recalculate the status, and build fresh candidates.
     `check_selection( fresh, selected )` raises when a selected file is no
     longer changed locally or has a different action. That gives the outcome
     `changed`, and nothing is pushed.
  3. Local files for the selected objects come from
     `get_files_local_filtered` with a filter for several objects.
  4. Stage with `zcl_abapgit_stage`: `rm` for action RM (a file deleted
     locally), `add` with the local data otherwise.
  5. If a token was given, call
     `zcl_abapgit_login_manager=>set_basic( url, user, token )`.
  6. Save the committer name and e-mail in abapGit's user settings, as
     abapGit does.
  7. Push: `repo_online->push( comment, stage )`. The comment is
     `commit_message( title, body )`, with committer and author both set to
     name and e-mail.
  8. Call `zcl_abapgit_login_manager=>clear( )` in every case, success or
     exception.
  9. The outcome is `pushed`, with `commit` = the first 7 characters of the
     remote head after the push.

Pure methods, all unit-tested:

| Method | What it does |
|---|---|
| `stage_candidates( it_results )` | Keeps rows whose `lstate` is A, M or D. D gives action RM, the others ADD. |
| `check_selection( it_fresh, it_selected )` | Raises if a selected file is missing from the fresh candidates, or its action differs. |
| `commit_message( iv_title, iv_body )` | The title, plus an empty line and the body when there is a body. |

## App `ZCL_AG2UI5_APP_STAGE`

- It is opened from the status page with the "Stage" button, which is enabled
  only when the status has a local change.
- Public, bound data:
  - `mt_items`, each row with a `selected` checkbox
  - `ms_commit` (title, body, name, email)
  - `mv_user`, `mv_token` (an Input of type Password)
- Protected: `mv_key`, and `mi_service` (a test seam that is unbound in
  production).
- Events:
  - `ALL` / `NONE` select or clear every row.
  - `DIFF` opens the diff page with the path and filename.
  - `BACK` leaves the page.
  - `PUSH`:
    - Copy the token into a local variable, then clear `mv_token`
      straight away.
    - Check that at least one file is selected and the title is filled.
    - Call the service and show the result.
    - On success: a toast, then reload the candidates.
    - On `changed`: an error message box.
    - On an exception: an error message box with the text. The token is
      already cleared at that point.

## Tests

- **Unit tests for the service:** `stage_candidates`, `check_selection`,
  `commit_message`.
- **App test, with a double for the abap2UI5 client and one for the service:**
  - After `PUSH`, `mv_token` is initial both on success and when the service
    raises.
  - The service received the token.
- **End to end on A4H25:**
  - The candidates of a repository with a local change.
  - A push with a wrong token gives a clean error message, and the app state
    keeps no token.
- **The real push:** Chris pushes to a test repository.

## Out of scope

- Patch (single lines).
- Ignore and `.gitignore`.
- Pushing to another branch.
- Pushing to a new branch.
