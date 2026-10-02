# Delete branch: design

Date: 2026-10-02. Status: approved in chat.

## Choices

- A branch is deleted on the remote from the branch dialog of the status
  page. abapGit's exit supplies the credentials, as for creating.
- **Protected, as in abapGit:** the default branch (the remote's HEAD) and
  the branch the repository follows. Other repositories on the system that
  follow the same URL are not checked (Chris's choice).
- No object in the system changes, and the repository keeps following its
  branch.
- The header button "Switch branch" becomes **"Branches"**; the dialog title
  too, and its intro reads: "Switch: only the branch the repository follows
  changes. Create and delete act on GitHub."

## Dialog

- With an existing branch picked, a **"Delete"** button shows in the footer
  next to "Switch" and "Cancel". It is hidden for "New branch...", the
  current branch and the default branch.
- "Delete" opens a confirmation: "Delete branch <name> (at <commit, 7>) on
  GitHub? abapGit cannot undo this." with "Delete" and "Cancel". The commit
  comes from the branch list just loaded.
- After confirming: the branch is deleted, a toast says "Deleted <name> (was
  at <commit, 7>)", and the branch list reloads in the dialog.
- On an error (401, already gone, protected): a message box; the dialog stays
  open.

## Service

- `ty_branch` gets `sha1`, filled by `branch_rows`.
- `delete_branch( iv_key, iv_branch ) RETURNING rv_sha1`:
  1. `assert_authorized( )`, `silence_progress( )`.
  2. A fresh `list_branches( iv_key )`.
  3. `assert_deletable( iv_branch, branches )`.
  4. `zcl_abapgit_git_porcelain=>delete_branch( url, branch )` with the name
     and the **fresh** commit; the commit the browser saw is never used.
  5. `rv_sha1` = that commit.
  No COMMIT is needed: abapGit's repository settings do not change.

Method without side effects (unit-tested, written to fail first):

| Method | What it does |
|---|---|
| `assert_deletable( iv_branch, it_branches )` | Raises unless the branch is listed, and is neither the default nor the current branch |

## Checks on what the client sends

The branch name comes from the browser. It is checked against a fresh branch
list, and the commit sent to the remote comes from that list. `AGENTS.md`
lists `assert_deletable` under "checked again on the server".

## Tests

- Unit: `assert_deletable` refuses an unknown name, the default and the
  current branch, accepts another; `branch_rows` carries `sha1`.
- `npm run check`, a headless screenshot of the confirmation.
- On A4H25 (`$UMLAUT`, with Chris's OK): "Delete" is hidden for `main` and
  `test`; create `delete-me` with "New branch...", switch back to `test`,
  delete `delete-me` through the dialog; `git ls-remote` shows it gone and
  the other branches unchanged. `feature/test1234` is left alone.

## Out of scope

- Checking other repositories on the system.
- Deleting tags.
