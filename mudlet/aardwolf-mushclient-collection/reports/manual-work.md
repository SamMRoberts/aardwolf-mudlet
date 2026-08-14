# Remaining manual conversion work

The complete, item-level disposition is in `conversion-report.md`. This file
groups the work that cannot safely be inferred from the MUSHclient sources.

## Inspection failures

The following sources were not parsed or repaired. They remain manual work:

- `Aardwolf_Bigmap_Graphical.xml` — malformed XML.
- `aard_ASCII_map.xml` — malformed XML.
- `aard_GMCP_mapper.xml` — external/custom entity declaration rejected.
- `aard_soundpack.xml` — malformed XML.
- `aard_vi_review_buffers.xml` — malformed XML.
- `aard_vital_shortcuts.xml` — malformed XML.

## Safety and portability blockers

`aard_GMCP_handler.xml` uses Windows-specific behavior, and
`universal_text_to_speech.xml` loads a native library. Neither has been
translated. A safe Mudlet design must replace the exact capability without
loading DLLs, handling raw telnet packets, or assuming Windows APIs.

## Design work needed

The remaining plugins depend on one or more MUSHclient-only facilities:

- Cross-plugin broadcasts and plugin IDs require a declared Mudlet provider and
  package-scoped API.
- GMCP relays require feature-specific direct `gmcp.*` event/table mappings.
- Miniwindows, layout hooks, and custom painting need a visual and accessibility
  acceptance design.
- Filesystem and update features need an explicit data-ownership, consent, and
  failure-handling policy.
- Command/line interception and substitution features need an equivalent Mudlet
  ordering and suppression contract.

No assets, executable companion Lua, or original MUSHclient source code are
packaged while those items remain unresolved.
