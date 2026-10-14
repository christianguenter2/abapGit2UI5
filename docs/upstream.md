# Upstream: open points

Issues found while building abapGit2UI5 in abapGit, abap2UI5 and related
tools. Fixed, merged or dropped points are removed; Git history has them.
Texts marked with `>` are ready to post (Chris files them).

## Tracking

- **abapGit #7941** (discussion: pull and push without the UI layer): pull
  (`zcl_abapgit_repo_pull`, PR #7951) and push (`zcl_abapgit_repo_push`, PR
  #7956) are merged; both come from `zcl_abapgit_repo_factory`.
  `ZCL_AG2UI5_REPO_SERVICE` uses the pull class; push still goes through
  abapGit's older push API. Deferred in #7951's review:
  `zcl_abapgit_gui_page_pull` still calls `deserialize_checks( )` directly
  instead of `zif_abapgit_repo_pull~checks`.
- **AJSON PR sbcgua/ajson#228** (escape every control character): open.
  Until then a form feed or other control character in a JSON string blanks
  the abap2UI5 page; abapGit2UI5 replaces them itself (`visible`). After the
  merge, abap2UI5 has to refresh `ajson_mirror`.
- Parked by Chris: the self-update guard deciding by package (abapGit).

## abapGit

### C. Form feed marker in diff output

> **Title:** Diff: "no newline at end of file" as a flag instead of a form feed
>
> `zcl_abapgit_diff_std=>unpack` appends a form feed to the last line as the
> "no newline at end of file" marker. Consumers get it inside the line text:
> #7922 had to strip it from staged files, and abapGit2UI5's JSON response
> broke on it. A flag in `ty_diff` (or on the diff object) would keep the line
> texts clean. Low priority.

### Proposal: replaceable popups

`ZCL_ABAPGIT_UI_INJECTOR` is `FOR TESTING`, so a headless caller (ADT
backend, abapgit-agent, web frontends) cannot register a non-interactive
popup implementation that raises cleanly. Not drafted yet; it could join
the discussion in #7941.

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

### L. Linter `--screenshot` limits

Not drafted yet: `abap2ui5lint --screenshot` does not follow values passed
into helper methods, and it renders every branch of an `IF`, so dialogs need
a system or a scratch copy with the helpers inlined.
