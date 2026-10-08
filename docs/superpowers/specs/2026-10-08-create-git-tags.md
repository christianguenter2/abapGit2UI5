# Create Git tags

Add New tag to the Tags tab. Show the current selected remote reference and full
resolved commit before creation. Default to lightweight; annotated tags require
message and author name/email, seeded from abapGit's Git identity preferences.
Creating publishes only a remote tag, preserves the selected reference and local
objects, and refreshes the Tags list. Back discards the draft; failures keep it.

Only the service uses abapGit. Check raw repository keys, valid Git ref components,
type, annotation identity, fresh tag uniqueness, and the fresh selected reference
and resolved commit against the opening target. Refuse fixed commits and switched
origins. Use porcelain create_tag with a server-derived commit and zero-old ref
semantics so an existing remote tag cannot be overwritten. Keep authentication
handling and branch workflows. No deletion UI in this slice.
