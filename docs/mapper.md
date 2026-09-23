# GMCP auto-mapper contract

`aardwolf-vibe` listens to `gmcp.room.info` and treats each accepted packet as a
fresh snapshot of the current room's six standard exits. Aardwolf does not put
custom exits in this payload. The event callback reads the current global GMCP
table; callback arguments are not treated as payload data.

Aardwolf ANSI CSI formatting in `room.info.name` is removed before the visible
room name is validated and stored. Any remaining control character still
rejects the packet. This allows names such as the colorized `The Meadow of
Portals` value to update and center the native mapper on `room.info.num`.

Movement is confirmed only when the validated `room.info.num` changes. A fresh
packet with the same room number is treated as a stationary room refresh: its
metadata and exits can still be reconciled, but it does not advance or replace
the movement origin used to place the next room. Consequently, a failed `n`,
`e`, `s`, `w`, `u`, or `d` attempt that leaves the character in the same room
cannot be counted as an extra movement. Session boundaries clear the origin.
For a cardinal transition, the new room number must also exactly match the
destination number reported for one unique `n`, `e`, `s`, `w`, `u`, or `d`
exit in that origin snapshot. A changed room number with no such match is still
accepted as the current room, but is placed as an unanchored or special
transition; the mapper never guesses a cardinal direction from command text.
When the immediately preceding outbound command is not one of the six short or
long cardinal commands, that observed transition is also stored from the prior
room with `addSpecialExit(source, destination, command)`. A same-room refresh,
another outbound command, disconnection, reconnection, disabled GMCP, or mapper
restart invalidates the pending command before it can be attributed to a later
movement.
When the destination snapshot also maps the opposite direction back to the
origin room number, the placement is marked `gmcp-reciprocal`. For example,
`100.s = 101` together with `101.n = 100` confirms that room 100 is north of
room 101, but the rooms may have unused grid cells between them. A one-way GMCP
exit remains a directed exit and its initial placeholder remains provisional;
the mapper does not invent the missing return exit.

The graphical mapper appears in the right workspace on a new profile. Profiles
using standalone docks continue to call Mudlet's `openMapWidget()` after load
and package installation. Switching the workspace off opens the native map
dock. These presentation changes do not replace or clear map data.

## Identity and ownership

The positive integer `room.info.num` is the native Mudlet room ID. Known numeric
exit destinations use the same number for their placeholder room. Each owned
room also carries the hash `aardwolf-vibe:aardwolf:room:<number>`, matching
owner and server-ID metadata, and a final construction marker. Identity or
construction disagreement stops mapping rather than adopting or overwriting
the room. A coordinate that differs from the mapper's recorded placement is
instead treated as a fixed manual layout change: mapping may continue, but the
mapper does not re-adopt or automatically move that room.

Areas are named exactly from `room.info.zone`. A same-name area is reusable only
when it already carries the mapper's owner metadata. The package never renames
or takes ownership of a foreign area.

## Room search

Room search is a read-only view of the map currently loaded in Mudlet. It does
not require automatic mapping to be enabled and includes package-owned,
user-authored, and imported rooms. Queries are case-insensitive literal
substrings; punctuation is not interpreted as a Lua pattern or regular
expression.

```text
aardwolf-vibe mapper search world <room name>
aardwolf-vibe mapper search area <area name> :: <room name>
aardwolf-vibe mapper locate <room id>
```

An area query prefers a case-insensitive exact name, otherwise it must identify
one unique partial name. Ambiguous matches report sorted candidate areas. Room
results put exact names first and then sort by area, room name, and numeric room
ID. The public `mapper:searchRooms(query, areaName)` API returns the complete
sorted result set and canonical scope; console output displays at most the first
50 entries and reports truncation.

`mapper:locateRoom(roomID)` validates an existing mapped room, opens the native
mapper, and centers its view. It does not update Aardwolf Vibe's GMCP-tracked
player room, create or edit rooms, change coordinates, or invoke pathfinding or
movement. Mudlet's `centerview` function updates its native mapper marker as
part of centering the view; the next room GMCP update restores that marker to
the character's actual room.

## Map travel

Double-clicking a room in either the embedded or native graphical map starts a
route to it. Mudlet scripts calling `gotoRoom(roomID)` use the same route handler.
Navigation remains available with `aardwolf-vibe mapper off`, provided the
current connection has supplied a fresh `gmcp.room.info.num`. The displayed
map marker is not used as the route origin, so locating another room does not
change the starting point.

