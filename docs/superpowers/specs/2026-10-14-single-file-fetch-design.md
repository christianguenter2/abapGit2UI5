# Single-file fetch for diffs: design

Date: 2026-10-14. Status: approved by Chris (2026-10-14).

## Problem

Every `get_diff` on an online repository fetches the whole repository from
Git: the node resets abapGit's repository service per request
(`request_start`), and `read_file_pair` reads the remote side through
`get_files_remote( )`. Pick lines, the Diff page and every expanded panel of
the repository Diff page pay for it on each click. The local side is already
serialized for the one object only.

Measured on A4H25 (`$ABAPGIT`, 1597 files): full fetch 1,276 ms, the same
file fetched alone 390-439 ms. The single fetch stays about constant, the
full one grows with the repository.

## Spike results

- `zcl_abapgit_git_transport=>upload_pack_by_commit( iv_hash = <blob SHA1> )`
  sends `want <hash>` and returns exactly that blob, byte-for-byte equal to
  the full fetch. No abapGit change is needed.
- Accepted by GitHub, git.kernel.org (plain Git), Codeberg (Forgejo/Gitea)
  through abapGit on A4H25, and by GitLab.com and Bitbucket Cloud (same
  request with curl; A4H25 lacks their CA certificates in STRUST). Plain Git
  2.55 with default settings serves it over smart HTTP (`--stateless-rpc`).
  An unknown hash is refused with `not our ref`.
- Not tested: Azure DevOps, older self-hosted servers. Hence the fallback.

## Design

### Rows carry the remote SHA1

- `ty_status_row` and `ty_stage_item` get `remote_sha1 TYPE string`: the SHA1
  of the file in Git, empty when the file is not in Git.
- `get_status` fills it from `li_repo->get_files_remote( )` after
  `zcl_abapgit_repo_status=>calculate( )` (already fetched in that request).
  `get_stage` fills it from `is_files-remote`. Offline repositories: empty
  (the ZIP path stays as it is).
- The apps keep it where they keep the row today. Status and Stage rows are
  public (bound) data, so the value the diff page uses must not come from the
  browser: the apps read it from their PROTECTED copies (Stage `mt_rows`,
  Status's file lists, Repo diff's `mt_source`) when they open the diff, as
  they do for path and filename now. To be checked per app in the plan;
  where the row exists only as public data, the app keeps a PROTECTED map
  path/filename -> SHA1.

### `get_diff` takes the SHA1

New optional parameters on `zif_ag2ui5_repo_service~get_diff`:

- `iv_remote_sha1 TYPE string`: the file's SHA1 in Git.
- `iv_remote_known TYPE abap_bool`: the caller knows the remote side from a
  status or stage row. With an empty `iv_remote_sha1` this means "not in
  Git": no fetch at all.

Without `iv_remote_known` (offline, ZIP, unknown callers) `get_diff` works
as today.

`read_file_pair` then reads the remote side:

1. Offline or not known: as today, `get_files_remote( )`.
2. Known, empty SHA1: no remote file.
3. Known SHA1: `fetch_blob( )` -> `upload_pack_by_commit` with that hash.
   Checks: exactly one object, type blob, its SHA1 recomputed with
   `zcl_abapgit_hash=>sha1_blob( )` equals the requested one (lower case).
4. Fallback: when the single fetch raises or a check fails, the full
   fetch runs as today. A login error (`login_required( )`) is raised
   directly, without a second request.

A per-request cache (static, hashed by SHA1, cleared in `request_start`)
keeps fetched blobs, so the semantic summary and the line diff of one file
never fetch twice.

### What does not change

- Patch safety: `commit_push` / `apply_patch` and the fingerprint still read
  both sides fresh (full fetch). A diff opened on an outdated SHA1 shows the
  file as it was when the list loaded; picked lines on it come back as
  `changed`, as today when Git moves.
- Status's object overview (several files of one object in one request)
  keeps the full fetch: one fetch serves all files of the request. It does
  not pass the SHA1.
- Offline repositories and uploaded ZIPs.
- The local side (already filtered to the one object).

## Tests

- Service unit tests (no network): `fetch_blob` behind a seam that tests
  replace (the class is FINAL: an injected fetcher interface or a test
  double via a `FOR TESTING` setter, decided in the plan). Cases: known
  SHA1 uses the blob; mismatching hash or type falls back; fetch error falls
  back; login error is raised without fallback; known empty SHA1 has no
  remote; not known uses the old path; cache hit fetches once.
- `status_rows` / stage rows: `remote_sha1` filled from the remote list,
  empty for local-only files.
- App tests: Stage, Status and Repo diff pass the SHA1 from PROTECTED data,
  not from posted row data.
- On A4H25: Pick lines, Diff and a repository Diff panel on `$UMLAUT` and
  `$AG2UI5_TEST`; timing on `$ABAPGIT` before/after; an offline repository
  still diffs from its ZIP.

## Decisions

1. Files only in the system (known, empty SHA1) fetch nothing.
2. Status's object overview stays on the full fetch.
