# aardwolf-character

Text-first character, group, and vital-status summaries from GMCP.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_group_monitor_gmcp`, `aard_health_bars_gmcp`, `aard_statmon_gmcp`. Supported aliases: `^aard character status$`, `^groupon$`, `^groupoff$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

The package stores bounded character vital and group snapshots. It is quiet by default; `groupon` and `groupoff` change notification behavior only, and no data collection or dashboard dependency is introduced.


Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
