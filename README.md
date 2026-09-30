# abapGit2UI5

A browser frontend for [abapGit](https://github.com/abapGit/abapGit), built with
[abap2UI5](https://github.com/abap2UI5/abap2UI5). It runs in any browser, so
it avoids the quirks of the SAP GUI HTML control (IE and Edge controls, SAP GUI
for Java, WebGUI).

This is a proof of concept. It supports three things:

- **Repository list:** all abapGit repositories of the system, with a search.
- **Status:** the files that differ between the system and the remote, or that
  are inactive.
- **Pull in abort mode:** only imports when no local change would be lost. If
  anything would be lost, it lists what blocks the pull and imports nothing.

Stage, commit, push and the diff view are not part of it yet.

## Prerequisites

- The abapGit **developer version**, meaning the `ZCL_ABAPGIT_*` classes. The
  standalone program `ZABAPGIT_STANDALONE` is not enough, because its classes
  are local to the program.
- abap2UI5 1.146.0 or later, with its ICF service active.
- ABAP 7.50 or later.

## Installation

Install this repository with abapGit into a local package, for example
`$ABAPGIT2UI5`.

## Start

```
https://<host>:<port>/sap/bc/z2ui5?sap-client=<client>&app_start=zcl_ag2ui5_app_repos
```

## How a pull decides

abapGit's SAP GUI pull asks for a decision on every changed object. This
frontend makes that decision itself:

| Change | Treatment |
|---|---|
| Added or changed only remotely | Imported |
| Object type not supported | Skipped and reported |
| Changed or added locally, or would be deleted | Blocks |
| Package move, data loss, a table with data would be deleted | Blocks |
| Package outside the repository | Blocks |
| Requirements or APACK dependencies not met | Blocks |
| A transport request is needed | Blocks (only local packages are supported) |

Pulling abapGit itself, or this repository, is refused. It would replace code
that is running in the same session. Use abapGit in SAP GUI for those.

## Development

```sh
npm install
npm run check   # abaplint + abap2UI5 linter, no SAP system needed
```

Unit tests (`ZCL_AG2UI5_REPO_SERVICE`) run as ABAP Unit on the system.

The design is in `docs/superpowers/specs/`. The results of the end-to-end test
are in `docs/findings.md`.
