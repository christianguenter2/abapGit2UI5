# Pull mark-all implementation plan

Status: implemented, deployed and verified on A4H25 (2026-10-05).
Results are recorded in `docs/findings.md`.

1. Add popup toolbar actions and a selection helper restricted to selectable rows.
2. Test all groups and preservation of unrelated state; run lint/render checks.
3. Deploy the existing status class and test include, run native tests and Chrome
   toggle/cancel checks, document results and commit/push.
