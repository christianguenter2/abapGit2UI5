# Remove and uninstall implementation plan

Status: implemented, deployed and verified on A4H25 on 2026-10-05.
Results are in [findings](../../findings.md#remove-and-uninstall-repositories-2026-10-05).

1. Add plain lifecycle types and service methods with fresh scope, authorization,
   transport and running-code checks.
2. Add actions in both repository layouts and confirmation/preview dialog;
   retain partial-failure logs and refresh the list after success.
3. Add meaningful unit tests; run lint and render checks.
4. Deploy existing includes via ADT, run native tests and Chrome workflows on
   disposable fixtures, clean up, and record results before commit/push.
