# ASCII map pane

Version 0.7.0 adds a passive ASCII map display to AardwolfToolbox. Use `aardwolf-ascii` to enable/open or raise it; `aardwolf-config` exposes the ASCII map section.

Only complete frames replace the previous display. Exact `<MAPSTART>` and `<MAPEND>` lines may have surrounding whitespace. While enabled, markers and all enclosed lines are hidden from the main console. Spaces, empty lines, symbols, title, exits, and foreground/background color runs are retained. Text is written literally to a monospaced MiniConsole, without HTML, links, Lua, or color-markup interpretation. Wrapping is disabled; scrollbars allow inspecting larger maps without changing alignment.

The pane starts floating at (40, 140), 420×460 pixels, unlocked. Drag its title to move; drag an edge to resize. Right-click the title for lock/unlock, floating or four-edge docking, font adjustment, settings, and close. The context menu follows Mudlet's normal popup behavior. A docked pane can be dragged back to floating or resized along its reserved edge. Closing disables the feature, immediately returning subsequent map output to the game console. Reopen with `aardwolf-ascii`.

| Setting | Default | Range / choices |
| --- | --- | --- |
| Enable ASCII map | Enabled | Boolean |
| Locked | Disabled | Boolean |
| Dock position | Floating | Floating, left, right, top, bottom |
| Font size | 11 points | 6–20 |
| Capture timeout | 10 seconds | 1–120 |
| Floating X / Y | 40 / 140 pixels | 0–16384, clamped on screen |
| Width / height | 420 / 460 pixels | Minimum 160 / 100; maximum 16384 |

Settings use the existing profile-local `AardwolfToolbox-settings.json`. Completed mouse moves/resizes save one draft atomically. A stale draft or failed write restores the saved placement and reports the failure. Adjustable's separate save/load persistence is disabled. Dock thickness uses width for left/right and height for top/bottom. Docked resizing preserves the saved floating coordinates. Settings permit unlocking at any time.

ASCII and Vitals coordinate their console reservations. Bottom-docked ASCII sits above Vitals; side docking leaves room for the existing sidebar. Unrelated border reservations are retained, including external changes noticed during the feature's lifetime. Floating panes reserve no space.

A repeated start marker discards the partial frame and starts again. Orphan end markers are hidden. Partial frames time out after the configured absolute deadline or abort beyond 256 content lines / 256 KiB of plain text. The offending over-limit line remains visible. An abort retains the previous complete map and releases suppression of subsequent ordinary text. Disconnecting or connecting clears partial and completed maps and displays “Waiting for map.” Changing ASCII settings also abandons a partial frame.

No map contents are persisted. Disabling, stopping, or uninstalling removes owned widgets, callbacks, capture subscriptions, timers, and border reservations. Preferences remain saved. Pane activation failures leave map output visible and appear in settings status.

## Integration

`incoming.lua` owns one incoming-line trigger. ASCII capture has priority over brace-tag capture and claims every line of its frames, so braces inside maps cannot create generic blocks. Claimed lines are gagged at most once, after formatted text is copied. Other packages' triggers are not stopped. The Game tags setting and public tag APIs remain independent.

`ascii-map.lua` exposes repeatable `start`, `configure`, `stop`, `destroy`, and `open` operations. Toolbox feature code should register all preferences through the shared configuration registry; it should not create another incoming trigger or directly alter border space. `borders.lua` coordinates Toolbox reservations and preserves the external baseline at each edge.

Validation fixtures in `tests/native_ascii*.lua` reject execution outside the disconnected disposable `AardwolfToolboxSettingsTest` profile. Never replay them in a player profile. Native live acceptance uses naturally arriving map frames only.
