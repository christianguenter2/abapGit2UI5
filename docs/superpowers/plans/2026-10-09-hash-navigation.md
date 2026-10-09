# Hash navigation route-contract plan

Status: **implemented with app-owned replacement routes**. Chris authorized a
hash listener after the no-listener hash_replace attempt appended the existing
hash. The final contract and acceptance results are below; the numbered steps
record the earlier, superseded investigation plan. Browser Back/Forward does
not acquire an in-app page history. No framework changes.

1. **Resolve the failed minimal gate before implementation.** The 2026-10-09
   app-owned list/Status prototype left the list visible at the Status hash
   after immediate browser Back → Forward. Investigate pending-response hash
   dispatch and listener re-registration/adoption; the exact cause is not yet
   traced. Any further live spike needs its own scope: separate authenticated
   tabs, sapcli `class read` backups compared with HEAD, temporary ADT
   `class write` only, and restoration readbacks compared with backups and HEAD.
   Use $UMLAUT key 000000000010 read-only and stop if login is needed. The
   earlier KEEP failures were not re-tested by this minimal gate and their
   unresolved causes remain open; no framework changes are approved.
2. **Adopt app-owned routes if the gate confirms the source contract.** Keep
   framework routing OFF and app-state routing inactive. List reads
   `get( )-s_config-hash` at cold boot; every participating rendered app
   registers `hash_attach_changed` and handles the named event. Resolve
   the empty list hash (accept `#/` on input), `#/repo/<key>`,
   `#/repo/<key>/diff` and file diff with encoded
   path/filename. Validate raw key before conversion against fresh service
   registration DTOs; resolve file metadata against fresh status. Invalid key
   returns list/message; missing file returns Status/message. Do not use draft
   IDs or table indexes as route identity. The pinned hash API normalizes `/`
   to empty, so exact `#/` output needs a changed contract or a different
   nonempty list route. Distinguish genuine cold boot from an explicit list
   handover: the new list app must not parse the old request hash and undo a
   queued redirect. The prototype's explicit `r_event_data` handover passed
   the no-caller app Back retest.
3. **Make history policy explicit.** User navigation pushes the destination
   hash with its rendered view. Valid history changes render without another
   write. Canonicalization and invalid-route redirects replace. Preserve
   existing app-stack handovers; cold app Back constructs the deterministic
   Status/list parent and replaces the entry. Test repeated visits, busy Back,
   ordinary non-rendering events and history after reload. Registering a
   listener adopts the current hash: do not let re-registration swallow a
   pending history change.
4. **Reload data on every route entry.** Construct fresh Status and diff inputs,
   then read through the service. Restored DTOs never supply authoritative
   status. Retain all existing server authorization, selection, transport and
   fingerprint checks. No route dispatch may replay a mutation.
5. **Keep first-version exclusions deliberate.** Stage retains online Status
   identity so refresh returns fresh Status. Login uses list identity so
   refresh returns list; retain token clearing before every dispatch and Git
   user clearing on exit. Offline ZIP screens retain list identity and require
   a new upload after refresh. Route events from excluded screens must safely
   discard their temporary state and navigate, without replaying actions.
6. **Preserve session cleanup.** Browser return to list must enter the real
   repository-list app so logoff and the SESSION_END timer run. Resolve fast
   Forward/navigation while that timer is pending; both contracts can otherwise
   leave session cleanup unfinished. Cover token-free behavior with doubles;
   authenticated browser steps belong to Chris. No tokens in routes.
7. **Acceptance and cleanup.** Test cold deep link, two Status/diff reloads,
   ordinary events, list -> Status -> repo/file diff, Back/Forward before and
   after reload, app Back with/without caller, malformed/unknown routes and
   registration disappearance. Check Stage/login/offline exclusion and pending
   SESSION_END without mutating fixtures. Restore SAP backups even on failure;
   read back and compare with backups AND Git HEAD. Record live outcomes before
   turning this into an implementation plan with lint/native regression checks.

The minimal live gate temporarily deployed only Repositories and Status main
sources. Both were restored and activated; readbacks match the class-read
backups and Git HEAD byte for byte. Evidence and discarded prototype sources:
`/tmp/ag2ui5-routing-live/`. All four test tabs closed; no credentials entered,
fixture/settings mutations, transports, framework edits, abapgit-agent or Git
commit/push. This agent changed only the spec and this plan in Git, leaving
both uncommitted; a concurrent README.md edit was left untouched.
The real list logoff path was observed; the stateful SESSION_END timer was not.
App-owned routing remains a candidate with a reproduced fast-history blocker;
an upstream framework fix would require a separate decision.

## Approved implementation: replacement routes (2026-10-09)

Chris postponed an in-app browser history. Framework routing stays DEFAULT/OFF,
app-state inactive, no KEEP, and every URL write uses hash_replace. The final
routes are empty/#/#/ for the list, #/repo/<12 digits> for Status, and
#/repo/<12 digits>/diff for the repository-wide changed-file diff. No indexes,
file DTOs, credentials or draft IDs enter the URL. Individual-file diff retains
Status identity. Hash keys are registration identities, not authorization.

The pinned API appends hash_replace to the current hash without a listener.
Chris therefore authorized hash_attach_changed (ROUTE_CHANGED). Every response
that writes a route also asserts the listener. Registering only in rendered
views reproduced a duplicate Diff hash on refresh; unconditional registration
passed both consecutive refreshes and panel events. The exact frontend cause
was not established. No pushes means no in-app history entries. Manual URL
edits dispatch through a fresh root list and the same cold-start validation.
Fast overlapping URL edits and history after manual edits are not promised.

Cold list initialization validates the raw shape/key and fresh registration
DTOs through its service, then constructs Status. Aggregate Diff entry reads
fresh Status through the service, filters changed files and constructs Diff
directly, without an intermediate Status navigation. Offline, missing changes
or a failed read fall back to Status with a handover message; Status handles
load errors and login as before. Explicit list handovers carry bound event data
so the old request hash cannot reopen the repository. Status Back and label
handovers construct a list without a caller; Diff Back constructs fresh Status.
Existing caller handovers remain intact.

Stage, login, single-file diff and new repository keep a safe parent route.
Manual route edits leave temporary screens without replaying mutations. Offline
uploads are not restored; refresh returns Status without ZIP. Login clears the
token before route handling and the Git user before leaving on a route edit.
List logoff/SESSION_END and all fresh action validation remain unchanged.

Tests in existing app includes cover strict shapes, fresh registration checks,
cold dispatch versus handover, fresh aggregate files/fallback messages, Back
with/without caller, replacement-only writes, listener dispatch and excluded
screens. No new test includes or service/framework edits. npm check passes;
native app suites total 260/260. Fourteen deployed readbacks match. Live tests
passed list/Status/Diff navigation, two refreshes each, saved URLs, cold Back,
invalid/unknown keys, manual edits, panel events, history with no extra app
entries, Stage/file-diff/creation exclusions and offline fallback. Real Git-login
SESSION_END remains covered by doubles; no credentials were entered in Chrome.
Evidence and the full report: /tmp/ag2ui5-hash-routing-impl/.
