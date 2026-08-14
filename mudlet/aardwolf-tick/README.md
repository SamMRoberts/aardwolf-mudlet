# aardwolf-tick

Direct GMCP tick status with a text-first accessible fallback.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `Aardwolf_Tick_Timer`. Supported aliases: `^aard tick( help| miniwin| status)?$`, `^aard tick reset$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP events: `gmcp.comm.tick`. The package uses namespaced handlers, sends no game commands, and removes its handlers through `aardwolf_tick.lifecycle.shutdown()`.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
