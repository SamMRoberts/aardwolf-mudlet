# Aardwolf Map help

Use `aard map import` to merge the bundled map into the current Mudlet profile. The map is imported in small timer batches so the client stays responsive. `aard map import cancel` preserves work already completed; run the import command again to resume. `aard map status` shows current progress. Use `aard map palette source`, `aard map palette obsidian`, or `aard map palette high-contrast` to change the persistent terrain palette.

When import finishes, the package centers the mapper using the current validated `gmcp.room.info.num` value and signals the Aardwolf interface to reveal the embedded map. This also occurs on package reload when GMCP room data is already available.

The importer is intentionally merge-safe: it never clears a map and will skip a source hash owned by another package or user data. Original Aardwolf vnums are stored as room user data while Mudlet assigns compact room IDs.

Terrain UIDs receive persistent, collision-free custom environment IDs outside Mudlet's reserved ranges. Existing custom colors and every room's current environment are checked before allocation and again before recoloring. Foreign rooms are never recolored or migrated; only rooms marked with this package's owner value can move from a legacy or newly-colliding environment ID. Running `aard map import` again repairs stale assignments on package-owned rooms without rewriting exits after the source snapshot has completed.

`aardwolf_map.integration.snapshot()` provides phase, progress, source hash, owned-room count, current and resolved room identifiers, palette, freshness, and errors. `aardwolf-map::status-changed` is raised whenever those operational states materially change. A reload or exit during import removes the active timer and reports `interrupted`, ready for a safe resume.

Locations are centered only after an imported room receives a valid `gmcp.room.info.num` event. The package never sends commands or changes map data from GMCP.

Coordinates are a deterministic provisional layout, not authoritative geography. This package does not include mapper editing, portals, search, or synchronization features from the MUSHclient collection.
