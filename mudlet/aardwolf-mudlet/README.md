# aardwolf-mudlet

`aardwolf-mudlet` is a source-controlled Mudlet 4.14+ package for Aardwolf. It provides validated native GMCP state, a responsive Geyser workspace and HUD, configurable Chat tabs and quickbar, explicit Equipment/Bags refresh, native TTS controls, local-only sound mappings, and a collision-safe importer for the packaged Aardwolf map snapshot.

The canonical source is this directory. Build artifacts are generated deterministically in `build/` and copied to `dist/`. The MUSHclient collection and `Aardwolf.db` beneath `.resources/` are read-only conversion inputs and are not redistributed.

## Build and validate

From the repository root:

```sh
python3 plugin/aardwolf-mudlet-dev/scripts/validate_aardwolf_mudlet_project.py mudlet/aardwolf-mudlet --release
python3 plugin/aardwolf-mudlet-dev/scripts/build_mudlet_package.py mudlet/aardwolf-mudlet --backend native
```

Install `dist/aardwolf-mudlet.mpackage` with Mudlet's Package Manager. Disable legacy modular Aardwolf UI packages first; the package detects their active namespaces and defers initialization rather than competing for border or mapper ownership.

See [HELP.md](HELP.md) and [USER-GUIDE.md](USER-GUIDE.md). The complete 522-item inventory and dispositions are in `reports/`.
