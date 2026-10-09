# Repository navigation that survives browser refresh

## Goal

After opening a repository, browser refresh must return to that repository's
Status page instead of the repository list. Browser Back/Forward and app Back
must agree about the displayed page. This must preserve authentication cleanup
and must never replay a remote or SAP mutation.

## Approved scope (2026-10-09)

The implementation uses app-owned identity routes and replacement writes:
list `#`/`#/`, Status `#/repo/<12-digit key>` and repository-wide Diff
`#/repo/<key>/diff`. Fresh service data validates every cold or manual route
entry. Missing/offline Diff falls back to Status. App Back selects the safe
parent even without a caller. Stage, login, creation, single-file diff and ZIP
state are excluded from restoration; they retain a parent route.

Chris postponed a browser history of app pages. No hash_set, KEEP or app-state
hash is used. The pinned hash_replace needs hash_attach_changed to replace the
whole hash rather than append a suffix, so Chris subsequently authorized the
listener. Its event runs the same fresh root resolver as cold start. Every
replacement response asserts it, including non-rendering panel events. There
are no new in-app entries for browser Back/Forward to traverse. This supersedes
the historical investigation's push-history requirement below. Fast overlapping
manual URL edits and real Git-login SESSION_END remain outside live coverage.
No framework change; see the plan and docs/findings.md for acceptance evidence.

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

### Equal-contract spike (2026-10-09): source results; live gate blocked

Recommendation to Chris: choose **app-owned identity routes**, subject to the
minimal A4H25 acceptance gate below. Do not ship KEEP or call this spike's live
comparison complete. The new separate Chrome tab at the own-node start URL
failed with `net::ERR_INVALID_AUTH_CREDENTIALS`. Per the explicit stop-if-login
rule, no credentials were entered, no prototype was deployed, and no SAP source
was changed. Consequently there are no new live results or restoration
readbacks to certify. Earlier KEEP observations above remain earlier evidence,
not newly reproduced results. Scratch source evidence is in
`/tmp/ag2ui5-routing-spike/framework/`, extracted with `git archive 1.146.0`.
The local abap2UI5 HEAD is newer; all framework references below are to the tag
(commit `2a55c9f5f12b73f2cf2d9e2309e8f115a958384e`), not that HEAD.

#### 1. App-owned contract

Source establishes cold-start hash availability: `app/webapp/core/Server.js:226-234`
sends raw `window.location.hash` on EVERY request, including boot;
`src/01/02/z2ui5_cl_ui5_handler.clas.abap:405` reads it;
`src/01/02/z2ui5_cl_ui5_client.clas.abap:158` exposes it as
`client->get( )-s_config-hash`. The backend boot parser selects an app route
only for `/app/...` (`handler:303-318`), so `/repo/000000000010` leaves
`app_start=zcl_ag2ui5_app_repos` in control. This proves the API path, not the
unperformed live forward to Status.

Keep framework routing OFF (explicit DEFAULT where inherited KEEP is possible)
and app-state routing inactive. Every rendered participating app registers
`cs_event-hash_attach_changed` with a named `HASH_CHANGED` event. Registration
is a response option applied before URL cleanup (`Router.js:364-390`), and
must be reasserted after app switches (`View1.controller.js:100-109`). Browser
Back/Forward dispatch that named event to the CURRENT app with the new hash in
`s_config-hash`, no route arguments (`Router.js:393-429`). Busy changes park
until completion; this path is separate from KEEP restores. Do not re-register
on unrelated non-rendering responses during a pending history change: adoption
at registration can swallow it; test rapid Back while busy.

Suggested standalone routes:

- List: `#/` (raw empty hash accepted as its alias).
- Status: `#/repo/<12-digit-key>`.
- Repository diff: `#/repo/<key>/diff` (fresh changed-file set).
- Single file: `#/repo/<key>/diff?path=<encoded-path>&file=<encoded-filename>`.

Use path plus filename, never table index, object metadata or a fingerprint as
file identity. Decode once with strict limits; reject malformed escapes,
controls, duplicate/unknown parameters and unsupported shapes. Validate raw key
length/digits BEFORE fixed-length conversion; match a fresh `list_repos` DTO
through the service. Unknown/unregistered key -> fresh list with clear message,
replace invalid entry. Resolve a diff file against fresh status, deriving object
identity, object link and remote direction from that row. Missing file -> Status
with message. Never replay actions, ZIP bytes, patches or staged selections.
Key is user/system-local identity, not an authorization credential.

