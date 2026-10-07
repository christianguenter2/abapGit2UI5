# Commit and push to a new branch

## Problem

The Stage app pushes only to the branch the repository follows. To prepare a
pull request, a user first has to create a branch on the Branches page and
then come back. Conventional abapGit offers an optional "New Branch Name" on
its commit page (`zcl_abapgit_gui_page_commit`): it creates the branch at the
current head, follows it, and commits there.

## Scope

A new branch only, as in abapGit. Pushing to a different existing branch is
out of scope: staging compares the system with the followed branch, so a push
to another existing branch could overwrite changes that exist only there.

## Behavior

### Service (`ZIF_AG2UI5_REPO_SERVICE`)

- `ty_commit` gets `new_branch` (string, optional).
- `ty_push_result` gets `branch`: the display name of the branch pushed to.
- `ty_stage` gets `branch`: the display name of the followed branch, for the
  input's placeholder.
- `commit_push` keeps its signature. When `new_branch` is not empty:
  1. Normalize with `branch_name( )`, check with `assert_branch_name( )` and
     `assert_new_branch( )` against a fresh `list_branches( )`. A failure
     raises before anything is written.
  2. The existing checks run unchanged (refresh, `check_selection` →
     `changed`, `check_push_allowed`, patch fingerprints). Any failure
     returns or raises before a branch exists.
  3. The stage is built as today.
  4. `create_branch( iv_name = <normalized> iv_from = <head after the
     refresh in step 2> )`: the branch starts exactly at the commit the
     selection was checked against; abapGit follows it.
  5. Exit `validate_before_push`, push, `COMMIT WORK AND WAIT`, exit
     `validate_after_push`, in abapGit's order. The exit sees the new branch,
     as in abapGit.
- The credentials are set before step 1 and cleared on every way out, as
  today; the branch creation uses them too.
- If the exit or the push fails after step 4, the branch exists and is
  followed, without the commit (as in abapGit). The error text says that the
  branch was created and is now followed; a retry commits on it normally.
- With `new_branch` empty, behavior is unchanged; `branch` is still filled.

### Stage app

- The commit form gets an optional input "New branch" after Committer, with
  placeholder `Leave empty to push to <followed branch>`.
- Success toast: `Pushed <commit> to <branch>`.
- After success `new_branch` is cleared with title and body.

## Tests

- Service unit tests (no system writes): an invalid name and an existing
  branch name are refused; the result's branch field is filled from the
  branch name helper. The push itself has no unit test, as before.
- Stage app tests (service double): the form renders the input and
  placeholder; `PUSH` passes `new_branch`; success clears it and shows the
  toast with the branch.
- Live on `$UMLAUT` (only with Chris's OK, since abapGit's exit supplies his
  real credentials): push one change to a throwaway branch
  `ag2ui5-push-test-<date>`, check toast and status, switch back to the
  original branch and delete the throwaway branch in the app. Leave
  `feature/test1234` untouched.

## Docs

`docs/findings.md` gets the slice; the README's stage description if it
covers the commit form.
