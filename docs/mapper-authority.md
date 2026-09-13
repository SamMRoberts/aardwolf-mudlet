# Authoritative GMCP mapping — 0.23.0

The native Mudlet room ID equals Aardwolf's positive `room.info.num`. A reported
exit destination is a game room number, never a local allocation index or a
coordinate lookup. Current rooms and unexplored placeholders use the same rule.

## Updates and coordinates

A fresh valid packet replaces the current Toolbox-owned room's name and zone,
records its terrain/details, and reconciles the six standard exits. A changed or
removed standard exit replaces a saved manual edit when that source room is
observed again. Previously recorded incoming observations can still resolve when
a destination appears, but do not overwrite a later manual source edit without a
fresh observation of that source. Foreign room identities are not adopted.

Aardwolf's [GMCP contract](https://www.aardwolf.com/wiki/index.php/Clients/GMCP)
distinguishes continent coordinates from an interior area's world position:

- `coord.cont = 1`: X and inverted Y are authoritative native coordinates. Z is
  zero unless explicitly supplied; an occupied position does not change the
  reported coordinates or invent another floor.
- `coord.cont = 0`: X/Y describe the area's location, not unique indoor room
  positions. Preserve them as metadata and use the inferred interior map layout.
  Horizontal discovery stays on the same floor; up/down change the inferred Z.
- Missing coordinates do not erase an existing interior layout. Moving a room to
  a newly reported zone establishes layout in that zone.

GMCP supplies only n/e/s/w/u/d exits, with unknown destinations in mazes. The
mapper does not infer reverse links or overwrite unreported custom/diagonal
exits. Unknown or obstructed previews use stubs. Known destinations remain linked
by identity even when their saved drawing positions are not adjacent.

Terrain coloring remains optional. With it enabled, reported terrain overrides
saved room environment assignments; disabling it leaves colors untouched. Empty
terrain clears the recorded terrain and uses the unknown palette, while a missing
or malformed terrain field leaves the last usable terrain unchanged. User notes,
symbols other than the owned placeholder question mark, locks, custom exits, and
other annotations are not supplied by GMCP and remain intact.

## Stored data

Room user data includes:

| Key | Value |
| --- | --- |
| `AardwolfToolbox:vnum` | Authoritative game room number as a string. |
| `AardwolfToolbox:gmcp` | JSON of the latest accepted complete packet, including extra fields. |
| `AardwolfToolbox:gmcp:<field>` | Latest reported scalar field, such as `name`, `outside`, or `mapterrain`. |
| `AardwolfToolbox:coord:<field>` | Reported raw coordinate fields, without Y inversion. |
| `AardwolfToolbox:details` | Latest reported details string; an empty string clears it. |
| `AardwolfToolbox:terrain` / `zone` | Normalized terrain / reported zone. |
| `AardwolfToolbox:exit:<direction>` | Reported game destination, empty for absent/unknown destinations. |

Fields not present in a later packet are not synthesized or cleared in the
searchable metadata. Use the `gmcp` JSON snapshot to distinguish absence from a
previously reported field. Capture is bounded to 512 values, eight nested levels,
and 64 KiB of string content; invalid packets do not mutate the map.

## Legacy IDs

Mudlet does not expose in-place room renumbering. The migration uses its
[JSON map export/import APIs](https://wiki.mudlet.org/w/Manual:Mapper_Functions#saveJsonMap)
and the [Mudlet 5.0.1 room schema](https://github.com/Mudlet/Mudlet/blob/Mudlet-5.0.1/src/TRoom.cpp).
It changes only IDs and references in the exported document, retaining native
room properties, labels, custom exit geometry, locks, environments and metadata.
Room-ID cycles are remapped together; foreign inbound connections follow the
same room under its new ID without changing their commands or properties.

Before migration, the mapper verifies the owner, game number, forward/reverse
hash, construction marker, and available destination ID. Foreign collisions,
incomplete identities, or broken native exit references stop migration before
import. No unrelated room is removed. The existing binary backup is refreshed
specifically for this migration. The backup path gains `.ids-source.json` and
`.ids-game.json` files for inspection; JSON maps larger than 64 MiB are rejected.

The imported result is checked for room count, identity, names, areas,
coordinates, user data, and standard/special destinations. A failed import or
readback attempts binary restoration and stops the mapper with a diagnostic.
Native JSON migration may display Mudlet's progress dialog. Subsequent startup
finds IDs already aligned and performs no further import. Uninstall retains the
map, new IDs, metadata, and backup files.

External scripts or bookmarks that stored old native numeric room IDs need to
use the corresponding game IDs after migration. Toolbox's namespaced hashes
remain stable. Building this package does not migrate the running player profile.

## Verification boundary

The automated suite exercises packet validation, authoritative updates, game-ID
allocation, placeholders, migration chains/cycles, metadata and connection
preservation, foreign conflicts, checked writes, and failed-import restoration
through Lua/native-API contracts. No Mudlet interaction or player-profile
migration was performed for this change. Native import/export fidelity and live
GMCP acceptance require a backed-up installation and manual verification.

## Double-click to run

Version 0.23.1 installs a reversible `doSpeedWalk` adapter with Mudlet's custom
speedwalk mode. Double-clicking the native graphical map passes its destination
to the adapter, which calculates a path from fresh GMCP current-room identity.
It sends one literal command, such as `run 3n2e`, without alias expansion.
Aardwolf's [run command](https://www.aardwolf.com/wiki/index.php/Help/Run) accepts
basic directions, not a room number. No mapped path, stale identity, non-ready
state, or a route requiring a special exit produces a visible explanation and
sends nothing. Doors or other game restrictions can stop the server's run;
Toolbox does not automatically open doors, retry, or resume movement.

**Auto-mapper → Double-click map rooms to run** defaults on. It also works with
room discovery disabled, provided fresh GMCP and an existing verified map are
available. Turning it off or uninstalling restores the previous speedwalk hook
and flags while still owned. It is independent of the bottom action bar.
`AardwolfToolbox.mapTravel.runTo(nativeRoomID)` uses the same guarded path.
Native clicks and actual travel remain manual acceptance checks; automated tests
intercept outgoing commands and never move the player.
