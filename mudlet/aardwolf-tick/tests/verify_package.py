#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-tick"
assert metadata["namespace"] == "aardwolf_tick"
assert metadata["version"] == "1.1.0"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_tick" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_tick" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_tick.commands." in action
source = (root / "src" / "scripts" / "aardwolf_tick" / "aardwolf_tick_main.lua").read_text()
assert "aardwolf_tick" in source
assert "send(" not in source
assert source.count("function aardwolf_tick.") >= 5
assert "function aardwolf_tick.lifecycle.initialize" in source
assert "function aardwolf_tick.lifecycle.shutdown" in source
assert "TICK_DURATION = 30" in source and "state.remaining" in source
assert "Updated from gmcp.comm.tick" not in source
assert "payload == nil" not in source
assert (root / "tests" / "tick_stub_spec.lua").is_file()



assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source
