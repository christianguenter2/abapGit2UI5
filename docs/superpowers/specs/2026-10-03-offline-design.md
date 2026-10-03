# Offline repositories

Open offline repositories from either list layout. Their status page offers
Import ZIP and Export ZIP; Git branches and staging stay online-only.

Import uploads a binary ZIP, compares its files with the current package,
and opens the existing pull decision dialog. Nothing is imported until Pull
selected. The existing authorization, package guard, fresh object/group
decisions, dependency acknowledgment and transport checks apply unchanged.

The original ZIP is protected app state, retained until Back or replacement
by another valid upload. Every status, diff, preview and pull request reloads
it into a fresh abapGit repository instance. No abapGit object is retained by
an app. The ZIP is not stored as repository content on the system. Canceling
the decisions keeps the comparison available; canceling upload keeps the
previous comparison. Opening the repository again starts without an upload.

Reject malformed or empty ZIPs and archives without a root .abapgit.xml.
Accept abapGit ZIPs and GitHub ZIPs using abapGit's path normalization.
Export serializes current local files with abapGit and downloads their ZIP
bytes directly, without converting binary content to text or calling SAP GUI.

Verification: unit tests for ZIP validation and app flows, both local linters
with render gate, SAP activation and ABAP Unit where access is available.
Use $TEST_OFFLINE (key 29) for read-only smoke tests and export/preview;
imports that change existing fixture contents require an inspected decision.
