# Switch branch: implementation plan

**Spec:** `docs/superpowers/specs/2026-10-01-switch-branch-design.md`

Branch `branch-switch`, on top of `patch`. Deploy with
`deploy-abapgit2ui5.sh`; if abapgit-agent blocks with `SYSTEM_EDIT`, write the
sources over ADT (`sapcli class write`) and compare with `get_status`.

## Review focus

- A branch name from the browser that is not on the remote.
- The remote's `HEAD` entry, which abapGit lists next to the real default
  branch.
- A remote without any branch, or a fetch error: a message, no dump.
- Switching to the current branch.
- The commit and origin are reset, as abapGit does, so a repository on a
  fixed commit follows the branch again.

## Task 1: types and pure methods, test first

`ty_branch`/`ty_branches`, `branch_rows`, `assert_branch`, with stubs, then
the failing tests, then the implementation.

## Task 2: service list_branches and switch_branch

A smoke test of `list_branches( '000000000020' )` through sapcli.

## Task 3: status page dialog

Button, dialog, events `BRANCHES` and `SWITCH_BRANCH`; `npm run check` and a
headless screenshot.

## Task 4: browser check on A4H25, docs

Switch a test repository chosen by Chris, then back. `findings.md`,
`README.md`, `AGENTS.md` table.
