#!/usr/bin/env python3
"""Inspect MUSHclient XML as data without evaluating its contents."""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from common import MAX_INPUT_BYTES, ToolError, sha256_bytes, write_json


MAX_XML_DEPTH = 64
MAX_XML_NODES = 20_000
DOCTYPE_EXTERNAL_RE = re.compile(rb"<!DOCTYPE[^>]*(?:SYSTEM|PUBLIC)", re.IGNORECASE)
ENTITY_RE = re.compile(rb"<!ENTITY", re.IGNORECASE)
NOTICE_RE = re.compile(r"<!--(.*?)-->", re.DOTALL)
NOTICE_WORD_RE = re.compile(r"\b(?:copyright|license|licence|notice|attribution)\b", re.IGNORECASE)
CALLBACK_RE = re.compile(r"\bfunction\s+(OnPlugin[A-Za-z0-9_]*)\s*\(")
SIGNAL_PATTERNS = {
    "gmcp": re.compile(r"\b(?:gmcp(?:val)?|GMCP_HANDLER|send_gmcp(?:_packet)?|Send_GMCP_Packet|Core\.Supports\.Set)\b", re.IGNORECASE),
    "plugin-dependency": re.compile(r"\b(?:CallPlugin|GetPlugin(?:Variable|Info)|IsPluginInstalled|PluginSupports)\b"),
    "miniwindow": re.compile(r"\b(?:miniwin\.|Window[A-Za-z0-9_]+)\b"),
    "filesystem": re.compile(r"\b(?:dofile|loadfile|io\.open|os\.(?:remove|rename)|lfs\.|GetInfo\s*\(\s*(?:60|66)\s*\))\b"),
    "dll-loading": re.compile(r"\b(?:package\.loadlib|loadlib)\b|\.dll\b", re.IGNORECASE),
    "windows-api": re.compile(r"\b(?:winapi|rundll32|cmd\.exe|powershell|WM_TIMER)\b|[A-Za-z]:\\\\"),
}
KNOWN_TAGS = {
    "muclient", "plugin", "aliases", "alias", "triggers", "trigger", "timers", "timer",
    "variables", "variable", "script", "send", "include", "description", "comments", "comment",
    "colours", "colour", "macros", "macro", "keypad", "key", "keys", "world", "option",
}


def _local_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1].lower()


def _bounded_parse(raw: bytes) -> ET.Element:
    if len(raw) > MAX_INPUT_BYTES:
        raise ToolError(f"XML input exceeds {MAX_INPUT_BYTES} byte limit")
    if DOCTYPE_EXTERNAL_RE.search(raw) or ENTITY_RE.search(raw):
        raise ToolError("XML external or custom entity declarations are not allowed")
    try:
        depth = 0
        node_count = 0
        for event, _ in ET.iterparse(io.BytesIO(raw), events=("start", "end")):
            if event == "start":
                depth += 1
                node_count += 1
                if depth > MAX_XML_DEPTH:
                    raise ToolError(f"XML nesting exceeds {MAX_XML_DEPTH}")
                if node_count > MAX_XML_NODES:
                    raise ToolError(f"XML node count exceeds {MAX_XML_NODES}")
            else:
                depth -= 1
        return ET.fromstring(raw)
    except ET.ParseError as error:
        raise ToolError(f"invalid XML: {error}") from error


def _read_bounded(path: Path, label: str) -> bytes:
    if path.is_symlink():
        raise ToolError(f"{label} must not be a symbolic link: {path}")
    try:
        size = path.stat().st_size
    except FileNotFoundError as error:
        raise ToolError(f"missing {label}: {path}") from error
    if size > MAX_INPUT_BYTES:
        raise ToolError(f"{label} exceeds {MAX_INPUT_BYTES} byte limit: {path}")
    return path.read_bytes()


def _item(identifier: str, kind: str, source: str, summary: str, details: dict[str, Any], signals: list[str] | None = None) -> dict[str, Any]:
    return {
        "details": details,
        "id": identifier,
        "kind": kind,
        "signals": sorted(signals or []),
        "source": source,
        "summary": summary,
    }


def _node_identifier(kind: str, element: ET.Element, ordinal: int) -> str:
    label = element.attrib.get("name") or element.attrib.get("label") or element.attrib.get("match") or str(ordinal)
    slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", label).strip("-").lower() or str(ordinal)
    return f"{kind}:{slug}"


def _script_signals(text: str) -> list[str]:
    return [name for name, pattern in SIGNAL_PATTERNS.items() if pattern.search(text)]


def _signal_items(parent_id: str, source: str, signals: list[str]) -> list[dict[str, Any]]:
    kind_by_signal = {
        "gmcp": "gmcp-dependency",
        "plugin-dependency": "plugin-dependency",
        "miniwindow": "miniwindow-api",
        "filesystem": "filesystem-api",
        "dll-loading": "dll-loading",
        "windows-api": "windows-api",
    }
    parent_slug = re.sub(r"[^A-Za-z0-9_.-]+", "-", parent_id)
    return [
        _item(
            f"signal:{parent_slug}:{signal}",
            kind_by_signal[signal],
            source,
            f"static {signal} signal",
            {"signal": signal, "source_item": parent_id},
            [signal],
        )
        for signal in signals
    ]


