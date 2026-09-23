# Docked workspace

On a new profile, the workspace opens as a `Geyser.UserWindow` in Mudlet's right
dock. The default matches the observed Aardwolf profile: Spellups and the ASCII
minimap share the upper 30 percent, the graphical map occupies the middle, and
Chat occupies the bottom. The upper split gives Spellups 53 percent of the
width; the middle takes 57 percent of the remaining height. The command queue
stays in its own left dock, and the character status and vitals stay on the
main console. Quest Tracker is a second tab alongside Chat, with Chat selected
initially.

The workspace owns split nodes and tab stacks. Registered panels contribute
ordinary Geyser content roots; native Mudlet docks are not nested. An existing
profile with saved workspace settings keeps its saved mode and layout. An
earlier package install without workspace settings keeps its standalone dock
layout. Drag a
tab over the center of a stack to move it into that tab group, or use its left,
right, top, or bottom target to create a split. The vertical-ellipsis menu in
each stack provides move, split, and hide actions. Splitters update
interactively and save their ratio when released.

## Commands

```text
aardwolf-vibe workspace on
aardwolf-vibe workspace off
aardwolf-vibe workspace show
aardwolf-vibe workspace hide
aardwolf-vibe workspace status
aardwolf-vibe workspace reset
```

`on` and `off` move Spellups, the ASCII map, Chat, and Quest Tracker without restarting their
protocol handlers or replacing retained models. The embedded graphical mapper
is created while the workspace is on. Turning it off returns those panels to
their standalone `UserWindow`s and opens Mudlet's native map dock. Mudlet can
restore the placement saved for each standalone window. A failed move rolls
panels back to their prior host and leaves the saved mode unchanged.

`reset` replaces only the inner split/tab arrangement. It does not reset panel
configuration, chat history, spell state, character state, map data, native
standalone placement, the Help window, or the bottom character gauges.

The mode, outer visibility, split tree, ratios, tab order, active tabs, and
hidden-panel set are stored in `aardwolf-vibe-data/workspace.json`. Writes use a
temporary file and atomic replacement. The reader accepts only schema version
1, limits the file to 64 KiB, bounds tree depth and node count, and rejects
cycles, duplicate panel IDs, invalid ratios, and malformed values. A malformed
file is left untouched and forces standalone mode until an explicit `reset`,
which first renames the original with a timestamped `.corrupt-...` suffix.
The saved workspace visibility is respected at profile load; showing the
minimap automatically applies only in standalone mode.

## Panel adapter API

Register cooperative Geyser content through the active manager:

```lua
local handle, message = AardwolfVibe.plugins.workspace:registerPanel({
  id = "my-package.inventory",
  title = "Inventory",
  minimumWidth = 240,   -- optional pixels
  minimumHeight = 160,  -- optional pixels
  standalone = {        -- optional UserWindow options for workspace-off mode
    name = "my-package.inventory.window",
    titleText = "Inventory",
    dockPosition = "right",
  },
  mount = function(parent)
    -- Build once or reparent an existing ordinary Geyser root to parent.
    -- Return that root and preserve logical state across calls.
    return root
  end,
  unmount = function(root)
    -- Detach, park, or delete only this panel's view hierarchy.
    -- Do not stop its producers or discard retained state.
    return true
  end,
  onResize = function(root) end,             -- optional
  onVisibilityChanged = function(shown) end, -- optional
})
assert(handle, message)
```

IDs must be stable strings containing only letters, digits, `.`, `_`, and `-`.
Titles are treated as plain text and escaped before display. Duplicate live
registrations are rejected. An unavailable registered ID remains in the saved
tree as a non-rendered placeholder; a later registration with the same ID
reclaims that location. `unregisterPanel(id)` removes the live adapter but does
not discard its saved location.

The returned handle provides:

```lua
handle:show()
handle:hide()
handle:status() -- registered, visible, hidden, and current host
```

`show()` clears the panel's layout-safe hidden state and activates its stack.
`hide()` hides only the panel; it does not destroy the panel or collapse its
saved location. Arbitrary native `UserWindow` objects cannot be registered as
children—the adapter must expose cooperative Geyser content.

## Acceptance boundary

Pure-Lua tests cover schema validation, model mutations, rollback, persistence,
late registration, and state-preserving remounts. Actual native docking,
pointer drag/drop, splitter feel, focus, DPI scaling, narrow-window behavior,
and restart layout restoration require a separately authorized disposable
Mudlet profile. Connected Aardwolf behavior is a separate acceptance layer.
