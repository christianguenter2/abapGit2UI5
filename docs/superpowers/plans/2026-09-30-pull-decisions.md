# Pull with decisions: implementation plan

**Spec:** `docs/superpowers/specs/2026-09-30-pull-decisions-design.md`

Deployment and test commands are as in `docs/superpowers/plans/2026-09-30-abapgit2ui5-poc.md`:
push the branch, run `agent-pull.py refs/heads/feature/pull-decisions --package '$ABAPGIT2UI5'`,
then run `agent.py unit`.

## Review focus

- An object that is in two check tables must get the same decision in both.
- The remote changes between preview and pull.
- A deletion is selected in a package that is transportable. This cannot happen,
  because a transport requirement blocks.
- A `NSPC` add plus other adds: only the namespace is preselected.
- A user who deselects everything: pull is a no-op, and nothing is deleted.

## Task 1: preview and apply_decisions, test first

- Interface: add `ty_decision_item(s)`, `ty_preview`, `c_group` and
  `c_outcome-changed`, change the signature of `pull`, and add `preview_pull`.
- Tests: rewrite `ltcl_classify` as `ltcl_preview` and add `ltcl_apply`. They
  must fail first.
- Implement `preview` and `apply_decisions`. Remove `classify`.
- Result: the unit tests are green.

## Task 2: service `preview_pull` / `pull` with deletion

- `preview_pull` covers fetch, checks and `preview`.
- `pull` covers fetch, checks, `apply_decisions` (an exception becomes
  `changed`), the deletion, `refresh` and `deserialize_logged`.
- Smoke test through `sapcli abap run`: `preview_pull` on `$AG2UI5_TEST` gives
  `nothing`, and the guard still refuses `$ABAPGIT`.

## Task 3: decision dialog in the status app

- The dialog as the spec describes it.
- `npm run check` must be clean.
- E2E with MCP and the service, because Chrome cannot take screenshots while
  the screen is locked:
  - overwrite restore
  - delete of a local-only class
  - "Already up to date"

## Task 4: docs

- README: replace the decision table and the screenshots.
- `docs/findings.md`: an addendum.
- `AGENTS.md`.
