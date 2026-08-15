# aardwolf-gmcp-diagnostics

Safe native GMCP state diagnostics for Aardwolf.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_GMCP_handler`. Supported aliases: `^aard gmcp status$`, `^gmcpdebug (on|off)$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

GMCP diagnostics remain in bounded state, but console logging defaults off and is emitted only after explicit `gmcpdebug on`. Namespaced handlers are removed through `aardwolf_gmcp_diagnostics.lifecycle.shutdown()`.


Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
