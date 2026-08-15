# aardwolf-gmcp-diagnostics

Safe native GMCP state diagnostics for Aardwolf.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_GMCP_handler`. Supported aliases: `^aard gmcp status$`, `^gmcpdebug (on|off)$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: `gmcp.room.info`, `gmcp.char.vitals`, `gmcp.comm.tick`. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_gmcp_diagnostics.lifecycle.shutdown()`.


Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
