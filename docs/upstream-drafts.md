# Upstream drafts (to post by Chris)

Texts ready to paste, one issue each. Background and evidence are in
`upstream-notes.md`. Searched on 2026-10-06: none of these is filed yet.

## abapGit

### A. Self-update guard: decide by package, not by URL and program

> **Title:** Self-update protection misses headless callers and mirrored URLs
>
> `zcl_abapgit_services_repo=>check_self_update` (and the restart in
> `gui_deserialize`) only apply when `sy-cprog = 'ZABAPGIT'` and
> `zcl_abapgit_url=>is_abapgit_repo( )` is true, which only matches github.com
> URLs ending in `/abapGit` or `/abapGit.git`.
>
> So the check is skipped when the developer version is pulled
> - by a headless caller (ADT backend, abapgit-agent, a web frontend), or
> - from a mirror (GitLab, Bitbucket, an internal Git server).
>
> In both cases the pull can overwrite classes that are running in the same
> session.
>
> Idea: decide by package. Compare the TADIR package of a running abapGit
> class (for example `ZCL_ABAPGIT_REPO`) with the repository's package tree
> and refuse (or warn) when they overlap. abapGit2UI5 does this for its own
> pulls (`assert_pull_allowed`) and could contribute a PR. Is that the
> direction you would want?

### B. Pull and push for headless callers (discussion first, no code yet)

> **Title:** Discussion: pull and push without the UI layer
>
> The steps of a pull and a push live in `ui/routing`
> (`zcl_abapgit_services_repo`, `zcl_abapgit_services_git`). Every entry
> point that is not the SAP GUI popup flow puts them together itself, and the
> copies already differ inside abapGit:
>
> | Entry point | Self-update check | Delete removed objects | Push exits |
> |---|---|---|---|
> | Pull with popups (`gui_deserialize`) | yes | yes | - |
> | HTML pull page (Flow, `gui_page_pull`) | **no**, calls `real_deserialize` directly | yes | - |
> | Background pull | no | yes, via the UI class `zcl_abapgit_services_repo` | - |
> | Commit page (`services_git=>commit`) | - | - | yes |
> | Background push (`push_au`, `push_fi`) | - | - | **no**: `validate_before_push` / `validate_after_push` are not called |
>
> Outside abapGit, the ADT backend, abapgit-agent and abapGit2UI5 (an abap2UI5
> frontend) each have their own copy too. abapGit2UI5, for example, first
> missed the push exits and the `COMMIT WORK`.
>
> **Proposal:** two small classes in the repo layer that hold the steps without
> any UI, and that every entry point calls:
>
> 1. **Pull:** `checks` (as today, `deserialize_checks( )`) → the caller fills
>    in the decisions → `pull( is_checks )` deletes the removed objects,
>    deserializes and returns the log. The GUI keeps the popups, the success
>    message and the restart; the background job keeps its "yes to all".
> 2. **Push:** `push( is_comment, io_stage )` calls `validate_before_push`,
>    pushes, commits and calls `validate_after_push`. The commit page keeps
>    the form checks and saving the committer per user.
>
> Each would be one PR, moving code without changing behaviour for the SAP GUI
> flow, with unit tests for the new classes.
>
> **Questions:**
> - Is this a direction you would accept, and in which package (`src/repo`)?
> - Should the background push call the push exits? Today it does not. Adding
>   them changes behaviour for users with an exit, so we would make it an
>   explicit decision.
> - The self-update check is GUI specific today (`sy-cprog = 'ZABAPGIT'`,
>   restart via `SUBMIT`). Leave it in the GUI for now, or move the check
>   into the pull class? (Related: the separate issue about the guard itself.)

### C. Form feed marker in diff output

