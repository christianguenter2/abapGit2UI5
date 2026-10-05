# Create a package from New repository

Date: 2026-10-05. Approved in chat; implemented and deployed.

A Create package link beside the package field opens a dialog without losing
the repository form. Package creation is a separate explicit action. On
success, the dialog closes and the normalized package name fills the form.
Cancel leaves the form unchanged. Creating a package does not register or
pull a repository; the package remains if repository creation later fails.

Fields: package (30), description (60), software component (20), transport
layer (4), optional superpackage (30), and an existing workbench request.
Defaults follow the entered name: LOCAL and $TMP for local packages; HOME
and the system default layer for transportable packages. The repository's
ABAP language version is carried into the package defaults (including cloud
defaults). A request is required for transportable packages and is checked
against a fresh list of the user's modifiable workbench requests.

Only the repository service reads abapGit or SAP package APIs. It checks
startup and repository-creation authorization, normalizes and validates all
fields before writes, refuses existing packages, checks the parent and
package hierarchy, and preserves the self-update guard. SAP creation and
save explicitly suppress dialogs; save receives the validated transport.
Successful persistence commits before abap2UI5 rolls back the request.
Errors retain the dialog's inputs. Failed saves discard the newly created
in-memory package so retries in the session are possible.

Verify normalization, invalid input without writes, existing package and
forged transport rejection, app cancel/error/success, local and transportable
SAP creation, persistence, and the rendered dialog.
