# Short branch labels and remote links

Date: 2026-10-07. Requested by Chris in chat.

## Behavior

Repository list rows, tiles and the status header display `feature/test1234`
instead of `refs/heads/feature/test1234`. Click the branch to open the remote
branch in a new tab. The branch dialog keeps its Select and adds Open branch
for the selected existing branch. New branch mode hides that link, and its
starting-branch text also uses the short name. Offline repositories have no
branch links.

## Data and validation

Keep the original branch ref in service data and in selector keys. Add separate
plain display and link fields; applications bind only these presentation fields.
Switch/create/delete validation is unchanged. Link construction is pure and
uses HTTP(S) URLs on the exact GitHub, GitLab.com and Bitbucket Cloud hosts.
Strip a trailing slash and `.git`, and URL-encode the short branch name as one
path component. Other hosts and non-head refs have no link. No abapGit object
is retained by an app.

## Verification

Cover prefix handling, nested branches, reserved URL characters, provider
routes, offline/missing values, non-head refs, unknown hosts and misleading
hostnames with ABAP Unit cases. Run npm check and inspect headless desktop
and phone renders. SAP activation and native tests are a separate deployment
step; no repository or remote branch mutation is needed for this feature.
