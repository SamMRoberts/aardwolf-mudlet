# AardwolfToolbox 0.24.0-dev.4

This is a development candidate for the roadmap to a standalone 1.0, not a
completed 1.0 release. See [implementation status and remaining milestones](docs/roadmap-status.md).

This candidate adds a searchable **Tools** utility menu, an offline setup
walkthrough, and an **Inventory / Equipment / Abilities** workspace. Open these
from Tools or Views. Workspace tabs can float independently, and browsing does
not execute an ability or change equipment. See [workspace controls](docs/workspace.md).
Native validation remains pending: use the disconnected disposable profile
before upgrading a player profile.

Chat search, quiet mention badges, raw Aardwolf chat colors and
**Off / Captured queries / Compact output** cleanup are also included.
See [chat controls](docs/ui-dashboard.md#chat-search-colors-and-mentions)
and [console cleanup](docs/console-cleanup.md).

New controls are in **aardwolf-config → Sidebar and setup** and **Diagnostics**.
The settings search field filters sections and their setting descriptions when
Enter is pressed; input stays local. `aardwolf-status` includes feature health
and the current query owner. Diagnostics show queued requests, recent failures,
and requested/confirmed monitoring; they can be exported locally as JSON.

This candidate moves inventory, abilities, spell snapshots, room scans, and
consider batches onto the shared request broker. Progression changes cancel
unsent obsolete catalog work and drain the active response before refreshing.
The item service now retains bounded, session-only item records and observed
equipment/container data. The workspace displays these observations; verified
item-changing actions and equipment comparisons remain future work.

Automatic sidebar ownership retains an installed starter UI; on fresh profiles,
Toolbox supplies its own map/dashboard/chat shell. Explicit Toolbox mode moves
existing map/chat widgets after saving a layout/settings snapshot. This migration
is a native acceptance candidate: back up the profile before installing it.


AardwolfToolbox is a Mudlet package for Aardwolf with automatic mapping, readable
player dashboards, room-mob tracking, configurable action buttons, and shared
settings. It targets **Mudlet 5.0.1** and uses Lua 5.1-compatible scripts.

## Install

1. Obtain **`AardwolfToolbox.mpackage`**. In a local checkout, the package is
   [build/AardwolfToolbox.mpackage](build/AardwolfToolbox.mpackage). If it is missing
   or you changed the source, follow [Build and verify](#build-and-verify) first.
   Install the `.mpackage` file, not the repository ZIP or an individual Lua file.
2. Open Mudlet and select your **Aardwolf profile**. Installation and preferences
   apply to that profile.
3. Open **Packages** on Mudlet's toolbar to open **Package Manager**, choose
   **Install**, and select `AardwolfToolbox.mpackage`.
4. Enable **GMCP** in that profile's Mudlet settings. Log in normally so features
   can receive fresh character and room data. If you enabled GMCP while connected,
   reconnect when convenient to establish the protocol.
5. Enter **`aardwolf-config`** in Mudlet's command input to customize the package.
   Use `aardwolf-status` for package status and `aardwolf-map status` for mapping
   diagnostics. Open Mudlet's **Map** window if the graphical mapper is not visible.

The package starts on installation and profile load. Data-dependent panels may
show waiting or unavailable readings until fresh server data arrives. Features
can request informational data according to their settings; **automatic spellup
casting starts disabled**. Action buttons and mob actions execute only when used.

### Upgrade or uninstall

Before upgrading, save and back up your Aardwolf profile, native map, and settings.
In Package Manager, uninstall the existing **AardwolfToolbox**, then install the
new `.mpackage`. If migrating from **AardwolfStarter**, uninstall that old package
first to avoid duplicate aliases. Do not delete your profile to upgrade.

Package uninstall preserves the native map, saved Toolbox preferences, and local
ability catalog. Preferences are reused after reinstalling. Settings use format
3; releases that only understand older formats cannot read those preferences.
Keep your backup if you may need to downgrade.

Use only one active mapping package per profile. If `generic_mapper` is installed,
Toolbox's mapper stays off and reports the conflict. Back up the map, remove
`generic_mapper` through Package Manager, then use `aardwolf-map on` to enable
Toolbox mapping. Existing foreign map rooms are not automatically adopted.

## Features

| Feature | What it provides |
| --- | --- |
| **Auto-mapper** | Maps fresh GMCP room observations, follows your position, colors terrain, and previews unexplored exits with gray **?** rooms or exit stubs. Uses game room IDs and authoritative reported fields. See [mapping behavior](#mapping-behavior-and-preservation). |
| **Graphical and ASCII maps** | Switch map tabs or pop out the ASCII pane. Captured ASCII frames retain spacing and colors and are hidden from the game console. [Map and layout guide](docs/ui-dashboard.md). |
| **Player dashboard** | Compact identity, total/base attributes, combat rolls, and conditions; base attributes are italic. [Dashboard guide](docs/ui-dashboard.md#sidebar-views-0220). |
| **Quest and Group dashboards** | Quest state, target/location, approximate timer, and local map lookup; group membership, presence, and resource readings. [Dashboard guide](docs/ui-dashboard.md#sidebar-views-0220). |
| **Buffs and spellups** | Active effects, recoveries, expiry warnings, coverage, and a utility-bar indicator. Optional auto refresh uses `spellup learned retry`. [Spellup guide](docs/spellups.md). |
| **External views and chat** | Move Player, Quest, Group, Buffs, or existing All/Tells/Channels chat views into separate native windows. Chat retains its history, with unread counts and Latest/Mark read controls. [View controls](docs/ui-dashboard.md#sidebar-views-0220). |
| **Room mobs and Nearby scans** | Individual mob rows, observed consider ranges, target/attacker/kill indicators, and compact nearby scans. Configurable double-click actions and right-click command/alias menus. [Room mobs guide](docs/room-mobs.md). |
| **Action and navigation bar** | Paged command/alias buttons, optional keybindings, a directional compass, door controls, and known special exits. [Action bar guide](docs/action-bar.md). |
| **Ability catalog and smart buttons** | Locally stored learned skills/spells, filters and type corrections, and buttons for a specific ability or the highest-required-level eligible ability of a type. [Ability guide](docs/abilities.md). |
| **Inventory and ability workspace** | Search observed inventory/equipment and learned abilities; inspect captured details, command verification and smart-button selections. Workspace tabs can float independently. [Workspace guide](docs/workspace.md). |
| **Tools and setup** | Search local views, settings and guarded refreshes; follow the resumable offline setup walkthrough. [Guide](docs/workspace.md). |
| **Top utility bar** | Level, total levels, tier, remorts, worth, gold, inventory count, status indicators, Settings, and Views access. [Utility bar guide](docs/utility-bar.md). |
| **Bottom Vitals** | HP, Mana, Moves, target health, and TNL in one row above the command input, with TNL at the far right. |
| **Consider formatting** | Compact difficulty labels, relative-level ranges, and threat colors using shared ratings with Room mobs. [Consider guide](docs/consider.md). |
| **Floating help** | Tagged help pages in a bordered, movable reading pane. [Help guide](docs/help-pane.md). |
| **Console cleanup and tag capture** | Configurable blank-line/repeated-prompt filtering and bounded capture of tagged records for other features. [Cleanup](docs/console-cleanup.md) · [Game tags](docs/game-tags.md). |
| **Shared appearance and data** | Readable fonts, layout controls, profile-local settings, and a shared GMCP cache for current and future features. [Appearance](docs/ui-dashboard.md) · [GMCP API](docs/gmcp-cache.md). |

## Access and use settings

Enter either command in **Mudlet's command input**, then press Enter:

```text
aardwolf-config
```

```text
aardwolf-settings
```

Both open the same draggable, resizable settings window. You can also click
**⚙** on the top utility bar.

1. Select a feature section in the settings navigation.
2. Edit its switches, fields, or lists. Scroll the body for additional controls.
3. Click **Apply** to validate, save, and activate your changes.

**Cancel** or closing the window discards unsaved edits. **Restore defaults**
changes only the selected section's draft; click Apply to save those defaults.
Opening the settings command again raises the existing window without discarding
its draft. If a command changes preferences while a draft is open, cancel and
reopen the panel before applying.

Useful sections to start with:

- **Appearance:** shared UI/reading fonts, sizes, and presets.
- **Dashboard and layout:** sidebar sizing, section proportions, and layout controls.
- **Dashboard and chat views:** tabbed or external placement for each view, Buffs
  recovery visibility, and expiry warnings. The utility **Views** menu also opens,
  floats, or returns a view to the sidebar.
- **Room mobs:** refresh behavior, indicators, double-click action, and right-click
  command/alias templates such as `kill {target}`.
- **Action bar:** buttons, ability selections, and keyboard shortcuts.
- **Spellups:** tracking and optional automatic refresh. Enable casting only if you
  want Toolbox to start guarded spellup batches.
- **Auto-mapper:** mapping, following, terrain colors, and unexplored placeholders.

Preferences are saved per profile in **`AardwolfToolbox-settings.json`**, inside
Mudlet's profile directory (`getMudletHomeDir()`), outside the installed package.
They survive restarts, uninstall, and upgrades. Validation or storage failures
keep active settings unchanged; invalid settings files are preserved and reported.
Feature status messages distinguish saved preferences from actual activation.

Developers adding configurable features must use this same window through the
[settings registry](docs/settings-framework.md).

## Command reference

| Command | Action |
| --- | --- |
| `aardwolf-config` or `aardwolf-settings` | Open the shared settings window. |
| `aardwolf-ascii` | Enable/select ASCII, or raise its popped-out pane. |
| `aardwolf-buffs` | Open the Buffs view. |
| `aardwolf-spellup on\|off\|status\|sync\|now` | Enable/pause automation, inspect status, synchronize data, or request one guarded spellup batch. |
| `aardwolf-status` | Show package status and session invocation count. |
| `aardwolf-map` or `aardwolf-map status` | Show mapper state, counts, last result, and backup path. |
| `aardwolf-map off` | Stop mapper updates. |
| `aardwolf-map on` | Resume mapping, waiting for fresh room data. |

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

**Version 0.23.0 uses the game room number as the native Mudlet room ID.** For
example, GMCP `room.info.num = 1400` creates or updates Mudlet room **1400**, and
`exits.e = 1023` points east to room **1023**. Coordinates never identify rooms.

Fresh, valid `gmcp.room.info` is authoritative for reported room names, zones,
terrain, and north/east/south/west/up/down exits. These observations replace stale
or manually changed values in Toolbox-owned rooms. Removed standard exits are
cleared; maze exits with unknown destinations become stubs when previews are
enabled. Custom exits, annotations, symbols, and unrelated rooms remain intact.
Private/invalid IDs and incomplete room packets do not change the map.

Continental coordinates place the room at GMCP X and inverted Y, with Z zero
unless explicitly reported. These positions are updated on each visit, including
after a manual move. Indoor `coord.x/y` describe the area's world location, so they
are stored as metadata while the mapper retains its inferred interior layout.
The complete bounded packet, details, and additional reported fields are saved
in room user data. See [authoritative mapping and migration](docs/mapper-authority.md)
for the metadata keys and coordinate contract.

Double-click a mapped room to send one Aardwolf `run` command along the mapped
path (for example, `run 3n2e`). Toggle this in **Auto-mapper → Double-click map
rooms to run**. It uses fresh current-room GMCP, requires standing outside combat,
and reports missing paths or routes requiring custom exits. See [map travel](docs/mapper-authority.md#double-click-to-run).

### Existing maps and ID migration

On the first fresh room update after upgrading, Toolbox checks its existing IDs.
If necessary, it saves a native binary backup, exports the current map, and
renumbers verified Toolbox rooms together with incoming/outgoing connections,
special exits, player-room references, and owned link metadata. Areas, map labels,
room notes, custom line data, locks, and other saved native properties are retained.
A conflicting foreign ID or incomplete identity stops migration with a diagnostic.
It never deletes a foreign room to free an ID. Native migration files are limited
to 64 MiB; import/readback failures attempt to restore the binary backup.

The old local IDs change during migration. Update any external scripts that saved
those numeric IDs; Toolbox's game-number hashes remain stable. No live map is
modified by building the package—migration runs inside Mudlet after installation
and a fresh room observation. Keep the reported backup until you have checked it.

### Terrain and unexplored rooms

Terrain coloring is configurable under **Auto-mapper → Color rooms by terrain**.
When enabled, fresh reported terrain determines the room environment, including
replacing a saved manual environment assignment. Shops are orange, forests green,
water blue, deserts sandy yellow, and unknown or empty terrain neutral gray.
Disabling coloring retains existing colors while recording terrain. Shared custom
palette RGB values are preserved.

**Create unexplored room placeholders** starts enabled. Each update previews at
most six reported unmapped destinations as gray **?** rooms using their game IDs.
Placeholders have no guessed names, terrain, or reverse exits. An unknown
identity or occupied preview position uses an exit stub instead. Entering a
placeholder fills in that same game ID with observed data. Turning previews off
stops new previews; existing ones remain and are completed on entry.

Before map writes, the mapper saves a checked binary backup named
`AardwolfToolbox-before-<timestamp>-<suffix>.dat` in the profile directory. Backup
failure stops mapping. Native map data and backups survive uninstall; use Mudlet's
normal map saving to persist your latest exploration.

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

Use the pinned local toolchain (Python 3.14.6, Temurin 17.0.16+8,
Muddler 1.1.0, Lupa 2.6):

```sh
python3 tools/check.py --bootstrap
# Subsequent builds, archive checks, Lua 5.1 tests and mob benchmarks:
python3 tools/check.py
```

Bootstrap downloads tools into ignored `.tools/` and installs test dependencies
in `.venv/`; it does not install anything into Mudlet. `JAVA_HOME` and
`MUDDLER_JAR` can point to an existing toolchain. CI uses the same check command.


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

Choose learned abilities in the existing button editor, or bind a button to the highest-required-level learned ability of a chosen role/type and compatible targeting behavior. The catalog is stored per character in SQLite. See the [ability guide](docs/abilities.md) for filters, local corrections, supported skill commands, freshness rules, and the API. Skill command syntax is collected dynamically from in-game help and saved in SQLite, with no built-in ability command list. Automatic refresh collects new skills; manual Refresh also rechecks saved syntax. Refreshes are informational; all ability buttons remain manual.

### Room mob tracker (0.18.1)

A dedicated left pane tracks visible room mobs as individual rows, the current
GMCP target, confirmed kills, and recently observed attackers. Configure refresh,
colors, symbols, and optional pulsing in `aardwolf-config → Room mobs`. Double-click
a living row to attack with `kill <number>.<last word>`. Duplicate combat targets default to the first match; numbered `kill` targets select the corresponding row. Compact Refresh/Settings buttons share the title row (0.18.4).
Version **0.18.5** adds a compact, collapsible nearby **Scan** inset with direction/distance headings and individual names. Refresh requests `scan`; disable **Include nearby scan results** in Room mobs settings to return to `scan here`. Nearby rows are read-only.
Version **0.18.6** omits leading `a`/`the` from Room mobs double-click commands and adds colored direction headers and separators to nearby scans.
Version **0.18.7** marks the most likely attacker among duplicate names, preferring the current opponent and otherwise the first living match. Attacker colors and optional flashing apply to that row.
Version **0.18.8** uses only the mob index and last word for double-click attacks, such as `kill 2.bat`, while preserving full names in the roster.
Version **0.19.2** replaces stale Toolbox-owned exit connections with stubs when fresh GMCP reports an unknown destination. Manual exits remain protected. Known destinations are resolved by server ID, even when their saved positions are not adjacent.

Version **0.19.1** adds a visible blue-gray border around the floating help window, with the text console inset so it cannot cover the frame.

Version **0.19.0** adds observed consider ranges and threat colors to individual Room mobs cards, sharing the console formatter's rating logic. Flags before entire consider sentences now match correctly. Toggle the rating line in **Room mobs → Show observed consider ratings**; no automatic consider commands are sent.

Version **0.18.9** compacts Room mobs cards and status chrome, places nearby scans directly beneath short rosters, and avoids redundant widget updates during refreshes and flashing.

[Controls, data limitations, and validation](docs/room-mobs.md).

### Console cleanup (0.18.2)

Blank game lines and repeated identical standard Aardwolf prompts are hidden by
default. Changed prompts and ordinary messages remain visible. Configure each
filter independently in `aardwolf-config → Console cleanup`. Captured help,
ASCII maps, and game-tag blocks retain their spacing. Existing scrollback is not
rewritten. See [console cleanup](docs/console-cleanup.md).

Version **0.19.3** realigns an unchanged Toolbox-owned room when a fresh horizontal exit points diagonally to it, provided the expected position is empty and no aligned incident exit would be broken. Room identities and links are retained; manual placements, other floors, and blocked layouts are preserved. Existing destinations are never duplicated to make the map look adjacent.

Version **0.20.0** makes Room mobs event-driven: stable rows, correct keyword ordinals, independent on-demand Nearby scans, and shared consider parsing. Use **≋ Rate room** once to verify completion each session before automatic once-per-visit ratings run. See [Room mobs](docs/room-mobs.md) for controls, diagnostics, and manual acceptance. The package artifact is built; this release has not been installed or tested through the Mudlet UI.


Version **0.21.0** adds configurable Room mob double-click actions and right-click
menus. Edit the shared action list under **aardwolf-config → Room mobs** using
command/alias templates such as `kill {target}` or `cast 123 {target}`. Attack and
Consider are included; Disable and Select only are available for double-click.
See [controls and manual acceptance](docs/room-mobs.md). This artifact has not been
installed or validated through native Mudlet interaction.


Version **0.21.1** fixes Stomp (#452) being rejected as an unverified skill command.
Existing saved catalog rows gain the verified command on read; the highest-level
picker now shows candidates without switching the button to a specific ability.
See [ability controls](docs/abilities.md). This artifact has not been installed;
no live skills or spells were executed for verification.
