# Room mobs — 0.18.1

The **Room mobs** pane stays on the left beside the console, independently of the
right dashboard and its tabs. It reserves console space and uses shared Appearance
fonts. Its list scrolls without reducing the font size. It remains visible while
disconnected, displaying a waiting state. Disable it explicitly in
`aardwolf-config → Room mobs` to reclaim the space.

This is a room-visit tracker of what the game reveals, not a way to see hidden
creatures. It does not attack, target, cast, move, open doors, or execute names.

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

**Double-click** a living mob to select it as the local Toolbox target. The footer
shows the selection; **Clear** removes it. This preserves command-input text and
sends no gameplay command. Selection is separate from **Fighting**, which comes
from GMCP. Aardwolf's ranged `target` command does not normally work in the same
room, so the pane does not use that command or start an attack. Selection requires
a connected, command-ready or fighting character and a complete current-room
scan. A refreshed scan, room change, disconnect, or ambiguous duplicate death
clears selection. A list change between the two clicks cancels selection.

Name-only combat reports cannot distinguish identical mobs. Such rows show
**Possible opponent** or **Possible attacker** rather than asserting that all are
fighting. A confirmed duplicate death marks one separate row **Killed · duplicate
identity unknown**; it does not claim which physical instance died. A GMCP
opponent absent from the scan is explicitly unclassified and cannot be selected,
since GMCP does not establish that it is a mob rather than a player.

The roster uses a count summary, readable names, restrained status-colored card
edges, optional flags, a selected-row highlight, and a fixed selection footer.
Confirmed kills remain separate entries. Color-independent text labels explain
each state; Refresh and Settings stay accessible above the scrolling list.

The pane refreshes on room entry and after combat by default. **Refresh** requests
one new snapshot. Optional periodic refresh is off by default; set an interval
of 10–300 seconds to enable it. Requests wait for a fresh room identity, standing
command-ready state, and the shared information-query coordinator. No request is
sent during combat, sleep, AFK, running, or paging/editing. A failed scan pauses
periodic refresh until manual Refresh or the next room/combat transition.

Automatic setup sends `tags scan on` once per connection; snapshots use exactly
`scan here`. Disable setup if another component manages tags. Tags are left enabled
on teardown so other consumers keep their access. The feature does not change
spam/damage modes, paging preferences, or detection abilities.

Colors, symbols, flags/auras, target/attacker indicators, retained kills, missing
mobs, pane width, and evidence lifetime are configurable. Optional attacker
background pulsing runs at one change per second and is **off by default**.
Text labels remain available with colors and symbols disabled. Color preferences
accept `#RRGGBB`; use Appearance for typography.

## Data and lifecycle boundaries

Only a complete Toolbox-requested tagged scan replaces the list. Requests time out
after ten seconds; scans are limited to 1,024 lines, 256 KiB, and 512 occupants.
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
observation time, scan revision, and individual rows. Each row has a local ID,
name, flags, ordinal among identical living names, living/killed/missing state,
selection, target/health, and recent attacker evidence. `possibleTarget` and
`possibleAttacker` distinguish ambiguous duplicate matches. Updates raise the
profile-local `AardwolfToolbox.mobs.updated` event after incoming processing.
`mobs.refresh()` requests a guarded refresh. `mobs.select(id, revision)` selects
a current living observation, `mobs.selected()` returns a defensive copy of the
selection, and `mobs.clearSelection()` clears it. No selection API sends commands. Start, configure, stop, and destroy
are repeatable and remove owned handlers, timers, widgets, and border claims.

## Verification status

Automated checks cover individual duplicates, scan order, flags, Unicode/markup
escaping, separate selected/combat targets, ambiguous evidence, retained kills,
stale double clicks, command-input isolation, readiness, capture limits, settings,
fonts, and teardown. `tests/native_mobs.lua` is restricted to the disconnected
AardwolfToolboxSettingsTest profile and intercepts all command dispatch.

Native replay verified the individual card layout and combat/kill presentation.
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
