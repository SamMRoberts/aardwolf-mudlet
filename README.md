# aardwolf-vibe

`aardwolf-vibe` is a source-controlled Mudlet package for Aardwolf on Mudlet
5.0.1. It provides a defensive GMCP auto-mapper, an in-memory character state
handler, a top character status bay with bottom vitals, a docked workspace
with an ASCII minimap and graphical map, and a transient tagged-help popup, plus a configurable
GMCP chat window with configurable transcript font and size. It also includes
session-only spell/recovery tracking and explicitly opt-in self-spellup maintenance.

The mapper consumes `gmcp.room.info`, uses Aardwolf room numbers as native
Mudlet room IDs, names areas exactly from `room.info.zone`, colors rooms by
terrain, creates placeholders for known destinations, and represents unexpected
non-standard exit keys as Mudlet special exits. Because Aardwolf omits custom
exits from `room.info`, the mapper also correlates a non-cardinal outbound
command with the next validated room change and records the observed one-way
transition as a Mudlet special exit. Learned exits survive ordinary GMCP room
refreshes, while manual or externally modified special exits are preserved.
Movement is confirmed by a change in the validated GMCP room number, so a
failed direction command that leaves the character in the same room does not
advance the mapper. Exact
forward-and-return GMCP exit pairs confirm bidirectional topology without
requiring adjacent grid cells or causing the mapper to invent a reverse exit.
Cardinal exits may span intentional gaps. When a new edge closes a loop, the
mapper may reflow only the smallest affected component whose placement is still
mapper-owned and provisional; established, continent, manual, and foreign
coordinates remain fixed. When an interior cardinal edge instead meets an
intact mapper-owned non-continent perimeter room in the immediately adjacent
cell, the mapper evaluates outward shifts of one through 32 grid steps. For
new or provisional destinations, only rooms required by collisions or cardinal
constraints join the expansion; existing gaps can keep fixed neighbors in place.
Plans prefer fewer moved rooms, then less total movement. Established interior
rooms that already overlap the compact perimeter retain the connected
half-perimeter expansion behavior. Continent, manual, and foreign coordinates
remain untouched.

New placeholders forced farther away by a collision retain persistent
displacement metadata. The mapper retries insertion when the source or
destination is refreshed, keeping unresolved placements provisional even after
a reciprocal visit. Successful repair clears that metadata and allows normal
establishment. Unresolved insertion is reported as a non-fatal layout conflict;
intentional long gaps are not compacted automatically.

When a north/south connection is diagonal or passes through an unrelated room,
the mapper can shift the connected north/south column sideways to open a gap.
East/west rows receive the equivalent vertical repair. This targeted repair can
move intact mapper-owned established rooms and carry required provisional side
exits; manual, foreign, and continent placements remain fixed. Every affected
exit must remain correctly aligned and clear of intervening rooms, and moved
rooms must not obstruct other connectors. If no safe plan exists, the original
layout and exit destinations are retained and a conflict is reported.

Refresh checks use row/column indexes and skip unnecessary repair searches on
healthy layouts. Map membership is shared only within an update, so later
packets still detect manual edits. The offline refresh benchmark and its limits
are described in [the mapper contract](docs/mapper.md#refresh-performance).

Aardwolf color formatting embedded in GMCP room names is stripped before the
visible room name is stored, so it cannot prevent current-room synchronization.
The native graphical mapper is reopened automatically whenever the profile
launches.

Terrain names follow Aardwolf's complete terrain catalog (including roads,
weather, water, ice, hell, structures, and dead-land variants) and use the
catalog's supplied ANSI color index. Unknown terrain remains visible in gray.

Mapped rooms can be searched by a case-insensitive literal name fragment across
the world or within one explicitly named area. Results include room ID, room
name, and area; a separate locate command opens and centers the native mapper
without sending movement, changing Aardwolf Vibe's GMCP-tracked current room,
or modifying map data.

