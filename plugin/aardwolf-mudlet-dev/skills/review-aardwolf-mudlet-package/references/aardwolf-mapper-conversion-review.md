# Aardwolf mapper conversion review

Use this reference only for a project that imports an Aardwolf map resource into Mudlet. The map
converter proves source-data integrity; the review must also prove that the live importer is safe
to run in an existing profile.

## Evidence and integrity

- The canonical resource is `aardwolf-map-v11.json`. Its source hash, schema version, ordered
  areas, environments, rooms, exits, layout, and counts must agree with the validated source
  database and any generated inventory reports.
- Review the validator's output, resource, reports, source database, source Lua, tests, XML, and
  `.mpackage` together. A report or resource without the source database cannot prove the imported
  map's provenance.
- The mapper resource must be packaged as a declared resource in both native XML/`.mpackage` and
  Muddler output. Archive contents must not contain an alternate resource, source database, or
  unreviewed generated map payload.

## Safe map ownership

- Package-owned rooms, areas, and map metadata need namespaced ownership markers. Stable hashes
  derived from Aardwolf vnums identify the intended package record; do not use a raw Mudlet room
  ID as a cross-profile identity.
- Foreign rooms, exits, areas, colors, and user map data remain outside the package's ownership.
  A collision is a recorded safe skip or an explicit failure, never a destructive repair.
- Reject or flag calls that clear a map, load or replace a profile map, globally recolor map data,
  delete unknown rooms or areas, or mutate a record without first establishing package ownership.
- Environment allocation must use package-owned or collision-safe assignments and must not silently
  change the appearance of foreign environments.

## Import and lifecycle behavior

- Imports must use bounded batches with visible progress. Cancellation, disable, reload, and
  reconnect must stop the active batch and leave a resumable, consistent ownership record.
- A repeated import of the same source snapshot must be idempotent and retain user-edited exits.
  A changed source snapshot may refresh only data owned by this package.
- Dynamic handlers, timers, aliases, and import state need named, namespaced records and complete
  cleanup on cancel, disable, reload, disconnect, and unload. Repeated starts must not add a
  second importer or GMCP handler.
- `gmcp.room.info` may center or highlight the mapped current room only. It must read the current
  GMCP table, tolerate missing or delayed values, send no command, and never edit room topology,
  colors, areas, or user map data.

## Required observable coverage

Require tests for foreign collisions, package-owned record reuse, same-snapshot reruns, changed
snapshots, cancellation and resume, user-edited exit preservation, lifecycle cleanup, and missing
or delayed `gmcp.room.info`. Test reports should demonstrate that non-destructive behavior holds
for both native and Muddler package representations.
