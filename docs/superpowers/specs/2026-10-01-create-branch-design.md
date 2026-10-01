# Create branch: design

Date: 2026-10-01. Status: approved in chat.

## Choices

- A new branch starts at the **head of the branch the repository follows
  now** (abapGit's "Create branch"). Afterwards the repository follows the
  new branch. No object in the system changes, and no commit is pushed.
- It lives in the **"Switch branch" dialog** of the status page (option B).
- **No credentials in the dialog:** abapGit's exit supplies them, as for
  Chris's real push. Without them the remote answers 401, which the dialog
  shows as an error. No secret reaches the status app's state.

## Dialog

- The branch list keeps its entries; its last entry is **"New branch…"**.
- Picking it shows below the list:
  - "Starts from: <branch> at <commit, 7 characters>",
  - **Name** (required).
- The begin button then reads **"Create"**. Picking an existing branch
  turns it back into "Switch" and hides the name. The list's `change` event
  makes a round trip, because the dialog content changes.
- **Create:** the service creates the branch; the dialog closes, a toast says
  "Created and following <name>", and the status reloads.
- **Error** (name exists, invalid name, 401): a message box; the dialog stays
  open and keeps the name.
- **Cancel** closes the dialog.

## Service

`create_branch( iv_key, iv_name ) RETURNING rv_branch`:

1. `assert_authorized( )`, `silence_progress( )`.
2. `rv_branch = branch_name( iv_name )`.
3. `assert_branch_name( rv_branch )`.
4. `assert_new_branch( iv_branch = rv_branch it_branches = list_branches( iv_key ) )`.
5. abapGit's `create_branch( rv_branch )` on the repository: it pushes the
   new ref at the current head and switches to it.
6. `COMMIT WORK AND WAIT` (abap2UI5 rolls back after `main( )`).

Methods without side effects (unit-tested, written to fail first):

| Method | What it does |
|---|---|
| `branch_name( iv_name )` | Spaces become `-`; `refs/heads/` is added unless present (abapGit's `normalize_branch_name` and `complete_heads_branch_name`) |
| `assert_branch_name( iv_name )` | Git's ref rules for the part after `refs/heads/`: not empty; no `..`, `~`, `^`, `:`, `?`, `*`, `[`, `\` or control characters; does not start or end with `/` or `.`; does not end with `.lock`. Raises with the reason |
| `assert_new_branch( iv_branch, it_branches )` | Raises if the branch already exists |

## Checks on what the client sends

The name comes from the browser. It is normalized, checked against Git's
rules, and checked against a fresh branch list before anything reaches
abapGit. An empty name is refused. `AGENTS.md` lists `assert_branch_name`
and `assert_new_branch` under "checked again on the server".

## Tests

- Service unit tests:
  - `branch_name`: `feature x` → `refs/heads/feature-x`; `refs/heads/a`
    unchanged.
  - `assert_branch_name`: refuses empty, `a..b`, `a~b`, `a:b`, `/a`, `a/`,
    `.a`, `a.lock`, a control character; accepts `feature/x-1`.
  - `assert_new_branch`: refuses an existing name, accepts a new one.
- The status app has no test include; its new code is the dialog and one
  service call. `npm run check` (render gate) covers the dialog.
- On A4H25: a sapcli smoke test of the name checks, creating nothing.
- **The real creation** is an outward action, done by Chris or with his OK:
  `test/create-branch` on `$UMLAUT`. GitHub then shows the branch at the old
  head, the status header and the branch list show it. Chris deletes it
  afterwards, or tells the agent to.

## Out of scope

- Credentials in the dialog.
- "Create from" another branch.
- Pushing a commit to a new branch.
