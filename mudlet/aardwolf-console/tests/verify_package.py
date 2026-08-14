#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-console"
assert metadata["namespace"] == "aardwolf_console"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_console" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_console" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_console.commands." in action
source = (root / "src" / "scripts" / "aardwolf_console" / "aardwolf_console_main.lua").read_text()
assert "aardwolf_console" in source
assert "send(" not in source
assert source.count("function aardwolf_console.") >= 5
assert "function aardwolf_console.lifecycle.initialize" in source
assert "function aardwolf_console.lifecycle.shutdown" in source