Ordinary list -> Status -> diff clicks render the destination AND push its hash
in the same response via `hash_set` (wire `SET_PUSH_STATE`). Own-write echoes
are suppressed (`Router.js:575-585`). Refresh boot resolves the same identity
into new apps; history `HASH_CHANGED` renders the destination WITHOUT pushing
or replacing a valid route. Registration keeps hash cleanup from wiping it
(`Router.js:596-603`). Canonicalization/errors use `hash_replace`; a redirect
on a history restore must never push and truncate Forward. App Back must both
perform existing caller handovers when available and select the parent route.
For cold roots use explicit fresh Status/list fallback and replace the current
entry. `hash_back` is available (`Router.js:299-305`) but its page-local
push-count fallback does not alone enforce the required diff -> Status parent;
keep the parent route deterministic. All consistency claims here still require
live confirmation, including two refreshes, ordinary diff events, history after
refresh, repeated visits and busy navigation.

#### 2. KEEP failure attribution (no framework edits)

| Observed failure | Source evidence and boundary |
|---|---|
| Diff refresh empties hash | Frontend OFF/no-listener cleanup explicitly writes empty hash (`Router.js:596-615`). Backend is meant to resend restored KEEP on no-ID/navigated requests (`handler:1132-1151`); initialized=X only skips app init, not that resend. A saved KEEP flag alone cannot establish which response option reached sync. Exact cause remains unconfirmed without tracing response `setNavRouting` and live frontend state. App workaround: explicitly assert KEEP on all participating renders; not demonstrated to fix this failure. |
| Back changes URL but leaves diff | With routing OFF, only a registered app event can render another page (`Router.js:324-329,393-402`); with KEEP ON a different draft should restore (`316-354`). This is consistent with the preceding hash/mode failure, but not proof. Trace mode, currentDraftId, HashChanger event and request dispatch. No existing app history handler repairs an OFF route. |
| Forward from list lands on list | KEEP's `navFromHash` branch explicitly avoids rewriting history (`Router.js:506-515`); ordinary route writes replace/push (`527-543`). List main itself loads/displays list, with no Status redirect (`app_repos:96-139`). Source alone cannot choose between wrong restore request, mode loss, echo or response ordering. Exact attribution remains open; do not claim an app-only fix or a confirmed Router bug. |
| App Back dead after restore | Confirmed backend/app contract mismatch: `action:150` clears `id_prev_app_stack`; `client:300-315` resolves leave through that stack; `handler:1351-1355` drops root self-leave. Our `app_status:1470`, `app_diff:580-581`, `app_repo_diff:206-207` call bare leave. Fixable in apps using `check_app_prev_stack` and explicit safe parent construction. |
| Missing draft shows error page | Confirmed backend fallback plus app gap: `action:157-175` catches missing draft and instantiates routed class without create(key); service `get_repo:2994-2997` rejects empty key. Fixable in Status/diff by guarding key and returning to fresh list with message before load. Arbitrary invalid class routes can fail before app main; application fallback cannot cover every framework `/app/...` shape. |

Thus two failures have conclusive source attribution; three have located code
paths and hypotheses only. The authentication blocker prevents the requested
five-way live root-cause classification. KEEP is neither exonerated nor proven
unfixable from these sources.

#### 3. Fresh Status and session cleanup

KEEP does NOT currently satisfy fresh Status on refresh. A saved initialized
app enters `check_on_navigated`, not init (`action:135`, `client:678`), and Status
reloads only for PUSHED/LOGGED_IN handovers (`app_status:279-305`). Ordinary
restoration redraws persisted status. Add a route-restore refresh boundary;
`get( )-s_draft-id_prev_app_stack` alone cannot identify a restore. Repo/file diff
also retains cached data on navigated (single diff `app_diff:273-287`). Existing
fresh checks for mutations remain necessary, but do not satisfy requirement 1.
App-owned routes instantiate Status and run `load_status` at every route entry;
load fresh diff inputs and content too. Route state must never override those
checks. `repo_service:2888-2890` resets abapGit at each own-node request.

