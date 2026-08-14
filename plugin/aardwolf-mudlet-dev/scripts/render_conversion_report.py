#!/usr/bin/env python3
"""Render complete, deterministic MUSHclient-to-Mudlet conversion reports."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from common import ToolError, load_json, require_relative_path, write_json, write_text


ALLOWED_STATUSES = {
    "converted",
    "converted-with-review",
    "manual-action-required",
    "unsupported-blocker",
    "not-applicable",
}


def _read_decisions(path: Path) -> list[dict[str, Any]]:
    value = load_json(path)
    decisions = value.get("decisions") if isinstance(value, dict) else None
    if not isinstance(decisions, list):
        raise ToolError("decisions JSON must be an object containing a decisions array")
    if not all(isinstance(decision, dict) for decision in decisions):
        raise ToolError("every decision must be an object")
    return decisions


def _validate(inventory: dict[str, Any], decisions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    items = inventory.get("items")
    if inventory.get("schema_version") != 1 or not isinstance(items, list):
        raise ToolError("inventory must be schema version 1 with an items array")
    item_ids = {item.get("id") for item in items if isinstance(item, dict) and isinstance(item.get("id"), str)}
    if len(item_ids) != len(items):
        raise ToolError("inventory item IDs must be unique non-empty strings")
    by_id: dict[str, dict[str, Any]] = {}
    for decision in decisions:
        item_id = decision.get("item_id")
        status = decision.get("status")
        reason = decision.get("reason")
        target_paths = decision.get("target_paths")
        if not isinstance(item_id, str) or not item_id:
            raise ToolError("each decision needs a non-empty item_id")
        if item_id in by_id:
            raise ToolError(f"duplicate decision for {item_id}")
        if item_id not in item_ids:
            raise ToolError(f"decision references unknown inventory item {item_id}")
        if status not in ALLOWED_STATUSES:
            raise ToolError(f"invalid status for {item_id}: {status!r}")
        if not isinstance(reason, str) or not reason.strip():
            raise ToolError(f"decision for {item_id} needs a non-empty reason")
        if not isinstance(target_paths, list) or not all(isinstance(target, str) and target for target in target_paths):
            raise ToolError(f"decision for {item_id} needs a target_paths string array")
        for target in target_paths:
            require_relative_path(target, f"decision for {item_id} target path")
        by_id[item_id] = decision
    missing = sorted(item_ids - set(by_id))
    if missing:
        raise ToolError("missing decisions for: " + ", ".join(missing))
    return [by_id[item_id] for item_id in sorted(item_ids)]


def report(inventory: dict[str, Any], decisions: list[dict[str, Any]]) -> tuple[dict[str, Any], str]:
    ordered_decisions = _validate(inventory, decisions)
    items = {item["id"]: item for item in inventory["items"]}
    status_counts = Counter(decision["status"] for decision in ordered_decisions)
    document = {
        "decisions": ordered_decisions,
        "input": inventory.get("input", {}),
        "metadata": inventory.get("metadata", {}),
        "schema_version": 1,
        "status_counts": dict(sorted(status_counts.items())),
    }
    lines = [
        "# MUSHclient to Mudlet conversion report",
        "",
        "## Summary",
        "",
        f"- Source: `{document['input'].get('name', 'unknown')}`",
        f"- Inventoried items: {len(ordered_decisions)}",
    ]
    for status, count in sorted(status_counts.items()):
        lines.append(f"- {status}: {count}")
    lines.extend(["", "## Dispositions", "", "| Item | Kind | Status | Targets | Reason |", "| --- | --- | --- | --- | --- |"])
    for decision in ordered_decisions:
        item = items[decision["item_id"]]
        targets = ", ".join(f"`{target}`" for target in decision["target_paths"]) or "—"
        reason = decision["reason"].replace("|", "\\|").replace("\n", " ")
        lines.append(f"| `{decision['item_id']}` | {item['kind']} | {decision['status']} | {targets} | {reason} |")
    blockers = [decision for decision in ordered_decisions if decision["status"] in {"manual-action-required", "unsupported-blocker"}]
    if blockers:
        lines.extend(["", "## Release blockers", ""])
        for decision in blockers:
            lines.append(f"- `{decision['item_id']}`: {decision['reason']}")
    notices = [decision for decision in ordered_decisions if items[decision["item_id"]]["kind"] == "notice"]
    if notices:
        lines.extend(["", "## License and attribution preservation", ""])
        for decision in notices:
            lines.append(f"- `{decision['item_id']}`: {', '.join(decision['target_paths']) or 'no preservation target recorded'}")
    return document, "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--decisions", required=True, type=Path)
    parser.add_argument("--json-output", required=True, type=Path)
    parser.add_argument("--markdown-output", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        inventory = load_json(args.inventory)
        if not isinstance(inventory, dict):
            raise ToolError("inventory JSON must be an object")
        document, markdown = report(inventory, _read_decisions(args.decisions))
        write_json(args.json_output, document)
        write_text(args.markdown_output, markdown)
        return 0
    except (OSError, ToolError) as error:
        print(f"report failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
