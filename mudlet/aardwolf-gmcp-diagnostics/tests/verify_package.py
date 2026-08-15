#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-gmcp-diagnostics"
assert metadata["namespace"] == "aardwolf_gmcp_diagnostics"
assert metadata["version"] == "1.1.0"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_gmcp_diagnostics" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_gmcp_diagnostics" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_gmcp_diagnostics.commands." in action
source = (root / "src" / "scripts" / "aardwolf_gmcp_diagnostics" / "aardwolf_gmcp_diagnostics_main.lua").read_text()
assert "aardwolf_gmcp_diagnostics" in source
assert "send(" not in source
assert source.count("function aardwolf_gmcp_diagnostics.") >= 5
assert "function aardwolf_gmcp_diagnostics.lifecycle.initialize" in source
assert "function aardwolf_gmcp_diagnostics.lifecycle.shutdown" in source
assert "settings.enabled == true" in source
assert "settings.enabled ~= false" not in source
assert "Diagnostic console logging enabled." in source
assert (root / "tests" / "diagnostics_stub_spec.lua").is_file()



assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source
