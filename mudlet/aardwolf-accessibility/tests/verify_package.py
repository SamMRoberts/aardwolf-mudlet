#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-accessibility"
assert metadata["namespace"] == "aardwolf_accessibility"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_accessibility" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_accessibility" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_accessibility.commands." in action
source = (root / "src" / "scripts" / "aardwolf_accessibility" / "aardwolf_accessibility_main.lua").read_text()
assert "aardwolf_accessibility" in source
assert "send(" not in source
assert source.count("function aardwolf_accessibility.") >= 5
assert "function aardwolf_accessibility.lifecycle.initialize" in source
assert "function aardwolf_accessibility.lifecycle.shutdown" in source


assert "ttsQueue" in source and "ttsClearQueue" in source and "Text-to-speech is unavailable" in source

