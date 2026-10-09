# Tag reference and target verification

Refuse fixed commits and switched origins for tag listing, switching, deletion
and creation targets before any writes. Verify tag targets as commit objects
before enabling Switch or accepting a creation target; ref peeling alone is
insufficient. Keep raw tag hashes available for guarded deletion of noncommit
and unresolved tags. Preserve pure unit-tested validation and fresh server
checks. Accept depth-one object fetch latency without importing SAP objects.
Do not change branch switching, deploy, commit or push.
