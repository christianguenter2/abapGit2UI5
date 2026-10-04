# Ignore rules on staging

The staging page must respect abapGit's native ignore rules, including
starting-folder exclusions. abapGit stores these in `.abapgit.xml`; it does
not interpret a conventional `.gitignore`. Use the native matcher rather
than introducing a second interpretation that differs between clients.

Each staging row offers Ignore, opening an editable exact-path rule. Users
can keep the exact file or enter a pattern (`*` any sequence, `+` one
character, as in abapGit). Preview lists the currently affected staging
files before Save is enabled. Saving changes local `.abapgit.xml`, not the
remote; the configuration change can be committed normally. Ignoring a
tracked file leaves its remote version in place.

Ignore rules lists existing rules and allows removal after a preview. This
also makes an accidental ignore reversible. Existing ordered negation rules
are preserved. Removal previews serialize on an unregistered repository
copy with the proposed rules, so hidden files can appear in the preview
without persisting anything. Protected repository metadata cannot be ignored.

Every save re-fetches status and rules and recomputes the preview. Changed
rules or affected files refuse the save. No browser-supplied preview is
trusted. Commit validation uses the same ignore-aware candidates as staging.
Every event still clears the staging token first. Dialog edits hide their
preview and disable Save immediately without an extra server event. Saving
checks the rule against the protected preview again. Saving reloads staging
and drops file selections and stale line patches while
retaining commit text and committer details.

Online staging remains reachable with no local changes so that rule
removal is available after the ignore configuration has been committed.

Verify pure filtering/rule/preview helpers and app events in ABAP Unit,
lint/render locally, deploy through ADT with backups/readback, and test on
the authorized `$UMLAUT` fixture without pushing its remote.
