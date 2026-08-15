# Aardwolf MUSHclient Collection

This 1.0.0 release is the audited catalog and compatibility package for the
MUSHclient sources in `.resources/worlds/plugins`. It keeps only the two
already-reviewed compatibility behaviors:

- a local one-second clock rendered as a named Geyser label; and
- exact blank-line omission through `deleteLine()`.

The full conversion ledger covers all 522 static inventory items. Every item
is either represented by a native package or visibly marked
`intentionally-retired`; no `manual-action-required` or `unsupported-blocker`
entries remain.

## Native replacement packages

Install only the independent feature packages you want. Their aliases, help,
lifecycle, and GMCP handlers are namespaced and they share no relay or
automatic network behavior.

- `aardwolf-gmcp-diagnostics` — safe, direct GMCP inspection
- `aardwolf-tick` — direct `gmcp.comm.tick` status
- `aardwolf-console` — text-first safe console controls
- `aardwolf-communication` — direct channel GMCP status
- `aardwolf-character` — direct character and group GMCP summaries
- `aardwolf-help` — accessible help and migration guidance
- `aardwolf-interface` — responsive Geyser dashboard, embedded native mapper, and an expanded-only character-details column
- `aardwolf-profile-data` — explicit local note export/import
- `aardwolf-accessibility` — Mudlet-native text-to-speech controls
- `aardwolf-map` — separately maintained safe map importer

## Install and lifecycle

Install the generated `.mpackage` from `dist/` in Mudlet. It is the complete
package archive. The `.xml` beside it is a raw Mudlet-object export for
inspection or controlled import and does not include package resources.

The compatibility package starts the clock when loaded. Before disabling or
reloading it, run `aardwolf_mushclient_collection.lifecycle.shutdown()` to
remove its named timer and label; run
`aardwolf_mushclient_collection.lifecycle.start()` to restore them.

It sends no game commands, has no GMCP handler, keeps no persistent settings,
and includes no copied MUSHclient source or companion assets.

## Audit and limits

Read `reports/conversion-report.md` for all dispositions and
`reports/retirements.md` for each migration note. The six malformed or
external-entity inputs are retired rather than inferred; the map package is
the supported replacement for safe map import. No license or copyright notice
was inferred from static inspection, so this project does not claim rights to
redistribute the original MUSHclient sources or assets.