def _read_companions(roots: list[Path]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for root_index, root in enumerate(roots, start=1):
        if not root.is_dir():
            raise ToolError(f"companion path is not a directory: {root}")
        if root.is_symlink():
            raise ToolError(f"companion path must not be a symbolic link: {root}")
        for path in sorted(root.rglob("*")):
            relative = path.relative_to(root)
            if path.is_symlink():
                items.append(_item(f"unknown:symlink:{root_index}:{relative.as_posix()}", "unknown", f"companion-{root_index}/{relative.as_posix()}", "symbolic-link companion", {"path": relative.as_posix()}, ["path-symlink"]))
                continue
            if not path.is_file():
                continue
            payload = _read_bounded(path, "companion file")
            source = f"companion-{root_index}/{relative.as_posix()}"
            suffix = path.suffix.lower()
            details = {"bytes": len(payload), "sha256": sha256_bytes(payload)}
            if suffix == ".lua":
                text = payload.decode("utf-8", errors="replace")
                identifier = f"script:companion-{root_index}-{relative.as_posix().replace('/', '-')}"
                signals = _script_signals(text)
                items.append(_item(identifier, "script", source, "companion Lua file", details, signals))
                items.extend(_signal_items(identifier, source, signals))
            else:
                items.append(_item(f"asset:companion-{root_index}-{relative.as_posix().replace('/', '-')}", "asset", source, "companion resource", details))
                text = payload.decode("utf-8", errors="replace")
                if NOTICE_WORD_RE.search(text) or re.fullmatch(r"(?:notice|licen[cs]e|copying)(?:\..*)?", path.name, re.IGNORECASE):
                    items.append(_item(
                        f"notice:companion-{root_index}-{relative.as_posix().replace('/', '-')}",
                        "notice",
                        source,
                        "license or attribution notice",
                        {"text": text},
                    ))
    return items


def inspect_xml(path: Path, companion_roots: list[Path]) -> dict[str, Any]:
    raw = _read_bounded(path, "XML input")
    root = _bounded_parse(raw)
    if _local_name(root) not in {"muclient", "world"}:
        raise ToolError(f"expected MUSHclient muclient/world root, found {_local_name(root)!r}")

    items: list[dict[str, Any]] = []
    metadata: dict[str, Any] = {}
    plugin = next((node for node in root.iter() if _local_name(node) == "plugin"), None)
    if plugin is not None:
        metadata = {key: plugin.attrib[key] for key in sorted(plugin.attrib)}
        items.append(_item("metadata:plugin", "metadata", path.name, "plugin metadata", metadata))

    ordinal_by_kind: dict[str, int] = {"alias": 0, "trigger": 0, "timer": 0, "variable": 0, "script": 0}
    for element in root.iter():
        tag = _local_name(element)
        if tag in ordinal_by_kind:
            ordinal_by_kind[tag] += 1
            identifier = _node_identifier(tag, element, ordinal_by_kind[tag])
            details = {"attributes": {key: element.attrib[key] for key in sorted(element.attrib)}}
            text = "".join(element.itertext()).strip()
            if tag == "script":
                details.update({"bytes": len(text.encode("utf-8")), "sha256": sha256_bytes(text.encode("utf-8"))})
                signals = _script_signals(text)
                items.append(_item(identifier, tag, path.name, "embedded Lua script", details, signals))
                items.extend(_signal_items(identifier, path.name, signals))
                for callback in sorted(set(CALLBACK_RE.findall(text))):
                    items.append(_item(f"callback:{callback}", "callback", path.name, "MUSHclient callback", {"callback": callback, "script_item": identifier}, _script_signals(text)))
            else:
                details["text"] = text
                items.append(_item(identifier, tag, path.name, f"MUSHclient {tag}", details))

    include_ordinal = 0
    for element in root.iter():
        if _local_name(element) != "include":
            continue
        include_ordinal += 1
        location = "".join(element.itertext()).strip()
        items.append(_item(
            f"asset:include:{include_ordinal}",
            "asset",
            path.name,
            "MUSHclient included resource",
            {"attributes": {key: element.attrib[key] for key in sorted(element.attrib)}, "path": location},
            ["included-resource"],
        ))

    unknown_elements: list[dict[str, Any]] = []
    unknown_ordinal = 0
    for element in root.iter():
        tag = _local_name(element)
        if tag not in KNOWN_TAGS:
            unknown_ordinal += 1
            item = _item(f"unknown:{tag}:{unknown_ordinal}", "unknown", path.name, "unrecognized XML element", {"tag": tag, "attributes": {key: element.attrib[key] for key in sorted(element.attrib)}}, ["unknown-xml"])
            unknown_elements.append(item)
            items.append(item)

    notices: list[dict[str, Any]] = []
    notice_ordinal = 0
    for comment in NOTICE_RE.findall(raw.decode("utf-8", errors="replace")):
        normalized = comment.strip()
        if normalized and NOTICE_WORD_RE.search(normalized):
            notice_ordinal += 1
            notice = _item(f"notice:{notice_ordinal}", "notice", path.name, "license or attribution notice", {"text": normalized})
            notices.append(notice)
            items.append(notice)

    items.extend(_read_companions(companion_roots))
    items.sort(key=lambda entry: entry["id"])
    ids = [entry["id"] for entry in items]
    if len(ids) != len(set(ids)):
        raise ToolError("inventory generated duplicate item IDs; rename source items to disambiguate")
    return {
        "input": {"name": path.name, "sha256": sha256_bytes(raw)},
        "items": items,
        "metadata": metadata,
        "notices": notices,
        "schema_version": 1,
        "unknown_elements": unknown_elements,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="MUSHclient XML plugin or world file")
    parser.add_argument("--companion", type=Path, action="append", default=[], help="companion directory to inventory")
    parser.add_argument("--output", type=Path, help="write JSON inventory to this path instead of stdout")
    args = parser.parse_args(argv)
    try:
        inventory = inspect_xml(args.input, args.companion)
        if args.output:
            write_json(args.output, inventory)
        else:
            print(json.dumps(inventory, indent=2, sort_keys=True))
        return 0
    except (OSError, ToolError) as error:
        print(f"inspection failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
