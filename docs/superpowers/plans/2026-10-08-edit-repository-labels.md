# Edit repository labels plan

1. Add plain-data save_labels to the service interface and a pure checked_labels
   helper for validation, normalization and stale snapshot rejection.
2. Add bound draft selection, suggestions, new-label input and error state to
   the status app; keep opening snapshot and dialog state protected.
3. Add the toolbar action and dialog, with Add/Save/Cancel events. Save returns
   colored header labels; cancel clears draft data without changing persistence.
4. Test valid normalization, removal, invalid and stale values, dialog lifecycle,
   suggestion deduplication, selection changes, errors and ZIP preservation.
5. Run lint/render checks, deploy verified sources through ADT, run affected
   native suites and test on A4H25 with the authorized $UMLAUT fixture. Restore
   its labels and verify other settings are unchanged. Check desktop and phone.
6. Record findings and leave changes ready for review.
