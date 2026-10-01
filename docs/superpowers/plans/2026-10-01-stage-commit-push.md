# Stage, commit, push: implementation plan

**Spec:** `docs/superpowers/specs/2026-10-01-stage-commit-push-design.md`

Deploy with agent-pull. Check `MESSAGE`/`CONFLICT_COUNT`, because a
`SYSTEM_EDIT` conflict can abort it; in that case make surgical MCP edits and
compare with `get_status`.

## Review focus

- The token never reaches the draft, logs or messages.
- A file deleted locally (RM).
- The status went stale between loading the page and pushing.
- The push is rejected because the remote moved.
- `login_manager=>clear( )` runs on every path.

## Task 1: types and pure methods, test first

`stage_candidates`, `check_selection`, `commit_message`, and the filter class
for several objects.

## Task 2: service get_stage and commit_push

Smoke test with candidates and a wrong token.

## Task 3: stage app and the status button

App test for clearing the token, both linters, and a screenshot.

## Task 4: docs, review, merge, then hand the real push over to Chris
