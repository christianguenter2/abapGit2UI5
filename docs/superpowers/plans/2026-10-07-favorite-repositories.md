# Favorite repositories: implementation plan

1. Map abapGit user favorites onto repository rows; add an idempotent setter
   with validated string inputs and fresh registration checks.
2. Add the allow-listed REPOS_FAVORITES_ONLY frontend setting.
3. Add stars in both layouts, overflow filter, favorites-first search/filter
   transformation and a shared empty state; retain navigation and links.
4. Cover persistence/validation, filter/sort and app events with doubles.
5. Run npm check and inspect desktop/phone layouts including empty results.
6. Activate approved sources on A4H25, run affected native suites, verify
   readbacks and classic-abapGit synchronization, and restore fixture settings.
7. Record results and limitations in docs/findings.md. No commit or push until
   Chris accepts the result and requests it.
