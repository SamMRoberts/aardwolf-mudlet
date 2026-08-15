#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-help"
assert metadata["namespace"] == "aardwolf_help"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_help" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_help" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_help.commands." in action
source = (root / "src" / "scripts" / "aardwolf_help" / "aardwolf_help_main.lua").read_text()
assert "aardwolf_help" in source
assert "send(" not in source
assert source.count("function aardwolf_help.") >= 5
assert "function aardwolf_help.lifecycle.initialize" in source
assert "function aardwolf_help.lifecycle.shutdown" in source




