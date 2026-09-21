# Docked workspace

The workspace is an explicitly opt-in `Geyser.UserWindow` that starts in
Mudlet's right dock. It owns a recursive arrangement of split nodes and tab
stacks. It does not attempt to nest native Mudlet dock windows: registered
panels contribute ordinary Geyser content roots, which can safely move between
their original standalone windows and the workspace.

The first-use layout places the ASCII map in the upper 45 percent. Character,
Chat, and Spellups share tabs in the lower 55 percent, with Chat active. Drag a
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

`on` and `off` move the existing panel roots without restarting their protocol
handlers or replacing their retained models. Turning the workspace off returns
each built-in panel to its original native `UserWindow`, so Mudlet can restore
the placement previously saved for that window name. A failed move rolls every
panel back to its prior host and leaves the saved mode unchanged.

`reset` replaces only the inner split/tab arrangement. It does not reset panel
configuration, chat history, spell state, character state, map rows, native
standalone placement, the Help window, or the bottom character gauges.

The mode, outer visibility, split tree, ratios, tab order, active tabs, and
hidden-panel set are stored in `aardwolf-vibe-data/workspace.json`. Writes use a
temporary file and atomic replacement. The reader accepts only schema version
1, limits the file to 64 KiB, bounds tree depth and node count, and rejects
cycles, duplicate panel IDs, invalid ratios, and malformed values. A malformed
file is left untouched and forces standalone mode until an explicit `reset`,
which first renames the original with a timestamped `.corrupt-...` suffix.

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
