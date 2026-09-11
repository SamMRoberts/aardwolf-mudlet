# Aardwolf Toolbox

A Mudlet 5.0.1 package with an incremental Aardwolf GMCP auto-mapper, a compact
bottom Vitals strip, a full-width utility bar, tabbed maps and gameplay dashboard, shared readable typography, inventory tracking, game-tag capture, colored consider ratings, and a shared settings window. Uses Lua 5.1-compatible code and built-in Mudlet APIs.

## Install and use

Install `build/AardwolfToolbox.mpackage` through **Package Manager**, open Mudlet's
**Map** window, and enable GMCP in your Aardwolf profile. The mapper starts on
installation and profile load unless disabled in saved settings. Move normally to receive fresh room information;
it records visited rooms, connects reported exits when both endpoints are known,
and follows your position in the map. It never walks or sends gameplay commands.

Version **0.14.3** fixes spellup completion without end tags and bases buff coverage on the confirmed server-selected buff set. Version **0.14.1** adds a colored top-bar spellup indicator: buff coverage, automation status, and click-to-open Buffs. Version **0.14.0** adds a Buffs dashboard tab, live spell/recovery tracking, and opt-in automatic `spellup learned retry`. Automatic casting starts off. See the [spellup guide](docs/spellups.md).

Version **0.13.0** added shared Appearance settings, Graphical/ASCII map tabs, a Player/Quest/Group/Combat dashboard, and persistent layout ownership. See [UI and dashboard guide](docs/ui-dashboard.md).

The mapper keeps new-room placement collisions on the intended Z level by
searching nearby X/Y positions. Only reported up/down exits change the inferred
floor; occupied coordinates no longer push rooms upstairs. Existing coordinates
remain unchanged, including older incorrect placements and manual edits.

Use one mapping package per profile. If `generic_mapper` is installed, Toolbox
stays off and explains the conflict. Generic Mapper can move the same marker
even after `stop mapping`, which only stops its room creation. To use Toolbox,
back up your map, remove `generic_mapper` through Package Manager, then run
`aardwolf-map on`. Existing rooms remain in the map; rooms created by Generic
Mapper have no reliable Aardwolf room IDs and are not automatically adopted.
Toolbox also stops before applying room data if Generic Mapper is installed
later. Other packages and unrelated room listeners remain supported.

| Command | Action |
| --- | --- |
| `aardwolf-config` or `aardwolf-settings` | Open the floating settings panel. |
| `aardwolf-ascii` | Enable/select ASCII, or raise its popped-out pane. |
| `aardwolf-buffs` | Open the Buffs dashboard tab. |
| `aardwolf-spellup on\|off\|status\|sync\|now` | Control guarded spellup automation or synchronize spell data. |
| `aardwolf-status` | Show package status and session invocation count. |
| `aardwolf-map` or `aardwolf-map status` | Show mapper state, counts, last result, and backup path. |
| `aardwolf-map off` | Stop mapping and release this component's handlers/subscription. |
| `aardwolf-map on` | Resume, waiting for a fresh room update. |

If replacing the previously named `AardwolfStarter`, uninstall that package first
to avoid two copies of the status alias. Use Package Manager to uninstall an older
`AardwolfToolbox` before installing its replacement. Map data survives uninstall.

## Settings

Run `aardwolf-config` to open a draggable, resizable panel inside Mudlet. Select a
feature, edit its controls, and press **Apply** to save and activate the changes.
**Cancel** and the close button discard unsaved edits. **Restore defaults** changes
the selected section's draft; press Apply to save it. Re-running the command raises
the existing window. Use its scrollable body to reach settings on smaller panels.

The Auto-mapper section provides **Enable mapping**, **Follow current room**, and
**Color rooms by terrain**. All default to enabled. Following can be disabled while
mapping continues; terrain coloring can be disabled without erasing existing colors
or terrain metadata. Re-enabling either takes effect on fresh room updates. The
status line shows actual mapper state separately from its saved enabled preference.

Preferences live in `AardwolfToolbox-settings.json` in the Mudlet profile directory
and survive restart, uninstall, and package upgrades. Failed validation or saving
keeps active settings unchanged. If a command changes preferences while a draft is
open, cancel and reopen the panel before applying. Unreadable or invalid settings
files are preserved and reported rather than overwritten.

Future features register their settings with this window. See the
[settings framework contract](docs/settings-framework.md) for types and examples.

## Top utility bar (0.12.0)

