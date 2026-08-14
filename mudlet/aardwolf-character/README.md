# aardwolf-character

Text-first character, group, and vital-status summaries from GMCP.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_group_monitor_gmcp`, `aard_health_bars_gmcp`, `aard_statmon_gmcp`. Supported aliases: `^aard character status$`, `^groupon$`, `^groupoff$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: `gmcp.char.vitals`, `gmcp.group`. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_character.lifecycle.shutdown()`.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