When KEEP successfully restores list, `check_on_navigated` runs `logoff`, sets
list stateful and schedules SESSION_END (`app_repos:99-108`); the timer clears
both framework state and login latch (`352-355`). A mere URL Back with no
request cannot do this. App-owned `HASH_CHANGED` must navigate into the actual
list app, not just render its XML or call a list helper; that invokes the same
cleanup and timer. Ensure the list remains active until that timer executes;
a fast Forward may cancel it (`Server.js:189-196`). Both approaches need a
test/strategy for navigating away during pending SESSION_END, and cleanup
handover that completes before leaving list. No authenticated lifecycle was
tested; login was blocked and no token was used.

#### 4. Exclusions and comparison

App-owned: feasible first-version design. Stage keeps the online Status route
and no Stage route is parsed, so reload constructs fresh Status. Login replaces
the current entry with list and registers a safe history escape; reload starts
list. Keep token clearing at the very start of login main (`app_login:86-90`),
clear Git user on every exit, and preserve own-node/stateful rules. Browser
history from excluded screens must not replay actions. Offline ZIP is omitted
from URL/draft restoration: either offline screens keep list route (reload loses
ZIP) or key route opens offline Status with explicit import-again notice; choose
the former for literal exclusion. Do not retain a routable diff carrying ZIP.

KEEP: exclusions are possible only with extra navigation policy, not inherited
KEEP alone (`action:365-368`). Stage DEFAULT clears hash and boots list, not
Status; leaving inherited KEEP restores Stage. Achieving Stage -> fresh Status
requires explicitly retaining a safe Status draft route or replacing Stage by a
route-aware parent policy. That still needs a freshness fix for the parent.
Login DEFAULT can clear hash so reload boots list; force fresh list cleanup on
exit and guard any earlier login drafts. Offline DEFAULT can exclude ZIP
restoration, at the cost of losing the normal route. Mixed-mode history and
listener/route ownership need live tests; do not combine owners in one screen.

| Criterion | KEEP | App-owned |
|---|---|---|
| Refresh | Status identity observed; diff hash failure | Cold hash API proved; live blocked |
| Back/Forward | 3 related observed failures; causes partly open | Explicit named-event route resolver; live blocked |
| App Back | App fallback required after stack erased | Explicit parent + existing handover |
| Missing/invalid route | Missing-draft guard needed; class failure can precede main | Strict parser + fresh registration; list/message |
| Fresh status | Current implementation restores stale DTOs; add reload | New Status/load on route entry |
| Logoff | Works only when list actually restored; timer race remains | Navigate into list cleanup; same timer race remains |
| Effort | Small opt-in, substantial repair/exclusion work; unknown total | Medium: parser, resolver, per-app events/history policy |
| Framework dependency | Draft lifetime, restore lifecycle, mode and sync | Hash transport/listener/write API; no draft URL dependency |

Next live gate (no feature build): back up every changed class with sapcli
`class read` under `/tmp/ag2ui5-routing-spike/`; compare to Git HEAD; temporary
ADT `class write` only. Test both prototypes against key 000000000010 only:
cold Status deep link, two reloads, list/Status/repo diff/file diff and ordinary
events, Back/Forward including after refresh, app Back with/without parent,
missing/invalid key/draft and pending timer navigation. Capture settled URL and
view plus routing options/request IDs. Restore from backups even on failure;
read back and compare with backup and HEAD. Stop again if login is required.
This is the outstanding evidence gate, not an implementation authorization.

### App-owned live gate after Chris's SAP login (2026-10-09)

The minimal **list ↔ Status** prototype was deployed and tested on A4H25,
client 001, through the own ICF node in separate Chrome tabs. Diff was
deliberately omitted. Only the main sources of `ZCL_AG2UI5_APP_REPOS` and
`ZCL_AG2UI5_APP_STATUS` changed, temporarily. sapcli `class read` backups in
`/tmp/ag2ui5-routing-live/backup/` matched Git HEAD before either ADT
`class write`. No framework or service source changed.

The prototype read `get( )-s_config-hash` at cold boot, validated the raw
12-digit key against a fresh service `list_repos` result, and constructed a
new Status app. Each participating render asserted DEFAULT routing, disabled
app-state routing using the API's single-space argument, and registered
`cs_event-hash_attach_changed` for `HASH_CHANGED`. Ordinary repository opening
used `hash_set`; valid history dispatch did not write a hash; invalid routes
and app Back used `hash_replace`. Status's temporary visible fresh timestamp
was assigned only after successful `get_status` and `rows_build`, making
reloads distinguishable from rendering a persisted DTO. The list displayed a
temporary timestamp assigned immediately after its actual `logoff` call.