The top row spans the console and sidebar: level, total levels (excluding powerups),
tier, remorts, worth, gold, and loose inventory count. Worth means bank plus carried
gold. Missing readings show `--`; zero remains visible. Amounts shorten when space
is tight, with exact amounts in tooltips; lower-priority readings move into **⋯**.
The **⚙** button opens the shared settings window.

Under **Utility bar**, hide individual readings, disable the bar,
or disable automatic inventory tracking. Tracking explicitly enables server
monitoring and requests `invdata` once a fresh GMCP state says the character is
command-ready. Clicking **Items** refreshes that snapshot when safe. It counts loose
carried items, excluding worn equipment and container contents. Monitoring remains
on at teardown so other packages can continue using it. No inventory data persists.
See [utility bar and extension API](docs/utility-bar.md) for details.

## Bottom Vitals

Version 0.5.0 displays HP, Mana, Moves, target health, and TNL in one row above
the command input, with green, blue, gold, red, and purple fills. TNL stays on the
far right. The strip reserves output space and fits
the console beside the existing map/chat sidebar. The original starter Vitals
pane is hidden through a reversible adapter; disabling the strip restores it.

In **aardwolf-config → Vitals**, choose **Enable bottom Vitals**,
**Show target health**, **Show TNL**,
**Bar height** (16–36 pixels; default 22, increased when necessary to fit the shared font). Fonts are configured under **Appearance**.
Hiding either target health or TNL shares its space among the other bars.
Narrow windows shorten labels
without shrinking text, while keeping one row. Default gaps are 6 pixels with 5 pixels
of padding. Changes take effect after Apply and persist per profile.

TNL shows experience remaining and percentage earned, using the server's
`char.base.perlevel` requirement and `char.status.tnl`: completion is
`100 × (perlevel − tnl) / perlevel`, clamped to 0–100. Experience debt remains
visible even when it exceeds the requirement. Missing or invalid readings show
`--`; a missing/zero denominator leaves the fill unavailable. No requirements
are estimated from prior levels. Target health uses `char.status.enemy` and
`enemypct`, shows a shortened enemy name and percentage, and clears when the
server reports no enemy or a non-combat state. Target names are escaped as text.
Partial character updates are combined locally.
Disconnect and GMCP disable clear old values. Enable requests fresh character
data through GMCP on an active connection; no gameplay command is sent.

The strip owns its gauges, twelve named handlers, and shared `gmod` Char
subscription. Stop/uninstall releases these and restores the previous bottom
border only if its reservation is still current. Incompatible starter UI APIs
produce an activation diagnostic and preserve the original pane. The strip can
also run without the starter UI. Starter package files/settings are unchanged.

## Game tags

Version 0.6.0 introduced capture of `{name}payload` records and entire `{name}` … `{/name}`
blocks, including unfamiliar tag names. Captured output is hidden by default;
this includes ordinary descriptions or chat inside tagged blocks. Text outside
blocks stays visible. Open **aardwolf-config → Game tags** to disable capture,
show captured output, or change the 10-second block timeout.

Captured records and completed/incomplete blocks are available to other Toolbox
features through `AardwolfToolbox.tags` and local events. Repeated tags and empty
pipe-delimited fields are preserved. Data is bounded session memory and cleared
on disconnect, disable, or uninstall; only settings persist. Missing/mismatched
closing tags and size limits release suppression with a diagnostic. No server
commands or tag preferences are sent or changed.

See the [game-tag API and example](docs/game-tags.md) for access methods, grammar,
retention, and consumer lifecycle. Aardwolf's [tag reference](https://www.aardwolf.com/wiki/index.php/Help/Tags)
explains how the server supplies tagged output.

## Consider ratings (0.8.0)

Consider messages now display a mob name, difficulty label, and relative level
range, such as `(Hidden) | a goblin | Easy | −9…−5 lvls`. Colors progress
from gray/green for easier mobs through yellow/orange to red/purple for harder
mobs. The original background is retained. This does not estimate actual levels.

Use **aardwolf-config → Consider** to disable formatting or difficulty colors.
Both options start enabled. Maps and tagged blocks take priority; no server
commands are sent. See [consider ratings](docs/consider.md) for the full scale.

## Floating help (0.11.0)

Tagged `{help}` pages open in a floating pane, using `{helpkeywords}` as the title
and `{helpbody}` as the body. Close hides the pane; the next page reopens it.
Configure it under **aardwolf-config → Help pane**. See [floating help](docs/help-pane.md).

## Player sidebar panel (0.10.0)

