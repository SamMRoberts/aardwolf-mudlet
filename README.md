# aardwolf-vibe

`aardwolf-vibe` is a source-controlled Mudlet package for Aardwolf on Mudlet
5.0.1. It provides a defensive GMCP auto-mapper, an in-memory character state
handler, responsive Geyser status bars, a native dockable ASCII minimap, and a
configurable GMCP chat window. It also includes session-only spell/recovery
tracking and explicitly opt-in self-spellup maintenance.

The mapper consumes `gmcp.room.info`, uses Aardwolf room numbers as native
Mudlet room IDs, names areas exactly from `room.info.zone`, colors rooms by
terrain, creates placeholders for known destinations, and represents unexpected
non-standard exit keys as Mudlet special exits. Movement is confirmed by a
change in the validated GMCP room number, so a failed direction command that
leaves the character in the same room does not advance the mapper. Exact
forward-and-return GMCP exit pairs confirm direct adjacency without causing the
mapper to invent a reverse exit.
Aardwolf color formatting embedded in GMCP room names is stripped before the
visible room name is stored, so it cannot prevent current-room synchronization.
The native graphical mapper is reopened automatically whenever the profile
launches.

Terrain names follow Aardwolf's complete terrain catalog (including roads,
weather, water, ice, hell, structures, and dead-land variants) and use the
catalog's supplied ANSI color index. Unknown terrain remains visible in gray.

The always-active character plugin consumes `char.base`, `char.vitals`,
`char.stats`, `char.maxstats`, `char.status`, and `char.worth`. It exposes
validated defensive-copy snapshots through `AardwolfVibe.plugins.character`
and raises local update events for other scripts. Character state is scoped to
the current GMCP session and is never written to disk. See
[`docs/character.md`](docs/character.md) for the API and event contract.
After an install or upgrade, the package requests a fresh character snapshot
with `protocols gmcp sendchar` after its character consumers are ready. This
install-only request is sent without local command echo.

The always-visible character strip uses that validated state to show HP, mana,
moves, level progress, the current enemy, and alignment. A three-cell status row
above the gauges shows the character's level, position, and friendly state name.
The gauges occupy one row on normal windows and reflow into two rows below 840
pixels while the status row remains horizontal. See
[`docs/character-bars.md`](docs/character-bars.md) for its rendering and layout
contract.

The always-active ASCII minimap enables Aardwolf's master tag output and then
requests the `MAP` tag with `tags on` followed by `tags map on`. It captures
complete `<MAPSTART>` / `<MAPEND>` frames and displays
them in a movable, resizable native Mudlet dock window. The map canvas preserves
literal spacing and server colors while suppressing the duplicate frame in the
main console. It starts in the right dock and Mudlet restores the user's later
floating, docked, resized, or tabbed layout. See
[`docs/ascii-map.md`](docs/ascii-map.md) for its API and capture contract.
The minimap is also reopened automatically on every profile launch; hiding it
remains effective for the rest of the current session.

The always-active chat plugin consumes `gmcp.comm.channel` into a movable,
resizable native window that starts docked across the top. Its initial All,
Tell, Group, Clan, Newbie, and Gossip tabs can be renamed, reordered, removed,
or supplemented through the built-in visual editor. Aardwolf channel text is
requested over GMCP only; `say` and `mobsay` remain mirrored into the gameplay
console. See [`docs/chat.md`](docs/chat.md) for routing, persistence, and API
details. Each GMCP session advertises Aardwolf Vibe's `char`, `comm`, and
`room` modules through Aardwolf's accepted lowercase `core.supports.set`
command, explicitly disables GMCP debugging, and only then requests GMCP-only
channel output.

The spellup tracker enables only Aardwolf's spell tag option, synchronizes
bounded `slist` snapshots, and presents confirmed effects and recoveries in an
“Aardwolf Spellups” window. Its first successful mount creates a distinct
right-side dock; Mudlet restores the user's later placement without reusing the
map or chat window. Automatic maintenance defaults off.
When enabled it submits only `spellup learned retry`, only while fresh GMCP
reports an active, standing character, and never constructs individual cast
commands. See [`docs/spellups.md`](docs/spellups.md) for readiness gates,
failure handling, public APIs, and acceptance boundaries.

## Commands

```text
aardwolf-vibe mapper on
aardwolf-vibe mapper off
aardwolf-vibe mapper status
aardwolf-vibe minimap
aardwolf-vibe minimap show
aardwolf-vibe minimap hide
aardwolf-vibe minimap status
aardwolf-vibe chat
aardwolf-vibe chat show
aardwolf-vibe chat hide
aardwolf-vibe chat status
aardwolf-vibe chat config
aardwolf-vibe spellups
aardwolf-vibe spellups show
aardwolf-vibe spellups hide
aardwolf-vibe spellups status
aardwolf-vibe spellups sync
aardwolf-vibe spellups on
aardwolf-vibe spellups off
aardwolf-vibe spellups now
```

Mapping is enabled on first install. The selected state persists in
`aardwolf-vibe-data/settings.json` under the active profile. Before the first
map mutation of each activation, the package saves a timestamped native map
backup under `aardwolf-vibe-data/backups/`.
The same settings file stores the automatic-spellup opt-in; its default is
`false`. Mudlet owns spellup-window geometry and docking through its saved
layout rather than package JSON.

The mapper owns only rooms, areas, palette entries, and exits carrying its
metadata. A numeric room collision, a same-name foreign area, or a known
competing mapper stops mapping instead of adopting or overwriting existing map
data. Uninstalling the package leaves mapped data and backups intact.

## Build and test

The project uses Muddler 1.1.0 and Lua 5.1-compatible source.

```sh
python3 tools/check.py --bootstrap
```

The command builds and verifies `build/aardwolf-vibe.mpackage`, inspects its
container and XML, checks Lua 5.1 syntax, and runs the pure-Lua contract tests.
It does not install into a live profile or establish connected Aardwolf GMCP
delivery.
