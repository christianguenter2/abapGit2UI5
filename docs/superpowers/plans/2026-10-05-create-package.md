# Create package implementation plan

Status: implemented, deployed and live-tested in Chrome on A4H25 on 2026-10-05. Results are in
[findings](../../findings.md#create-package-from-new-repository-2026-10-05).

1. Add plain service types, defaults and create methods; pure normalization
   and field validation, fresh checks, suppressed SAP creation/save.
2. Add the dialog and events to New repository. Retain the repository form,
   surface errors, and hand the created package back.
3. Add meaningful service and app tests; run lint/render and native suites.
4. Deploy via ADT, verify SAP persistence and dialog behavior, record results
   and update documentation.
