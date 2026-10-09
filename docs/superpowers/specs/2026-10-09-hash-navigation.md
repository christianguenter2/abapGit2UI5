# Repository navigation that survives browser refresh

## Goal

After opening a repository, browser refresh must return to that repository's
Status page instead of the repository list. Browser Back/Forward and app Back
must agree about the displayed page. This must preserve authentication cleanup
and must never replay a remote or SAP mutation.

## Investigation on A4H25 (2026-10-09)

The pinned abap2UI5 1.146.0 API supports `cs_event-hash_routing` with KEEP.
KEEP routes carry app class and a user-owned server draft ID. FRESH carries
only the app class and cannot recover the protected repository key supplied by
`ZCL_AG2UI5_APP_STATUS=>create`.

A temporary prototype enabled KEEP in the repository list's initialization.
No production source changes were kept. Browser tests used a separate Chrome
tab, the own ICF node, and the existing `$UMLAUT` registration. Its existing
local source difference and selected `main` branch were left untouched.

| Test | Observed result |
|---|---|
| List -> Status | URL carries Status class and draft ID; correct `$UMLAUT` repository |
| Browser refresh on Status | Correct repository, URL, remote commit and changed file retained |
| Refresh status event | Status draft ID in URL advances |
| Saved Status URL plus full reload | Correct repository restored |
| Status -> repository diff | Routed diff opens for the existing changed ABAP file |
| Diff refresh | Diff content restores, but hash becomes empty; reproduced twice |
| Browser Back after diff refresh | URL changes to Status route while diff stays displayed |
| Diff -> Status browser Back before reload | Correct Status view restored |
| Status -> diff browser Forward before reload | Correct diff view restored |
| Status -> list browser Back | Repository list restored |
| Browser Forward from list | Settled page and URL stay on the list rather than restoring repository |
| App Back after restored Status/diff | Remains on restored page; no usable parent navigation |
| Missing Status draft (synthetic nonexistent ID) | Fresh Status has no key; shows 'No repository selected' error instead of safe list fallback |

The original saved Status and diff containers both had KEEP and initialized=X
when read through a diagnostic. Thus the diff failure cannot simply be assumed
to be a missing routing mode in the saved draft. Root cause is still open.
Framework draft restoration explicitly clears `id_prev_app_stack`, which
explains why relying only on `nav_app_leave` is insufficient for a cold restore.

Native suites with the prototype: Repositories 33/33, Status 80/80, Login 13/13.
Initially 28 repository-list tests failed because its PARTIALLY IMPLEMENTED
client double lacks `check_on_init`. Adding that method to a temporary test
include restored 33/33; those tests do not assert the new KEEP initialization.
No real credential entry/session lifecycle was tested; existing login unit tests
passed, but that is not proof of browser-history cleanup after authentication.

## Required behavior

1. Restore the repository identity and reload current status on a full page
   refresh. A restored draft must not make old status authoritative for writes.
2. Keep page, hash and browser history consistent after refresh, repeated
   refreshes and ordinary event round trips. Back/Forward must navigate views,
   not merely change the URL. A response to a history restore must not overwrite
   the user's Forward target with another list entry.
3. App Back from restored Status returns to the repository list. Restored diff
   returns to Status for its protected repository key; Status then returns to
   the list. If an app-stack parent exists, retain existing handover behavior.
4. Invalid/expired/missing drafts fail safely to the repository list with a
   clear message. A fresh Status instance without a key must not render an
   unusable page. Never infer a repository key from an arbitrary draft ID.
5. Remote actions, pull decisions, staged selections and deletion confirmations
   are not replayed by route restoration. Every action keeps its existing
   fresh server validation and authorization checks.
6. Login credentials never enter URLs. Retain token clearing on every login
   round trip. Returning to the list through browser history must still call
   logoff and finish the stateful session; refresh does not promise to preserve
   Git login credentials. Review routing of the login app explicitly.
7. Protected fields remain protected. Do not expose repository-service or
   abapGit object references. Hash IDs are state handles, not authorization.
8. KEEP is a candidate, not approved as a one-line implementation. Resolve the
   reproduced routing failures before adopting it. If they require framework
   work, scope that separately or propose app-owned stable repository routes.

## Scope and exclusions

Target the repository list, Status and diff navigation first. Evaluate Stage,
login, new-repository screens and offline ZIP state before inheriting routing
through the whole app stack. Popup restoration is not promised. Draft links
are temporary and user-scoped; permanent/shareable repository links are a
separate requirement. No automatic imports, branch/tag changes or pushes.
