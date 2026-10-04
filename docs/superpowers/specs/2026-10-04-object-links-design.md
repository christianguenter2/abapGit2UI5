# Object links to ADT

Agreed with Chris on 2026-10-04: object names should offer a jump as a
link. ADT is the first destination.

## Behavior

- Object names in status, staging and pull decisions link to their local
  object in ADT. Row navigation continues to open the file diff.
- The diff page has an Object attribute with the same link, including in
  patch mode and for binary files.
- Missing, deleted, remote-only or unresolved objects remain readable with
  plain text. Repository files with no object have no navigation.
- Works for online and offline repositories. A link opens the local object,
  never the version of a file in Git or an uploaded ZIP.
- Eclipse must have the ADT link handler enabled. Supported editors depend
  on the SAP system and ADT installation; legacy objects may use Workbench
  navigation through ADT.

## Service boundary

The existing authorized service calls enrich their plain results with an
`object_link` string. Pure status/staging/preview helpers remain unchanged.
Only the service calls abapGit's existence check. SAP's Workbench object
and ADT URI mapper generate the URI dynamically; no object-type URL table
and no SAP GUI frontend execution are used.

Cache successful and unsuccessful lookups by object type and name within
one service call. No cache or mapper reference survives into app state.
Unsupported APIs or mapping failures leave the link empty and do not block
status, staging or preview. Diff navigation carries the already resolved
link rather than performing another lookup.

Links are display data; pull decisions, transport checks, staging selections
and patch fingerprints continue to be checked against fresh server data.

## Validation

- Local lint and the render gate.
- Native tests for an existing object, a missing object, invalid transport
  keys and cache keys; app tests for status/stage-to-diff handoff and the
  diff's link/plain-text placement.
- Service smoke tests on online/offline fixtures and a large repository.
- Browser inspection and click-to-Eclipse handoff when a browser is connected.