The handler uses Mudlet's mapped path. Consecutive north, east, south, west, up,
and down steps become Aardwolf `run` commands of at most 200 characters,
compressing repeats such as `run 3n2e`. Mapped special exits are sent as their
recorded commands between run segments. It waits for `room.info` to confirm the
destination of each segment before sending the next one. An unexpected room,
send failure, or timeout stops the remaining route and reports the reason in
the main console. Segment timeouts are 30 seconds plus 2 seconds per movement.
Other commands do not cancel travel; another map travel request during an
active route is ignored. No `stop` command is sent when a route is abandoned.

Disconnecting, reconnecting, or disabling GMCP clears the current-room snapshot
and any active route. Navigation waits for a new room packet before it can start
again. The package owns Mudlet's `doSpeedWalk` callback while active, restores
the previous callback and custom-speedwalk setting on teardown, and reports a
conflict instead of replacing another script's callback.

## Placement

For continent rooms (`coord.cont = 1`), GMCP x and inverted y are authoritative.
For other rooms, north/east/south/west preserve the source floor and remain on
the requested axis, but they do not require adjacent grid cells. North and
south share x, east and west share y, and the destination only needs to be on
the correct positive directional ray. If the nearest location is occupied, the
mapper searches farther along that ray rather than drawing an east room to the
southeast. Up and down always change z by exactly one; a collision is displaced
only in x/y on that target floor.

Before linking an existing destination, the mapper validates every known owned
cardinal edge incident to the affected provisional rooms. If the new edge
closes a loop with incompatible provisional coordinates, it searches the
existing two-cell grid for the smallest connected provisional component that
can be reflowed without moving or overlapping fixed rooms. Candidate plans are
ordered by rooms moved, total Manhattan distance, room ID, and coordinates.
The complete plan is checked before any coordinate write and each applied
coordinate and placement marker is read back.

Ordinary loop repair may move only intact placements marked `provisional`.
Established placements (including existing `gmcp-reciprocal` values) are fixed
for that repair.

A separate sparse-grid insertion applies when a destination belongs in the cell
immediately beyond a source, but that cell is occupied by an intact mapper-owned
non-continent perimeter. The destination can be a new room, a provisional room
that was displaced farther along the ray, or an intact established interior
room already overlapped by the compact perimeter. The mapper evaluates outward
shifts from 2 through 64 coordinate units in two-unit increments. For new or
provisional destinations, it starts with the blockers at the cut and includes
other eligible rooms only when a collision or incident cardinal constraint
requires them to move. Existing gaps can therefore accommodate insertion without
moving a fixed neighbor. Plans prefer fewer moved rooms, then less total
Manhattan movement, with deterministic tie-breaking.

The selected plan places a new or displaced provisional destination in the
opened cell. For an established interior destination already overlapping the
perimeter, the existing connected half-perimeter expansion is retained and the
destination stays put. All candidates are validated before coordinate writes;
room coordinates and placement markers are read back after application. Plans
cannot overlap rooms or violate known incident cardinal edges. Existing
placement authorities are preserved during expansion.

New non-continent cardinal placeholders forced beyond the adjacent cell record
their source and direction in `aardwolf-vibe:displaced-from` and
`aardwolf-vibe:displaced-direction`. These fields survive package reloads and
allow retries when either the source or destination receives fresh room
information, even if the adjacent cell has since become vacant. Destination
retries validate the original owned exit and include the destination's fresh
topology before moving anything. Unresolved collision-displaced rooms remain
provisional even when reciprocal exits confirm movement. Successful repair
clears the fields and allows normal reciprocal establishment. Cross-area or
continent-authoritative placement also clears the obsolete displacement record.

A long edge alone does not create displacement metadata. Intentional sparse gaps
remain valid and do not trigger compaction of established destinations. Older
provisional destinations retain the existing occupied-cut insertion behavior.

### Sideways row and column repair

A cardinal connection must also have a clear connector: an unrelated room on
the same area and floor cannot occupy a point strictly between its endpoints.
The mapper checks the complete segment, including rooms on non-grid coordinates,
rather than only checking whether the destination cell is vacant.

If a known north/south edge is diagonal or obstructed, the mapper evaluates
sideways translations of the affected aligned north/south chain. East/west chains
are handled symmetrically with vertical translations. It checks both sides of
a misaligned boundary and shifts of 2 through 64 coordinate units, preferring
fewer moved rooms and then less movement, with deterministic ties. A candidate
must move a connected row or column of at least two rooms; this is not a general
re-layout of isolated established destinations or a whole-map migration.

