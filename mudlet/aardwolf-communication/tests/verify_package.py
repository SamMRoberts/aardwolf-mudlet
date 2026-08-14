#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-communication"
assert metadata["namespace"] == "aardwolf_communication"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_communication" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_communication" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_communication.commands." in action
source = (root / "src" / "scripts" / "aardwolf_communication" / "aardwolf_communication_main.lua").read_text()
assert "aardwolf_communication" in source
assert "send(" not in source
assert source.count("function aardwolf_communication.") >= 5
assert "function aardwolf_communication.lifecycle.initialize" in source
assert "function aardwolf_communication.lifecycle.shutdown" in source



assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source
