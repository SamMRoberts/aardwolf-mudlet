#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-interface"
assert metadata["namespace"] == "aardwolf_interface"
assert metadata["version"] == "1.5.0"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_interface" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_interface" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_interface.commands." in action
script_dir = root / "src" / "scripts" / "aardwolf_interface"
source = "\n".join((script_dir / (spec["name"].replace(".", "_") + ".lua")).read_text() for spec in json.loads((script_dir / "scripts.json").read_text()))
assert "aardwolf_interface" in source
assert "sendRaw" not in source and "sendSocket" not in source
assert source.count("function aardwolf_interface.") >= 5
assert "function aardwolf_interface.lifecycle.initialize" in source
assert "function aardwolf_interface.lifecycle.shutdown" in source
assert "Geyser.Container" in source and "Geyser.Label" in source and "Geyser.Mapper" in source
assert (root / "tests" / "interface_stub_spec.lua").is_file()
assert all(command in source for command in ("commands.set_tab", "commands.toggle_pin", "commands.toggle_palette", "commands.summary", "commands.action_add"))
assert 'id="map-import"' in source and 'new_button("map-import"' in source and "aardwolf_map.commands.start_import" in source
assert "schema_version = SCHEMA_VERSION" in source and 'SCHEMA_VERSION = 4' in source and 'candidate.theme == "dark"' in source
assert "setBorderRight" in source and "setBorderBottom" in source and "Geyser.CommandLine:new" in source
assert all(event in source for event in ("gmcp.char.base", "gmcp.char.vitals", "gmcp.char.maxstats", "gmcp.char.status", "gmcp.char.stats", "gmcp.char.worth", "gmcp.group", "gmcp.room.info", "gmcp.comm.tick", "gmcp.comm.quest"))
assert "sysWindowResizeEvent" in source and "sysUninstallPackage" in source and "sysExitEvent" in source
assert "commands.repair" in source and "release_saved_claims" in source and "LEGACY_EVENT_PREFIX" in source
assert 'disableScript,"aardwolf_interface.main"' in source
assert "legacy_base_pending" in source and "legacy_base_right" in source
assert "if not aardwolf_interface.lifecycle.initialized then return end" not in source
assert all(command in source for command in ('command="eqdata"', 'command="invdata"', '"invdetails "'))
assert all(removed not in source for removed in ('slist affected', 'enqueue("resists"', 'tags spellup', 'details_affects', 'details_resists'))
assert "LIMIT, TIMER = 100" in source and "capture_timeout" in source and "Container ID did not match request" in source
assert "deleteLine" in source and "aardwolf_interface.actions.confirm" in source
assert 'payload and payload ~= "" and payload or line' not in source and 'command:find("[%c]")' in source
assert "send(pending.command, false)" in source and "room.name" not in source[source.find("function aardwolf_interface.actions.execute"):source.find("local function valid")]
assert "downloadFile" not in source and "io.popen" not in source and "loadstring" not in source



assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source
