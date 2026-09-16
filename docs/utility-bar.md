# Top utility bar and inventory tracking

AardwolfToolbox 0.12.0 reserves 28 pixels through its shared border service. The bar
spans the full profile width. Top-docked ASCII maps sit below it; the starter
sidebar retains its constraints and width while its computed geometry is offset
and shortened. Disabling or uninstalling restores that adapter and releases only
the Toolbox reservation. Existing Vitals and other edge reservations remain owned
by their respective components.

## Readings

All character readings consume the shared GMCP cache; reset/disconnect clears them.
Level prefers `char.status.level`, falling back to `char.base.level`. Tier, redos,
and remorts come from `char.base`. Remorts is the current class count (1-based).
Total levels excludes powerups:

```
201 * (7 * (tier + redos) + remorts - 1) + min(level, 201)
```

Worth is `char.worth.gold + char.worth.bank`; Gold is gold on hand. Finite,
nonnegative integer readings are required. Missing data is `--`, distinct from 0.
Comma-separated exact amounts appear normally and in tooltips. Smaller windows
use K/M/B amounts and shorter labels, then move low-priority entries into **⋯**.
Click **⋯** again or a menu action to close it. **⚙** always opens Toolbox settings.

The shared **Utility bar** settings control enablement, 8–16 pt font size (default
10), automatic inventory tracking, and each of the seven readings. Visibility does
not change server monitoring; disable automatic tracking separately if unwanted.

## Inventory service

`AardwolfToolbox.inventory.count` is a session-only integer or nil when unavailable.
`last` explains its state. `request(true)` requests a manual refresh and returns
false if disconnected, not in fresh GMCP state 3, disabled, or already capturing.
`AardwolfToolbox.inventory.updated` is a profile-local change notification.

The service explicitly sends GMCP `config invmon on` and requests one top-level
`invdata` after fresh, command-ready character data. State 3 is required: AFK,
combat, sleep, paging, and editing do not issue requests. Updates still apply while
busy. No movement or other gameplay commands are sent.

A complete snapshot replaces a set of loose object IDs; worn rows and
container-specific snapshots do not contribute. Item names may contain commas.
Interleaved invmon events queue until completion; duplicate IDs are idempotent.
Actions 1, 4, 5, 10, 12 add loose IDs; 2, 3, 6, 7, 9, 11 remove them. `invitem`
metadata is archived by the generic tag service, without double-counting.
See the server [Invdata](https://www.aardwolf.com/wiki/index.php/Help/Invdata),
[Invmon](https://aardwolf.com/wiki/index.php/Help/Invmon), and
[GMCP](https://www.aardwolf.com/wiki/index.php/Clients/GMCP) references.

Capture is bounded to 4,096 rows, 1 MiB, 4,096 queued deltas, and 10 seconds.
Malformed/unknown updates invalidate the count and permit one deferred resync when
command-ready. A failed resync does not start an endless retry loop; click Items
to retry manually. Disabling clears the count and removes owned listeners/timers.
Monitoring stays enabled on the server on teardown to avoid disrupting other
packages. Reconnecting begins a new session and setup sequence.

Inventory uses the shared incoming dispatcher after ASCII/help ownership and
before generic tags. Owned machine-readable lines are gagged once, then forwarded
to the generic tag archive if enabled. Disabling Game tags does not disable inventory.

## Utility item API

Register features after Toolbox initializes, and unregister your own items during
feature teardown. Register configurable preferences with the shared config service
as described in [settings-framework.md](settings-framework.md).

```lua
local bar = AardwolfToolbox.utilityBar
bar.registerItem({
  id = "quest_summary", label = "Quest", order = 20,
  overflowPriority = 10, -- smaller numbers enter overflow first
  tooltip = "Current quest status",
  callback = function() myFeature.openQuestDetails() end,
})
bar.updateItem("quest_summary", {
  text = "Ready", compactText = "Ready", visible = true,
  tooltip = "A quest is available",
})
-- On feature shutdown:
bar.unregisterItem("quest_summary")
```

`myFeature.openQuestDetails` is the future feature's own window callback. Omit
`callback` for a read-only indicator. Definitions require a lowercase letter-led
ID containing only letters, digits, and underscores; a label; finite order and
overflowPriority numbers. Duplicate/invalid definitions and updates raise errors.
Updates accept text, compactText, tooltip strings (maximum 4,096 bytes) and visible
booleans. They retain existing widgets. Text/tooltip content is escaped as literal
text. Function callbacks are invoked with no arguments, guarded against runtime
errors and inactive components. No strings are executed as code or commands.

The seven initial readings and Settings use this same registry. Built-in IDs are
`level`, `total`, `tier`, `remorts`, `worth`, `gold`, `items`, `settings`; extensions
must use their own IDs. Stop destroys native widgets and callbacks but retains
item definitions for a repeatable start. `unregisterItem` releases a definition
and its widgets, returning false when absent.
