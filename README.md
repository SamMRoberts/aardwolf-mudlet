# aardwolf-vibe

`aardwolf-vibe` is a source-controlled Mudlet package for Aardwolf on Mudlet
5.0.1. It provides a defensive GMCP auto-mapper, an in-memory character state
handler, and responsive Geyser status bars.

The mapper consumes `gmcp.room.info`, uses Aardwolf room numbers as native
Mudlet room IDs, names areas exactly from `room.info.zone`, colors rooms by
terrain, creates placeholders for known destinations, and represents unexpected
non-standard exit keys as Mudlet special exits.

Terrain names follow Aardwolf's complete terrain catalog (including roads,
weather, water, ice, hell, structures, and dead-land variants) and use the
catalog's supplied ANSI color index. Unknown terrain remains visible in gray.

The always-active character plugin consumes `char.base`, `char.vitals`,
`char.stats`, `char.maxstats`, `char.status`, and `char.worth`. It exposes
validated defensive-copy snapshots through `AardwolfVibe.plugins.character`
and raises local update events for other scripts. Character state is scoped to
the current GMCP session and is never written to disk. See
[`docs/character.md`](docs/character.md) for the API and event contract.

The always-visible character strip uses that validated state to show HP, mana,
moves, level progress, the current enemy, and alignment. It occupies one row
above the command input on normal windows and reflows into two rows below 840
pixels. See [`docs/character-bars.md`](docs/character-bars.md) for its rendering
and layout contract.

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
