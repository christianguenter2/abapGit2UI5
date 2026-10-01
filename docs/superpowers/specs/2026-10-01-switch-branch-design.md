# Switch branch: design

Date: 2026-10-01. Status: approved in chat (bounded slice).

## Choices

- Switch between **existing** branches of the remote only. Creating a branch
  belongs to the open point "push to another branch, or a new one".
- Switching changes only which remote branch the repository follows, as in
  abapGit. No object in the system changes. Afterwards the status shows the
  differences to the new branch, and a pull (with its decisions and the
  self-update guard) brings them in. So there is no extra guard on the switch
  itself.
- The branch list is fetched without credentials, like the status. Private
  repositories work only through abapGit's user exit (known limitation).

## Service

| Method | What it does |
|---|---|
| `list_branches( iv_key ) RETURNING ty_branches` | The remote's branches, cleaned up as abapGit's branch popup does |
| `switch_branch( iv_key, iv_branch )` | Checks the name against a fresh list, then switches as abapGit's `zcl_abapgit_services_git=>switch_branch` does: `select_commit( '' )`, `switch_origin( '' )`, `select_branch( name )`, `COMMIT WORK AND WAIT` |

`ty_branch`: `name` (`refs/heads/...`), `display`, `default` (the remote's
`HEAD`), `current` (the branch the repository follows now).

Methods without side effects (unit-tested):

| Method | What it does |
|---|---|
| `branch_rows( it_branches, iv_head_symref, iv_current )` | Drops empty names and `HEAD` duplicates, marks default and current, sorts default first, then by name |
| `assert_branch( iv_branch, it_branches )` | Raises unless the name is one of the listed branches |

Switching to the branch that is already selected does nothing.

## Status page

- A "Switch branch" button in the header opens a dialog with a Select of the
  branches, the current one preselected, the default one marked.
- "Switch" calls the service, closes the dialog, shows a toast and reloads
  the status. Cancel closes the dialog.
- An error (fetch, unknown branch) shows a message box; the dialog stays.

## Tests

- Service unit tests for `branch_rows` and `assert_branch`, written to fail
  first.
- The status app has no test include; its new code is view wiring and one
  service call. It is checked by `npm run check` (render gate) and in the
  browser on A4H25.
- On A4H25: list the branches of `$ABAPGIT2UI5` (main, patch,
  branch-switch, earlier ones) through a sapcli snippet. In the browser,
  switch a test repository's branch and back. Chris decides which repository;
  `$ABAPGIT2UI5` itself is switched by every deploy anyway.
