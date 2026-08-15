# Aardwolf Mudlet packages

Each directory below is an independently installable Mudlet 4.14+ project.
Install its `dist/*.mpackage` archive. The colocated `dist/*.xml` artifact is
a raw Mudlet object export, not the full resource-bearing package archive.
Regenerate every release artifact with `python3 tools/build_mudlet_release.py`;
it runs the release validator before copying deterministic native output.

## All-in-one installation

Install [aardwolf-mudlet-suite.mpackage](dist/aardwolf-mudlet-suite.mpackage)
when one archive is preferred. It contains the native objects from every
package in this catalog and the declared map JSON resource. Do not install the
suite alongside the individual `.mpackage` files in the same profile: the
objects have the same package-owned names. The suite XML is available beside
it for inspection, but cannot provide the map resource on its own.

| Package | Purpose | Source scope |
| --- | --- | --- |
| `aardwolf-mushclient-collection` | Audited catalog; local clock and blank-line compatibility | Collection-wide ledger |
| `aardwolf-gmcp-diagnostics` | Direct GMCP inspection with logging off by default | `aard_GMCP_handler` |
| `aardwolf-tick` | 30-second numeric tick prediction | `Aardwolf_Tick_Timer` |
| `aardwolf-console` | Safe console controls | Command-tag, color-copy, VI, lockout, prompt, repaint, substitution |
| `aardwolf-communication` | Channel status | Channel, chat echo, translation |
| `aardwolf-character` | Quiet, on-demand character and group summaries; `groupon`/`groupoff` control update notifications | Group monitor, health bars, stat monitor |
| `aardwolf-help` | Accessible help | MUSHclient help, Aardwolf help, plugin list/summary |
| `aardwolf-interface` | Obsidian Jewel adaptive command deck with room context, Map/Character/Group/Inventory tabs, optional inspector, balanced HUD, accessible summaries, and confirmed custom actions | Theme, responsive layout, structured GMCP, mapper integration, strict tagged details |
| `aardwolf-profile-data` | Explicit local data import/export | Backup, config, serials, connection, notes, update checker, requirements |
| `aardwolf-accessibility` | Mudlet-native text-to-speech | SAPI, universal TTS |
| `aardwolf-map` | Safe native map import with collision-free environment colors, source/Obsidian/high-contrast palettes, resumable lifecycle, and integration status snapshots | Supersedes the safe mapper use case |

All unportable, malformed, or uninspectable source behavior remains visible in
`aardwolf-mushclient-collection/reports/retirements.md`; it is not silently
dropped or redistributed.
