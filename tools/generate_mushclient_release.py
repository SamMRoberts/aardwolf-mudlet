#!/usr/bin/env python3
"""Generate the safe feature-package source projects and conversion retirement ledger."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Feature:
    name: str
    namespace: str
    description: str
    source_plugins: tuple[str, ...]
    events: tuple[tuple[str, str, str], ...]
    aliases: tuple[tuple[str, str, str], ...]
    kind: str = "standard"
    version: str = "1.0.0"


FEATURES = (
    Feature(
        "aardwolf-gmcp-diagnostics", "aardwolf_gmcp_diagnostics", "Safe native GMCP state diagnostics for Aardwolf.",
        ("aard_GMCP_handler",),
        (("gmcp.room.info", "gmcp and gmcp.room and gmcp.room.info", "room_info"), ("gmcp.char.vitals", "gmcp and gmcp.char and gmcp.char.vitals", "vitals"), ("gmcp.comm.tick", "gmcp and gmcp.comm and gmcp.comm.tick", "tick")),
        (("status", "^aard gmcp status$", "aardwolf_gmcp_diagnostics.commands.status()"), ("toggle", "^gmcpdebug (on|off)$", "aardwolf_gmcp_diagnostics.commands.set_enabled(matches[2] == 'on')")),
    ),
    Feature(
        "aardwolf-tick", "aardwolf_tick", "Direct GMCP tick status with a text-first accessible fallback.",
        ("Aardwolf_Tick_Timer",),
        (("gmcp.comm.tick", "gmcp and gmcp.comm and gmcp.comm.tick", "tick"),),
        (("status", "^aard tick( help| miniwin| status)?$", "aardwolf_tick.commands.status()"), ("reset", "^aard tick reset$", "aardwolf_tick.commands.reset()")),
    ),
    Feature(
        "aardwolf-console", "aardwolf_console", "Safe console controls and migration help for output plugins.",
        ("aard_Command_Tag_Handler", "aard_Copy_Colour_Codes", "aard_VI_command_output", "aard_keyboard_lockout", "aard_prompt_fixer", "aard_repaint_buffer", "aard_text_substitution"),
        (),
        (("status", "^aard console status$", "aardwolf_console.commands.status()"), ("toggle", "^showcommandtags(.*)$", "aardwolf_console.commands.toggle()")),
    ),
    Feature(
        "aardwolf-communication", "aardwolf_communication", "Namespaced channel and chat visibility controls using native GMCP.",
        ("aard_channels_fiendish", "aard_chat_echo", "aard_translate_foreign_friends"),
        (("gmcp.comm.channel", "gmcp and gmcp.comm and gmcp.comm.channel", "channel"),),
        (("status", "^aard comm status$", "aardwolf_communication.commands.status()"), ("toggle", "^chats? echo( on| off| channels| nonchannels)?$", "aardwolf_communication.commands.set_enabled(matches[2] ~= ' off')")),
    ),
    Feature(
        "aardwolf-character", "aardwolf_character", "Text-first character, group, and vital-status summaries from GMCP.",
        ("aard_group_monitor_gmcp", "aard_health_bars_gmcp", "aard_statmon_gmcp"),
        (("gmcp.char.vitals", "gmcp and gmcp.char and gmcp.char.vitals", "vitals"), ("gmcp.group", "gmcp and gmcp.group", "group")),
        (("status", "^aard character status$", "aardwolf_character.commands.status()"), ("group_on", "^groupon$", "aardwolf_character.commands.set_enabled(true)"), ("group_off", "^groupoff$", "aardwolf_character.commands.set_enabled(false)")),
    ),
    Feature(
        "aardwolf-help", "aardwolf_help", "Accessible in-client help and migration guidance.",
        ("MUSHclient_Help", "aard_help", "aard_ingame_help_window", "plugin_list", "plugin_summary"),
        (),
        (("help", "^aard help$", "aardwolf_help.commands.status()"), ("legacy_help", "^mchelps?(?: .*)?$", "aardwolf_help.commands.status()")),
    ),
    Feature(
        "aardwolf-interface", "aardwolf_interface", "Responsive Aardwolf Geyser dashboard with an accessible text fallback.",
        ("aard_Theme_Controller", "aard_layout", "aard_miniwindow_z_order_monitor", "aard_splitscreen_scrollback"),
        (("window_resize", "true", "window_resize"),),
        (
            ("status", "^aard interface status$", "aardwolf_interface.commands.status()"),
            ("show", "^aard interface show$", "aardwolf_interface.commands.show()"),
            ("hide", "^aard interface hide$", "aardwolf_interface.commands.hide()"),
            ("theme", "^aard theme change$", "aardwolf_interface.commands.toggle_theme()"),
        ),
        "interface", "1.1.2",
    ),
    Feature(
        "aardwolf-profile-data", "aardwolf_profile_data", "Explicit local profile note export and import tools.",
        ("Automatic_Backup", "Config_Option_Changer", "aard_inventory_serials", "aard_new_connection", "aard_new_connection_no_UI", "aard_note_mode", "aard_package_update_checker", "aard_requirements"),
        (),
        (("status", "^aard data status$", "aardwolf_profile_data.commands.status()"), ("note", "^aard data note (.+)$", "aardwolf_profile_data.commands.note(matches[2])"), ("export", "^aard data export$", "aardwolf_profile_data.commands.export()"), ("import", "^aard data import$", "aardwolf_profile_data.commands.import()")),
        "profile-data",
    ),
    Feature(
        "aardwolf-accessibility", "aardwolf_accessibility", "Portable Mudlet text-to-speech controls without native libraries.",
        ("SAPI", "universal_text_to_speech"),
        (),
        (("status", "^tts(?: (?:focus|help|running))?$", "aardwolf_accessibility.commands.status()"), ("toggle", "^sapi (on|off)$", "aardwolf_accessibility.commands.set_enabled(matches[2] == 'on')"), ("say", "^sapi say (.+)$", "aardwolf_accessibility.commands.speak(matches[2])"), ("note", "^tts_note (.+)$", "aardwolf_accessibility.commands.speak(matches[2])"), ("clear", "^sapi (?:clear|skip)$", "aardwolf_accessibility.commands.clear()"), ("stop", "^tts_stop$", "aardwolf_accessibility.commands.clear()"), ("rate", "^sapi (faster|slower)$", "aardwolf_accessibility.commands.rate(matches[2])"), ("rate_value", "^sapi rate(?: (.+))?$", "aardwolf_accessibility.commands.rate_value(matches[2])"), ("voices", "^sapi list voices$", "aardwolf_accessibility.commands.voices()"), ("voice", "^sapi voice (.+)$", "aardwolf_accessibility.commands.voice(matches[2])"), ("status_help", "^sapi (?:debug|filtering(?: .*)?|help(?: printed)?)$", "aardwolf_accessibility.commands.status()"), ("test", "^sapi test$", "aardwolf_accessibility.commands.speak('Text-to-speech test.')"), ("interrupt", "^tts_interrupt (.*)$", "aardwolf_accessibility.commands.interrupt(matches[2])")),
        "accessibility",
    ),
)

FEATURE_BY_SOURCE = {source: feature for feature in FEATURES for source in feature.source_plugins}
MALFORMED = {"Aardwolf_Bigmap_Graphical", "aard_ASCII_map", "aard_GMCP_mapper", "aard_soundpack", "aard_vi_review_buffers", "aard_vital_shortcuts"}
CURRENT_CONVERTED = {
    "source:Time/metadata:plugin",
    "source:Time/script:1",
    "source:Omit_Blank_Lines/metadata:plugin",
    "source:Omit_Blank_Lines/trigger:1",
}
REPLACED_ALIASES = {
    "source:Aardwolf_Tick_Timer/alias:aard-tick-help-miniwin-status",
    "source:Aardwolf_Tick_Timer/alias:resetaard",
    "source:aard_Command_Tag_Handler/alias:showcommandtags-.",
    "source:aard_chat_echo/alias:chats-echo-on-off-channels-nonchannels",
    "source:aard_group_monitor_gmcp/alias:groupon",
    "source:aard_group_monitor_gmcp/alias:groupoff",
    "source:MUSHclient_Help/alias:mchelp-.",
    "source:MUSHclient_Help/alias:mchelp-d",
    "source:MUSHclient_Help/alias:mchelps",
    "source:MUSHclient_Help/alias:mchelps-.",
    "source:aard_Theme_Controller/alias:aard-theme-change",
    "source:aard_help/alias:aard-help",
}

PORTABLE_UI_SOURCES = {
    "Aardwolf_Tick_Timer",
    "aard_group_monitor_gmcp",
    "aard_health_bars_gmcp",
    "aard_layout",
    "aard_miniwindow_z_order_monitor",
    "aard_statmon_gmcp",
}


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def slug(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_]+", "_", value).strip("_").lower() or "item"


def module_sources(feature: Feature) -> dict[str, str]:
    namespace = feature.namespace
    state = f'''{namespace} = {namespace} or {{}}
{namespace}.state = {namespace}.state or {{}}

function {namespace}.state.record(key, value)
  {namespace}.state.values = {namespace}.state.values or {{}}
  {namespace}.state.values[key] = value
  {namespace}.state.update_count = ({namespace}.state.update_count or 0) + 1
end

function {namespace}.state.reset()
  {namespace}.state.values = {{}}
  {namespace}.state.update_count = 0
end

function {namespace}.state.summary()
  return "updates=" .. tostring({namespace}.state.update_count or 0)
end
'''
    settings = f'''{namespace} = {namespace} or {{}}
{namespace}.settings = {namespace}.settings or {{}}

function {namespace}.settings.is_enabled()
  return {namespace}.settings.enabled ~= false
end

function {namespace}.settings.set_enabled(enabled)
  {namespace}.settings.enabled = enabled and true or false
end
'''
    ui = f'''{namespace} = {namespace} or {{}}
{namespace}.ui = {namespace}.ui or {{}}

function {namespace}.ui.message(message)
  echo("\\n[{feature.name}] " .. tostring(message) .. "\\n")
end

function {namespace}.ui.status(summary)
  {namespace}.ui.message("Status: " .. tostring(summary))
end
'''
    commands = f'''{namespace} = {namespace} or {{}}
{namespace}.commands = {namespace}.commands or {{}}

function {namespace}.commands.status()
  {namespace}.ui.status({namespace}.state.summary())
end

function {namespace}.commands.set_enabled(enabled)
  {namespace}.settings.set_enabled(enabled)
  {namespace}.ui.message(enabled and "Enabled." or "Disabled.")
end

function {namespace}.commands.toggle()
  {namespace}.commands.set_enabled(not {namespace}.settings.is_enabled())
end

function {namespace}.commands.reset()
  {namespace}.state.reset()
  {namespace}.ui.message("State reset.")
end
'''
    protocol_parts = [f"{namespace} = {namespace} or {{}}", f"{namespace}.protocol = {namespace}.protocol or {{}}", ""]
    handler_rows = []
    for event_name, expression, label in feature.events:
        function_name = f"on_{slug(label)}"
        protocol_parts.extend([
            f"function {namespace}.protocol.{function_name}()",
            f"  local payload = {expression}",
            "  if payload == nil then",
            "    return",
            "  end",
            f"  {namespace}.state.record(\"{label}\", payload)",
            f"  if {namespace}.settings.is_enabled() then",
            f"    {namespace}.ui.message(\"Updated from {event_name}.\")",
            "  end",
            "end",
            "",
        ])
        handler_rows.append((event_name, function_name, label))
    if not feature.events:
        protocol_parts.extend([
            f"function {namespace}.protocol.describe()",
            f"  return \"{feature.description}\"",
            "end",
            "",
        ])
    protocol = "\n".join(protocol_parts)
    lifecycle_parts = [f"{namespace} = {namespace} or {{}}", f"{namespace}.lifecycle = {namespace}.lifecycle or {{}}", ""]
    lifecycle_parts.extend([f"function {namespace}.lifecycle.initialize()"])
    for event_name, function_name, label in handler_rows:
        handler_name = f"{feature.name}::event::{label}"
        lifecycle_parts.extend([
            f"  deleteNamedEventHandler(\"{namespace}\", \"{handler_name}\")",
            f"  registerNamedEventHandler(\"{namespace}\", \"{handler_name}\", \"{event_name}\", {namespace}.protocol.{function_name})",
        ])
    lifecycle_parts.extend(["end", "", f"function {namespace}.lifecycle.shutdown()"])
    for _, _, label in handler_rows:
        lifecycle_parts.append(f"  deleteNamedEventHandler(\"{namespace}\", \"{feature.name}::event::{label}\")")
    lifecycle_parts.extend(["end", "", f"{namespace}.lifecycle.initialize()", ""])
    help_source = f'''{namespace} = {namespace} or {{}}
{namespace}.help = {namespace}.help or {{}}

function {namespace}.help.summary()
  return "{feature.description}"
end
'''
    return {
        "state": state,
        "settings": settings,
        "commands": commands,
        "protocol": protocol,
        "ui": ui,
        "lifecycle": "\n".join(lifecycle_parts),
        "help": help_source,
    }


def accessibility_sources(feature: Feature) -> dict[str, str]:
    sources = module_sources(feature)
    namespace = feature.namespace
    sources["commands"] = f'''{namespace} = {namespace} or {{}}
{namespace}.commands = {namespace}.commands or {{}}

function {namespace}.commands.status()
  local voices = type(ttsGetVoices) == "function" and ttsGetVoices() or {{}}
  {namespace}.ui.status("enabled=" .. tostring({namespace}.settings.is_enabled()) .. "; voices=" .. tostring(#voices))
end

function {namespace}.commands.set_enabled(enabled)
  {namespace}.settings.set_enabled(enabled)
  {namespace}.ui.message(enabled and "Text-to-speech enabled." or "Text-to-speech disabled.")
end

function {namespace}.commands.speak(text)
  if not {namespace}.settings.is_enabled() or type(text) ~= "string" or text == "" then
    return
  end
  if type(ttsQueue) == "function" then
    ttsQueue(text)
  else
    {namespace}.ui.message("Text-to-speech is unavailable in this Mudlet profile.")
  end
end

function {namespace}.commands.clear()
  if type(ttsClearQueue) == "function" then
    ttsClearQueue()
  end
end

function {namespace}.commands.rate(direction)
  if type(ttsGetRate) ~= "function" or type(ttsSetRate) ~= "function" then
    {namespace}.ui.message("Text-to-speech rate control is unavailable.")
    return
  end
  local current = ttsGetRate() or 0
  local delta = direction == "faster" and 0.1 or -0.1
  ttsSetRate(current + delta)
end

function {namespace}.commands.rate_value(value)
  if value == nil or value == "" then
    if type(ttsGetRate) == "function" then
      {namespace}.ui.message("Current text-to-speech rate: " .. tostring(ttsGetRate()))
    end
    return
  end
  local rate = tonumber(value)
  if rate and type(ttsSetRate) == "function" then
    ttsSetRate(rate)
  else
    {namespace}.ui.message("Text-to-speech rate control is unavailable.")
  end
end

function {namespace}.commands.voices()
  local voices = type(ttsGetVoices) == "function" and ttsGetVoices() or {{}}
  {namespace}.ui.message("Available voices: " .. tostring(#voices))
end

function {namespace}.commands.voice(name)
  if type(ttsSetVoiceByName) == "function" and type(name) == "string" and name ~= "" then
    ttsSetVoiceByName(name)
  end
end

function {namespace}.commands.interrupt(text)
  {namespace}.commands.clear()
  {namespace}.commands.speak(text)
end
'''
    return sources


def profile_data_sources(feature: Feature) -> dict[str, str]:
    sources = module_sources(feature)
    namespace = feature.namespace
    sources["state"] = sources["state"] + f'''
function {namespace}.state.note(text)
  {namespace}.state.notes = {namespace}.state.notes or {{}}
  table.insert({namespace}.state.notes, text)
end
'''
    sources["commands"] = f'''{namespace} = {namespace} or {{}}
{namespace}.commands = {namespace}.commands or {{}}

function {namespace}.commands.status()
  {namespace}.ui.status("notes=" .. tostring(#({namespace}.state.notes or {{}})))
end

function {namespace}.commands.note(text)
  if type(text) == "string" and text ~= "" then
    {namespace}.state.note(text)
    {namespace}.ui.message("Note added to the local export set.")
  end
end

function {namespace}.commands.file_path()
  return getMudletHomeDir() .. "/aardwolf-profile-data.json"
end

function {namespace}.commands.export()
  local file, error_message = io.open({namespace}.commands.file_path(), "w")
  if not file then
    {namespace}.ui.message("Export failed: " .. tostring(error_message))
    return
  end
  file:write(yajl.to_string({{notes = {namespace}.state.notes or {{}}}}))
  file:close()
  {namespace}.ui.message("Exported local notes by explicit request.")
end

function {namespace}.commands.import()
  local file = io.open({namespace}.commands.file_path(), "r")
  if not file then
    {namespace}.ui.message("No local export file was found.")
    return
  end
  local contents = file:read("*a")
  file:close()
  local succeeded, value = pcall(yajl.to_value, contents)
  if succeeded and type(value) == "table" and type(value.notes) == "table" then
    {namespace}.state.notes = value.notes
    {namespace}.ui.message("Imported local notes by explicit request.")
  else
    {namespace}.ui.message("The local export file is invalid.")
  end
end
'''
    return sources


def interface_sources(feature: Feature) -> dict[str, str]:
    implementation = (ROOT / "tools" / "templates" / "aardwolf_interface_main.lua").read_text(encoding="utf-8")
    return {
        module: implementation if module == "state" else ""
        for module in ("state", "settings", "commands", "protocol", "ui", "lifecycle", "help")
    }

def write_feature(feature: Feature, destination: Path) -> None:
    sources = accessibility_sources(feature) if feature.kind == "accessibility" else profile_data_sources(feature) if feature.kind == "profile-data" else interface_sources(feature) if feature.kind == "interface" else module_sources(feature)
    write(destination / ".gitignore", "/build/\n")
    write(destination / "package-metadata.json", json.dumps({"schema_version": 1, "name": feature.name, "version": feature.version, "namespace": feature.namespace, "minimum_mudlet_version": "4.14", "description": feature.description, "game": "Aardwolf"}, indent=2, sort_keys=True) + "\n")
    write(destination / "mfile", json.dumps({
        "author": "Aardwolf Mudlet",
        "description": feature.description,
        "package": feature.name,
        "title": feature.name.replace("aardwolf-", "Aardwolf ").replace("-", " ").title(),
        "version": feature.version,
    }, indent=2, sort_keys=True) + "\n")
    aliases = []
    alias_dir = destination / "src" / "aliases" / feature.namespace
    for name, regex, action in feature.aliases:
        object_name = f"{feature.namespace}.{name}"
        aliases.append({"name": object_name, "regex": regex})
        write(alias_dir / f"{slug(object_name)}.lua", action + "\n")
    write(alias_dir / "aliases.json", json.dumps(aliases, indent=2) + "\n")
    for category in ("triggers", "timers", "keys", "resources"):
        write(destination / "src" / category / "EMPTY-CATEGORY.md", f"# No {category}\n\nThis package has no declarative {category}.\n")
    script_dir = destination / "src" / "scripts" / feature.namespace
    # These generated projects intentionally keep their runtime in one cohesive
    # Mudlet script. Alias action files are declarative object glue; splitting
    # the implementation into one-file-per-function makes the package harder
    # to inspect, maintain, and uninstall safely.
    for stale in script_dir.glob(f"{feature.namespace}_*.lua"):
        stale.unlink()
    object_name = f"{feature.namespace}.main"
    implementation = sources["state"] if feature.kind == "interface" else "\n".join(
        sources[module]
        for module in ("state", "settings", "ui", "commands", "protocol", "lifecycle", "help")
    )
    write(script_dir / f"{slug(object_name)}.lua", implementation)
    script_specs = [{"name": object_name}]
    write(script_dir / "scripts.json", json.dumps(script_specs, indent=2) + "\n")
    source_list = ", ".join(f"`{source}`" for source in feature.source_plugins)
    command_list = ", ".join(f"`{regex}`" for _, regex, _ in feature.aliases)
    event_list = ", ".join(f"`{event}`" for event, _, _ in feature.events) or "none"
    runtime_boundary = (
        "The dashboard consumes direct `gmcp.char.*`, `gmcp.group`, `gmcp.room.info`, and `gmcp.comm.tick` events. It creates a reserved right sidebar after install/profile load, sends no game commands, and restores its border and shared mapper ownership through `aardwolf_interface.lifecycle.shutdown()`."
        if feature.kind == "interface"
        else f"GMCP events: {event_list}. The package uses namespaced handlers, sends no game commands, and removes its handlers through `{feature.namespace}.lifecycle.shutdown()`."
    )
    help_text = (
        "Run `aard interface show` or `aard interface hide` to control the right sidebar. Character and group values are arranged in readable rich-text rows, and empty group state collapses to preserve mapper space. `aard interface status` prints the same essential room, vital, group, tick, and mapper state as a text fallback. `aard theme change` cycles the dark and high-contrast themes. Visibility and theme are stored as JSON data in `aardwolf-interface/settings.lua` below the Mudlet profile; the file is never executed as Lua. While visible, the sidebar owns Mudlet's singleton mapper display, temporarily hides Mudlet 4.20+'s adjacent-floor overlay, and restores both that preference and a previously visible `generic_mapper` view when hidden or unloaded. The package never recreates raw telnet, DLL, Windows API, cross-plugin broadcast, unattended network behavior, or game-command sending."
        if feature.kind == "interface"
        else "Run a supported status alias to inspect the current state. The package never recreates raw telnet, DLL, Windows API, cross-plugin broadcast, or unattended network behavior."
    )
    feature_notes = '''
## Dashboard behavior

The sidebar appears automatically on first install and then remembers explicit show/hide and theme choices. It reserves 340–480 pixels at the right edge without overwriting an existing right border. Missing or partial GMCP remains visibly unavailable instead of being shown as zero.

Mudlet has one native mapper display per profile. While this dashboard is visible it owns that display; hiding or unloading the package restores a `generic_mapper` view that was visible before the dashboard claimed it. The dashboard never imports, creates, edits, or deletes map rooms. Use `aard map import` from `aardwolf-map` to populate the packaged Aardwolf snapshot.

In Mudlet 4.20 and newer, the dashboard temporarily disables the global `showUpperLowerLevels` overlay while its narrow embedded mapper is visible. This prevents adjacent floors from appearing stacked behind the active floor. The prior value is restored on hide, reload, or unload, and older Mudlet versions use capability-checked fallback behavior.

The room, tick, character, and group sections use escaped rich-text rows so Qt does not collapse intended line breaks into a single dense line. Empty group state stays compact to preserve mapper space in shorter profile windows.

For upgrades, remove an older `aardwolf-interface` or `aardwolf-mudlet-suite` package before installing 1.1.2 so Mudlet does not retain duplicate static objects.
''' if feature.kind == "interface" else ""
    write(destination / "README.md", f'''# {feature.name}

{feature.description}

## Compatibility

This package is a safe native Mudlet replacement for selected behavior from {source_list}. Supported aliases: {command_list}. Colliding, raw-protocol, automated-network, and source-specific behaviors are documented in the collection retirement ledger.

## Runtime boundary

{runtime_boundary}

{feature_notes}
Use the generated `.mpackage` in `dist/` for installation. The raw XML only contains Mudlet objects.
''')
    write(destination / "HELP.md", f'''# {feature.name} help

{feature.description}

{help_text}
''')
    write(destination / "dist" / "README.md", f'''# {feature.name} release artifacts

Install `{feature.name}.mpackage` in Mudlet. It contains the Mudlet objects and any declared resources. `{feature.name}.xml` is the raw Mudlet object export for inspection or controlled import.

Artifacts are regenerated by the native package builder after the source and release validators pass.
''')
    interface_assertions = '''assert "Geyser.Container:new" in source and "Geyser.Gauge:new" in source and "Geyser.Mapper:new" in source
assert (root / "tests" / "interface_stub_spec.lua").is_file()
assert "commands.show" in source and "commands.hide" in source and "commands.toggle_theme" in source
assert "settings.lua" in source and "yajl.to_value" in source and "table.load" not in source
assert "setBorderRight" in source and "getBorderRight" in source and "map.showMap" in source
assert "showUpperLowerLevels" in source and "getConfig" in source and "setConfig" in source
assert '<table width="100%%"' in source and "<b>Hitroll</b>" in source and "group_row_capacity" in source
assert all(event in source for event in ("gmcp.char.base", "gmcp.char.vitals", "gmcp.char.maxstats", "gmcp.char.status", "gmcp.char.stats", "gmcp.char.worth", "gmcp.group", "gmcp.room.info", "gmcp.comm.tick"))
assert "sysInstall" in source and "sysLoadEvent" in source and "sysWindowResizeEvent" in source and "sysUninstallPackage" in source and "sysExitEvent" in source
assert "send(" not in source and "downloadFile" not in source and "io.popen" not in source and "loadstring" not in source
''' if feature.kind == "interface" else ""
    version_assertion = (
        f'\nassert metadata["version"] == "{feature.version}"'
        if feature.kind == "interface"
        else ""
    )
    test = f'''#!/usr/bin/env python3
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
metadata = json.loads((root / "package-metadata.json").read_text())
assert metadata["name"] == "{feature.name}"
assert metadata["namespace"] == "{feature.namespace}"{version_assertion}
aliases = json.loads((root / "src" / "aliases" / "{feature.namespace}" / "aliases.json").read_text())
assert aliases
for alias in aliases:
    action = (root / "src" / "aliases" / "{feature.namespace}" / (alias["name"].replace(".", "_") + ".lua")).read_text()
    assert "{feature.namespace}.commands." in action
source = (root / "src" / "scripts" / "{feature.namespace}" / "{feature.namespace}_main.lua").read_text()
assert "{feature.namespace}" in source
assert "send(" not in source
assert source.count("function {feature.namespace}.") >= 5
assert "function {feature.namespace}.lifecycle.initialize" in source
assert "function {feature.namespace}.lifecycle.shutdown" in source
{interface_assertions}
{'assert "commands.export" in source and "commands.import" in source and "io.open" in source and "io.popen" not in source' if feature.kind == 'profile-data' else ''}
{'assert "ttsQueue" in source and "ttsClearQueue" in source and "Text-to-speech is unavailable" in source' if feature.kind == 'accessibility' else ''}
{'assert "registerNamedEventHandler" in source and "deleteNamedEventHandler" in source' if feature.events else ''}
'''
    write(destination / "tests" / "verify_package.py", test)


def source_plugin(item_id: str) -> str | None:
    if not item_id.startswith("source:"):
        return None
    return item_id.split("/", 1)[0].removeprefix("source:")


def retirement_for(item: dict[str, Any], feature: Feature | None) -> tuple[str, str, str]:
    item_id = item["id"]
    plugin = source_plugin(item_id)
    if item_id.startswith("companion:"):
        return ("Original companion resources are not redistributed.", "Use only assets declared by a portable destination package.", "Companion source remains inventory-only; no asset was copied.")
    if plugin in MALFORMED:
        migration = "Use aardwolf-map for supported map import." if plugin == "aard_GMCP_mapper" else "No safe behavior can be established from the supplied malformed source."
        return ("The source could not be inspected safely.", migration, "Malformed or external-entity source was intentionally retired.")
    if plugin == "aard_package_update_checker":
        return ("Automatic update checks are retired to avoid unattended network access.", "Check release artifacts manually.", "Automatic network behavior was intentionally retired.")
    if item.get("kind") in {"windows-api", "dll-loading"} or "windows-api" in item.get("signals", []) or "dll-loading" in item.get("signals", []):
        return ("Windows or native-library behavior is not portable.", "Use aardwolf-accessibility for Mudlet-native text-to-speech or aardwolf-gmcp-diagnostics for native GMCP.", "No DLL, Windows API, or raw protocol replacement is shipped.")
    if feature:
        return ("The exact MUSHclient object is not ported verbatim.", f"Use {feature.name}'s documented native Mudlet commands and lifecycle.", "The safe replacement keeps only the documented feature boundary.")
    return ("The source behavior has no safe portable Mudlet equivalent.", "No replacement is available in this release.", "Behavior was intentionally retired after static review.")


def decisions(inventory: dict[str, Any]) -> tuple[dict[str, Any], str]:
    output: list[dict[str, Any]] = []
    retirement_rows = ["# Intentional retirements", "", "Every item below was reviewed from the read-only source inventory. These are explicit release decisions, not untracked omissions.", "", "| Item | User impact | Migration |", "| --- | --- | --- |"]
    for item in inventory["items"]:
        item_id = item["id"]
        plugin = source_plugin(item_id)
        feature = FEATURE_BY_SOURCE.get(plugin or "")
        if item_id in CURRENT_CONVERTED:
            output.append({"item_id": item_id, "status": "converted", "reason": "The existing compatibility package preserves this reviewed behavior.", "target_paths": ["src"]})
            continue
        if plugin and feature and item["kind"] == "metadata":
            output.append({"item_id": item_id, "status": "converted", "reason": f"Metadata is represented by the native {feature.name} package.", "target_paths": [f"mudlet/{feature.name}/package-metadata.json"]})
            continue
        if plugin and feature and item["kind"] == "gmcp-dependency":
            targets = [f"mudlet/{feature.name}/src/scripts/{feature.namespace}"]
            dashboard_target = plugin in PORTABLE_UI_SOURCES
            if dashboard_target and "mudlet/aardwolf-interface/src/scripts/aardwolf_interface" not in targets:
                targets.append("mudlet/aardwolf-interface/src/scripts/aardwolf_interface")
            reason = (
                f"The replacement consumes direct native GMCP in {feature.name} and the Aardwolf dashboard."
                if dashboard_target
                else f"The replacement consumes a direct native GMCP event in {feature.name}."
            )
            output.append({"item_id": item_id, "status": "converted-with-review", "reason": reason, "target_paths": targets})
            continue
        if plugin in PORTABLE_UI_SOURCES and item["kind"] == "miniwindow-api":
            output.append({"item_id": item_id, "status": "converted-with-review", "reason": "The portable presentation use case is replaced by the responsive native Geyser dashboard; exact MUSHclient window mechanics remain retired with their owning scripts.", "target_paths": ["mudlet/aardwolf-interface/src/scripts/aardwolf_interface"]})
            continue
        if plugin == "Aardwolf_Tick_Timer" and item["kind"] == "timer":
            output.append({"item_id": item_id, "status": "converted-with-review", "reason": "Tick status is replaced with the direct gmcp.comm.tick event.", "target_paths": ["mudlet/aardwolf-tick/src/scripts/aardwolf_tick"]})
            continue
        if item_id in REPLACED_ALIASES:
            output.append({"item_id": item_id, "status": "converted-with-review", "reason": "The non-conflicting alias is preserved or moved to a documented aard command when it collides.", "target_paths": [f"mudlet/{feature.name}/src/aliases/{feature.namespace}"] if feature else ["reports/retirements.md"]})
            continue
        if plugin in {"SAPI", "universal_text_to_speech"} and item["kind"] == "alias":
            output.append({"item_id": item_id, "status": "converted-with-review", "reason": "Portable aliases are implemented with Mudlet's native text-to-speech API.", "target_paths": ["mudlet/aardwolf-accessibility/src/aliases/aardwolf_accessibility"]})
            continue
        user_impact, migration, reason = retirement_for(item, feature)
        output.append({"item_id": item_id, "status": "intentionally-retired", "reason": reason, "target_paths": ["reports/retirements.md"], "retirement": {"user_impact": user_impact, "migration": migration}})
        retirement_rows.append(f"| `{item_id}` | {user_impact} | {migration} |")
    return {"decisions": output}, "\n".join(retirement_rows) + "\n"


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--collection", default=ROOT / "mudlet" / "aardwolf-mushclient-collection", type=Path)
    parser.add_argument("--mudlet-root", default=ROOT / "mudlet", type=Path)
    args = parser.parse_args(arguments)
    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    if inventory.get("schema_version") != 1 or not isinstance(inventory.get("items"), list):
        raise SystemExit("inventory must be a schema v1 document")
    decision_document, retirement_document = decisions(inventory)
    write(args.collection / "reports" / "decisions.json", json.dumps(decision_document, indent=2, sort_keys=True) + "\n")
    write(args.collection / "reports" / "retirements.md", retirement_document)
    for feature in FEATURES:
        write_feature(feature, args.mudlet_root / feature.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
