# Room mobs — 0.18.9

The **Room mobs** pane stays on the left beside the console, independently of the
right dashboard and its tabs. It reserves console space and uses shared Appearance
fonts. Its list scrolls without reducing the font size. It remains visible while
disconnected, displaying a waiting state. Disable it explicitly in
`aardwolf-config → Room mobs` to reclaim the space.

This is a room-visit tracker of what the game reveals, not a way to see hidden
creatures. Tracking never attacks automatically. Double-clicking a living row explicitly sends the manual kill command described below.

## Indicators and refresh

- **◎ Target**: the current GMCP opponent and its reported health percentage.
- **⚔ Attacking (observed)**: a known mob produced a recognized incoming damage
  message recently while combat is active. The evidence expires after 12 seconds
  by default and clears when combat ends. This is independent of the current target.
- **† Killed**: a recognized, explicit death message. Kills remain in this visit's
  list until leaving the room, reconnecting, disabling, or uninstalling.
- **Not seen**: an optional indication that a mob disappeared from the next scan;
  this does not prove death.

Every mob is displayed individually in scan order. Identical living names receive
`#1`, `#2`, etc. in that scan. These are local observation numbers, not guaranteed
server targeting keywords or persistent mob IDs. Each row keeps its own flags.
Rows stay in place during combat instead of jumping under the pointer.

**Double-click** a living mob to send one literal `kill <number>.<last word>`
command, such as `kill 2.snake`. The number counts living entries of that same
name in scan order, not every row in the panel. Only the last whitespace-separated
word of the mob name is used in the command. The displayed name stays unchanged.
For example, `a tiny bat` sends `kill 1.bat`, its second duplicate sends
`kill 2.bat`, and `the caretaker` sends `kill 1.caretaker`. The last word's case,
Unicode, and punctuation are preserved.
This starts an attack and preserves command-input text. It requires a connected,
command-ready or fighting character and a complete current-room scan. A changed
list between clicks cancels the action. Dead or unclassified rows cannot attack.

GMCP combat updates mark the first living matching name as **Fighting** by default.
Outgoing `kill` / `k` commands, including keyword targets such as `2.snake`, select
the corresponding observation when matching combat data arrives within ten seconds.
The chosen row remains stable through partial updates and receives matching death
reports. This is an ordering heuristic, not a server-provided instance identity.
Other command forms fall back to the first matching mob. Incoming name-only attacker
reports mark one likely row as **Attacking you**: the matching current combat
target, or the first living matching name in scan order. The normal attacker
color and optional flashing apply to that row. This is a best-match heuristic;
identical mobs do not have server-provided instance IDs.

The roster combines counts and freshness into a compact summary, with readable
names, restrained status-colored card edges, optional flags, a selected-row
highlight, and a fixed selection footer. Ordinary rows omit the redundant
“In room” line; combat and historical states retain explicit labels. Long flags
are shortened visually, with the complete name, flags, and attack command in the
row tooltip. Diagnostic messages have a compact row and a full-text tooltip.
Confirmed kills remain separate entries. Color-independent text labels explain
each state; compact ↻ Refresh and ⚙ Settings buttons share the title row and have tooltips.

### Nearby scan

