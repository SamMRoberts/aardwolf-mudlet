# GMCP auto-mapper contract

`aardwolf-vibe` listens to `gmcp.room.info` and treats each accepted packet as a
fresh snapshot of the current room's six standard exits and any extra exit keys.
The event callback reads the current global GMCP table; callback arguments are
not treated as payload data.

## Identity and ownership

The positive integer `room.info.num` is the native Mudlet room ID. Known numeric
exit destinations use the same number for their placeholder room. Each owned
room also carries the hash `aardwolf-vibe:aardwolf:room:<number>`, matching
owner and server-ID metadata, and a final construction marker. Any disagreement
stops mapping rather than adopting or overwriting the room.

Areas are named exactly from `room.info.zone`. A same-name area is reusable only
when it already carries the mapper's owner metadata. The package never renames
or takes ownership of a foreign area.

## Placement

For continent rooms (`coord.cont = 1`), GMCP x and inverted y are authoritative.
For other rooms, north/east/south/west preserve the source floor and remain on
the requested axis. If the nearest location is occupied, the mapper searches
farther along that axis rather than drawing an east room to the southeast. Up
and down always change z by exactly one; a collision is displaced only in x/y
on that target floor.

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
