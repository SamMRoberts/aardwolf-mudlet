# aardwolf-vibe

`aardwolf-vibe` is a source-controlled Mudlet package for Aardwolf. Its first
plugin is a defensive GMCP auto-mapper for Mudlet 5.0.1.

The mapper consumes `gmcp.room.info`, uses Aardwolf room numbers as native
Mudlet room IDs, names areas exactly from `room.info.zone`, colors rooms by
terrain, creates placeholders for known destinations, and represents unexpected
non-standard exit keys as Mudlet special exits.

Terrain names follow Aardwolf's complete terrain catalog (including roads,
weather, water, ice, hell, structures, and dead-land variants) and use the
catalog's supplied ANSI color index. Unknown terrain remains visible in gray.

## Commands

```text
aardwolf-vibe mapper on
aardwolf-vibe mapper off
aardwolf-vibe mapper status
```

Mapping is enabled on first install. The selected state persists in
`aardwolf-vibe-data/settings.json` under the active profile. Before the first
map mutation of each activation, the package saves a timestamped native map
backup under `aardwolf-vibe-data/backups/`.

The mapper owns only rooms, areas, palette entries, and exits carrying its
metadata. A numeric room collision, a same-name foreign area, or a known
competing mapper stops mapping instead of adopting or overwriting existing map
data. Uninstalling the package leaves mapped data and backups intact.

## Build and test

The project uses Muddler 1.1.0 and Lua 5.1-compatible source.

```sh
python3 tools/check.py --bootstrap
```

The command builds and verifies `build/aardwolf-vibe.mpackage`, inspects its
container and XML, checks Lua 5.1 syntax, and runs the pure-Lua contract tests.
It does not install into a live profile or establish connected Aardwolf GMCP
delivery.