A compact player panel sits between the graphical map and docked chat. It shows
level, race/class, core stats, combat rolls, position, alignment, hunger, and
thirst from the shared GMCP cache. Use **aardwolf-config → Player panel** to
toggle it; use **Appearance** to adjust shared fonts. See [player panel](docs/player-panel.md).

## Shared GMCP values (0.9.0)

Future features can read `AardwolfToolbox.gmcp.get("char.vitals.hp")` or access
the nested `AardwolfToolbox.gmcp.data` variables. Character, communication, group,
and room messages are copied into session memory and cleared on disconnect.
Use **aardwolf-config → GMCP data** to toggle caching. See the
[GMCP cache API](docs/gmcp-cache.md) for paths, update events, and lifecycle rules.

## Mapping behavior and preservation

The producer is Aardwolf's lowercase `gmcp.room.info` event. Room numbers are
positive integers; names accept `name` or the legacy `brief` field. A complete
record needs a name, zone, and exits table. Private rooms (`num = -1`), malformed
records, and incomplete updates leave the map and displayed marker unchanged.
Unknown maze destinations and custom exits are not guessed.

### Terrain colors

Fresh room updates capture `terrain` (or legacy `sector` when `terrain` is absent)
in room metadata as `AardwolfToolbox:terrain`. The mapper assigns a local terrain
palette through Mudlet environments: forests green, fields light green, water
blue, deserts sandy yellow, ice pale cyan, mountains brown-gray, cities gray,
and volcanoes orange-red. Other supported types include inside, hills, air,
underwater, waternoswim, quicksand, underground, roads, rivers, caves, dungeons,
and swamps. Unknown names are retained and displayed in neutral gray. This is
the Toolbox palette, not a copy of Aardwolf's configurable ASCII-map colors.

Terrain changes update the room color when it still matches the mapper's last
assignment. A manual environment override is preserved. Existing Toolbox rooms
with an unassigned/default environment gain colors on their next valid visit;
there is no bulk recoloring. Missing, empty, or malformed terrain leaves the
previous terrain and color unchanged. Palette IDs are allocated outside Mudlet's
reserved ranges and avoid existing environments and custom colors. Palette
bindings and terrain metadata persist with the map, including across uninstall;
customized palette RGB values are preserved on reuse.

New rooms get allocated Mudlet IDs, persistent `AardwolfToolbox:aardwolf:vnum:`
hashes, and ownership metadata. Areas use the server zone name alone, such as `academy` or `boot`.
Previously generated prefixed areas are renamed in place when visited, provided
the plain name is available. Manually renamed and foreign areas are preserved;
name collisions stop mapping rather than merging areas. Revisited rooms retain their names, areas,
coordinates, and user annotations. Foreign numeric room IDs, earlier importer
hashes, or conflicting ownership stop mapping with a diagnostic; this package
neither adopts nor replaces an existing Aardwolf map automatically.

Continental rooms (`coord.cont = 1`) use server x/y with y inverted for Mudlet.
Inside areas, layout follows the previous room's reported exit when available.
Disconnected rooms start at the origin; overlapping newly visited rooms use a free
position on the same level.
This is an inferred layout, not a reproduction of Aardwolf's ASCII map. Existing
positions are never rearranged, and no reverse exits are inferred.

Observed n/e/s/w/u/d destinations are stored in room metadata, so pending links
can resolve after a profile restart. A changed or removed exit is updated only
when its current value still matches this mapper's last write. Manual changes
and deletions are preserved and counted as conflicts. An unresolved destination
is never used as a room ID. Unknown maze destinations preserve existing topology.
Each event adds at most one visited room and six unexplored placeholders, and processes
at most 60 incoming references;
excess references are counted as deferred and resolve when their source is revisited.
The six metadata searches run synchronously in Mudlet and may cost more on large maps.

### Unexplored rooms (0.16.0)

**Auto-mapper → Create unexplored room placeholders** starts enabled. Each fresh
room update creates gray **?** neighbors with empty names for reported n/e/s/w/u/d
destinations not yet mapped. These are one-hop previews, not recursively generated
rooms. No room details, reverse exits, or special exits are guessed. Horizontal
previews stay on the current floor (two-unit area spacing, one-unit continent
spacing); only up/down changes Z. An unknown destination or occupied preview
position is shown as a directional exit stub instead.

Entering a placeholder fills in the same room ID and preserves incoming links.
The area and display position are provisional until entry; fresh destination data
can confirm a different area or continent position. Manual names, placements,
symbols, colors, annotations, exits, and stubs are preserved. Conflicts are reported
without moving saved rooms; conflicting destination identities do not prevent other
safe neighbors from being discovered. Existing visited rooms are never downgraded.

