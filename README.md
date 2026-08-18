# Aardwolf Mudlet Dev

Codex skills for creating, converting, reviewing, testing, and packaging
source-controlled Mudlet extensions and full-lifecycle Geyser interfaces for
Aardwolf MUD.

This is a skills-only plugin; it includes no MCP server, app connector, hooks,
marketplace entry, installation flow, or publication configuration.

## Components

- `create-aardwolf-mudlet-package` creates namespaced Mudlet 4.14+ package
  projects with native XML and Muddler build paths.
- `convert-mushclient-to-mudlet` inventories MUSHclient XML without executing
  it, converts supported behavior, and records every disposition.
- `develop-geyser-ui` designs, implements, troubleshoots, refactors, and audits
  responsive package-owned Geyser interfaces for Mudlet 4.14 and newer.
- `review-aardwolf-mudlet-package` performs a release-oriented Aardwolf and
  Mudlet review.

The shared Python tools require only Python 3.9+ and the standard library:

```sh
python3 scripts/inspect_mushclient_xml.py input.xml --output inventory.json
python3 scripts/render_conversion_report.py --inventory inventory.json \
  --decisions decisions.json --json-output conversion-report.json \
  --markdown-output conversion-report.md
python3 scripts/validate_aardwolf_mudlet_project.py package-project --release
python3 scripts/build_mudlet_package.py package-project --backend native
```

Use `--backend muddler` or `--backend both` only where the `muddle` command is
available. The native backend writes deterministic XML and `.mpackage` files to
the project `build/` directory.

The command-line tools share [`scripts/common.py`](scripts/common.py) for
bounded I/O and stable JSON, and [`scripts/project_contract.py`](scripts/project_contract.py)
for the source-project contract used by the builder and validator.

## Validation

```sh
python3 -m unittest discover -s tests -v
python3 -m compileall -q scripts
python3 -m tabnanny scripts
```

The development-only maintained skill validators additionally require PyYAML;
use an isolated virtual environment rather than adding a plugin dependency.
