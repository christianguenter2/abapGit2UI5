# Pull with decisions: design

Date: 2026-09-30. Status: approved in chat.

## Goal

Replace abort mode with a decision dialog, as in abapGit's own pull. The first
slice showed that abort mode blocks 10 of 17 real repositories
(`docs/findings.md`).

The choices made in chat:
- Pull **always** opens the dialog, with abapGit's defaults preselected.
- **One** grouped dialog replaces abapGit's sequence of popups.
- Transportable packages stay blocked. A transport picker is a later slice.

## Flow

1. **Pull** calls `preview_pull( key )`. It fetches the remote and runs
   `deserialize_checks( )`, then `preview( checks )`. Nothing is imported.
   - If the outcome is `nothing`, a toast says "Already up to date".
   - If the outcome is `blocked` (a transport is required), the error is shown
     as today.
   - Otherwise the decision dialog opens.
2. **Pull selected** calls `pull( key, items, acknowledged )`. It fetches and
   runs the checks again, then `apply_decisions( checks, items, acknowledged )`.
   - If the checks now contain an object that is not in `items`, the outcome
     is `changed`: nothing is imported, and the message is "The remote changed
     - please review again".
   - Otherwise it deletes the selected objects, refreshes the repository and
     deserializes. The log handling stays as it is today (`deserialize_logged`).

Both network steps keep the guard, the authorization check and the silent
progress indicator.

## Items

`ty_decision_item`:

| Field | Content |
|---|---|
| `obj_type`, `obj_name` | The object |
| `group` | The group constant, see the table below |
| `reason` | abapGit's `text`, or a fixed text as fallback |
| `selected` | `abap_bool`, bound two-way to the dialog |
| `selectable` | `abap_bool`, false for `skipped` |

There is **one item per object**. An object that is in several check tables is
shown in the most dangerous of its groups. Its single decision is written to
every table it appears in.

| Group (in this severity order, most dangerous first) | Source | Default |
|---|---|---|
| `DATA_LOSS` | `data_loss`, `delete_tabl_with_data` | not selected |
| `DELETE` | overwrite action `delete` / `delete_add` | not selected |
| `OVERWRITE` | overwrite action `overwrite` | not selected |
| `PACKAGE` | overwrite action `packmove`, `warning_package` | not selected |
| `IMPORT` | overwrite action `add` / `update` | selected, except when a namespace is new: then only the `NSPC` add is selected, as in abapGit's `popup_decisions` |
| `SKIPPED` | overwrite action `no_support` | not selectable, decision `N` |

Conditions that apply to the whole repository:
- `requirements-met = N` or `dependencies-met = N` gives `ack_text`. The dialog
  shows it with a "Pull anyway" checkbox, and "Pull selected" requires that
  checkbox. `apply_decisions` sets the matching decision to `Y` only when it is
  acknowledged, and raises an exception otherwise.
- `transport-required` or `customizing-required` gives the outcome `blocked`.

## Service interface changes

In `ZIF_AG2UI5_REPO_SERVICE`:

- `preview_pull( iv_key ) RETURNING ty_preview`, where `ty_preview` has
  `outcome`, `items` and `ack_text`.
- `pull( iv_key, it_items, iv_acknowledged ) RETURNING ty_pull_result`. It
  replaces today's `pull( iv_key )`.
- New outcome `changed`. The outcome `ready` is only used by `preview_pull`.

`ty_pull_result` loses `blocking` and `info`.

In `ZCL_AG2UI5_REPO_SERVICE`, two public static methods without side effects
replace `classify`:

- `preview( is_checks ) RETURNING ty_preview`
- `apply_decisions( is_checks, it_items, iv_acknowledged ) RETURNING ty_deserialize_checks`.
  It raises an exception when an object in the checks has no item. `pull`
  turns that into the outcome `changed`. It sets the decision of **every**
  row of the four tables, so abapGit's `checks_adjust` finds no row without a
  decision.

Deletion is a new private method: for `overwrite` rows with action `delete` or
`delete_add` and decision `Y`, it collects TADIR entries, calls
`zcl_abapgit_objects=>delete( it_tadir, is_checks-transport, log )`, and then
`repo->refresh( iv_drop_log = abap_false )`. This mirrors
`zcl_abapgit_services_repo=>delete_unnecessary_objects`.

## UI (`ZCL_AG2UI5_APP_STATUS`)

- Public, bound data:
  - `mt_items`
  - `mv_ack_text`
  - `mv_acknowledged`
- The Pull button calls `preview_pull` and opens the dialog.
- The dialog shows one `Table` per non-empty group, in the severity order
  above. Each table has a title and a warning strip for the risky groups. Each
  row has a CheckBox (`selected`, enabled when `selectable`) and the object
  and reason.
- If `ack_text` is set, the dialog shows it in a strip with a "Pull anyway"
  CheckBox.
- Buttons:
  - **Pull selected:** calls `pull`, handles the outcome, closes the dialog and
    clears the dialog data.
  - **Cancel:** closes the dialog on the client.
- The outcomes after a pull are handled as today: `pulled` shows a toast or the
  warnings, `failed` shows the log. `changed` shows an error MessageBox.

## Tests

- **Unit tests for `preview`:**
  - one test per group, including its default
  - the `NSPC` rule
  - one item per object, in its most dangerous group
  - requirements and dependencies produce `ack_text`
  - a transport requirement gives `blocked`
  - empty checks give `nothing`
- **Unit tests for `apply_decisions`:**
  - a choice lands in every table the object is in
  - every row gets a decision
  - an object that is not in the items raises an exception
  - without acknowledgement, requirements that are not met raise an exception
- **End to end** on the fixture `$AG2UI5_TEST` (`abapGit-tests/INTF`):
  - Change the interface through MCP. After Pull its row is in `OVERWRITE`,
    unselected. Selecting it and pulling restores the remote version.
  - Create a local-only class in the package. It appears under `DELETE`.
    Selecting it and pulling deletes it.
  - Unchanged: "Already up to date".

## Out of scope

- The transport request picker.
- The diff view.
- Parallel pulls.
