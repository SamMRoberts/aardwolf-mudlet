#!/usr/bin/env python3
"""Validate and publish deterministic native Mudlet release artifacts."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "plugin" / "aardwolf-mudlet-dev" / "scripts"))

from build_mudlet_package import build_native, package_config_lua  # noqa: E402
from project_contract import CATEGORY_INFO, load_project  # noqa: E402
from validate_aardwolf_mudlet_project import validate  # noqa: E402


PACKAGES = (
    "aardwolf-mushclient-collection",
    "aardwolf-gmcp-diagnostics",
    "aardwolf-tick",
    "aardwolf-console",
    "aardwolf-communication",
    "aardwolf-character",
    "aardwolf-help",
    "aardwolf-interface",
    "aardwolf-profile-data",
    "aardwolf-accessibility",
    "aardwolf-map",
)
SUITE_NAME = "aardwolf-mudlet-suite"
SUITE_MFILE = {
    "author": "Aardwolf Mudlet",
    "description": "All-in-one native Mudlet package for the audited Aardwolf collection, diagnostics, interface, accessibility, profile-data, and map importer.",
    "package": SUITE_NAME,
    "title": "Aardwolf Mudlet Suite",
    "version": "1.0.2",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def suite_xml(mudlet_root: Path) -> bytes:
    """Merge every independently built XML export into one Mudlet package XML."""
    root = ET.Element("MudletPackage", {"version": "1.001"})
    for category, info in CATEGORY_INFO.items():
        destination = ET.SubElement(root, info["package"])
        for name in PACKAGES:
            component = ET.parse(mudlet_root / name / "build" / f"{name}.xml").getroot()
            source = component.find(info["package"])
            if source is not None:
                for child in source:
                    destination.append(copy.deepcopy(child))
    ET.SubElement(root, "VariablePackage")
    payload = ET.tostring(root, encoding="utf-8", xml_declaration=True, short_empty_elements=False)
    return payload.replace(b"?>", b"?>\n<!DOCTYPE MudletPackage>", 1) + b"\n"


def suite_resources(mudlet_root: Path) -> dict[str, bytes]:
    """Collect declared package resources without importing source assets."""
    resources: dict[str, bytes] = {}
    for name in PACKAGES:
        resource_root = mudlet_root / name / "src" / "resources"
        for resource in sorted(resource_root.rglob("*")):
            if not resource.is_file() or resource.name in {".gitkeep", "EMPTY-CATEGORY.md"}:
                continue
            if resource.is_symlink():
                raise ValueError(f"suite resource must not be a symlink: {resource}")
            archive_name = f"resources/{resource.relative_to(resource_root).as_posix()}"
            payload = resource.read_bytes()
            if archive_name in resources and resources[archive_name] != payload:
                raise ValueError(f"suite resource name collision: {archive_name}")
            resources[archive_name] = payload
    return resources


def _zip_entry(name: str, payload: bytes, archive: zipfile.ZipFile) -> None:
    entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    entry.compress_type = zipfile.ZIP_DEFLATED
    entry.external_attr = 0o100644 << 16
    archive.writestr(entry, payload)


def verify_suite(mudlet_root: Path, xml_payload: bytes, resources: dict[str, bytes]) -> None:
    root = ET.fromstring(xml_payload)
    if root.tag != "MudletPackage":
        raise ValueError("suite XML root must be MudletPackage")
    for category, info in CATEGORY_INFO.items():
        expected: list[str] = []
        for name in PACKAGES:
            expected.extend(record.spec["name"] for record in load_project(mudlet_root / name).objects if record.category == category)
        package = root.find(info["package"])
        actual = [] if package is None else [element.text for element in package.iter("name")]
        if actual != expected:
            raise ValueError(f"suite XML {category} objects do not match component order")
    expected_resources = suite_resources(mudlet_root)
    if resources != expected_resources:
        raise ValueError("suite resources do not match declared component resources")


def build_suite(mudlet_root: Path) -> dict[str, str]:
    xml_payload = suite_xml(mudlet_root)
    resources = suite_resources(mudlet_root)
    verify_suite(mudlet_root, xml_payload, resources)
    dist = mudlet_root / "dist"
    dist.mkdir(exist_ok=True)
    xml_path = dist / f"{SUITE_NAME}.xml"
    package_path = dist / f"{SUITE_NAME}.mpackage"
    xml_path.write_bytes(xml_payload)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{package_path.name}.", dir=dist)
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, strict_timestamps=True) as archive:
            _zip_entry(xml_path.name, xml_payload, archive)
            _zip_entry("config.lua", package_config_lua(SUITE_MFILE), archive)
            for name, payload in sorted(resources.items()):
                _zip_entry(name, payload, archive)
        os.replace(temporary, package_path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    with zipfile.ZipFile(package_path) as archive:
        if archive.namelist() != sorted(archive.namelist()):
            raise ValueError("suite archive entries are not sorted")
        if archive.read(xml_path.name) != xml_payload:
            raise ValueError("suite archive XML differs from the generated XML")
        if archive.read("config.lua") != package_config_lua(SUITE_MFILE):
            raise ValueError("suite archive Package Manager metadata differs from suite metadata")
    return {"xml": str(xml_path), "mpackage": str(package_path)}


def build_release(mudlet_root: Path) -> dict[str, dict[str, str]]:
    results: dict[str, dict[str, str]] = {}
    for name in PACKAGES:
        project_root = mudlet_root / name
        errors = validate(project_root, release=True, check_native_output=False)
        if errors:
            raise ValueError(f"{name} release validation failed: {'; '.join(errors)}")
        outputs = build_native(load_project(project_root))
        output_errors = validate(project_root, release=True)
        if output_errors:
            raise ValueError(f"{name} built output validation failed: {'; '.join(output_errors)}")
        dist = project_root / "dist"
        dist.mkdir(exist_ok=True)
        xml = Path(outputs["xml"])
        package = Path(outputs["mpackage"])
        shutil.copyfile(xml, dist / xml.name)
        shutil.copyfile(package, dist / package.name)
        results[name] = {
            "xml_sha256": digest(dist / xml.name),
            "mpackage_sha256": digest(dist / package.name),
        }
    suite = build_suite(mudlet_root)
    results[SUITE_NAME] = {
        "xml_sha256": digest(Path(suite["xml"])),
        "mpackage_sha256": digest(Path(suite["mpackage"])),
    }
    return results


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mudlet-root", type=Path, default=ROOT / "mudlet")
    args = parser.parse_args(arguments)
    try:
        print(json.dumps(build_release(args.mudlet_root), indent=2, sort_keys=True))
    except (OSError, ValueError) as error:
        print(f"release build failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
