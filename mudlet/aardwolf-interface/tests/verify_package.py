#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "aardwolf-interface"
assert metadata["namespace"] == "aardwolf_interface"
assert metadata["version"] == "1.3.0"
aliases = json.loads((root / "src" / "aliases" / "aardwolf_interface" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "aardwolf_interface" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "aardwolf_interface.commands." in action
source = (root / "src" / "scripts" / "aardwolf_interface" / "aardwolf_interface_main.lua").read_text()
assert "aardwolf_interface" in source
assert "sendRaw" not in source and "sendSocket" not in source
assert source.count("function aardwolf_interface.") >= 5
assert "function aardwolf_interface.lifecycle.initialize" in source
assert "function aardwolf_interface.lifecycle.shutdown" in source
assert "Geyser.Container:new" in source and "Geyser.Gauge:new" in source and "Geyser.Mapper:new" in source and "Geyser.ScrollBox:new" in source
assert (root / "tests" / "interface_stub_spec.lua").is_file()
assert all(command in source for command in ("commands.show", "commands.hide", "commands.toggle_theme", "commands.details_show", "commands.details_hide", "commands.details_toggle", "commands.details_refresh", "commands.details_status"))
assert "settings.lua" in source and "yajl.to_value" in source and "table.load" not in source
assert "setBorderRight" in source and "getBorderRight" in source and "map.showMap" in source
assert "showUpperLowerLevels" in source and "getConfig" in source and "setConfig" in source
assert '<table width="100%%"' in source and "<b>Hitroll</b>" in source and "group_row_capacity" in source
assert all(event in source for event in ("gmcp.char.base", "gmcp.char.vitals", "gmcp.char.maxstats", "gmcp.char.status", "gmcp.char.stats", "gmcp.char.worth", "gmcp.group", "gmcp.room.info", "gmcp.comm.tick", "gmcp.config"))
assert "sysInstall" in source and "sysLoadEvent" in source and "sysWindowResizeEvent" in source and "sysUninstallPackage" in source and "sysExitEvent" in source
assert all(command in source for command in ('enqueue("eqdata"', 'enqueue("invdata"', 'enqueue("slist affected"', 'enqueue("resists"', '"invdetails "'))
assert "DETAIL_LIMIT = 100" in source and "capture_timeout" in source and "schedule_targeted" in source
assert 'widgets.tick = new_gauge("tick", primary)' in source and "TICK_DURATION = 30" in source and "tick-countdown" in source
assert "downloadFile" not in source and "io.popen" not in source and "loadstring" not in source



assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source
