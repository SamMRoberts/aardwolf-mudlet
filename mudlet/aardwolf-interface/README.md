# aardwolf-interface

Responsive Aardwolf Geyser dashboard with an accessible text fallback.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_Theme_Controller`, `aard_layout`, `aard_miniwindow_z_order_monitor`, `aard_splitscreen_scrollback`. Supported aliases: `^aard interface status$`, `^aard interface show$`, `^aard interface hide$`, `^aard theme change$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

The dashboard consumes direct `gmcp.char.*`, `gmcp.group`, `gmcp.room.info`, and `gmcp.comm.tick` events. It creates a reserved right sidebar after install/profile load, sends no game commands, and restores its border and shared mapper ownership through `aardwolf_interface.lifecycle.shutdown()`.


## Dashboard behavior

The sidebar appears automatically on first install and then remembers explicit show/hide and theme choices. It reserves 340–480 pixels at the right edge without overwriting an existing right border. Missing or partial GMCP remains visibly unavailable instead of being shown as zero.

Mudlet has one native mapper display per profile. While this dashboard is visible it owns that display; hiding or unloading the package restores a `generic_mapper` view that was visible before the dashboard claimed it. The dashboard never imports, creates, edits, or deletes map rooms. Use `aard map import` from `aardwolf-map` to populate the packaged Aardwolf snapshot.

In Mudlet 4.20 and newer, the dashboard temporarily disables the global `showUpperLowerLevels` overlay while its narrow embedded mapper is visible. This prevents adjacent floors from appearing stacked behind the active floor. The prior value is restored on hide, reload, or unload, and older Mudlet versions use capability-checked fallback behavior.

The room, tick, character, and group sections use escaped rich-text rows so Qt does not collapse intended line breaks into a single dense line. Empty group state stays compact to preserve mapper space in shorter profile windows.

For upgrades, remove an older `aardwolf-interface` or `aardwolf-mudlet-suite` package before installing 1.1.2 so Mudlet does not retain duplicate static objects.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
