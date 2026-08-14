#!/usr/bin/env python3
"""Release-contract checks for the audited MUSHclient collection."""

from __future__ import annotations

import json
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NAMESPACE = "aardwolf_mushclient_collection"
FEATURE_PACKAGES = (
    "aardwolf-gmcp-diagnostics",
    "aardwolf-tick",
    "aardwolf-console",
    "aardwolf-communication",
    "aardwolf-character",
    "aardwolf-help",
    "aardwolf-interface",
    "aardwolf-profile-data",
    "aardwolf-accessibility",
)


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def main() -> None:
    metadata = json.loads(read("package-metadata.json"))
    assert metadata["namespace"] == NAMESPACE
    assert metadata["minimum_mudlet_version"] == "4.14"
    assert metadata["version"] == "1.0.0"

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

    xml_export = read("dist/aardwolf-mushclient-collection.xml")
    assert "<MudletPackage" in xml_export
    assert f"{NAMESPACE}.omit_blank_lines" in xml_export
    with zipfile.ZipFile(ROOT / "dist" / "aardwolf-mushclient-collection.mpackage") as archive:
        assert "aardwolf-mushclient-collection.xml" in archive.namelist()

    inventory = json.loads(read("reports/inventory.json"))
    report = json.loads(read("reports/conversion-report.json"))
    decisions = report["decisions"]
    assert len(inventory["items"]) == 522
    assert len(decisions) == len(inventory["items"])
    assert {item["id"] for item in inventory["items"]} == {decision["item_id"] for decision in decisions}
    assert not {decision["status"] for decision in decisions} & {"manual-action-required", "unsupported-blocker"}
    repository_root = ROOT.parents[1]
    for decision in decisions:
        for target in decision["target_paths"]:
            target_path = repository_root / target if target.startswith("mudlet/") else ROOT / target
            assert target_path.exists(), (decision["item_id"], target)
    retired = [decision for decision in decisions if decision["status"] == "intentionally-retired"]
    assert retired
    assert (ROOT / "reports" / "retirements.md").read_text(encoding="utf-8").strip()
    for decision in retired:
        assert "reports/retirements.md" in decision["target_paths"]
        assert decision["retirement"]["user_impact"].strip()
        assert decision["retirement"]["migration"].strip()

    mudlet_root = ROOT.parent
    for package in FEATURE_PACKAGES:
        project = mudlet_root / package
        feature_metadata = json.loads((project / "package-metadata.json").read_text(encoding="utf-8"))
        assert feature_metadata["name"] == package
        assert feature_metadata["version"] == "1.0.0"
        assert (project / "dist" / "README.md").is_file()


if __name__ == "__main__":
    main()
