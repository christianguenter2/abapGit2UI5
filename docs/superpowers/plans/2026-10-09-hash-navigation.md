# Hash navigation implementation plan

Status: investigation complete; implementation pending. See the matching
[spec](../specs/2026-10-09-hash-navigation.md) for observed failures and acceptance
criteria. Do not ship the initialization-only KEEP prototype.

1. **Reproduce and locate the routing failures.** Use temporary backed-up
   sources and an isolated browser tab. Capture the installed framework's
   response routing flags and browser navigation state around diff refresh,
   Back/Forward and list restore. Check why a KEEP draft restore clears the
   diff hash, and why Forward to Status ends on the list. Do not change the
   framework until the cause and required scope are concrete.
2. **Choose the route contract.** Prefer framework KEEP if these failures can
   be resolved and covered against the pinned release. Otherwise document the
   alternative: app-owned stable repository routes, freshly validated on the
   server, with explicit handling for nested screens and fresh-start behavior.
   Do not combine mutually exclusive hash routing/app-state/hash listeners.
3. **Add restoration fallbacks.** Detect a missing repository key before
   loading Status. Navigate to the list with a handover message. Add an app
   Back fallback when the restored draft has no caller; use the protected key
   to reconstruct Status from a restored diff. Preserve existing caller
   handovers when a parent exists. Test that this creates no navigation loops.
4. **Wire routing and tests together.** Enable the chosen mode in the intended
   lifecycle path without duplicate init/navigated dispatch. Complete the
   repository-list double's `check_on_init`, record the routing action/mode
   and assert initialization behavior. Add regression tests for missing keys,
   absent parents, restored screens and invalid routes. Existing refresh and
   fresh server-check tests must stay valid.
5. **Audit login and stateful behavior.** Ensure browser Back to list performs
   logoff and the SESSION_END timer even after draft restoration. Verify that
   URLs and saved drafts contain no token and that history cannot replay an
   action. Real-token browser steps must be performed by Chris under the local
   instructions; use native doubles for the automated tests. Cover the known
   generic leave-event caveat instead of assuming routing resolves it.
6. **Run the acceptance matrix.** Online Status refresh twice, bookmark/new
   tab, Status event; Status/diff/list Back and Forward before and after
   refresh; app Back with and without a parent; missing/expired draft and
   missing repository registration; Stage draft and offline ZIP restoration
   if enabled; login cancellation and authenticated-session cleanup. Inspect
   settled view AND hash, not only a heading that also exists on a list card.
7. **Validate and deliver.** Run npm run check and affected native unit suites.
   Update README and findings with actual behavior, temporary-link limits,
   framework version and remaining exclusions. Read back deployed sources.
   Restore temporary experiments, tabs and preferences. Commit/push/deploy
   permanent implementation only within the user's authorized scope.

Investigation cleanup: original repository-list main and test include restored
on A4H25 and compared with backups; no application changes kept in Git. Scratch
sources and readbacks are under `/tmp/ag2ui5-hash-routing`.
