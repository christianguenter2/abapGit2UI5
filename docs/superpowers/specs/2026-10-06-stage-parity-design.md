# Stage the SAP version, as conventional abapGit does

## Problem

`$UMLAUT` follows `feature/test1234`. The ABAP source has a remote-only
comment change, while the XML metadata changed locally. Conventional
abapGit offers both for staging; this frontend offered only XML and refused
selected remote changes at push time.

## Behavior

Use abapGit's stage logic as the authoritative file comparison, not only
local baseline states. A local candidate stages SAP contents; a remote-only
candidate stages removal. This permits reverting remote edits, restoring
remote deletions and removing remote additions. Nothing is selected by default.
Show that selected files changed in Git will commit the SAP version.

The service alone accesses abapGit. Keep authentication cleanup, fresh
selection validation, patch fingerprints, ignore previews and the guard
requiring removal of an old path when staging a move. Patch direction stays
Git to SAP. No remote push is required to test this change.

## Verification

Unit coverage: remote-only candidates, additions/deletions, metadata removal,
selection changes, explicit remote overwrite and move guards. Run lint/render
and affected native suites. Compare `$UMLAUT` staging with conventional
abapGit without modifying its objects, rules, branch or remote commits.