The always-active character plugin consumes `char.base`, `char.vitals`,
`char.stats`, `char.maxstats`, `char.status`, and `char.worth`. It exposes
validated defensive-copy snapshots through `AardwolfVibe.plugins.character`
and raises local update events for other scripts. Character state is scoped to
the current GMCP session and is never written to disk. See
[`docs/character.md`](docs/character.md) for the API and event contract.
After an install or upgrade, the package requests a fresh character snapshot
with `protocols gmcp sendchar` after its character consumers are ready. This
install-only request is sent without local command echo. During replacement,
the new producer starts empty, so the authenticated-state gate also accepts
Mudlet's current cached `gmcp.char.status` while the connection remains active.

The always-active character status bay renders the character name, current and
total levels, remorts, tier, and the six primary attributes as one compact row
across the top of the main Mudlet window. It switches to smaller text at narrow
widths without wrapping. HP, mana, moves, TNL, enemy, and alignment gauges
remain in a responsive strip across the bottom. The bay opens visibly on each
profile launch; hiding it releases the top space for the current session and
leaves the bottom gauges visible. See
[`docs/character-window.md`](docs/character-window.md) for its rendering,
layout, and lifecycle contract.

The default layout on a new profile keeps the command queue in a narrow left
dock and the game console in the center. A right workspace places Spellups and
the ASCII minimap side by side at the top, the graphical map in the middle,
and Chat below. Saved layouts in existing profiles remain in effect. See
[`docs/workspace.md`](docs/workspace.md) for layout controls and persistence.

The always-active ASCII minimap enables Aardwolf's master tag output and then
requests the `MAP` tag with `tags on` followed by `tags map on`. It captures
complete `<MAPSTART>` / `<MAPEND>` frames and displays
them in the workspace or its standalone Mudlet dock window. The map canvas preserves
literal spacing and server colors while suppressing the duplicate frame in the
main console. Mudlet restores the player's standalone window layout. See
[`docs/ascii-map.md`](docs/ascii-map.md) for its API and capture contract.
In standalone mode the minimap reopens on each profile launch. Workspace mode
restores the player's saved visibility.

The always-active help plugin queues Aardwolf's `HELPS` tags after installation
and on every connection, then sends `tags HELPS on` only after fresh character
status confirms that the session can accept game commands. It never submits the
tag command at the username or password prompt. Ordinary help and `help search`
responses are captured between their server-owned outer tags,
removed from the main console, and displayed with their original colors and
spacing in a transient “Aardwolf Help” window. Each completed response replaces
the previous one and opens the window; its floating or docked layout remains
under Mudlet's window-layout ownership. Its first creation is a 700×460 floating
window; subsequent launches restore the placement chosen by the user. Incomplete
or malformed responses leave
the previous document intact and stop capture after a bounded timeout. See
[`docs/help-window.md`](docs/help-window.md) for its API, limits, and acceptance
boundary.

The always-active chat plugin consumes `gmcp.comm.channel` into the workspace
or its movable standalone window. Its initial All,
Tell, Group, Clan, Newbie, and Gossip tabs can be renamed, reordered, removed,
or supplemented through the built-in visual editor. Aardwolf channel text is
requested over GMCP only; `say` and `mobsay` remain mirrored into the gameplay
console. See [`docs/chat.md`](docs/chat.md) for routing, persistence, and API
details. Each GMCP session advertises Aardwolf Vibe's `char`, `comm`, and
`room` modules through Aardwolf's accepted lowercase `core.supports.set`
command, explicitly disables GMCP debugging, and only then requests GMCP-only
channel output.

The always-active command queue window starts docked on the left and lists
commands sent to Aardwolf by the command line or scripts. Once authenticated,
the package sends `config echocommands on`. Each `You entered: <command>` server
echo removes the oldest matching pending command, ignoring surrounding spaces
and tabs. It also clears every entry before that match, since those commands
were sent earlier. The package hides all `You entered: ` server echo lines from
the main console, including unmatched echoes. Hiding the window does not pause
tracking; pending commands clear on disconnect. See
[`docs/command-queue.md`](docs/command-queue.md) for the matching and lifecycle
contract.