Turning the setting off stops creating previews; existing placeholders remain and
are completed when visited. Disabling mapping stops updates entirely. Placeholders
persist in the native map across reloads and uninstall; removed exits do not delete
their old destinations. A gray **?** is a destination reported by the server, not
proof it is reachable; the feature never issues movement commands. Mapper status
includes `placeholders`, `promoted`, `stubs`, and deferred/conflict counts.

Before the first map write per mapper instance, a checked binary backup is saved
as `AardwolfToolbox-before-<timestamp>-<suffix>.dat` in the profile directory.
Backup failure stops mapping. The snapshot and learned map are retained on
uninstall. Mudlet's normal map saving controls persistence; the package does not
replace, load, or clear maps. A partial native API failure stops mapping and reports
it. Incomplete rooms remain marked for inspection rather than being deleted or
silently duplicated. Consult the backup before manually repairing partial records.

## Lifecycle

`AardwolfToolbox.start()` and `.stop()` are repeatable. The mapper owns four named
event handlers and a shared `gmod` subscription for `Room`; other subscribers are
preserved. Disconnect, connection, and GMCP-disable events invalidate the previous
room and cached packet. Start/re-enable never consumes cached GMCP data.

Permanent aliases and install/load/uninstall callbacks belong to Mudlet's package
tree. Editor recompilation of the lifecycle script preserves the existing mapper
instance and adds no handlers. Uninstall stops the mapper and removes the package
globals; native map data and saved preferences remain. The settings panel owns
its widgets and a status-refresh timer only while open. Closing or stopping Toolbox
deletes them. Mapper preferences persist; counters remain session state. Module
Manager synchronization is outside scope.

## Build and verify

From this directory, use Muddler 1.1.0:

```sh
muddle
```

Alternatively, run `java -jar /path/to/muddle-1.1.0-all.jar` here with Java 17.
Outputs are `build/AardwolfToolbox.xml` and `build/AardwolfToolbox.mpackage`.
The archive includes `automapper.lua`, `configuration.lua`, and
`settings-window.lua`, `vitals.lua`, `tags.lua`, `ascii-map.lua`, `incoming.lua`,
`borders.lua`, `consider.lua`, `gmcp-cache.lua`, `player-panel.lua`, and `help-pane.lua` runtime resources.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m unittest discover -s tests -p 'check_*.py' -v
```

Tests inspect the built artifact and exercise its serialized Lua in a map API
harness. Native checks and their limits are recorded in `tests/verification.md`.
Use a disposable offline profile for synthetic event replay; never replay these
fixtures into a player profile. Actual server delivery and live gameplay require
separate acceptance.

Protocol and API references: [Aardwolf GMCP](https://www.aardwolf.com/wiki/index.php/Clients/GMCP)
and [Mudlet mapper functions](https://wiki.mudlet.org/w/Manual:Mapper_Functions).

## ASCII map pane (0.7.0)

`aardwolf-ascii` enables or raises the ASCII map pane. Complete `<MAPSTART>` / `<MAPEND>` frames appear **only in the pane**, with their spacing and server colors intact. The feature starts enabled, floating, and unlocked; it never requests maps from the server.

Drag the title to move the pane and its edges to resize it. Right-click the title to lock/unlock, dock to any edge, adjust font size, open settings, or close. Closing disables capture and restores normal map output. All controls, including capture timeout and saved geometry, are also in **aardwolf-config → ASCII map**. Bottom docking leaves the Vitals strip above the command input. Disabling Game tags does not disable ASCII maps.

See [ASCII map behavior and configuration](docs/ascii-map.md).

## Action and navigation bar (0.15.0)

Configure paged command/alias buttons and optional shortcuts in `aardwolf-config → Action bar`. The compass places North above, South below, West left and East right, with Up/Down alongside. Doors and Other exits send explicit single actions. [Action bar guide](docs/action-bar.md). Settings use format 3 with automatic backups when upgrading versions 1 or 2; older package versions cannot read format 3.

### Ability catalog and smart buttons (0.17.0)

Choose learned abilities in the existing button editor, or bind a button to the highest-required-level learned ability of a chosen role/type and compatible targeting behavior. The catalog is stored per character in SQLite. See the [ability guide](docs/abilities.md) for filters, local corrections, supported skill commands, freshness rules, and the API. Refreshes are informational; all ability buttons remain manual.
