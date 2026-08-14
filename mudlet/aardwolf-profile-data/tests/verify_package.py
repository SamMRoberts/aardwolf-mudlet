#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-profile-data"
assert metadata["namespace"] == "aardwolf_profile_data"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_profile_data" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_profile_data" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_profile_data.commands." in action
source = (root / "src" / "scripts" / "aardwolf_profile_data" / "aardwolf_profile_data_main.lua").read_text()
assert "aardwolf_profile_data" in source
assert "send(" not in source
assert source.count("function aardwolf_profile_data.") >= 5
assert "function aardwolf_profile_data.lifecycle.initialize" in source
assert "function aardwolf_profile_data.lifecycle.shutdown" in source

assert "commands.export" in source and "commands.import" in source and "io.open" in source and "io.popen" not in source


