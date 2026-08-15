# aardwolf-interface

Accessible interface state controls with text fallback.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_Theme_Controller`, `aard_layout`, `aard_miniwindow_z_order_monitor`, `aard_splitscreen_scrollback`. Supported aliases: `^aard interface status$`, `^aard interface show$`, `^aard theme change$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

Mudlet lifecycle events: `sysInstall`, `sysLoadEvent`, and `sysWindowResizeEvent`. The package retries Geyser UI creation after install and profile load, sends no game commands, and removes its handlers through `aardwolf_interface.lifecycle.shutdown()`.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
