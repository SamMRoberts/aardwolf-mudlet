#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-character"
assert metadata["namespace"] == "aardwolf_character"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_character" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_character" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_character.commands." in action
source = (root / "src" / "scripts" / "aardwolf_character" / "aardwolf_character_main.lua").read_text()
assert "aardwolf_character" in source
assert "send(" not in source
assert source.count("function aardwolf_character.") >= 5
assert "function aardwolf_character.lifecycle.initialize" in source
assert "function aardwolf_character.lifecycle.shutdown" in source



assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source
