# aardwolf-tick

Direct GMCP tick status with a text-first accessible fallback.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `Aardwolf_Tick_Timer`. Supported aliases: `^aard tick( help| miniwin| status)?$`, `^aard tick reset$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

The package treats `gmcp.comm.tick` as a payload-optional signal and predicts the next tick from Aardwolf's 30-second interval. It sends no game commands or automatic console messages.


Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
