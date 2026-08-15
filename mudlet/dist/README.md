# Aardwolf Mudlet Suite

`aardwolf-mudlet-suite.mpackage` is a deterministic all-in-one Mudlet 4.14+
installation archive. It merges the native Mudlet objects from the collection,
GMCP diagnostics, tick, console, communication, character, help, interface,
profile-data, accessibility, and map packages. It also contains the declared
map JSON resource.

Install either this suite or individual package archives in a profile, not
both. The adjacent XML is a raw object export for inspection and does not
contain resources, so it is not a functional replacement for the suite when
using the map importer.

The current suite version is 1.5.0. It includes Mudlet's required `config.lua`
Package Manager metadata and the Obsidian Jewel adaptive command deck: a
responsive right workspace with persistent room context, Map/Character/Group/
Inventory tabs, an optional inspector, a balanced multi-row HUD, accessible
plain-text summaries, and a contextual action drawer. The map integration adds
collision-safe environment colors, source/Obsidian/high-contrast palettes,
resumable import lifecycle, and trustworthy status snapshots. Character and
group tracking is quiet by default with useful on-demand summaries; `groupon`
and `groupoff` control update notifications. Diagnostic event logging is
disabled until the user runs `gmcpdebug on`. If an
older `Aardwolf Mudlet Suite` entry is already installed, remove it in Mudlet's
Package Manager before installing this archive.

Regenerate the XML and `.mpackage` with:

```sh
python3 tools/build_mudlet_release.py
```

The builder first validates every component release, merges the source-derived
native exports in a fixed order, and verifies every complete serialized object,
the suite version, and all archive XML, config, and resource bytes before
publishing the suite.
