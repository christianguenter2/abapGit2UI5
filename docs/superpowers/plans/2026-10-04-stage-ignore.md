# Staging ignore implementation plan

1. Add native ignore-aware candidate filtering and pure rule/preview logic.
2. Add authorized preview/save service calls with fresh-data validation.
3. Add staging Ignore and Ignore rules dialogs, preview/save/remove events,
   preserving token clearing and commit data.
4. Add unit coverage for filtering, native syntax, stale previews, protected
   metadata, event handoff, token clearing and error paths.
5. Run checks and SAP tests; deploy with backups/readback, verify reversible
   fixture behavior and browser UI; document, commit and push.
