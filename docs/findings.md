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
  Request texts appear only in the logon language (`list_transports`).
- **Push targets:** the followed branch or a new one, not another existing
  branch (`commit_push`). Not planned (Chris, 2026-10-22).
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
- **Tags:** the list shows each tag's target as the remote lists it, without
  checking that it is a commit. A tag on a tree or blob looks switchable and
  is refused only by Switch (`list_tags`, `switch_tag`).
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

- **Patch:** Select none keeps picked lines; they apply again when the file
  is selected (`zcl_ag2ui5_app_stage`).
- **Branches:** "Starts from" comes from the last status load, not from the
  fresh branch list.
- **Repository diff:** panels are not reloaded after returning from Open
  (`zcl_ag2ui5_app_repo_diff`).

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
