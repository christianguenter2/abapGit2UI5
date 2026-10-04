# Object overview implementation plan

Design: [Object overview](../specs/2026-10-04-object-overview-design.md).

1. Add plain object summary types and a pure grouping method; native tests
   exercise counts, states, keys and ordering before implementation.
2. Add the allow-listed per-user overview setting, preserving Files as the
   default and existing filter/sort settings.
3. Extend the status table and header for Files / Objects. Add a file dialog
   with diff navigation and return/close behavior. Test the app with doubles.
4. Run lint/render checks, back up and activate existing sources and test
   includes, run affected native suites and verify source readback.
5. Test browser navigation, saved preferences, repository files, offline
   behavior and narrow layout; document results, commit and push.