A compact **Scan** inset below the current-room roster shows nearby occupants in
server order, under colored direction headers and reported distance numbers.
Headers have a contrasting background, a separator line, and spacing between
sections. Direction colors respect **Use status colors**; separators remain
visible when colors are disabled. Duplicate
names remain separate lines; flags and names are rendered literally. Hover a
heading to read the original location wording. No distance is invented when the
server omits one. The parser follows the existing
[Aardwolf scan-client header grammar](https://www.mushclient.com/forum/threads/9783.html).

Click the inset header to collapse or expand it. Its content scrolls independently,
uses the shared readable font, and follows directly after a short room roster.
It expands into the remaining panel space instead of staying pinned at the bottom.
With long lists, current-room mobs and nearby scans have separate scroll areas;
approximately 40% of the available list space remains available to scans. Nearby entries are
read-only and never become local kill targets or acquire local combat markers.
The main roster retains its existing double-click behavior.

**Include nearby scan results** is enabled by default in `aardwolf-config → Room
mobs`. Refresh and existing automatic refreshes then request `scan`. Turning it off
hides the inset, clears nearby data, and returns future refreshes to `scan here`.
Changing the setting itself sends no command. The collapse state lasts for the
current pane lifetime; the enable preference persists normally.

Only complete, recognized responses replace nearby data. A failed refresh keeps
the last results labeled **stale**. Changing rooms or disconnecting clears them.
A scan that reports only nearby rooms does not establish current-room membership:
nearby results update, but the local list becomes stale and cannot launch attacks
until a scan reports the current room again.

The pane refreshes on room entry and after combat by default. **Refresh** requests
one new snapshot. Optional periodic refresh is off by default; set an interval
of 10–300 seconds to enable it. Requests wait for a fresh room identity, standing
command-ready state, and the shared information-query coordinator. No request is
sent during combat, sleep, AFK, running, or paging/editing. A failed scan pauses
periodic refresh until manual Refresh or the next room/combat transition.

Automatic setup sends `tags scan on` once per connection; snapshots use exactly
`scan` with nearby results enabled, or `scan here` otherwise. Disable setup if another component manages tags. Tags are left enabled
on teardown so other consumers keep their access. The feature does not change
spam/damage modes, paging preferences, or detection abilities.

Colors, symbols, flags/auras, target/attacker indicators, retained kills, missing
mobs, pane width, and evidence lifetime are configurable. Optional attacker
background pulsing runs at one change per second and is **off by default**.
Text labels remain available with colors and symbols disabled. Color preferences
accept `#RRGGBB`; use Appearance for typography.

## Data and lifecycle boundaries

Only a complete Toolbox-requested tagged scan replaces the list. Requests time out
after ten seconds; scans are limited to 1,024 lines, 256 KiB, 32 nearby sections, and 512 occupants across all sections.
At most 512 current occupants and 512 history rows are retained, evicting older
absent history before current occupants. Data stays in memory for the current visit; only preferences
persist. Room identities must be positive server room numbers. Unidentifiable
rooms show a diagnostic instead of merging observations across locations.

The existing incoming dispatcher handles ASCII and help ownership first. Owned
scan output is hidden once and forwarded to Game tags when enabled. The tracker
works when Game tags is disabled. Other scans are left to existing consumers;
issuing another scan during an owned refresh invalidates that refresh. Combat
output remains ordinary output. Unknown message forms do not create kills or
attack evidence.

The initial combat adapter recognizes known-name `NAME is DEAD!!` lines and
possessive incoming damage lines such as `NAME's bite hits you.` using Aardwolf's
documented damage verbs. Damage modes that omit the source, special attack
messages, missing server output, invisible mobs, and ambiguous names limit what
can be established. A current target is not automatically called an attacker.
Do not interpret this pane as an authoritative list of every possible attacker.

`AardwolfToolbox.mobs.snapshot()` returns a defensive copy of room freshness,
observation time, scan revision, and individual rows. Its `nearby` field contains
`fresh`, `updated`, and ordered `sections`; each section has `heading`, `direction`,
optional `distance`, and individual `entries` containing `name`. Nearby data has no
combat identity or attack action. Each row has a local ID,
name, flags, ordinal among identical living names, living/killed/missing state,
selection, target/health, and recent attacker evidence. `target` identifies the chosen combat row; `attacking` identifies the most likely attacker for each reported name.
The compatibility field `possibleAttacker` is always false. Updates raise the
profile-local `AardwolfToolbox.mobs.updated` event after incoming processing.
`mobs.refresh()` requests a guarded refresh. `mobs.select(id, revision)` selects
a current living observation, `mobs.selected()` returns a defensive copy of the
selection, and `mobs.clearSelection()` clears it. The selection APIs remain local. `mobs.attack(id, revision)` performs the guarded manual kill command used by double-click. Start, configure, stop, and destroy
are repeatable and remove owned handlers, timers, widgets, and border claims.

Rendering reuses existing widgets. Unchanged refreshes skip text measurement,
font application, styling, geometry updates, and label redraws. Freshness labels
advance in ten-second steps; attacker flashing changes only presentation, without
remeasuring cards. Surplus rows are deleted when lists shrink so obsolete widgets
do not retain scroll space or callbacks.

## Verification status

Automated checks cover individual duplicates, scan order, flags, Unicode/markup
escaping, separate selected/combat targets, ambiguous evidence, retained kills,
stale double clicks, command-input isolation, readiness, capture limits, settings,
fonts, and teardown. `tests/native_mobs.lua` is restricted to the disconnected
AardwolfToolboxSettingsTest profile and intercepts all command dispatch.

Version 0.18.8 uses local Lua/package tests only. The updated scan inset has not
been installed, rendered, or exercised against live server output; Mudlet was not
controlled, as requested.

Earlier native replay verified the individual card layout and combat/kill presentation.
Final mouse-gesture acceptance and installation are pending after macOS locked
during testing. The previous live informational scan verified the tagged format
with six occupants, including three identical frog names. Live death/damage
indicators remain unverified; no combat was initiated for testing.

## Sources

- [GMCP room identity and current opponent](https://www.aardwolf.com/wiki/index.php/Clients/GMCP)
- [Scan here and visibility](https://www.aardwolf.com/wiki/index.php/Help/NewGuide-Explore)
- [Scan tags announcement](https://www.aardwolf.com/blog/2010/05/13/necromancer-guild-quest-astral-travels-quest-updates/)
- [Original scan-client header and row grammar](https://www.mushclient.com/forum/threads/9783.html)
- [Damage modes](https://www.aardwolf.com/wiki/index.php/Help/Damage)
- [Damage verbs](https://www.aardwolf.com/wiki/index.php/Help/DamageVerbs)

- [Aardwolf ranged target behavior](https://www.aardwolf.com/wiki/index.php/Help/Target)
