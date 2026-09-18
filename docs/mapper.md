# GMCP auto-mapper contract

`aardwolf-vibe` listens to `gmcp.room.info` and treats each accepted packet as a
fresh snapshot of the current room's six standard exits and any extra exit keys.
The event callback reads the current global GMCP table; callback arguments are
not treated as payload data.

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
When the destination snapshot also maps the opposite direction back to the
origin room number, the placement is marked `gmcp-reciprocal`. For example,
`100.s = 101` together with `101.n = 100` confirms that room 100 is north of
room 101, but the rooms may have unused grid cells between them. A one-way GMCP
exit remains a directed exit and its initial placeholder remains provisional;
the mapper does not invent the missing return exit.

The package lifecycle calls Mudlet's `openMapWidget()` after profile load and
package installation so the native graphical mapper is visible. This does not
replace or clear map data and does not change the mapper's saved layout.

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
room already overlapped by the compact perimeter. The mapper shifts the
connected portion of the perimeter on the far side of that cut outward by one
two-cell grid step. It then places a new or displaced provisional destination
in the opened cell, or leaves an established destination there while separating
the perimeter from it. The plan includes rooms required by owned topology and
occupancy so it cannot split a row or column, collapse rooms onto one another,
or violate any known incident cardinal edge. Existing placement authorities are
preserved.

Continent coordinates, rooms moved manually since their placement marker was
recorded, and foreign rooms are fixed for every repair. If no safe plan exists,
the coordinates are retained, the server-authoritative exit is still recorded,
and the mapper reports a non-fatal layout conflict. Mapper status reports
cumulative `reflowed` and `layout-conflicts` counts for the current package
lifetime.

Known destinations are created as gray `?` rooms and promoted when visited.
Cross-zone promotion moves the room into the exact newly reported zone. A room
whose confirmed topology conflicts with later observations is retained and the
conflict is reported.

## Exits and terrain

Standard exits are one-way and reverse exits are never inferred. A direction
whose destination is withheld, as in a maze, becomes an exit stub. Extra keys
with numeric destinations become one-way special exits using the key literally
as the movement command. Only unchanged mapper-owned links are reconciled;
manual changes are preserved and relinquished by the package.

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
