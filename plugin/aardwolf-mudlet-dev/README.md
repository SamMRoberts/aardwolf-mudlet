# Aardwolf Mudlet Dev

Skills for creating, converting, reviewing, and packaging source-controlled Mudlet 4.14+ extensions for Aardwolf. This is a skills-only plugin: it has no MCP server, app connector, hooks, or credentials.

## Skills

- `create-aardwolf-mudlet-package` creates or extends a namespaced Mudlet package project, then builds native and optional Muddler artifacts.
- `convert-mushclient-to-mudlet` inspects Aardwolf MUSHclient XML as data and produces a reviewed Mudlet project with a conversion inventory and report.
- `convert-aardwolf-map-database-to-mudlet` converts a supported Aardwolf SQLite map database into a deterministic resource and a merge-safe Mudlet map importer; it never replaces or clears an existing profile map.
- `review-aardwolf-mudlet-package` performs an evidence-backed review of a package project's behavior, lifecycle, protocol use, portability, artifacts, and map-import safety when applicable.

Use the matching skill for the task. The package project produced by a skill is the source of truth; generated XML and `.mpackage` files are build outputs.

## Shared tooling

All root scripts use Python 3 standard-library modules unless a command explicitly invokes an optional external tool.

- `scripts/inspect_mushclient_xml.py` inventories MUSHclient XML safely; `convert-mushclient-to-mudlet` consumes it.
- `scripts/render_conversion_report.py` renders the conversion inventory and disposition report; `convert-mushclient-to-mudlet` consumes it.
- `scripts/build_mudlet_package.py` builds deterministic native XML and `.mpackage` output, and can invoke Muddler when installed; package creation, conversion, and review consume it.
- `scripts/validate_aardwolf_mudlet_project.py` validates the shared source-project contract; package creation, conversion, and review consume it.
- `scripts/common.py` provides shared input, JSON, hashing, path, and output helpers for the root scripts; it is an internal dependency of the report, project-contract, package-build, and project-validation scripts.
- `scripts/project_contract.py` loads and validates the source-controlled package model; it is an internal dependency of the package-build and project-validation scripts.
- `scripts/convert_aardwolf_map_database.py` converts the supported SQLite map database into the canonical map resource and inventory reports; `convert-aardwolf-map-database-to-mudlet` consumes it.
- `scripts/validate_aardwolf_map_conversion.py` verifies map resource, report, source-hash, project, and packaged-artifact agreement; the map-conversion and package-review skills consume it.

The map converter requires a supported SQLite input schema. Building both package backends additionally requires Muddler; native packaging does not. Live Mudlet import remains a manual acceptance check.

## Validation

Run from the repository root. Set `BPC_ROOT`, `SKILL_CREATOR_ROOT`, and `PLUGIN_CREATOR_ROOT` to the local tool roots that provide the indicated validation scripts.

```bash
python3 -m unittest discover -s plugin/aardwolf-mudlet-dev/tests -v
for skill in plugin/aardwolf-mudlet-dev/skills/*; do python3 "$BPC_ROOT/scripts/validate_generated_skill.py" "$skill"; done
for skill in plugin/aardwolf-mudlet-dev/skills/*; do python3 "$SKILL_CREATOR_ROOT/scripts/quick_validate.py" "$skill"; done
python3 "$BPC_ROOT/scripts/validate_generated_plugin.py" --plugin plugin/aardwolf-mudlet-dev
python3 "$BPC_ROOT/scripts/audit_generated_plugin.py" --plugin plugin/aardwolf-mudlet-dev --topic aardwolf-mudlet-development --root WRITABLE_CATALOG_COPY
python3 "$PLUGIN_CREATOR_ROOT/scripts/validate_plugin.py" plugin/aardwolf-mudlet-dev
git diff --check
```

For a generated map project, also run:

```bash
python3 plugin/aardwolf-mudlet-dev/scripts/validate_aardwolf_map_conversion.py --input Aardwolf.db --project PROJECT --artifacts
python3 plugin/aardwolf-mudlet-dev/scripts/validate_aardwolf_mudlet_project.py PROJECT --release
python3 plugin/aardwolf-mudlet-dev/scripts/build_mudlet_package.py PROJECT --backend native
```
