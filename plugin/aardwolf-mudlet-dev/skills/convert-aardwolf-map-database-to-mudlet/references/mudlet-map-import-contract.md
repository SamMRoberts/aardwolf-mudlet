# Mudlet merge-safe map importer contract

The generated map JSON is package data, not a profile map file. A profile map load can replace existing map data, so the importer must merge only its own records through ordinary mapper APIs. It must never call destructive or profile-map replacement APIs.

Use `aardwolf-map:vnum:<vnum>` as the stable hash for each source room. A new owned room receives a compact mapper ID from `createRoomID()` and is bound through the hash API. Never assume source vnums are safe Mudlet room IDs.

Ownership must be explicit and namespaced. Store a package marker plus the latest source SHA-256 in room, area, and map user data under `aardwolf_map` keys. Only package-owned records may be refreshed or reconciled. Any foreign or unmarked collision is left untouched and reported; skip an exit when either endpoint is foreign or unresolved.

Import a fixed-size batch at a time and keep durable progress: snapshot hash, phase, cursor, imported count, collision count, and cancellation request. Commands are `aard map import`, `aard map import cancel`, and `aard map status`. A resumed import must use the original snapshot identity; a new snapshot is a separate refresh.

A completed same-snapshot import must not overwrite edited exits. A changed snapshot may refresh package-owned source metadata and package-owned exits, but it must not modify foreign records or erase user changes that are not package-owned source fields. Name and remove package event/timer registrations during lifecycle shutdown.

`gmcp.room.info` support is optional centering only. It may locate an owned room and center the mapper; it may not send commands, trigger imports, add rooms/exits, alter colors, or write user data. It must safely ignore unavailable or malformed GMCP values.
