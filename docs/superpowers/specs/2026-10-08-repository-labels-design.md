# Repository labels in the overview — proposed design

Status: implemented and deployed on A4H25; native tests and live overview checks passed.

## Existing data and views

abapGit calls repository tags **labels**. They are local repository metadata
(`repo->ms_data-local_settings-labels`), not Git release tags. Its overview
uses `zcl_abapgit_repo_labels=>split` and global settings `label_colors`.
`ZCL_AG2UI5_REPO_SERVICE->list_repos` currently returns neither.

Our overview has 20rem sap.f.Card tiles and a responsive sap.m.Table.
The tile header already contains the name, package, repository type and
favorite. The table's Name cell currently contains only an ObjectIdentifier;
other metadata columns move into pop-ins on smaller screens.

## Recommended treatment: soft pills

- Tiles: a wrapping label row at the top of card content, immediately below
  the name/package header and above the URL. Keep the favorite in the header.
- List: labels below the name in the existing Name cell. This keeps them
  visible on phones without adding a column or making the table wider.
- Small text, restrained padding, lightly tinted backgrounds, dark readable
  foregrounds and gently rounded corners. No status icons or delete crosses.
- Same label, same color in both layouts and on every repository. Label text
  remains the identifying information; color is a scanning aid.
- No labels means no label row or placeholder. Untagged rows remain compact.
- Show the first three labels, with an accessible `+N` control opening all
  labels in a wrapping popover. The mockup expands inline for easy comparison;
  the production popover avoids changing card and row heights on expansion.
- Long labels truncate at a sensible maximum width; the full text is available
  in a tooltip and in the all-labels popover. Preserve their accessible names.
- Labels are display-only initially. Clicking a label should not unexpectedly
  open a repository or filter the overview. The existing search should include
  all labels, including overflow labels.

The interactive mockup also contains **Quiet dots**: neutral text with a small
colored dot, no pill background. This is lighter visually, but does less to
separate individual labels when scanning dense rows. Soft pills are preferred.
Example labels in the mockup are illustrative, not fetched from SAP.

## Color assignment

Use a fixed palette of six to eight accessible categorical colors: blue, teal,
violet, rose, amber and slate, with light/dark surface pairs. Assign an
unconfigured label using a deterministic hash of its normalized text modulo
the palette size. Do not use repository key, row order, random colors or the
currently visible label set. Adding a repository or searching must not recolor
existing labels. Different labels can share colors; uniqueness is not promised.
Normalization for color identity should trim/collapse spaces and fold case,
while the displayed spelling remains unchanged.

Honor explicit abapGit `label_colors` where they can be represented safely:
map supported named classes to known palette entries; parse explicit RGB values
through abapGit's validator. Derive an accessible theme-specific foreground
and tint rather than blindly using an unreadable configured text/background
pair. Unknown CSS class names fall back to automatic colors. Never copy
arbitrary class names or CSS declarations into the browser. Automatic colors
are presentation data; do not persist generated values back to abapGit.

## Implementation direction

Only the repository service reads abapGit labels and color settings. Extend
the plain repository DTO with a nested label table (text plus a checked palette
identifier or validated color data). The app keeps serializable plain rows.
Split and deduplicate labels with abapGit's conventions; replace control
characters before binding them. Preserve label order consistently.

Use a wrapping FlexBox with native Text controls and shared scoped styling,
fed by allow-listed CustomData values. Reuse one `labels_display` helper in
the tile content and the Name cell's VBox. GenericTag is oriented around
semantic status/value presentation and does not expose a general categorical
palette. ObjectStatus can expose indication colors, but arbitrary repository
categories should not acquire status semantics or accessibility announcements.

The existing app already injects a scoped style block for status highlighting;
the label styles must also be scoped, with UI5 theme parameters for surfaces
and high-contrast fallback. Verify native UI5 binding of nested label rows and
DOM CustomData in the render gate before settling the final implementation.

## Verification needed for implementation

Stable colors across reload, search, favorites and layout changes; duplicates,
case/space variants, empty/long labels, many labels, explicit/unknown colors,
plain serialization and search across hidden labels. Desktop and phone visual
checks in both layouts, light/dark/high-contrast themes, keyboard access to
overflow and preserved repository/favorite/action navigation. Run npm check,
affected ABAP Unit suites and a live SAP view check.

## Label click filtering

Labels are native keyboard-accessible Links in tiles, list rows and the full
popover. A click replaces the current search with an exact label filter;
Favorites only still applies. The label text is shown in the search field.
Submitting a search or clearing that field removes the exact-label mode and
returns to ordinary text search. Unknown posted labels are ignored against
the server-held overview rows.
