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
| `aardwolf-gmcp-diagnostics` | Direct GMCP inspection | `aard_GMCP_handler` |
| `aardwolf-tick` | Tick status | `Aardwolf_Tick_Timer` |
| `aardwolf-console` | Safe console controls | Command-tag, color-copy, VI, lockout, prompt, repaint, substitution |
| `aardwolf-communication` | Channel status | Channel, chat echo, translation |
| `aardwolf-character` | Character/group status | Group monitor, health bars, stat monitor |
| `aardwolf-help` | Accessible help | MUSHclient help, Aardwolf help, plugin list/summary |
| `aardwolf-interface` | Responsive dashboard, mapper, and collapsed character-details column | Theme, layout, miniwindow order, split scrollback, bounded tagged character data |
| `aardwolf-profile-data` | Explicit local data import/export | Backup, config, serials, connection, notes, update checker, requirements |
| `aardwolf-accessibility` | Mudlet-native text-to-speech | SAPI, universal TTS |
| `aardwolf-map` | Safe native map import | Supersedes the safe mapper use case |

All unportable, malformed, or uninspectable source behavior remains visible in
`aardwolf-mushclient-collection/reports/retirements.md`; it is not silently
dropped or redistributed.
