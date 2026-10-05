# Mark all pull decisions

The pull decision popup offers Mark all and Unmark all above its groups.
Both actions apply across data loss, deletion, overwrite, package and import
decisions. Nonselectable rows, including unsupported objects, remain unmarked.
Neither action imports anything, changes transport choices or acknowledges
Pull anyway. Existing server validation and explicit Pull selected stay in place.
The same controls serve online pulls and offline ZIP imports.

Tests cover all groups, disabled rows, marking/unmarking and preservation of
transport, acknowledgment and ZIP state. Live Chrome checks toggle the rows and
cancel without performing a pull.
