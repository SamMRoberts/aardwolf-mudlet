#!/usr/bin/env python3
"""Create deterministic disposition and retirement reports for aardwolf-mudlet."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


EXPECTED = {"converted": 37, "converted-with-review": 234, "intentionally-retired": 251}

ALIAS_RETIRED_SOURCES = {
    "Config_Option_Changer", "MUSHclient_Help", "aard_inventory_serials", "aard_keyboard_lockout",
    "aard_package_update_checker", "aard_text_substitution", "plugin_list", "plugin_summary",
}
ALIAS_RETIRED_IDS = {
    "source:aard_GMCP_handler/alias:sendgmcp", "source:aard_chat_echo/alias:ig-n-no-nor-nore-w",
    "source:aard_ingame_help_window/alias:h-he-hel-help-.",
    "source:aard_ingame_help_window/alias:h-he-hel-help-search-.",
    "source:aard_layout/alias:aard-logo", "source:aard_layout/alias:resetmain",
    "source:aard_requirements/alias:aard-sounds-in-background", "source:SAPI/alias:sapi-debug",
    "source:SAPI/alias:sapi-filtering", "source:universal_text_to_speech/alias:sapi-filtering",
    "source:universal_text_to_speech/alias:tts-focus", "source:universal_text_to_speech/alias:tts-running",
}
SCRIPT_RETIRED_SOURCES = {
    "Automatic_Backup", "Config_Option_Changer", "MUSHclient_Help", "aard_keyboard_lockout",
    "aard_new_connection", "aard_new_connection_no_UI", "aard_note_mode", "aard_package_update_checker",
    "aard_prompt_fixer", "aard_splitscreen_scrollback", "aard_text_substitution",
    "aard_translate_foreign_friends",
}
CALLBACK_RETIRED_SOURCES = {
    "Automatic_Backup", "aard_keyboard_lockout", "aard_new_connection", "aard_new_connection_no_UI",
    "aard_note_mode", "aard_package_update_checker", "aard_prompt_fixer", "aard_repaint_buffer",
    "aard_splitscreen_scrollback", "aard_text_substitution", "aard_translate_foreign_friends",
}
CALLBACK_RETIRED_IDS = {
    "source:Aardwolf_Tick_Timer/callback:OnPluginTelnetOption",
    "source:aard_GMCP_handler/callback:OnPluginPacketReceived",
    "source:aard_GMCP_handler/callback:OnPluginTelnetRequest",
    "source:aard_GMCP_handler/callback:OnPluginTelnetSubnegotiation",
    "source:SAPI/callback:OnPluginScreendraw", "source:SAPI/callback:OnPluginTabComplete",
    "source:universal_text_to_speech/callback:OnPluginBroadcast",
    "source:universal_text_to_speech/callback:OnPluginGetFocus",
    "source:universal_text_to_speech/callback:OnPluginLoseFocus",
    "source:universal_text_to_speech/callback:OnPluginScreendraw",
    "source:universal_text_to_speech/callback:OnPluginTabComplete",
}
GMCP_RETIRED_SOURCES = {"aard_note_mode", "aard_prompt_fixer", "aard_translate_foreign_friends"}
DEPENDENCY_RETIRED_SOURCES = {
    "telnet_options.lua", "aard_keyboard_lockout", "aard_note_mode", "aard_prompt_fixer",
    "aard_splitscreen_scrollback", "aard_text_substitution",
}
FILESYSTEM_RETIRED_SOURCES = {
    "Automatic_Backup", "aard_GMCP_handler", "aard_new_connection", "aard_new_connection_no_UI",
    "aard_note_mode", "aard_package_update_checker", "aard_prompt_fixer", "aard_text_substitution",
    "aard_translate_foreign_friends",
}


def source_name(item_id: str) -> str:
    prefix = item_id.split("/", 1)[0]
    if prefix.startswith("source:"):
        return prefix.removeprefix("source:")
    if "telnet_options.lua" in item_id:
        return "telnet_options.lua"
    if "constants.lua" in item_id:
        return "constants.lua"
    if "aardwolf_colors.lua" in item_id:
        return "aardwolf_colors.lua"
    return "companion"


def target_for(item: dict) -> str:
    item_id, kind, source = item["id"], item["kind"], source_name(item["id"])
    if kind == "metadata": return "reports/source-manifest.md"
    if kind in {"gmcp-dependency"}: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_protocol.lua"
    if kind in {"miniwindow-api"}: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_ui.lua"
    if kind == "timer": return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_lifecycle.lua"
    if kind == "alias": return "src/aliases/aardwolf_mudlet/aliases.json"
    if kind == "trigger":
        if "Command_Tag_Handler" in item_id: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_capture.lua"
        if "Hyperlink_URL2" in item_id: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_chat.lua"
        return "src/triggers/aardwolf_mudlet/triggers.json"
    if source in {"SAPI", "universal_text_to_speech"}: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_accessibility.lua"
    if source in {"aard_channels_fiendish", "aard_chat_echo", "Hyperlink_URL2"}: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_chat.lua"
    if source in {"aard_inventory_serials"}: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_details.lua"
    if source in {"Aardwolf_Tick_Timer", "aard_GMCP_handler", "aard_group_monitor_gmcp", "aard_health_bars_gmcp", "aard_statmon_gmcp"}: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_protocol.lua"
    if kind in {"callback", "plugin-dependency"}: return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_lifecycle.lua"
    if kind == "filesystem-api": return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_settings.lua"
    return "src/scripts/aardwolf_mudlet/aardwolf_mudlet_ui.lua"


def disposition(item: dict) -> tuple[str, str]:
    item_id, kind, source = item["id"], item["kind"], source_name(item["id"])
    if kind == "metadata": return "converted", "Original metadata is preserved as provenance without reusing legacy package identity."
    if kind in {"asset", "unknown", "dll-loading", "windows-api"}: return "intentionally-retired", "The original artifact or unsafe platform mechanism is not redistributed or executed."
    if kind == "alias":
        retired = source in ALIAS_RETIRED_SOURCES or item_id in ALIAS_RETIRED_IDS
        return ("intentionally-retired", "The alias would hijack game/client commands or emulate nonportable state.") if retired else ("converted-with-review", "The behavior is clean-room routed through validated namespaced commands.")
    if kind == "trigger":
        converted = source == "aard_group_monitor_gmcp" or item_id in {
            "source:Hyperlink_URL2/trigger:https-mailto-s-w", "source:aard_Command_Tag_Handler/trigger:tag",
        }
        return ("converted-with-review", "The bounded text-only fallback has no reliable GMCP replacement.") if converted else ("intentionally-retired", "Native validated GMCP or package-local presentation replaces global output rewriting.")
    if kind == "timer": return "converted-with-review", "A single package-owned countdown derives display state from authoritative GMCP tick data."
    if kind == "script":
        retired = source in SCRIPT_RETIRED_SOURCES or source in {"constants.lua", "telnet_options.lua"}
        return ("intentionally-retired", "The source script depends on obsolete, unsafe, or client-global MUSHclient behavior.") if retired else ("converted-with-review", "Portable intent is implemented as a clean-room namespaced Lua module.")
    if kind == "callback":
        retired = source in CALLBACK_RETIRED_SOURCES or item_id in CALLBACK_RETIRED_IDS
        return ("intentionally-retired", "The callback mutates raw telnet, client-global UI, focus, or automated session behavior.") if retired else ("converted-with-review", "Mudlet lifecycle and native GMCP events replace the MUSHclient callback.")
    if kind == "gmcp-dependency":
        retired = source in GMCP_RETIRED_SOURCES
        return ("intentionally-retired", "The dependent feature is outside the safe package scope.") if retired else ("converted-with-review", "Native validated gmcp.* handlers replace plugin broadcasts.")
    if kind == "plugin-dependency":
        retired = source in DEPENDENCY_RETIRED_SOURCES
        return ("intentionally-retired", "The dependency represented a retired companion or global client behavior.") if retired else ("converted-with-review", "Internal namespaced ownership replaces cross-plugin broadcasts.")
    if kind == "miniwindow-api": return "converted-with-review", "Responsive Geyser and the native mapper replace MUSHclient miniwindows."
    if kind == "filesystem-api":
        retired = source in FILESYSTEM_RETIRED_SOURCES
        return ("intentionally-retired", "Arbitrary or automatic filesystem behavior is not carried forward.") if retired else ("converted-with-review", "Only fixed profile-contained JSON, logs, media, and backups remain."
        )
    raise ValueError(f"unclassified inventory item: {item_id} ({kind})")


def retirement(item: dict) -> dict[str, str]:
    kind, source = item["kind"], source_name(item["id"])
    if kind == "asset":
        return {"user_impact": "The original companion file is not bundled.", "migration": "Use package defaults, database-derived terrain colors, or user-selected profile media."}
    if kind == "unknown":
        migrations = {
            "Aardwolf_Bigmap_Graphical": "Use the native mapper workspace and aard map commands.",
            "aard_ASCII_map": "Use the native mapper and room name, area, terrain, and exits display.",
            "aard_GMCP_mapper": "Use the canonical JSON snapshot and merge-safe aard map import.",
            "aard_soundpack": "Use disabled-by-default local aard sound mappings.",
            "aard_vi_review_buffers": "Use Chat tabs, bounded capture, clipboard, safe links, and native TTS.",
            "aard_vital_shortcuts": "Use validated vital, maximum, group, and command-line summaries.",
        }
        return {"user_impact": "Malformed legacy XML could not be inspected safely and is not loaded.", "migration": migrations[source]}
    return {
        "user_impact": f"The legacy {kind} behavior from {source} is unavailable in aardwolf-mudlet.",
        "migration": "Use the documented aard commands, native GMCP/Geyser facilities, or Mudlet preferences instead.",
    }


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    items = inventory.get("items", [])
    if len(items) != 522 or len({item["id"] for item in items}) != 522:
        raise SystemExit("inventory must contain exactly 522 unique items")
    decisions = []
    for item in sorted(items, key=lambda value: value["id"]):
        status, reason = disposition(item)
        decision = {"item_id": item["id"], "kind": item["kind"], "source": item["source"], "summary": item["summary"], "status": status, "reason": reason, "target_paths": [target_for(item)]}
        if status == "intentionally-retired":
            decision["target_paths"] = ["reports/retirements.md"]
            decision["retirement"] = retirement(item)
        decisions.append(decision)
    counts = Counter(decision["status"] for decision in decisions)
    if dict(counts) != EXPECTED:
        raise SystemExit(f"unexpected disposition counts: {dict(counts)} != {EXPECTED}")
    report = {"schema_version": 1, "package": "aardwolf-mudlet", "inventory_sha256": inventory.get("input", {}).get("sha256"), "counts": dict(sorted(counts.items())), "decisions": decisions}
    write(args.output / "conversion-report.json", json.dumps(report, indent=2, sort_keys=True) + "\n")
    rows = ["# Conversion Report", "", "Every frozen inventory item has exactly one disposition.", "", "| Status | Count |", "| --- | ---: |"]
    rows.extend(f"| {status} | {counts[status]} |" for status in sorted(counts))
    rows += ["", "| Item | Kind | Status | Target |", "| --- | --- | --- | --- |"]
    rows.extend(f"| `{d['item_id']}` | {d['kind']} | {d['status']} | `{d['target_paths'][0]}` |" for d in decisions)
    write(args.output / "conversion-report.md", "\n".join(rows) + "\n")
    retired = [d for d in decisions if d["status"] == "intentionally-retired"]
    ledger = ["# Explicit Retirement Ledger", "", "These behaviors and assets are intentionally absent from release 1.0.0.", "", "| Item | User impact | Migration |", "| --- | --- | --- |"]
    ledger.extend(f"| `{d['item_id']}` | {d['retirement']['user_impact']} | {d['retirement']['migration']} |" for d in retired)
    write(args.output / "retirements.md", "\n".join(ledger) + "\n")
    metadata = [item for item in sorted(items, key=lambda value: value["id"]) if item["kind"] == "metadata"]
    manifest = ["# Source Provenance", "", "Legacy metadata is preserved for attribution only; package identity is aardwolf-mudlet 1.0.0.", "", "| Source item | Name | Author | Version | Date | Purpose |", "| --- | --- | --- | --- | --- | --- |"]
    for item in metadata:
        details = item.get("details", {})
        values = [str(details.get(key, "")).replace("|", "\\|").replace("\n", " ") for key in ("name", "author", "version", "date_written", "purpose")]
        manifest.append(f"| `{item['id']}` | " + " | ".join(values) + " |")
    write(args.output / "source-manifest.md", "\n".join(manifest) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
