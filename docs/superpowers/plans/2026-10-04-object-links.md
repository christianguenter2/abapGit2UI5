# Object links implementation plan

Design: [Object links to ADT](../specs/2026-10-04-object-links-design.md).

Completed and pushed as `51fcf82`; deployed on A4H25. Browser checks passed
for link placement and file navigation. Final Eclipse editor opening remains
unverified. Results: [findings](../../findings.md#object-links-to-adt-2026-10-04).

1. Check SAP's URI mapper with representative native and legacy object types.
2. Add optional link strings to service results and request-local resolution
   after existing authorization checks, keeping pure mapping methods pure.
3. Render links in status, staging, pull decisions and diff; retain existing
   row navigation and pass the resolved link into diff/patch mode.
4. Add native resolution and navigation tests; run local lint/render checks.
5. Back up and deploy existing objects and test includes through ADT; run
   affected ABAP Unit suites, service smoke tests and source readback.
6. Record results and any browser verification still outstanding in findings.