| Step | Result | Settled view and hash observed |
|---|---|---|
| 1. List → Status | PASS | `$UMLAUT`, repository URL and commit `463690e`; `#/repo/000000000010` |
| 2. Refresh twice | PASS | Fresh Status load markers advanced from `20261009132131.4492200` to `20261009132140.6537120` and `20261009132141.2511990`; Status hash unchanged |
| 3. Saved URL in new tab/full reload | PASS | New tab opened fresh `$UMLAUT` Status (`20261009131811.5738130`) at the saved repository hash; full reloads also passed |
| 4. Back, Forward, Back | PASS with list alias | List/empty hash → fresh Status/repository hash → list/empty hash; final-prototype Forward marker `20261009132150.0231480` |
| 5. Cold Status app Back | PASS after prototype correction | Also tested with no app-stack caller: list/empty hash, logoff marker `20261009132016.1090180` |
| 6. Invalid and unknown key | PASS with list alias | `00000000001X` and `999999999999` cold starts showed the list and visible Information alertdialogs saying invalid/unknown repository key; hash replaced with empty/list alias |
| 7. Diff | SKIPPED | No diff prototype or live diff claim in this gate |
| 8. Cleanup and fast Forward | FAIL overall | Ordinary Back ran real list logoff, marker `20261009132141.3959990`. Immediate Back → Forward left the list visible while hash was `#/repo/000000000010`; list logoff marker `20261009132201.1449580`. Mismatch persisted on another settled DOM/URL inspection and screenshot |

Two details change the implementation recommendation:

- **Root spelling:** the pinned Router/HashChanger normalizes a bare `/` to
  the empty route, leaving a trailing `#` in these URLs. The views agreed with
  that accepted list alias, but the literal `#/` requirement was not met.
  `Router.js`'s `appHashNormalized` explicitly maps `/` to empty. Accept the
  documented empty alias or choose a nonempty list route; do not promise exact
  `#/` with the current hash API.
- **Fast history is an open blocker:** this minimal implementation does not
  satisfy view/hash consistency during pending responses. The result is
  consistent with listener re-registration adopting the already-forward hash
  while the Back response renders the list. No response/router-state trace
  was collected, so that mechanism remains a hypothesis rather than a
  confirmed root cause. Do not treat ordinary Back/Forward passes as proof
  that this race is solved.

The first no-caller app Back attempt also exposed an app dispatch issue: a
fresh list instance read the **old request hash** before the queued replacement
reached the browser, reopening Status while the URL became empty. The temporary
fix handed an explicit list destination through `r_event_data` and bypassed
cold parsing for that handover. Retesting the root fallback passed. Cold boot
and explicit in-request navigation must therefore be distinguished.

Step 8 observes the real list logoff path, not authenticated Git credential
expiry or a stateful SESSION_END timer. No Git login or token was entered and
no stateful-login latch was manufactured. Pending SESSION_END behavior remains
unverified; the fast-history failure already prevents full acceptance.
No native regression suites or full feature lint were claimed for this
temporary, discarded prototype; both prototype and restored classes activated
with zero errors.

Recommendation now: **retain app-owned identity routes as the preferred
candidate, but the live gate is not passed**. Resolve pending-history navigation
and make the list alias explicit before implementation approval. These tests
do not establish a KEEP root cause or approve framework changes.

Cleanup completed: both changed classes were restored with ADT `class write`,
activated, read back, and compared **byte for byte with both backups and Git
HEAD**. Every comparison passed; the machine-readable result is
`/tmp/ag2ui5-routing-live/restoration.json`, with prototype and observation notes
in the same directory. All four agent-created Chrome tabs were closed.
`$UMLAUT` was read-only throughout: no pull, push, Stage, branch/tag, label or
settings change, no transports, abapgit-agent, framework change or Git
commit/push. Repository source files remain untouched; this agent changed only
this spec and its plan in the checkout, leaving both uncommitted. A README.md
edit appeared concurrently and was left untouched.

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
