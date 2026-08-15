# Aardwolf Map help

Use `aard map import` to merge the bundled map into the current Mudlet profile. The map is imported in small timer batches so the client stays responsive. `aard map import cancel` preserves work already completed; run the import command again to resume. `aard map status` shows current progress.

The importer is intentionally merge-safe: it never clears a map and will skip a source hash owned by another package or user data. Original Aardwolf vnums are stored as room user data while Mudlet assigns compact room IDs.

Each import registers the terrain palette stored in `Aardwolf.db` as namespaced Mudlet custom environments, then applies those environments to new and existing package-owned rooms. Running `aard map import` again repairs missing terrain colors without rewriting exits after the source snapshot has completed.

Locations are centered only after an imported room receives a valid `gmcp.room.info.num` event. The package never sends commands or changes map data from GMCP.

Coordinates are a deterministic provisional layout, not authoritative geography. This package does not include mapper editing, portals, search, or synchronization features from the MUSHclient collection.
