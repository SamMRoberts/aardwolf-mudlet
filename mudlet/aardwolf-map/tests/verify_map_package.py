#!/usr/bin/env python3
"""Fast package-level contract checks for the generated Aardwolf map package."""

from __future__ import annotations

import hashlib
import json
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
PACKAGE = ROOT / "mudlet" / "aardwolf-map"
RESOURCE = PACKAGE / "src" / "resources" / "aardwolf-map-v11.json"
SOURCE = ROOT / ".resources" / "Aardwolf.db"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    data = json.loads(RESOURCE.read_text(encoding="utf-8"))
    report = json.loads((PACKAGE / "reports" / "aardwolf-db-inventory.json").read_text(encoding="utf-8"))
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    require(data["schema_version"] == 1, "unexpected map resource schema")
    require(data["source"]["sha256"] == source_hash, "resource hash differs from Aardwolf.db")
    require(data["counts"] == {"populated_areas": 21, "referenced_environments": 80, "rooms": 14257, "source_areas": 236, "standard_exits": 53662}, "unexpected map resource counts")
    require(len(data["rooms"]) == 14257 and len(data["exits"]) == 53662, "record arrays do not match resource counts")
    require(len(data["areas"]) == 236 and len(data["environments"]) == 80, "source inventories are incomplete")
    require(report["source"]["sha256"] == source_hash, "inventory source hash differs from Aardwolf.db")
    require(report["source_schema"]["sqlite_user_version"] == 11, "inventory source schema is unexpected")
    require(all(report["reference_checks"].values()), "inventory contains a failed source reference check")
    xml_export = (PACKAGE / "dist" / "aardwolf-map.xml").read_text(encoding="utf-8")
    require("<MudletPackage" in xml_export and "aardwolf_map.import" in xml_export, "importable XML export is missing map objects")
    with zipfile.ZipFile(PACKAGE / "dist" / "aardwolf-map.mpackage") as archive:
        require("aardwolf-map.xml" in archive.namelist(), "distribution package is missing XML")
        require("resources/aardwolf-map-v11.json" in archive.namelist(), "distribution package is missing map resource")

    aliases = json.loads((PACKAGE / "src" / "aliases" / "aardwolf_map" / "aliases.json").read_text(encoding="utf-8"))
    require([alias["name"] for alias in aliases] == ["aardwolf_map.import", "aardwolf_map.import_cancel", "aardwolf_map.status"], "explicit map aliases are missing")
    lifecycle = (PACKAGE / "src" / "scripts" / "aardwolf_map" / "aardwolf_map_lifecycle.lua").read_text(encoding="utf-8")
    protocol = (PACKAGE / "src" / "scripts" / "aardwolf_map" / "aardwolf_map_protocol.lua").read_text(encoding="utf-8")
    state = (PACKAGE / "src" / "scripts" / "aardwolf_map" / "aardwolf_map_state.lua").read_text(encoding="utf-8")
    require("createRoomID()" in lifecycle and "setRoomIDbyHash" in lifecycle, "importer does not use compact owned IDs")
    require("registerNamedTimer" in lifecycle and "deleteNamedTimer" in lifecycle, "import batching cannot be cancelled")
    require("aardwolf-map::event::room-info" in lifecycle and "gmcp.room.info" in lifecycle, "named GMCP handler is missing")
    require("clearMap" not in lifecycle and "deleteRoom" not in lifecycle, "importer contains destructive mapper actions")
    require("centerview(room_id)" in protocol and "send(" not in protocol, "GMCP handler has side effects beyond centering")
    require("aardwolf-mudlet-suite/aardwolf-map-v11.json" in state, "map resource does not support the suite package directory")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
