# Notes for upstream (abapGit, abap2UI5, abapgit-agent)

Collected while building abapGit2UI5 (2026-09-30 to 2026-10-01). Nothing here
is filed yet. The "likely bugs" are from reading code and code reviews; none
is reproduced yet.

**Next step (agreed with Chris):**
1. Reproduce 1 and 3 on A4H25 with the fixture packages (see
   `AGENTS-LOCAL.md`).
2. Check 4 with a small test file.
3. Draft the issue texts, and for 2 and 5 possibly PRs. Chris files them
   himself.

## abapGit: likely bugs

1. **A table with data can be deleted despite "No".**
   `zcl_abapgit_services_repo=>delete_unnecessary_objects` looks only at the
   `overwrite` decision. A table with Y in `overwrite` and N in
   `delete_tabl_with_data` (the "delete anyway?" popup) is deleted anyway.
   - Repro idea: a repository whose remote drops a table that has rows
     locally. In the overwrite popup choose Y, in the table-data popup choose
     N, then check whether the table is gone.
2. **The self-update guard only covers SAP GUI.**
   - `check_self_update` fires only for `sy-cprog = 'ZABAPGIT'`.
   - `zcl_abapgit_url=>is_abapgit_repo` matches only github.com URLs ending
     in `/abapGit[.git]`.

   So headless callers (ADT backend, abapgit-agent) and internal mirrors
   (GitLab, Bitbucket) can replace abapGit code that is running.
   - Better: decide by the TADIR package of the running classes, the way
     abapGit2UI5's `assert_pull_allowed` does (a PR candidate).
3. **The orphan cleanup removes newly created objects.**
   `remove_obsolete_tadir` (DEVC deserialize, local packages) deletes TADIR
   rows whose object `zcl_abapgit_objects=>exists( )` reports as missing.
   - Observed: a class re-created through ADT under the same name right after
     it was deleted counted as non-existent. abapGit hid it (`check_exists`),
     and the next pull removed its TADIR row.
   - To do: find out which `exists( )` check gave the false negative.
4. **The diff can stop early.** When `RS_CMP_COMPUTE_DELTA` returns
   `difference_not_found`, the fallback in `zcl_abapgit_diff_std`
   (`compute_diff_extra`) compares only up to the length of the shorter file.
   A change that only appends lines may show "no differences" while the
   status says modified.
   - Repro idea: two blobs where B = A plus extra lines at the end.
5. **`zcl_abapgit_utils=>is_binary` counts tabs as non-printable.** Text files
   with a lot of tab indentation (JS, Makefile) can be classified as binary.
   abapGit's diff page skips the check only for `.xml`, `.abap` and `.po`.
   A small PR candidate.
6. **The NSPC rule in `popup_decisions` reads only the first NSPC row.** An
   edge case, but inconsistent.

## abapGit: API proposals (for headless callers and other frontends)

7. **Popups cannot be replaced outside tests.** `ZCL_ABAPGIT_UI_INJECTOR` is
   `FOR TESTING`. Proposal: a public way to register a non-interactive popup
   implementation (one that raises cleanly), used by the ADT backend,
   abapgit-agent and web frontends.
8. **Pull logic sits in the UI layer.** `delete_unnecessary_objects`,
   `real_deserialize` and the default decisions live in
   `zcl_abapgit_services_repo` (ui/routing). Every headless caller has to copy
   them, and steps get lost that way: deleting whole objects, for example.
   Proposal: a pull service in the repo layer, `checks → decisions (data) →
   execute`, with the GUI only showing popups.
9. **Push logic sits in the UI layer too.** The push exits
   (`validate_before_push`/`after_push`), `COMMIT WORK` and saving the
   committer all live in `zcl_abapgit_services_git=>commit`. If they moved
   into the repo layer, headless callers could not skip them; abapGit2UI5
   missed the exits and the `COMMIT WORK` at first.
10. **A form feed in the diff output.** `zcl_abapgit_diff_std=>unpack` appends
    a form feed as the "no newline at end of file" marker. It leaks into
    consumers: abapGit2UI5's JSON broke on it. A flag on `ty_diff` would be
    cleaner.

## abapgit-agent (SylvosCai/abapgit-agent)

- `rejectUnauthorized: false` is hard-coded in the npm CLI's HTTP clients, so
  the TLS certificate is not verified, and there is no setting to change it.
- It reports `SYSTEM_EDIT`/`LOCAL_EDIT` conflicts for objects it imported
  itself, and after MCP/ADT edits whose content equals Git.
- An aborted pull reports `FAILED_COUNT: 0`. Only `MESSAGE` and
  `CONFLICT_COUNT` show the abort.
- `ZCL_ABGAGT_SYNTAX_CHK_CLAS` appends `locals_imp` after the whole main
  source. SAP places the CCIMP before `CLASS ... IMPLEMENTATION`, so a local
  class used in a method comes out as "Type LCL_... is unknown".

## abap2UI5

- **Control characters break the response:** `escape_string` in
  `z2ui5_cl_ajson` (`src/00/01`, `locals_imp`, around line 752) escapes only
  `" \ \t \n \r`. Any other control character (form feed, ESC, NUL) makes the
  frontend's `response.json()` fail, and the page goes blank.
- **Secrets in the draft table:** bound input fields are written as plain-text
  XML into `Z2UI5_T_01` after every event, including password fields. The
  guide could warn about this, or abap2UI5 could offer a binding for secrets
  that is applied but never stored.
- **The linter's `--screenshot` has limits:** it does not follow values
  passed into helper methods, and it renders every branch of an `IF`.
