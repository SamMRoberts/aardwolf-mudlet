# aardwolf-interface

Responsive Aardwolf Geyser dashboard with a mapper, collapsible character details, and text fallbacks.

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from `aard_Theme_Controller`, `aard_layout`, `aard_miniwindow_z_order_monitor`, `aard_splitscreen_scrollback`. Supported aliases: `^aard interface status$`, `^aard interface show$`, `^aard interface hide$`, `^aard interface details show$`, `^aard interface details hide$`, `^aard interface details toggle$`, `^aard interface details refresh$`, `^aard interface details status$`, `^aard theme change$`. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

The dashboard consumes direct `gmcp.char.*`, `gmcp.group`, `gmcp.room.info`, `gmcp.comm.tick`, and `gmcp.config` events. Each `gmcp.comm.tick` signal resets a local 30-second numeric countdown gauge whose bar diminishes once per second. Its optional details column issues only bounded Aardwolf tagged-data queries while expanded, never polls, and restores confirmed temporary Invmon/spellup settings through `aardwolf_interface.lifecycle.shutdown()`.


## Dashboard behavior

The sidebar appears automatically on first install and every subsequent Mudlet profile load. An explicit `aard interface hide` lasts for the current loaded session; the next profile load shows the dashboard again. Theme and details-column choices remain persisted. The sidebar reserves 340–480 pixels at the right edge without overwriting an existing right border. Missing or partial GMCP remains visibly unavailable instead of being shown as zero.

Mudlet has one native mapper display per profile. While this dashboard is visible it owns that display; hiding or unloading the package restores a `generic_mapper` view that was visible before the dashboard claimed it. The dashboard never imports, creates, edits, or deletes map rooms. Use `aard map import` from `aardwolf-map` to populate the packaged Aardwolf snapshot.

In Mudlet 4.20 and newer, the dashboard temporarily disables the global `showUpperLowerLevels` overlay while its narrow embedded mapper is visible. This prevents adjacent floors from appearing stacked behind the active floor. The prior value is restored on hide, reload, or unload, and older Mudlet versions use capability-checked fallback behavior.

The room, character, and group sections use escaped rich-text rows so Qt does not collapse intended line breaks into a single dense line. The tick section is a numeric gauge that resets to 30 on `gmcp.comm.tick`, counts down once per second, and diminishes toward zero. Empty group state stays compact to preserve mapper space in shorter profile windows.

The optional 360–460 pixel details column starts collapsed and remembers explicit show/hide choices. Its scrollable Equipment, Current Affects, Bags, Resists, and Condition sections retain a visibly stale last snapshot when collapsed. Every standard Aardwolf wear slot remains visible, and unknown numeric slots are appended.

Expanding details waits for active `gmcp.char.status`, then performs one paced refresh using `eqdata`, `invdata`, `invdetails`, `slist affected`, and `resists`. Bag-detail requests are limited to one per second. Invmon and spellup-tag changes are made only after their prior values are confirmed, and only package-owned changes are restored. There is no periodic polling. Captures are bounded to 100 records and malformed or incomplete responses preserve the previous valid snapshot with an error marker.

For upgrades, remove an older `aardwolf-interface` or `aardwolf-mudlet-suite` package before installing 1.3.1 so Mudlet does not retain duplicate static objects.

Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
