# Open points and known limits

What is still open in abapGit2UI5, checked against the code on 2026-10-09.
Results of finished slices are not kept here: Git history has them, and the
rules that still apply are in `AGENTS.md` and in code comments. A slice in
progress keeps its spec and plan in `docs/superpowers/`; they are removed
once it is merged, and its open points move here.

## Known limits

- **Background Status runs:** a run started by Refresh or by leaving and
  reopening Status keeps serializing until it ends; its row is removed only
  by the same user's next start after one hour. The task runs in a dialog
  work process, so `rdisp/max_wprun_time` limits it; a run that dies leaves
  the page waiting until its 15-minute idle limit. Notification is by
  polling; a websocket (abap2UI5's `Websocket` control with APC/AMC) is the
  next step (`zcl_ag2ui5_status_run`, `zcl_ag2ui5_app_status`).
- **URLs:** only the list, Status (`#/repo/<key>`) and the repository diff
  (`…/diff`) have URLs. App navigation adds no browser history entries;
  in-app Back/Forward is postponed, and fast overlapping manual URL edits are
  untested (`zcl_ag2ui5_app_repos=>write_route`).
- **Switched origin (abapGit's pull-request checkout):** the Branches dialog
  lists the fork's branches, and creating or deleting a branch acts on the
  fork, as in abapGit. Only Switch checks the registered remote and resets
  the origin (`list_branches`, `create_branch`, `delete_branch` use
  `get_url( )`; `switch_branch` uses `registered_url`).
- **Token in drafts:** abap2UI5's generic leave event `___ZZZ_NAL` skips
  `main`, so only a hand-made request could save the user's own token in that
  user's own draft (`zcl_ag2ui5_app_login`).
- **Transports:** no request creation (the pull dialog points to SE09).
  Request texts appear only in the logon language, and the first listed
  request is preselected, not the user's default (`list_transports`).
- **Push targets:** the followed branch or a new one, not another existing
  branch (`commit_push`).
- **Branch names:** `@{`, `a/.b`, `a.lock/b` and folder collisions (`test`
  vs `test/x`) are not refused locally; the remote refuses them.
  `REFS/HEADS/x` counts as a full name because `CP` ignores case. Non-ASCII
  names fail with a cryptic Git error from abapGit (`assert_branch_name`,
  `branch_name`).
- **Diff:** no warning when both sides changed; inline and side-by-side rows
  are both built on every round trip; a one-line gap reads "... 1 unchanged
  lines ..."; the tints suit light themes only (`zcl_ag2ui5_app_diff`,
  `compact`, `tinted_html`).
- **Status highlight:** the yellow bar relies on UI5's `sapMLIBHighlight`
  class; a rename in UI5 makes it dark orange (`zcl_ag2ui5_app_status`).
- **Pull dialog:** with selectable objects all unticked, changed repository
  files are not pulled either ("Nothing selected"); abapGit refuses this too
  (`pull_is_noop`).
- **Tags:** every distinct tag target is verified with a depth-one fetch,
  which makes long tag lists slow (`read_tag_commit`). Chris measured about
  30 seconds on abap2UI5, with reload as the only way to abandon the pending
  request. Performance work is deferred (2026-10-09); consider verifying
  targets on demand while retaining fresh commit checks before writes.
- **Session login:** `:` is accepted in the Git user; the 30-minute expiry
  counts service calls, not page use; abapGit keeps one token per host
  (`login`, `assert_authorized`).

## Not tested live (unit tests only)

- A failed pull, network or authentication errors during status or pull,
  and large pulls or ICM timeouts.
- The stale-fingerprint path of `commit_push` end to end.
- A real pull on a selected tag.
- Cloud package creation, authorization denials and a real partial
  Uninstall failure.
- ADT links actually opening Eclipse; TRAN and SHLP return legacy Workbench
  URIs.
- Labels in dark and high-contrast themes, keyboard navigation, and clicks in
  the +N popover.
- Large offline ZIPs.

## Open decisions

- Interpret a conventional `.gitignore` (today only `.abapgit.xml` rules).
- Create transport requests from the pull dialog.
- Candidate features: `feature-ideas.md`. Upstream issues: `upstream.md`.

## Deferred minors

- **Patch:** Select none keeps patches; a `changed` outcome reloads and drops
  picks without saying so; the Pick lines column has no header;
  `check_on_navigated` uses CAST/CATCH (`zcl_ag2ui5_app_stage`).
- **Branches:** the name field has no `labelFor` or submit, and "Starts
  from" comes from the last status load; the delete toast cuts the commit
  without a length guard, and a refused delete does not reload the list;
  "not on the remote" shows the full `refs/heads/` name.
- **Push to a new branch:** the wrapped push error drops `ix_previous` and is
  cut at 200 characters; whitespace-only input still fetches the branch list
  (`commit_push`).
- **New repository:** a package name over 30 characters is truncated, not
  refused; the checkboxes are not normalized; the branch error shows the full
  ref; a stale comment says condense takes inner blanks; the URL is checked
  over the network even without create authorization (`normalize_new_repo`,
  `create_repo`).
- **Repository diff:** no retry after a failed load, the "1 files" toast,
  the saved diff layout is ignored, `expand( sy-index )`, and panels are not
  refreshed after Open (`zcl_ag2ui5_app_repo_diff`).

## Facts for testing

- abapGit refuses a second registration of the same URL (`validate_url`).
- `octocat/Hello-World` has commits but no package file (the missing-package
  path); the `abapGit-tests/*` repositories have one.
- A class re-created through ADT right after a deletion counts as
  non-existent: abapGit hides it, and the next pull removes its TADIR row.
- abapGit refuses import and pull preview when the logon language differs
  from the repository's main language.
- abaplint is not the kernel: `COND #( WHEN condense( x ) IS NOT INITIAL … )`
  and `IS INITIAL` on a built-in expression pass abaplint but fail on the
  kernel. Code injected through test seams runs in production context and
  cannot reach the test class's private attributes.
