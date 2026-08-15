# aardwolf-interface

Adaptive Obsidian Jewel Aardwolf command deck with responsive workspace, structured GMCP views, safe actions, and text fallbacks.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_Theme_Controller`, `aard_layout`, `aard_miniwindow_z_order_monitor`, `aard_splitscreen_scrollback`. Supported aliases: `^aard interface status$`, `^aard interface show$`, `^aard interface hide$`, `^aard interface details show$`, `^aard interface details hide$`, `^aard interface details toggle$`, `^aard interface details refresh$`, `^aard interface details status$`, `^aard theme change$`, `^aard interface tab (map|character|group|inventory)$`, `^aard interface pin(?: (map|character|group|inventory|off))?$`, `^aard interface palette(?: (show|hide|toggle))?$`, `^aard interface summary (room|character|quest|group|equipment|bags|actions|all)$`, `^aard interface theme (obsidian|high-contrast)$`, `^aard interface density (compact|comfortable)$`, `^aard interface scale (90|100|115|130)$`, `^aard interface action add ([^|]{1,32})[|]([^|]{1,24})[|]([^\r\n]{1,200})$`, `^aard interface action edit (custom%-[0-9]+)[|]([^|]{1,32})[|]([^|]{1,24})[|]([^\r\n]{1,200})$`, `^aard interface action remove (custom%-[0-9]+)$`, `^aard interface action move (custom%-[0-9]+) ([0-9]{1,2})$`, `^aard interface action list$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

The command deck consumes documented `gmcp.char.*`, `gmcp.group`, `gmcp.room.info`, `gmcp.comm.quest`, and `gmcp.comm.tick` events into session-scoped freshness envelopes. Its strict, explicit Equipment and Bags refresh accepts only the active tagged grammar, bounds records, verifies container IDs, and deletes only proven package-owned response lines. Built-in commands are fixed; profile-local custom commands are printable single lines and require confirmation every time.


## Dashboard behavior

The package claims one responsive right border. Workspace width defaults to 440 pixels and is clamped to 360–520. It preserves at least `max(640px, 50% of usable width)` for the console and collapses to a 44-pixel restore rail when that cannot be satisfied. A 360–440 pixel inspector is pinned only when the console minimum still fits. Map is the default tab; room context, exits, connection state, four contextual actions, and tabs remain persistent.

The Map tab embeds Mudlet's native mapper but never imports, creates, edits, or deletes map rooms. Use `aard map import` from `aardwolf-map` to populate the packaged Aardwolf snapshot. Map controls are capability-checked, and integration status distinguishes a resolved package-owned Aardwolf room from unrelated Mudlet map content.

The Map, Character, Group, and Inventory tabs render escaped structured data with unavailable, partial, stale, and error states. The bottom HUD places HP/Mana/Moves on row one and TNL/Enemy/Hunger/Thirst on row two, wrapping to three rows under 640 pixels. Text stays on a stable dark surface above a separate thin semantic progress track. Package-local Obsidian Jewel and High Contrast themes, two densities, and four text scales need no external resources.

The optional 360–440 pixel inspector starts unpinned and remembers explicit pin intent while temporarily unpinning when width is insufficient. Inventory's Equipment and Bags subtabs retain a visibly stale last snapshot when hidden. Every standard Aardwolf wear slot can be shown, empty slots are optional, and unknown numeric slots are appended. Affects and Resists are intentionally not displayed or queried.

An explicit Inventory refresh performs one paced transaction using `eqdata`, `invdata`, and verified-container `invdetails`. Bag-detail requests are limited to one per second. There is no periodic polling or Invmon mutation. Captures are bounded to 100 records and malformed or incomplete responses preserve the previous valid snapshot with an error marker.

While a package-owned refresh capture is active, its recognized tagged response, structured event, header, data, and terminator lines are removed from the game console. The suppression exists only for the bounded active capture or for structured `invmon` and `invitem` events consumed while details are expanded. The same commands entered by the user outside that capture remain visible.

For upgrades, remove an older `aardwolf-interface` or `aardwolf-mudlet-suite` package before installing 1.5.0 so Mudlet does not retain duplicate static objects. Schema 3 settings migrate to schema 4, including `dark` to `obsidian` and legacy details intent to the responsive inspector.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