> **Title:** Diff: "no newline at end of file" as a flag instead of a form feed
>
> `zcl_abapgit_diff_std=>unpack` appends a form feed to the last line as the
> "no newline at end of file" marker. Consumers get it inside the line text:
> #7922 had to strip it from staged files, and abapGit2UI5's JSON response
> broke on it. A flag in `ty_diff` (or on the diff object) would keep the line
> texts clean. Low priority.

## abapgit-agent (SylvosCai/abapgit-agent)

### D. TLS certificate not verified (security)

> **Title:** CLI disables TLS certificate verification
>
> The npm CLI's HTTP clients hard-code `rejectUnauthorized: false`, so SAP
> credentials are sent without verifying the server certificate, and there is
> no option to turn verification on. Please verify by default and add an
> option for a custom CA bundle (for example via `NODE_EXTRA_CA_CERTS` or a
> setting in `.abapGitAgent`).

### E. Conflicts reported for content equal to Git

> **Title:** `pull` reports SYSTEM_EDIT/LOCAL_EDIT for its own imports
>
> Right after a pull with `conflict_mode: ignore`, the next `abort` pull
> reports `LOCAL_EDIT` ("system modified after last pull ..., Git content
> unchanged") for objects the backend has just written itself (seen with
> `TRAN` and `FUGR`). The same happens after an ADT edit whose result equals
> Git. Every following pull then needs `ignore` again. Comparing the actual
> content before flagging a conflict would avoid this.

### F. Aborted pull reports `FAILED_COUNT: 0`

> **Title:** Aborted pull looks successful in FAILED_COUNT
>
> When a pull stops on conflicts, the result has `FAILED_COUNT: 0`; only
> `MESSAGE` and `CONFLICT_COUNT` show that nothing was imported. Scripts that
> check `FAILED_COUNT` treat it as a success. Please set `SUCCESS` to false or
> add an explicit `ABORTED` flag.

### G. Syntax check places `locals_imp` after the class

> **Title:** Syntax check: "Type LCL_... is unknown" for local classes
>
> `ZCL_ABGAGT_SYNTAX_CHK_CLAS` appends `locals_imp` after the whole main
> source. SAP places the CCIMP include before `CLASS ... IMPLEMENTATION`, so a
> method that uses a local class reports "Type LCL_... is unknown". Inserting
> `locals_imp` before the implementation part (and mapping line numbers back)
> fixes it.

## abap2UI5

Control characters (AJSON PR sbcgua/ajson#228) need nothing more here until
it is merged; then `ajson_mirror` needs a refresh.

### H. Secrets in the draft table

> **Title:** Password fields are stored in Z2UI5_T_01
>
> Bound attributes are saved as plain-text XML in `Z2UI5_T_01` after every
> event, including attributes bound to `Input type="Password"`. An app has to
> clear them at the start of every event to keep them out (abapGit2UI5 does
> that for a Git token). Could the guide warn about this, or could abap2UI5
> offer a binding that is applied to the app but never stored?

### I. Toast lost on `nav_app_leave`

> **Title:** `message_toast_display` followed by `nav_app_leave` shows nothing
>
> A toast sent in the same round trip as `nav_app_leave( )` is not shown
> (checked with a hook on `MessageToast.show`). The workaround is to hand the
> text back via `nav_app_leave( r_data = ... )` and show it in the calling app.
> Either keep the toast across the navigation or mention it in the guide.

### J. Linter: comparing boolean event arguments with `true`

> **Title:** Linter rule: `get_event_arg( ) = 'true'` is always false
>
> Boolean event arguments arrive as `X` / space, as the guide says, so
> comparing `get_event_arg( )` with `` `true` `` / `` `false` `` never matches.
> Unit tests with a client double often send `true` too and miss it. A linter
> rule would catch it.

### K. Row styling from data

> **Title:** Guide: give a table row a CSS class from a binding
>
> There is no direct way to style a row from data. abapGit2UI5 uses
> `CustomData` with `writeToDom` plus a `<style>` block via `core:HTML`. A
> recipe in the guide, or a helper, would save apps the search.
