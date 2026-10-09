# Feature ideas

Ideas discussed with Chris for features that could distinguish abapGit2UI5.
These are candidates, not committed scope or implementation plans. Their
absence from every other ABAP client has not been verified.

## Named change sets

Organize mixed local changes by task, save each selection, and commit the
groups independently. Later, publish each group to its own branch without
changing the active code in the SAP system.

Example staging groups:

- **Fix invoice rounding:** two methods and one test, for `fix/rounding`.
- **New export format:** three objects, for `feature/export`.
- **Unassigned changes:** everything that has not been assigned yet.

Assign whole objects, files, or picked lines to a group. Remember the
selection, commit message and, eventually, target branch. Transport
membership could suggest groups.

Inspiration: [GitButler parallel branches](https://docs.gitbutler.com/features/branch-management/virtual-branches)
and [IntelliJ changelists](https://www.jetbrains.com/help/idea/managing-changelists.html).

First slice: persist named selections for one repository against its current
branch, using the existing partial staging and fingerprint checks. Detect
stale selections when the source changes and require review. Publishing to
different branches is a separate, more demanding slice.

Limits and questions:

- A transport identifies objects, not ownership of individual lines.
  Membership cannot prove which changes belong to a task.
- A commit serializes current object state; a transport is not a historical
  snapshot of that state.
- Groups organize publication, but do not isolate the running ABAP code.
- Define overlap rules for groups, stale picks, and the baseline after one
  group has been committed. Different target branches need their own fresh
  comparison and validation.

## Pull impact preview

Before importing, explain what the proposed update could affect elsewhere
in the system: known consumers, transport locks, local modifications and
dependencies outside the repository.

Example: a changed interface signature links to local callers, including
callers outside the imported package.

First slice: enrich the existing pull preview with available lock and
where-used information for selected objects. Show the evidence, its scope
and unknowns; do not promise that an import will activate successfully.
Investigate coverage and runtime costs before expanding dependency analysis.

abapGit already has [dependency processing](https://docs.abapgit.org/development-guide/serializers/serializers.html)
and [ATC/Code Inspector integration](https://docs.abapgit.org/user-guide/repo-settings/local.html).
The proposed distinction is an integrated explanation of the specific
update's impact, rather than simply adding a check button.

## Recovery checkpoints

Preserve local serialized objects before a pull, then allow comparison and
selective restoration of supported objects.

Inspiration: [Tower undo](https://www.git-tower.com/features/undo).

First slice: an explicit checkpoint export before import, with clear scope.
Later: retained checkpoints and a restore preview using the existing ZIP
comparison and pull decisions.

A ZIP cannot reverse database data changes or every import side effect.
Restoration needs fresh checks and the existing self-update guard; it must
not be advertised as universal undo. Retention, access and storage costs
need decisions before storing checkpoints on the server.

## Repository cockpit

Across repositories, show local changes, incoming updates, pull requests
awaiting review and failed checks, with navigation to the relevant work.

Inspiration: [GitKraken Launchpad](https://help.gitkraken.com/gitkraken-desktop/gitkraken-launchpad/).

First slice: an on-demand overview of local and remote status for selected
repositories. PR and CI information can follow through provider integrations.
Investigate fetch costs, caching, authentication and provider support;
ordinary repository listing should remain quick.
