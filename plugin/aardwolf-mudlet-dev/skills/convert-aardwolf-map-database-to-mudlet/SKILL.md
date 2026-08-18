---
name: convert-aardwolf-map-database-to-mudlet
description: Convert an Aardwolf/MUSHclient Aardwolf.db SQLite map database at schema v11 into a source-controlled, merge-safe Mudlet 4.14+ map package project. Use when importing or updating an Aardwolf.db map without replacing a profile's existing Mudlet map.
---

# Convert Aardwolf Map Database To Mudlet

Use this only for an Aardwolf/MUSHclient `Aardwolf.db` whose SQLite `user_version` is exactly 11. It produces a package resource and importer; it does not produce a Mudlet map backup, MMP document, or a profile map load.

Read [the database contract](references/aardwolf-map-database-v11.md) and [the Mudlet importer contract](references/mudlet-map-import-contract.md) before creating or changing the target project.

## Workflow

1. Confirm the source database path, destination directory, and package owner. For this repository the supplied source is `.resources/Aardwolf.db`. Default to package identity `aardwolf-map` and Lua namespace `aardwolf_map`. Stop if that identity collides with an installed or source-controlled package, if the destination is not new or explicitly user-approved, or if rights to redistribute the database-derived data are unclear. Do not copy the database into the package.

2. Create or update the approved Mudlet 4.14+ source project with the shared `create-aardwolf-mudlet-package` workflow. Keep the normal source tree, package metadata, native XML, and `.mpackage` reproducible. The generated map JSON is a resource, not a native map file: never use `loadMap`, `clearMap`, `closeMap`, or profile-map replacement as an import implementation.

3. Generate the resource and immutable inventory from the database. The converter opens the SQLite database read-only and rejects symlinks, unknown schema versions, malformed IDs or coordinates, invalid references, and unsupported directions. Keep all outputs inside the approved project and use its atomic writes.

   ```sh
   python3 ../../scripts/convert_aardwolf_map_database.py \
     --input INPUT_DATABASE \
     --output PROJECT/src/resources/aardwolf-map-v11.json \
     --report-json PROJECT/reports/aardwolf-db-inventory.json \
     --report-markdown PROJECT/reports/aardwolf-db-inventory.md
   ```

4. Treat `src/resources/aardwolf-map-v11.json` as the canonical schema-v1 source. Retain its `source`, `areas`, `environments`, `rooms`, `exits`, `layout`, and `counts` fields without hand edits. Keep the source SHA-256 with the generated JSON and Markdown inventories; a changed database must create a new snapshot rather than silently mutating provenance.

5. Implement the importer in the package's namespaced Lua modules. Import in bounded batches, exposing a resume cursor and cancellation flag. Allocate a compact Mudlet room ID with `createRoomID()` only when necessary and bind it to the stable hash `aardwolf-map:vnum:<vnum>` through the supported hash API. Use only namespaced room, area, and map user-data keys to record ownership and source snapshot state, such as `aardwolf_map.owner = "Aardwolf.db/v11"`.

6. Preserve ownership boundaries. Reuse rooms demonstrably owned by this package. If an existing room/hash/area/environment belongs to anything else or lacks this ownership marker, leave it untouched, record a collision, and do not add dependent exits through it. Never alter foreign rooms, exits, areas, user data, or environment colors. Allocate package-owned areas and environments deterministically, giving collision-created environments a stable package-owned alternative name instead of changing an existing color.

7. Make reruns safe. A matching source SHA-256 must be idempotent and preserve user-edited exits on package-owned rooms. When the source SHA-256 changes, refresh only package-owned source fields, retain user edits outside those fields, and reconcile only package-owned exits. A cancelled run must save its cursor and snapshot identity; a later resume must continue safely and a completed run must clear its transient import state. Use named event/timer/command registrations and clean them up in the package lifecycle handler.

8. Provide `aard map import`, `aard map import cancel`, and `aard map status`. `status` reports snapshot, cursor, counts, collisions, and whether a resume is pending. The `gmcp.room.info` handler may center on an already-imported owned room only; it must be read-only, tolerate absent/invalid GMCP data, and must not send commands, mutate map data, or trigger imports.

9. Add focused tests with a compact test-only map package and Lua stub coverage for foreign collisions, ownership reuse, repeated imports, changed snapshots, cancellation/resume, exit preservation, GMCP centering, and lifecycle cleanup. Verify converter fixtures independently for valid v11 input, deterministic bytes, coordinate collisions, disconnected components, cross-area exits, unchanged input bytes, schema/reference/ID/direction failures, symlink rejection, and unsafe output paths. Do not add a reusable importer-template asset to the plugin.

10. Validate the generated project against the actual source database, then run the shared project/package checks and create deterministic artifacts.

   ```sh
   python3 ../../scripts/validate_aardwolf_map_conversion.py \
     --input INPUT_DATABASE --project PROJECT --artifacts
   python3 ../../scripts/validate_aardwolf_mudlet_project.py PROJECT --check-native-output
   python3 ../../scripts/build_mudlet_package.py PROJECT --backend native
   ```

   Run the Muddler backend only when that runtime is available and report it as an acceptance gap otherwise. If database-ledger review or importer review can proceed independently after the input and output contracts are frozen, delegate those bounded reviews; integrate their evidence before delivery.

The completed deliverable is a reviewed source project plus deterministic native XML/`.mpackage` containing the generated map resource and a merge-safe importer. It must never replace or clear an existing profile map.