The spellup tracker enables only Aardwolf's spell tag option, synchronizes
bounded `slist` snapshots, and presents active effects, tracked beneficial
expirations, and recoveries in responsive tables in an “Aardwolf
Spellups” window. Full synchronization hydrates effects and recoveries that
were already active before a package reload, before automation can submit its
first batch. Aardwolf-classified bad effects remain visible while active,
but are excluded from expired-effect and automatic batch-completion tracking so
mob debuffs cannot hold a spellup batch open. Remaining time changes from green
to dark yellow to red as expiry approaches. Its standalone mount creates
a distinct right-side dock; Mudlet restores the player's later placement. Its scroll area starts at the top, retains the user's
position across refreshes, and does not use Mudlet's split console scrollback.
Spell machine tags are hidden by default and can be made visible without
disabling their parsing. A compact header shows only the current automation
status, while a small vertical-ellipsis menu provides Sync, Spellup now,
automatic, and spell-tag visibility actions without consuming table space.
Automatic maintenance defaults off.
When enabled it submits only `spellup learned`, only while fresh GMCP
reports an active, standing character, and never constructs individual cast
commands. While active effects exist, the spell tracker owns one one-second
local heartbeat and reconciles their wall-clock deadlines on every wake and
snapshot read. Due beneficial effects move into Expired Effects and emit the
event that queues the server-owned batch; due bad effects are discarded. This
includes granted, clan, and racial abilities that Aardwolf queues while
reporting 0% or 1% practice. After observed queue output becomes quiet for two
seconds, an affected/recovery snapshot confirms the batch when the final
spellup-end tag or effect delta is absent. Because Aardwolf prints queue entries
before their commands finish executing, each later apply/failure tag rearms one
final quiet confirmation pass. This is event-driven rather than continuous
polling, and uncertain confirmation never submits a duplicate batch. When an
ability appears in both Aardwolf's spellup and bad filters, the spellup
classification wins; genuinely bad non-spellup effects remain excluded.
See [`docs/spellups.md`](docs/spellups.md) for readiness gates, failure handling,
public APIs, and acceptance boundaries.

## Commands

```text
aardwolf-vibe mapper on
aardwolf-vibe mapper off
aardwolf-vibe mapper status
aardwolf-vibe mapper search world <room name>
aardwolf-vibe mapper search area <area name> :: <room name>
aardwolf-vibe mapper locate <room id>
aardwolf-vibe minimap
aardwolf-vibe minimap show
aardwolf-vibe minimap hide
aardwolf-vibe minimap status
aardwolf-vibe chat
aardwolf-vibe chat show
aardwolf-vibe chat hide
aardwolf-vibe chat status
aardwolf-vibe chat config
aardwolf-vibe queue
aardwolf-vibe queue show
aardwolf-vibe queue hide
aardwolf-vibe queue status
aardwolf-vibe help
aardwolf-vibe help show
aardwolf-vibe help hide
aardwolf-vibe help status
aardwolf-vibe stats
aardwolf-vibe stats show
aardwolf-vibe stats hide
aardwolf-vibe stats status
aardwolf-vibe spellups
aardwolf-vibe spellups show
aardwolf-vibe spellups hide
aardwolf-vibe spellups status
aardwolf-vibe spellups sync
aardwolf-vibe spellups on
aardwolf-vibe spellups off
aardwolf-vibe spellups now
aardwolf-vibe spellups tags hide
aardwolf-vibe spellups tags show
aardwolf-vibe spellups tags status
```

Mapping is enabled on first install. The selected state persists in
`aardwolf-vibe-data/settings.json` under the active profile. Before the first
map mutation of each activation, the package saves a timestamped native map
backup under `aardwolf-vibe-data/backups/`.
The same settings file stores the automatic-spellup opt-in and spell-tag
visibility; automatic casting defaults to `false` and tag hiding defaults to
`true`. Mudlet owns spellup-window geometry and docking through its saved layout
rather than package JSON.

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
