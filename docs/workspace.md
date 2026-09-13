# Tools, setup and the inventory/ability workspace

Available in **0.24.0-dev.5**, a development candidate with partial native
acceptance recorded in [verification](../tests/verification.md).

## Find a feature

Click **Tools** on the utility bar (or its overflow menu). Enter text and press
Enter to filter views, settings and manual informational requests. Enter never
executes a result: click the matching row. Tooltips explain unavailable refreshes.
Opening Tools again retains its search. Close or Escape dismisses it. Toolbox
shortcuts pause while the menu or workspace editor is open.

**Setup walkthrough** explains layout/migration, fonts, monitoring, shortcuts
and chat. Settings opens the relevant shared section. Reopen the guide to resume
its current step. Finish saves local completion metadata with checked atomic
storage. It does not enable monitoring, change spellup preferences or send commands.
The guide is available while disconnected and never opens automatically.

Configure the menu under **aardwolf-config → Utility menu and setup**. Turning
it off removes the Tools item. Existing Settings and Views remain available.

## Browse observations

Use **Tools → Open inventory / equipment / abilities**, or select them from
**Views**. These share workspace tabs, with separate search, page and selection.
Choose **View → Float outside Mudlet** to move a view to an external window;
**Return to workspace** restores it. Placement uses shared configuration and
per-profile window geometry. Closing does not delete observations or preferences.
The workspace remains available when the sidebar dashboard is disabled.

- **Inventory / Equipment:** name, object ID, level, reported type number and
  freshness. Select a row for flags, wear-slot number, reported timer, location,
  container identity and captured detail records. Unknown fields show `--`.
  The view preserves reported numeric codes rather than inventing meanings.
- **Abilities:** learned spells/skills from the local character catalog, required
  level, reported cost/resource, practice, targeting, classifications and command
  verification source. Zero cost differs from unknown cost. Local corrections
  are labeled. Details show configured smart buttons that currently resolve to
  that ability using the existing selection rules; stale disk data is labeled.
- **Search:** Enter filters locally by name/number. Ability searches also match
  Spell/Skill, role and type. Item searches also match flags and reported type
  number. ASCII search is case insensitive; Unicode names are preserved.
- **Refresh:** requests information through the existing collector, only after
  fresh login readiness. It never executes a skill or spell.
- **Inspect:** requests details for the selected, still-observed item. **Contents**
  requests a selected container and switches to its observed contents. Until a
  complete response arrives, content remains unavailable. **Reset** returns to
  carried/equipped items and clears the local filter.
- **Catalog / Buttons:** on the Abilities tab, open existing shared settings.
  Browsing makes no changes to saved buttons.

Lists create at most 24 row widgets per page and read catalogs on demand. Hidden
tabs do not load a catalog on update events. Closing workspace tabs releases
row widgets and selected details. Detail display is limited to 512 captured
records; the item service retains its own bounded complete observation.

Configure enablement and individual placement in **aardwolf-config → Inventory
and ability workspace**. Catalog refresh preferences remain in **Ability catalog**;
inventory monitoring remains in **Utility bar**. Wear/remove/transfer actions
and equipment comparisons are not implemented in this candidate.

## Extension API

Register local functions, never Lua strings or command text. IDs are unique;
registry capacity is 128. Optional readiness policies are `information`, `manual`
and `spellup`; they are checked immediately before an explicit activation.

```lua
AardwolfToolbox.launcher.register({
  id = 'example.status',
  label = 'Open example status',
  description = 'Open this feature’s existing local view',
  callback = function()
    return AardwolfToolbox.views.open('example')
  end,
})
-- On feature shutdown:
AardwolfToolbox.launcher.unregister('example.status')
```

`launcher.open()`, `launcher.open('setup')`, `launcher.activate(id)` and
`launcher.close()` expose the same local behavior. `browser.open(id)` accepts
`inventory`, `equipment` or `abilities`. The shared `views.open(id)` and
`views.setMode(id, 'tabbed' | 'floating')` work for these views too. Custom view
registrations can provide `homeLabel` and a local `settings` callback so their
view menus describe the correct host and settings section.

## Manual native acceptance

Only in the disconnected **AardwolfToolboxSettingsTest** profile, after a backup
and test-package installation, run `tests/native_foundation.lua` and then
`tests/native_workspace.lua`. The latter overrides read APIs with synthetic data;
it does not write the ability database or simulate a connection. Test search,
paging, Unicode/literal markup, readable fonts, button hit areas, Escape, native
close/reopen and floating/return placement. Verify command input remains intact.

Restore `AardwolfToolboxWorkspaceAcceptance.restore()` before
`AardwolfToolboxAcceptance.restore()`. With both fixtures active,
`tests/native_workspace_geometry.lua` checks real resize-event reflow and menu
ownership, then restores the prior placement mode. This does not replace mouse
dragging or multi-monitor acceptance. Workspace search/details, Tools/guide,
borrowed chat search, geometry and cleanup have partial native evidence; see
the verification record for the remaining checks. Live behavior is unverified.
