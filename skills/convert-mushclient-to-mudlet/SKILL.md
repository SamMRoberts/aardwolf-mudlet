---
name: convert-mushclient-to-mudlet
description: Convert and assess MUSHclient XML plugins, companion Lua, and resources as source-controlled Mudlet packages for Aardwolf. Use when migrating MUSHclient aliases, triggers, timers, variables, callbacks, GMCP handlers, miniwindows, or plugin dependencies to Mudlet without executing untrusted input.
---

# Convert MUSHclient to Mudlet

Convert only behavior that has an explicit, reviewable disposition. Treat every
MUSHclient XML file, Lua file, and resource as untrusted data; never load it in
MUSHclient, Lua, or Mudlet while inspecting it.

Read [MUSHclient-to-Mudlet mappings](references/mushclient-to-mudlet-mappings.md)
before translating objects or Lua. Read [callbacks and lifecycle mappings](references/callback-and-lifecycle-mappings.md)
when callbacks, broadcasts, persistent state, or teardown are present. Read
[Aardwolf GMCP conversion](references/aardwolf-gmcp-conversion.md) whenever the
plugin uses GMCP, Aardwolf options, or GMCP-handler broadcasts. Read
[unsupported patterns](references/unsupported-conversion-patterns.md) before
classifying platform, dynamic-loading, or UI behavior.

## Workflow

1. Establish read-only source inputs: one MUSHclient plugin XML file, any explicitly supplied companion Lua/resource roots, and a new or user-approved target directory. Confirm the intended package name and one Lua-identifier namespace; derive the namespace from metadata only when it is unambiguous. Stop and ask for a choice if the namespace is invalid, collides with an existing package, or source ownership/licensing is unclear.
2. Inspect the input without executing it. Run [`inspect_mushclient_xml.py`](../../scripts/inspect_mushclient_xml.py) as `python3 ../../scripts/inspect_mushclient_xml.py INPUT [--companion PATH]... [--output FILE]`; pass each companion root explicitly and retain its stable inventory JSON. Do not use `dofile`, `require`, MUSHclient, Lua, DLLs, archive extractors that follow links, or a Mudlet import to discover behavior. Stop if parsing or resource-boundary checks fail; record malformed, unknown, or out-of-bounds input rather than repairing it silently.
3. Read the inventory and construct a decision record for every inventory `items[].id`. Account for plugin metadata; aliases; triggers; timers; variables; callbacks; scripts; assets; plugin dependencies; GMCP dependencies; miniwindow APIs; filesystem calls; DLL loading; Windows-specific APIs; and every unknown XML element or static-analysis signal. Assign exactly one of `converted`, `converted-with-review`, `manual-action-required`, `unsupported-blocker`, or `not-applicable`, with nonempty reasoning and target paths. Do not treat an unrecognized Lua call, dynamic value, or missing companion as `not-applicable`.
4. If the inventory has two independent analysis branches, delegate only after it is frozen: one subagent maps statically defined aliases, triggers, timers, and variables; a second maps callbacks, protocols, UI, dependencies, and unsafe APIs. Give both the read-only inventory and source copies, require a decision table keyed by inventory ID, prohibit target-directory edits and source execution, and keep all final decisions, project edits, conflicts, and validation with the primary agent. Do not delegate tightly coupled Lua rewrites or unresolved license decisions.
5. Create a conventional source project with `package-metadata.json`, synchronized `mfile`, `src/scripts`, `src/aliases`, `src/triggers`, `src/timers`, `src/keys`, `src/resources`, help, README documentation, tests, and `reports/`. Keep one valid namespace for every runtime symbol, Mudlet object, named event handler, timer, UI object, setting key, and persisted state key. Separate bootstrap/lifecycle, state, settings, commands, protocol, UI, and help modules; do not replace missing behavior with placeholder functions or global compatibility shims.
6. Translate supported behavior using the mappings. Preserve matching order, enablement, send/gag behavior, timer semantics, captures, and declared dependencies where their semantics are known. Move mutable data behind the namespaced state/settings modules and make persistence explicit. Copy assets only after normalized relative-path and symlink-boundary checks, then declare them in package metadata and use package-local paths. Preserve discovered copyright, license, and NOTICE text exactly in the converted project; do not infer or add a license.
7. Convert known Aardwolf GMCP-handler broadcast patterns to direct native Mudlet GMCP handling. Register namespaced handlers for the emitted `gmcp.*` events, read the matching native `gmcp` table, validate fields before copying them into namespaced state, and unregister all handler IDs during teardown. For the Aardwolf tick pattern, use `gmcp.comm.tick` and `gmcp.comm.tick`; do not retain a MUSHclient broadcast relay. Require an explicit mapping and a declared provider for every other broadcast, plugin dependency, and GMCP subscription; classify arbitrary cross-plugin broadcasts as manual action or a blocker rather than guessing an event name.
8. Write `decisions.json`, then run [`render_conversion_report.py`](../../scripts/render_conversion_report.py) as `python3 ../../scripts/render_conversion_report.py --inventory INVENTORY --decisions DECISIONS --json-output PROJECT/reports/conversion-report.json --markdown-output PROJECT/reports/conversion-report.md`. Retain the deterministic JSON and Markdown reports with the project. Fix missing, duplicate, or unknown decisions before continuing; the report must name each source item, disposition, target path or absence, rationale, preserved notices, dependencies, and release blockers.
9. Add fixture-based tests for converted aliases, triggers, timers, lifecycle cleanup, GMCP event/state behavior, package metadata, assets, and every `converted-with-review` item. Run [`validate_aardwolf_mudlet_project.py`](../../scripts/validate_aardwolf_mudlet_project.py) in normal mode while iterating, then run it with `--release --json` only after every unsafe, unknown, manual, and blocker disposition is resolved. Build both artifacts only after release validation passes: `python3 ../../scripts/build_mudlet_package.py PROJECT --backend both`. Stop instead of packaging a partial conversion, unresolved notice, unsupported blocker, or behavior that lacks a disposition; deliver the partial source project and report as the honest result.
10. Deliver the source project, native XML/`.mpackage` artifact, Muddler artifact, inventory, decisions, conversion reports, test evidence, and an explicit list of remaining manual work. Do not claim behavioral equivalence, Mudlet import success, or a clean release when live verification was unavailable or any report item remains unresolved.

## Required output contract

The inspection inventory is the source-of-truth ledger. Every behavior-bearing
entry, including unknown XML/static-analysis signals and discovered notices, has
a stable ID in the report's decision universe. The decisions file contains a
`decisions` array with one unique `item_id` per source entry, a permitted
`status`, a nonempty `reason`, and `target_paths` as an array. The report
generator must reject an incomplete or ambiguous ledger.

Use the project validator as the machine-checkable gate and perform a separate
qualitative review of gameplay semantics, capture scopes, UI layout, user-visible
text, and accessibility. A report is complete only when a reviewer can trace any
source behavior to a concrete target or a plainly stated unresolved action.
