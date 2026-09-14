# Tools, setup and the inventory/ability workspace

Updated in **0.24.0-dev.16**, a development candidate with partial native
acceptance recorded in [verification](../tests/verification.md).

## Find a feature

Click **Tools** on the utility bar (or its overflow menu). Enter text and press
Enter to filter views, settings and manual informational requests. Enter never
executes a result: click the matching row or explicitly select it with the menu keys. Tooltips explain unavailable refreshes.
Opening Tools again retains its search. Close or Shift+Escape dismisses it. Toolbox
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
- **Item actions:** select an Inventory/Equipment row, then open its action
  list. Every entry includes its exact command. Wear/Remove operates on one
  item; Put lists fresh, directly carried containers; Get retrieves one item
  from its observed, directly carried container. Nested-container actions stay
  unavailable until that container is carried directly. Names never become
  commands: all targets use the complete object ID. The server decides whether
  an item fits, is cursed or can be worn; Toolbox does not predict success.
- **Compare:** select an item, then choose another observed equipped item.
  Rows show selected value / compared value / difference. Only supplied numeric
  fields are compared; omitted, invalid or repeated stat modifiers are unknown,
  not zero. Inspect both items to obtain fresh details. Comparisons are local,
  do not infer slot compatibility and never choose or equip a preferred item.

Lists create at most 24 row widgets per page and read catalogs on demand. Hidden
tabs do not load a catalog on update events. Closing workspace tabs releases
row widgets and selected details. Detail display is limited to 512 captured
records; the item service retains its own bounded complete observation.

Configure enablement and individual placement in **aardwolf-config → Inventory
and ability workspace**. Catalog refresh preferences remain in **Ability catalog**;
inventory monitoring remains in **Utility bar**. **Enable manual item actions**
can disable all item-changing workspace controls while retaining comparisons.
Commands use the shared manual-readiness policy, bypass informational queues,
and never alter command-input text. Item changes, reconnects, reconfiguration or
teardown invalidate open selections; a snapshot in progress blocks dispatch.
Server observations, rather than sent commands, update item locations.

Syntax was verified against Aardwolf's [ObjectId](https://www.aardwolf.com/wiki/index.php/Help/ObjectId),
[Wear](https://www.aardwolf.com/wiki/index.php/Help/Wear),
[command guide](https://aardwolf.com/wiki/index.php/NewbieInfo/Commands), and
[Containers](https://www.aardwolf.com/wiki/index.php/Help/Containers) references.
This is documentation verification, not live execution acceptance.

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


## Keyboard controls

Tools and the workspace's Item actions / Compare menus share these contextual
keys while open:

| Key | Behavior |
| --- | --- |
| Alt+J / Alt+K | Select next / previous entry; the current entry appears in the fixed feedback area. |
| Alt+Enter | Activate the explicitly selected entry through its usual guards. |
| Shift+Escape | Close the current menu; press again to close the workspace underneath. |

On macOS, Alt means Option. No action is selected initially, and filtering or
rebuilding a menu clears keyboard selection. Mouse activation remains available.
Page controls and scrolling retain their existing mouse behavior. Ordinary
letters, arrows, Tab and Enter are not bound; Enter in a search field filters
locally. Neither keyboard path changes or submits the main command input.

Plain Escape works only where Mudlet forwards it to Lua. Mudlet 5.0.1's
[TCommandLine implementation](https://github.com/Mudlet/Mudlet/blob/Mudlet-5.0.1/src/TCommandLine.cpp#L509)
uses it for completion before consulting user bindings, so use Shift+Escape
when a command input has focus. Existing bindings from other packages are never
removed; external collisions can be inspected in Mudlet's Keys editor.

One shared scope stack dispatches to the most recently opened Tools/workspace
menu. Settings, Views, mob context menus and chat search suspend those keys to
avoid activating a covered item. Other menu families keep their existing Close
controls. Closing all these menus releases the five temporary keys; package
teardown also invalidates retained callbacks. This service introduces no timers,
requests, persistent preferences, or gameplay automation.

Developers can use `AardwolfToolbox.menuKeys.push(owner, callbacks)` with `close`
and optional `next`, `previous`, `activate` functions. Keep its returned handle,
call `handle.raise()` when raising an existing surface, and `handle.release()`
before deleting it. Callbacks must revalidate their own selected row and source
revision. The service does not grant action readiness or evaluate commands.
