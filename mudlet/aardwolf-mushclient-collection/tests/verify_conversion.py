#!/usr/bin/env python3
"""Static contract checks for the converted, enabled Mudlet behavior."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NAMESPACE = "aardwolf_mushclient_collection"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def main() -> None:
    metadata = json.loads(read("package-metadata.json"))
    assert metadata["namespace"] == NAMESPACE
    assert metadata["minimum_mudlet_version"] == "4.14"

    trigger = json.loads(read("src/triggers/aardwolf_mushclient_collection/triggers.json"))
    assert trigger == [{
        "name": f"{NAMESPACE}.omit_blank_lines",
        "patterns": [{"pattern": "^$", "type": "regex"}],
    }]
    assert f"{NAMESPACE}.commands.omit_blank_line()" in read(
        "src/triggers/aardwolf_mushclient_collection/aardwolf_mushclient_collection_omit_blank_lines.lua"
    )
    assert "deleteLine()" in read(
        "src/scripts/aardwolf_mushclient_collection/aardwolf_mushclient_collection_commands.lua"
    )

    lifecycle = read("src/scripts/aardwolf_mushclient_collection/aardwolf_mushclient_collection_lifecycle.lua")
    assert "registerNamedTimer(" in lifecycle
    assert "deleteNamedTimer(" in lifecycle
    assert "aardwolf-mushclient-collection::timer::time-display" in lifecycle


if __name__ == "__main__":
    main()
