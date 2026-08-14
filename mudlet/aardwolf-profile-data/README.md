# aardwolf-profile-data

Explicit local profile note export and import tools.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `Automatic_Backup`, `Config_Option_Changer`, `aard_inventory_serials`, `aard_new_connection`, `aard_new_connection_no_UI`, `aard_note_mode`, `aard_package_update_checker`, `aard_requirements`. Supported aliases: `^aard data status$`, `^aard data note (.+)$`, `^aard data export$`, `^aard data import$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: none. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_profile_data.lifecycle.shutdown()`.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
