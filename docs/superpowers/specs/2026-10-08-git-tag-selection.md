# Browse and select Git tags

The status page's branch dialog becomes Branches and tags, with a Tags tab.
Tags load on demand from the remote and show their short name and commit, with
links for supported hosts. Resolve annotated tags through their peeled commit
and hide duplicate peel refs. Unresolved annotated tags remain visible without
a switch action. Sort by name descending; do not claim semantic version order.
Use a growing table and an explicit empty state. No tag creation/deletion UI.

Switch checks the selected full ref and displayed commit against fresh remote
tags, refuses missing/moved refs, resets fixed commits and switched origins,
and persists the tag selection using abapGit's native select_branch method.
It refreshes status but imports no objects. Pull remains a separate reviewed
action, including all existing running-code and transport guards. Diff follows
the selected tag automatically. Indicate Tag in headers/overview, disable Stage
while selected and refuse direct stage/push service calls against tags. Branch
switching remains available and restores staging. Preserve existing branch
create/delete behavior and authentication handling.

Only the repository service holds abapGit refs; DTOs and app state are plain
data. Validate raw repository keys before conversion in new tag entry points.
