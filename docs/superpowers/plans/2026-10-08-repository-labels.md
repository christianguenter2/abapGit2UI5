# Repository labels plan

Completed and deployed on A4H25 (2026-10-08). Results in docs/findings.md.

1. Extend the repository DTO with plain label rows. Read labels and configured
   colors only in the service; add pure normalization/color mapping helpers.
2. Add the shared label renderer to tile content and the table Name cell.
   Include labels in the existing search and add accessible overflow handling.
3. Check nested bindings, scoped styles and theme behavior in the render gate.
   Verify stable colors and data mapping with focused tests; run npm check.
4. Validate affected ABAP Unit suites and both live overview layouts, including
   long/multiple/empty labels and phone/keyboard behavior. Record results in
   docs/findings.md before considering deployment or commit.

Label-click follow-up: use native Links, match exact server-held labels, retain
Favorites only, clear exact mode on SEARCH, and close the labels popover.
Validate exclusion of partial labels/name matches, invalid labels and clearing
with ABAP Unit, then check tile/list clicks and search clearing in Chrome.
