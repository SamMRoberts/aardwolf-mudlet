# MUSHclient-to-Mudlet mappings

Use this as a conversion guide, not a source-code substitution table. Preserve
the original feature's user-visible behavior only after confirming the target
API and lifecycle semantics in the selected Mudlet version.

## Project and object mapping

| MUSHclient input | Mudlet project target | Conversion rule |
| --- | --- | --- |
| Plugin metadata | `package-metadata.json`, `mfile`, package description | Keep name, version, description, required packages, and attribution where known. Use a unique package ID and a valid Lua namespace. |
| Alias | `src/aliases/` plus command module | Preserve pattern, enabled state, send-to behavior, expansion, and capture use. Route implementation through `namespace.commands`. |
| Trigger | `src/triggers/` plus protocol or command module | Prefer GMCP for structured Aardwolf data. Retain a text trigger only for display-only or unavailable protocol data and document the fallback. |
| Timer | `src/timers/` plus state module | Preserve interval, repeat policy, initial enablement, and cleanup. Keep timer IDs/names namespaced. |
| Key binding | `src/keys/` plus command module | Preserve key scope and enablement; do not claim key portability when modifier behavior changes by platform. |
| Script | `src/scripts/` modules | Split bootstrap/lifecycle, state, settings, commands, protocol, UI, and help. Do not put project state in globals. |
| Variable | namespaced settings/state module | Decide whether it is package configuration, per-profile persistence, transient runtime state, or derived data. Keep storage keys namespaced and validate values on read. |
| Asset | `src/resources/` and package asset declaration | Copy only bounded relative files; use the installed package's asset directory instead of an author-machine path. |

## Lua and client API mapping

| Source pattern | Target approach | Review requirement |
| --- | --- | --- |
| Send a command | Use Mudlet's command-send API behind `namespace.commands`. | Preserve echo, queueing, aliases, and user-initiated versus automatic behavior. |
| Write colored output | Use a Mudlet display API behind `namespace.ui`. | Convert color markup deliberately; never treat incoming game text as trusted markup. |
| Read/write plugin variable | Use the namespaced settings wrapper around Mudlet persistence APIs. | Supply defaults, type checks, and a migration path for existing settings. |
| Regex captures such as `%1` | Use the captured Mudlet match value for the corresponding trigger pattern. | Test capture indexing and optional groups; do not mechanically replace capture tokens in arbitrary Lua. |
| Enable/disable named object | Use a namespaced Mudlet object name or retained object ID. | Confirm object lifetime and idempotent enable/disable behavior. |
| Dynamic alias, trigger, or timer creation | Use a Mudlet temporary object only when its lifetime and cleanup are fully known. | Otherwise require manual action; never create an untracked long-lived object. |
| Notification, log, or note window | Implement through the UI/logging module. | Preserve privacy, rotation, and failure handling rather than using a bare file write. |

## GMCP and broadcasts

Do not use a text trigger when an Aardwolf GMCP message supplies the same
structured state. A native handler reads Mudlet's populated `gmcp` table and
copies validated values into the package namespace. It does not implement or
overwrite the `gmcp` table.

MUSHclient plugin broadcasts are not a general Mudlet transport. Replace a
recognized Aardwolf GMCP-handler broadcast only when its message name and
payload are mapped to a declared GMCP module. For example, map a tick relay to
the `gmcp.comm.tick` event and table. Record any generic broadcast, sender-ID
check, or inter-plugin request that lacks a declared target provider as manual
action or an unsupported blocker.

## UI and miniwindows

Treat miniwindow conversion as a UI redesign with an acceptance review, not an
automatic API migration. Map simple text, gauges, images, and click handlers to
namespaced Mudlet UI objects only after defining sizing, font availability,
input behavior, cleanup, and asset paths. Keep custom drawing, drag behavior,
window z-order, DPI assumptions, and callback-driven hit testing as explicit
review items.

## Naming contract

Choose one Lua identifier namespace such as `aardwolf_tracker`. Prefix every
named Mudlet object with a package-safe derivative such as
`aardwolf_tracker__`. Keep public functions under the namespace table, retain
anonymous handler IDs in `namespace.lifecycle`, and never write package data to
generic global variables, unnamed events, or unqualified persistent keys.
