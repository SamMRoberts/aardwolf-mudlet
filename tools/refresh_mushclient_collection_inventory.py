#!/usr/bin/env python3
"""Create a deterministic, read-only inventory for the MUSHclient plugin collection."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "plugin" / "aardwolf-mudlet-dev" / "scripts"))

from common import write_json  # noqa: E402
from inspect_mushclient_xml import _read_companions, inspect_xml  # noqa: E402


def tree_hash(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(candidate for candidate in root.rglob("*") if candidate.is_file() and not candidate.is_symlink()):
        relative = path.relative_to(root).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(4, "big"))
        digest.update(relative)
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def prefixed(item: dict[str, Any], prefix: str, source: Path, separator: str) -> dict[str, Any]:
    return {
        **item,
        "id": f"{prefix}{separator}{item['id']}",
        "source": source.as_posix(),
    }


def inventory(plugin_root: Path, companion_root: Path) -> dict[str, Any]:
    items: list[dict[str, Any]] = []
    parse_failures: list[dict[str, Any]] = []
    for source in sorted(plugin_root.glob("*.xml")):
        try:
            inspected = inspect_xml(source, [])
        except Exception as error:  # The error is the audit result, not a recoverable parse.
            payload = source.read_bytes()
            item = {
                "details": {"error": f"inspection failed: {error}", "sha256": hashlib.sha256(payload).hexdigest()},
                "id": f"source:{source.stem}/unknown:parse-failure",
                "kind": "unknown",
                "signals": ["parse-failure"],
                "source": source.as_posix(),
                "summary": "MUSHclient XML inspection failed",
            }
            items.append(item)
            parse_failures.append(item)
            continue
        items.extend(prefixed(item, f"source:{source.stem}", source, "/") for item in inspected["items"])

    for item in _read_companions([companion_root]):
        companion_path = companion_root / item["source"].split("/", 1)[1]
        items.append(prefixed(item, "companion", companion_path, ":"))
    items.sort(key=lambda item: item["id"])
    item_ids = [item["id"] for item in items]
    if len(item_ids) != len(set(item_ids)):
        raise ValueError("collection inventory contains duplicate item identifiers")
    return {
        "input": {
            "name": ".resources/worlds/plugins (43 MUSHclient XML plugins and companion root)",
            "sha256": tree_hash(plugin_root),
        },
        "items": items,
        "metadata": {"parse_failures": [item["id"] for item in parse_failures]},
        "schema_version": 1,
    }


def source_manifest(plugin_root: Path) -> str:
    """Render the source metadata table without executing MUSHclient content."""
    rows = [
        "# Source manifest",
        "",
        "This manifest preserves metadata discovered without executing any source. It is not a license grant.",
        "",
        "| XML source | Name | Author | Version | Purpose | Inspection |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    notices = 0
    for source in sorted(plugin_root.glob("*.xml")):
        try:
            inspected = inspect_xml(source, [])
        except Exception as error:
            rows.append(f"| `{source.name}` | — | — | — | — | failed: inspection failed: {error} |")
            continue
        metadata = inspected.get("metadata", {})
        if not isinstance(metadata, dict):
            metadata = {}
        notices += len(inspected.get("notices", []))
        def value(key: str) -> str:
            candidate = metadata.get(key, "—")
            text = str(candidate).replace("|", "\\|").replace("\n", " ").strip()
            return text or "—"
        rows.append(
            f"| `{source.name}` | {value('name')} | {value('author')} | {value('version')} | {value('purpose')} | passed |"
        )
    rows.extend(["", "No copyright, license, attribution, or notice text was detected by the static inspection." if notices == 0 else f"{notices} source notice record(s) were detected by the static inspection.", ""])
    return "\n".join(rows)


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plugins", default=ROOT / ".resources" / "worlds" / "plugins", type=Path)
    parser.add_argument("--companion", default=ROOT / ".resources" / "worlds" / "plugins", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", type=Path, help="write the deterministic source manifest")
    args = parser.parse_args(arguments)
    try:
        write_json(args.output, inventory(args.plugins, args.companion))
        if args.manifest:
            args.manifest.parent.mkdir(parents=True, exist_ok=True)
            args.manifest.write_text(source_manifest(args.plugins), encoding="utf-8", newline="\n")
    except (OSError, ValueError) as error:
        print(f"inventory failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
