# aardwolf-help

Accessible in-client help and migration guidance.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `MUSHclient_Help`, `aard_help`, `aard_ingame_help_window`, `plugin_list`, `plugin_summary`. Supported aliases: `^aard help$`, `^mchelps?(?: .*)?$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: none. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_help.lifecycle.shutdown()`.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
