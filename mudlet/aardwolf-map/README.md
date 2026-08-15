# Aardwolf Map for Mudlet

This standalone Mudlet 4.14+ package imports the bundled, generated snapshot of `Aardwolf.db` v11 into Mudlet's native mapper. It is separate from `aardwolf-mushclient-collection` and deliberately covers only map import plus live location centering.

After an import completes, the package re-resolves the current `gmcp.room.info` room, centers Mudlet's mapper, and notifies the optional Aardwolf interface to reveal its embedded mapper immediately. Reloading the package while already connected also centers from Mudlet's current GMCP state rather than waiting for the player to move.

## Commands

- `aard map import` starts or safely resumes a bounded-batch import.
- `aard map import cancel` stops after the current batch. Imported package-owned rooms remain in place, and a later import safely reuses them.
- `aard map status` reports the active phase and progress counters.

Import never clears a map. A source vnum is mapped through the stable room hash `aardwolf-map:vnum:<vnum>`, while Mudlet receives a compact `createRoomID()` identifier. If that hash already belongs to a non-package room, the room and any dependent exits are skipped and counted; the package never overwrites it. Repeated imports reuse package-owned rooms. Once a source snapshot has completed, a repeat import does not rewrite its exits, preserving later mapper edits.

The importer creates namespaced area labels of the form `Aardwolf (<source-id>): <name>`. It records source vnums, terrain, details, source coordinates, area metadata, and snapshot metadata as `aardwolf_map.*` map/area/room user data. Standard `n`, `s`, `e`, `w`, `u`, and `d` exits use native mapper exits. Terrain values use the custom environment range beginning at 1000. On every package/profile load and before room batches run, the package converts the source mapper's ANSI terrain indices to their exact RGB equivalents and registers all referenced colors with Mudlet. Repeating the import repairs terrain assignments only on package-owned rooms.

## Layout and live location

The resource includes a deterministic provisional layout. It preserves usable source coordinates, then traverses same-area exits in stable order and resolves collisions with a deterministic spiral. Cross-area and conflicting directional edges are retained even where they cannot all be represented geometrically. These positions are not geographically authoritative.

After installation, the package registers a namespaced `gmcp.room.info` event handler. When Aardwolf supplies a valid `gmcp.room.info.num` that belongs to an imported room, the handler calls `centerview`. It does not create rooms, modify maps, or send game commands. GMCP room information must therefore be enabled and arriving from the game for live centering to occur.

This package does not reproduce the MUSHclient mapper's editing workflow, portal support, search UI, or automatic synchronization behavior.

## Installation and distributable artifacts

Import [the native XML export](dist/aardwolf-map.xml) in Mudlet when you only need the package objects. The map JSON resource is not embedded in a raw Mudlet XML export, so a functional installation should import [the native package](dist/aardwolf-map.mpackage), which includes the declared JSON asset.

The all-in-one `mudlet/dist/aardwolf-mudlet-suite.mpackage` also includes this
asset. The importer checks its standalone package directory first, then the
suite package directory. Do not install both archives into the same profile.

Both files are generated, never hand-edited. Regenerate them with:

```sh
python3 plugin/aardwolf-mudlet-dev/scripts/build_mudlet_package.py mudlet/aardwolf-map --backend native
cp mudlet/aardwolf-map/build/aardwolf-map.xml mudlet/aardwolf-map/dist/aardwolf-map.xml
cp mudlet/aardwolf-map/build/aardwolf-map.mpackage mudlet/aardwolf-map/dist/aardwolf-map.mpackage
```

## Data provenance

`src/resources/aardwolf-map-v11.json` is a deterministic, transformed export of the supplied `Aardwolf.db` v11 snapshot; the source database itself is not packaged. [The inventory report](reports/aardwolf-db-inventory.md) records the source SHA-256, validated schema, reference checks, counts, and omitted tables. Permission to redistribute this generated map-data resource has been confirmed for this package. No upstream license is inferred or claimed.

The `.mpackage` contains the declared JSON asset and Mudlet installs it beneath its package directory, where the importer reads it.
