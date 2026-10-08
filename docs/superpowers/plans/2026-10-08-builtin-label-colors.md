# Built-in label color fix

1. Read the saved A4H25 settings and compare with abapGit's advertised styles.
2. Extend the service's explicit mapping for all advertised names.
3. Cover the reported settings, all built-in styles and unconfigured fallback
   in ABAP Unit; run lint and render checks.
4. Back up and verify deployed service sources, activate the fix and its tests
   through ADT, compare readbacks, run native tests and check real DTO colors.
