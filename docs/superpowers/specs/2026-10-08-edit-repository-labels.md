# Edit repository labels

Offer Edit labels in the repository header's overflow toolbar, for online and
offline repositories including those without labels. The dialog presents a
MultiComboBox with removable tokens and suggestions collected from registered
repositories. A separate New label field and Add button accept one valid label
at a time. Save persists all selected labels; an empty selection removes all.
Cancel discards the draft. Typed text must be added or cleared before Save so
it cannot be silently lost. Errors stay in the dialog.

Only the repository service calls abapGit. Save validates the raw key before
fixed-length conversion, reloads registration and local settings, validates
label characters through abapGit, and refuses a concurrent label change by
comparing normalized fresh labels with the server-held opening snapshot.
Update only labels in the fresh local settings and commit persistence.
No Git commit, remote write, package or object update occurs. User-defined
colors and deterministic fallback continue to apply. Preserve offline ZIPs
and unrelated local settings. Refresh the header from the returned labels;
returning to the overview already reloads repositories.
