# Favorite repositories: draft design

Date: 2026-10-07. Status: implemented, pushed and deployed to A4H25; native tests and live star/filter checks passed.

## Recommendation

Reuse abapGit's existing per-user favorites. Add stars to the repository list
and tiles, a remembered Favorites only filter, and favorites-first ordering.
No new database table is needed.

## Findings from the current sources

- `ZCL_AG2UI5_APP_REPOS` builds list and tile layouts from the same `mt_repos`
  rows. `mt_all` retains the unfiltered rows; `apply_search` currently matches
  name, package and URL. The service currently sorts by package.
- abapGit's `ZIF_ABAPGIT_PERSIST_USER` exposes `get_favorites`,
  `is_favorite_repo` and `toggle_favorite`. Favorites use repository registration
  keys, not URLs, package names or branch names, and belong to a SAP user.
- `ZCL_AG2UI5_REPO_SERVICE->create_repo` already marks new repositories as
  favorites using abapGit persistence. The UI currently does not expose this.
- abapGit's repository-service deletion removes the current user's favorite
  entry. Other users may retain stale keys; joining with registered repositories
  prevents those keys from displaying. No global cleanup is needed for this slice.
- abapGit's user persistence `update` commits with `COMMIT WORK AND WAIT`.
  The favorite mutation therefore persists despite abap2UI5's later rollback.
- Our settings table has a 40-character VALUE and a strict key/value allow-list.
  It suits a filter boolean, rather than an arbitrarily long favorites list.

## Proposed user behavior

- Every registered repository, online or offline, has an outline or filled star.
  Clicking the star immediately adds or removes the favorite. It does not open
  the repository or invoke any Git operation.
- List: a narrow star column before Name, kept visible on phones. Adjust
  responsive column/pop-in behavior if needed so repository names retain space.
- Tiles: a star button at the top of the card content, aligned right. The card
  header continues to open the repository; URL and branch links keep their
  behavior. Do not replace the online/offline icon with the favorite star.
- Use a ToggleButton with a pressed state and an accessible name/tooltip:
  Add to favorites or Remove from favorites. Preserve native keyboard behavior.
- Add a Favorites only ToggleButton to the page's OverflowToolbar. It moves
  into the overflow menu on narrow screens, preserving the search/layout bar.
- Default is All. Remember the filter immediately per SAP user with a new
  `REPOS_FAVORITES_ONLY` setting, accepting only X or blank. The favorite list
  is shared with classic abapGit; this frontend's filter preference is separate.
- In All, favorites appear first; within each group retain package ordering,
  with name/key tie-breakers. Favorites only uses the same package ordering.
- Search combines with the filter: Favorites only AND a match in name, package
  or URL. Switching filters retains the search text and list/tile preference.
- Unstarring a repository in Favorites only removes it from the current view.
  Empty results show a message in both layouts and offer Show all repositories.
  That action switches off the favorite filter and retains the search term.
  Distinguish No favorites yet from No favorites match your search.
- Refresh and return from a repository reload favorite flags. Favorites created
  in classic abapGit, including existing ones, appear without migration.
- New repository registration keeps the existing automatic-favorite behavior.
  A branch switch or repository rename leaves its favorite state intact.
  Removing and re-registering a repository gives a new key and does not inherit
  an old registration's favorite state (new registration is auto-favorited).

## Service boundary and writes

Only `ZCL_AG2UI5_REPO_SERVICE` reads/writes abapGit favorites. The app retains
plain data only. The filter preference stays in `ZCL_AG2UI5_SETTINGS`.

Proposed interface additions:

- `ty_repo-favorite TYPE abap_bool`, mapped to the app row.
- `set_favorite( iv_key TYPE string, iv_favorite TYPE string )`
  validating the raw X/blank string before boolean conversion, returning the
  resulting favorite state and raising `zcx_abapgit_exception`.

`list_repos` fetches the current user's favorite keys once and maps flags onto
registered repositories. The app applies search, favorite filtering and ordering
in one side-effect-free transformation, shared by both layouts.

`set_favorite`:

1. Install silent progress and check abapGit startup authorization.
2. Validate a nonempty numeric key of at most 12 characters before converting
   to abapGit's fixed-length key. Reload the registration; refuse a removed or
   unknown repository. Do not trust rows or favorite flags sent by the browser.
3. Validate the desired state as X or blank. No username is accepted from the
   client; use the current SAP user.
4. Read the persisted current state, and call `toggle_favorite` only if it
   differs from the requested state. The public operation is a set, making a
   repeated request for the same state harmless.
5. Return the actual resulting state; reload the displayed list after success.
   No write is needed for an already-satisfied request. Verify persistence's
   existing commit behavior on the deployed abapGit version during implementation.

On failure, keep the prior display state and show the error. Do not display a
successful filled star before persistence succeeds. Check the client event's
raw value before converting it to `abap_bool`; overlong values must not truncate
into a valid state. Event booleans use X/blank, not the strings true/false.

Classic abapGit caches its current-user persistence object. During implementation
verify cross-request Refresh behavior and read the current state at the mutation
boundary. This proposal promises synchronization on refresh/navigation, rather
than live updates between browser sessions or transactional protection from
simultaneous edits to abapGit's whole user record.

## Checks and rollout

- Pure transformation tests: combinations of search and filter, favorites-first
  stable ordering, offline rows, no favorites, empty search results.
- Mutation tests with an injected persistence double: add/remove, repeated set,
  malformed/overlong/unknown/deleted keys, invalid states, current-user isolation,
  persistence failure, and no write when the desired state already holds.
- Repository app tests: star clicks keep navigation idle, both layouts share
  state, filter is remembered, removing the last visible favorite shows the
  empty state, and returning/refreshing updates favorite flags.
- Settings tests: new key, default All, X/blank allowed and invalid values refused.
- Run npm check and inspect desktop/phone views with long names, filled/outline
  stars, the overflow filter and empty results.
- After implementation approval, activate existing interface/class/test includes
  through ADT. Native affected suites and readback verification precede live UI
  checks. Verify classic-abapGit synchronization with a fixture and restore its
  favorite and frontend filter afterwards. No remote push is required.

## Approved decisions

Shared favorites with classic abapGit; default All; remember the filter; favorites
first in All; stars on the repository overview only for this first slice.
Custom ordering, groups, shared/team favorites and status-page stars are deferred.
