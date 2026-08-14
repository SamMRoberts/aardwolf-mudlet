#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-interface"
assert metadata["namespace"] == "aardwolf_interface"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_interface" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_interface" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_interface.commands." in action
source = (root / "src" / "scripts" / "aardwolf_interface" / "aardwolf_interface_main.lua").read_text()
assert "aardwolf_interface" in source
assert "send(" not in source
assert source.count("function aardwolf_interface.") >= 5
assert "function aardwolf_interface.lifecycle.initialize" in source
assert "function aardwolf_interface.lifecycle.shutdown" in source
assert "Geyser.Label:new" in source and "sysWindowResizeEvent" in source and ":delete()" in source


assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source
