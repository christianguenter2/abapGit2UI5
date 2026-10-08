# Delete Git tags

Offer Delete alongside Switch in the Tags table for unselected tags with a
known remote ref hash. Confirmation names the tag/commit, explains remote
removal cannot be undone in the app, defaults to Cancel, and leaves local objects
unchanged. The selected tag is protected until another reference is selected.
On success refresh Tags, preserving the active tab and reference.

Add the unpeeled remote ref hash to plain tag DTOs separately from the resolved
commit. Fresh server validation refuses non-tag/peel/missing/current/changed refs
and empty hashes. Annotated tags must be checked by their tag-object hash, so
changing annotation at the same commit also invalidates confirmation. Use the
fresh raw hash as receive-pack's expected old value through porcelain's
unpeeled deletion path, preserving atomic refusal if changed during deletion.
Only the service talks to abapGit, starts silent/auth checks, validates raw keys,
and commits. App pending confirmation stays protected and is cleared after
Cancel/success/error; forged/stale confirmation events cannot replay deletion.
