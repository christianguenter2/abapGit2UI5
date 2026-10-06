# Structural method review implementation plan

Design: [Structural method review](../specs/2026-10-06-semantic-diff-design.md).

Status: all five steps completed. Deployed through ADT to A4H25 with Chris's
explicit approval. Seven production/test readbacks match; affected native
suites pass 241/241 (service 180, diff 25, status 36). Local lint/render,
desktop/phone headless visual review, and live Chrome/SAP navigation pass.
The phone browser override did not yield a reliable responsive screenshot;
phone visual coverage is the headless render. Backups:
`/tmp/ag2ui5-semantic-backup`; readbacks: `/tmp/ag2ui5-semantic-readback`.
Chris accepted the slice and authorized its commit. Results: [findings](../../findings.md#structural-method-review-2026-10-06).

1. Probe SAP scanner behavior; add pure component extraction and comparison
   with native unit coverage, returning plain summaries and source ranges.
2. Enrich existing get_diff results for class/interface ABAP source files.
3. Add summary review and range filtering to the diff app, keeping patch mode
   on the full source. Add on-demand summaries to the object file dialog.
4. Run lint/render and affected native suites; deploy existing sources/includes
   with backups and source readback; verify rendered and live workflows.
5. Record final scope, results and limitations in README and findings.
