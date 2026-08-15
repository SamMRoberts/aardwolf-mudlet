#!/usr/bin/env python3
"""Release-contract checks for the audited MUSHclient collection."""

from __future__ import annotations

import json
import zipfile
import xml.etree.ElementTree as ET
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
ALL_RELEASE_PACKAGES = ("aardwolf-mushclient-collection", *FEATURE_PACKAGES, "aardwolf-map")


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
        assert feature_metadata["version"] == ("1.1.0" if package == "aardwolf-interface" else "1.0.0")
        assert (project / "dist" / "README.md").is_file()

    suite_xml_path = mudlet_root / "dist" / "aardwolf-mudlet-suite.xml"
    suite_package_path = mudlet_root / "dist" / "aardwolf-mudlet-suite.mpackage"
    suite_root = ET.parse(suite_xml_path).getroot()
    assert suite_root.tag == "MudletPackage"
    with zipfile.ZipFile(suite_package_path) as archive:
        assert archive.namelist() == ["aardwolf-mudlet-suite.xml", "config.lua", "resources/aardwolf-map-v11.json"]
        assert archive.read("aardwolf-mudlet-suite.xml") == suite_xml_path.read_bytes()
        suite_config = archive.read("config.lua").decode("utf-8")
        assert "mpackage = [[aardwolf-mudlet-suite]]" in suite_config
        assert "title = [[Aardwolf Mudlet Suite]]" in suite_config
        assert "version = [[1.1.0]]" in suite_config
        with zipfile.ZipFile(mudlet_root / "aardwolf-map" / "dist" / "aardwolf-map.mpackage") as map_archive:
            assert archive.read("resources/aardwolf-map-v11.json") == map_archive.read("resources/aardwolf-map-v11.json")
    for category in ("AliasPackage", "TriggerPackage", "TimerPackage", "ScriptPackage", "KeyPackage"):
        expected = []
        for package in ALL_RELEASE_PACKAGES:
            root = ET.parse(mudlet_root / package / "dist" / f"{package}.xml").getroot()
            source = root.find(category)
            expected.extend([] if source is None else [element.text for element in source.iter("name")])
        actual_package = suite_root.find(category)
        actual = [] if actual_package is None else [element.text for element in actual_package.iter("name")]
        assert actual == expected


if __name__ == "__main__":
    main()
