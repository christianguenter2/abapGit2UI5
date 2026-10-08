# Git tag selection plan

1. Inspect native tag refs and selection behavior; add plain tag DTOs, mapping,
   remote enumeration and fresh ref/commit validation to the service.
2. Add lazy Tags selection and a growing tag table to the existing dialog;
   refresh status after switching, label selected refs and disable tag staging.
3. Cover annotated peeling, lightweight refs, missing/moved/unresolved refs,
   links/display, tab loading/errors, selected rows and forged events in tests.
4. Run lint/render checks; deploy verified sources via ADT and run affected
   native service/status/overview/stage suites.
5. Test tag browsing, selection, status/diff, pull preview cancellation and
   returning to a branch on A4H25, with authorized fixture restoration. Check
   desktop and phone; record results and limitations in findings.
