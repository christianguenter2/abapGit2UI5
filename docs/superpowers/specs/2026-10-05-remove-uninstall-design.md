# Remove and uninstall repositories

Both online and offline repositories offer Remove and Uninstall in the list
and tiles layouts. Remove deletes only abapGit registration and local metadata;
SAP objects and the remote repository remain. Uninstall deletes the objects
returned by abapGit's package scan, including package entries, then removes
registration. Transportable packages may remain until deletion transports are
released, as in abapGit.

Opening either action reads a fresh preview identifying repository and package.
Uninstall lists the exact object/type/package scope, explains possible table-data
loss and irreversible deletion, and requires the package name to be typed.
A required workbench transport starts unselected. Cancel changes nothing.
Errors stay visible; failed uninstall reports its log and retains registration
so remaining objects can be inspected and retried.

The service uses non-UI delete/purge APIs, silent progress and startup
authorization. Uninstall also checks its authorization, write protection,
language, fresh transports and the running-code hierarchy guard. It reloads
repository persistence and compares a fresh preview before deleting anything.
Changed scope requires a new preview. abapGit commits each object deletion,
so partial failure cannot be rolled back. Success commits registration changes
explicitly. No remote Git mutation occurs.

Tests cover confirmation bypasses, changed scope/identity, cancellation,
success/error handling and preservation of objects on Remove. Live tests use
new disposable packages only, including local and transportable uninstall.