Unlike ordinary provisional loop repair, this targeted operation may move intact
mapper-owned established rooms while preserving their placement authorities.
The whole aligned chain moves together. A required provisional side branch may
move with it to keep its exits valid; unrelated occupied destination cells block
the candidate. A manual, foreign, or continent room in the chain prevents its
translation. Owned links to protected endpoints remain constraints even when
those endpoints are not mapper-owned.

All affected cardinal exits must satisfy their axis and direction and have clear
connector segments. A moved room also cannot become a new obstacle on an
otherwise untouched owned connector. Room IDs, exit destinations, and floors do
not change. Plans are validated before coordinate writes and coordinates and
placement markers are read back afterward. Repairs are considered on room
updates near the affected chain and repeated packets do not repeat a successful
translation. If protected anchors or other constraints prevent a safe repair,
the server exit is retained and the layout conflict is reported instead.

Continent coordinates, rooms moved manually since their placement marker was
recorded, and foreign rooms are fixed for every repair. If no safe plan exists,
the coordinates are retained, the server-authoritative exit is still recorded,
and the mapper reports a non-fatal layout conflict. Collision-displaced fallback
placement is also reported, even when its exit still satisfies axis and direction
checks. Repeated unresolved insertion reports are deduplicated by source,
direction, and destination. Mapper status reports cumulative `reflowed` and
`layout-conflicts` counts for the current package lifetime; successful repair
does not subtract an earlier conflict from that history.

Known destinations are created as gray `?` rooms and promoted when visited.
Cross-zone promotion moves the room into the exact newly reported zone. A room
whose confirmed topology conflicts with later observations is retained and the
conflict is reported.

## Exits and terrain

Standard exits are one-way and reverse exits are never inferred. A direction
whose destination is withheld, as in a maze, becomes an exit stub. Extra keys
with numeric destinations become one-way special exits using the key literally
as the movement command for compatibility with richer room producers. Normal
Aardwolf `room.info` does not include those keys, so successfully observed
non-cardinal command transitions are retained separately and merged back into
the package-owned special-exit set on later room refreshes. Retargeting removes
only that owned command before adding its new destination. The mapper never
uses `clearSpecialExits`, never infers a reverse special exit, and preserves and
relinquishes manual or externally modified links.

The terrain catalog mirrors all 100 supplied Aardwolf entries (IDs 0 through 88
except 9, plus 100 through 111) and their ANSI color indices, including weather,
road, water, ice, structure, hell, and dead-land variants. Names are trimmed and
lowercased, so `Mudschool` maps to `mudschool`. Unrecognized or empty terrain is
stored and rendered in gray.

## Persistence and acceptance

The mapper defaults on, with the selected state stored in the data-only file
`aardwolf-vibe-data/settings.json`. Corrupt settings are preserved and disable
automatic startup. The first mutation after each activation requires a native
map backup under `aardwolf-vibe-data/backups/`.

Automated tests validate normalization, topology, ownership, terrain mapping,
settings, lifecycle contracts, and the built archive. They do not establish
live Aardwolf negotiation, native rendering, or gameplay movement.

## Refresh performance

Healthy updates validate topology and connector clearance before skipping repair
searches. An adjacent destination alone in its cell does not trigger sparse
expansion. Connector checks use sorted row/column indexes on each floor instead
of comparing every exit with every room. Candidate positions override the index
so moved rooms are still checked for new obstructions on unrelated connectors.

Room membership is enumerated once per update and limited to the current area
before ownership inspection. New rooms and area changes invalidate that list,
and it is discarded after each packet, including failures. Geometry is reused
only while coordinates remain unchanged. External edits are therefore visible
on the next packet, even if its room data is otherwise identical. No repair
search bounds, ownership checks, display updates, or packets are throttled.

Run the offline refresh benchmark with the development environment:

```sh
.venv/bin/python tools/benchmark_mapper.py
.venv/bin/python tools/benchmark_mapper.py --sides 10 --outside 10000
```

The benchmark seeds unobstructed, fully explored grids and reports median update
time over three runs plus mapper API call counts. `--source` accepts another
mapper source file for comparison; `--sides` sets grid side lengths. It measures
Lua mapping logic with the test API, not native Mudlet painting or server latency.

In the local comparison of 0.7.21 and 0.7.22, a 100-room grid dropped from about
388 ms to 7 ms per update, a 400-room grid from 5.65 seconds to 29 ms, and a
900-room grid from 28.84 seconds to 67 ms. The 100-room case with 10,000 rooms in
other areas dropped from 521 ms to 11 ms. Both versions issued one map update
and one centering call per packet. Timing varies by machine; regression tests
bound unnecessary API reads instead of imposing fragile wall-clock limits.
