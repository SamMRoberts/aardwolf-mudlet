#!/usr/bin/env python3
"""Validate an Aardwolf v11 database conversion and its Mudlet package resource."""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from common import ToolError, load_json
from convert_aardwolf_map_database import ExportError, build_export, markdown_report
from project_contract import load_project
from validate_aardwolf_mudlet_project import validate as validate_project


RESOURCE_NAME = "aardwolf-map-v11.json"
REPORT_JSON_NAME = "aardwolf-db-inventory.json"
REPORT_MARKDOWN_NAME = "aardwolf-db-inventory.md"


def _read_json(path: Path, label: str, errors: list[str]) -> object | None:
    try:
        return load_json(path)
    except ToolError as error:
        errors.append(f"{label}: {error}")
        return None


def _check_artifacts(paths: list[Path], errors: list[str]) -> None:
    packages = [path for path in paths if path.suffix == ".mpackage"]
    xml_files = [path for path in paths if path.suffix == ".xml"]
    if not packages or not xml_files:
        errors.append("artifact validation requires both a native XML and .mpackage file")
        return
    for path in paths:
        if not path.is_file():
            errors.append(f"artifact does not exist: {path}")
    for xml_path in xml_files:
        if not xml_path.is_file():
            continue
        try:
            if ET.parse(xml_path).getroot().tag != "MudletPackage":
                errors.append(f"native XML root is not MudletPackage: {xml_path}")
        except ET.ParseError as error:
            errors.append(f"native XML is invalid: {xml_path}: {error}")
    for package_path in packages:
        if not package_path.is_file():
            continue
        try:
            with zipfile.ZipFile(package_path) as archive:
                names = archive.namelist()
                if f"resources/{RESOURCE_NAME}" not in names:
                    errors.append(f"package is missing converted map resource: {package_path}")
                if "config.lua" not in names:
                    errors.append(f"package is missing Package Manager metadata: {package_path}")
                if len(names) != len(set(names)) or names != sorted(names):
                    errors.append(f"package entries are not deterministic: {package_path}")
        except zipfile.BadZipFile as error:
            errors.append(f"package is invalid: {package_path}: {error}")


def validate(input_database: Path, project_root: Path, artifacts: list[Path] | None = None) -> list[str]:
    errors: list[str] = []
    try:
        expected_resource, expected_report = build_export(input_database)
    except ExportError as error:
        return [str(error)]

    resource = project_root / "src" / "resources" / RESOURCE_NAME
    report_json = project_root / "reports" / REPORT_JSON_NAME
    report_markdown = project_root / "reports" / REPORT_MARKDOWN_NAME
    actual_resource = _read_json(resource, "map resource", errors) if resource.is_file() else None
    if actual_resource is None:
        errors.append(f"project is missing generated resource: {resource.relative_to(project_root)}")
    elif actual_resource != expected_resource:
        errors.append("generated map resource does not exactly match the validated database export")
    actual_report = _read_json(report_json, "map report", errors) if report_json.is_file() else None
    if actual_report is None:
        errors.append(f"project is missing generated report: {report_json.relative_to(project_root)}")
    elif actual_report != expected_report:
        errors.append("generated map report does not exactly match the validated database export")
    if not report_markdown.is_file():
        errors.append(f"project is missing generated report: {report_markdown.relative_to(project_root)}")
    elif report_markdown.read_text(encoding="utf-8") != markdown_report(expected_report):
        errors.append("generated Markdown report does not exactly match the validated database export")

    try:
        project = load_project(project_root)
    except ToolError as error:
        errors.append(str(error))
        project = None
    if project is not None:
        errors.extend(validate_project(project_root, check_native_output=True))
        if artifacts is not None:
            artifact_paths = artifacts or [
                project.root / "build" / f"{project.metadata['name']}.xml",
                project.root / "build" / f"{project.metadata['name']}.mpackage",
            ]
            _check_artifacts(artifact_paths, errors)
    return sorted(set(errors))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Aardwolf.db v11 source database")
    parser.add_argument("--project", required=True, type=Path, help="source-controlled Mudlet package project")
    parser.add_argument("--artifacts", nargs="*", type=Path, metavar="ARTIFACT", help="also validate native build outputs; omit values to use PROJECT/build")
    parser.add_argument("--json", action="store_true", help="emit machine-readable validation output")
    args = parser.parse_args(argv)
    errors = validate(args.input, args.project, args.artifacts)
    if args.json:
        print(json.dumps({"errors": errors, "valid": not errors}, indent=2, sort_keys=True))
    elif errors:
        for error in errors:
            print(f"validation failed: {error}", file=sys.stderr)
    else:
        print("validation passed")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
