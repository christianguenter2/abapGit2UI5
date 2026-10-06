# Structural method review

First semantic diff slice, agreed 2026-10-06.

## Behavior

- Opening a changed class/interface in Objects loads structural summaries for
  its changed ABAP source files. The ordinary file list remains available.
- The file diff shows the same summaries above the raw diff. Each entry names
  the owning class/interface, method, component (declaration/implementation),
  and whether it was added, removed or changed, in the existing diff direction.
- Selecting an entry opens/filters the underlying source diff to the complete
  component on both sides. Show complete diff restores the file. Layout and
  changes-only preferences remain independent. Line picking always uses the
  full file and has no summary filtering.
- Declarations include static/instance status, visibility, parameters and
  other signature tokens. Implementation comparison detects token changes;
  whitespace/comment-only edits remain visible in the raw diff.
- Local classes/interfaces and test methods are included. Renames appear as
  removal and addition. XML metadata and other object types use the raw diff.
- A summary is a structural observation, never a claim about runtime behavior.
  Unsupported/incomplete source falls back to the raw diff with an explanation.

## Implementation

The service uses SAP's ABAP scanner (without includes/macro expansion) on the
original sources, before display normalization. Chained/multiline declarations
are separate scanner statements. Compare token sequences by owner, component
and method, retaining both source ranges. No execution or source changes occur.
Only the service talks to abapGit; results and app state are plain data. Object
review loads on demand, not during repository status loading. Offline source
comes from the existing ZIP restoration path.

## Validation

Native tests cover chains, multiline signatures, visibility, static methods,
local owners, additions/removals, direction, literals/comments/formatting,
invalid sources, source ranges, and tampered selection events. App tests cover
filtering, restoring the file and line-picking preservation. Run lint/render,
back up/deploy existing includes through ADT, read back, run affected suites,
and verify desktop/phone views and live navigation on A4H25.
