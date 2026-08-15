#!/usr/bin/env python3
"""Validate the source contract for an Aardwolf Mudlet package project."""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from common import ToolError, load_json, require_relative_path
from build_mudlet_package import package_config_lua
from project_contract import CATEGORY_INFO, Project, iter_project_files, load_project


GLOBAL_ASSIGNMENT_RE = re.compile(r"(?m)^\s*(?!local\b)([A-Za-z_][A-Za-z0-9_]*)\s*=")
GLOBAL_FUNCTION_RE = re.compile(r"(?m)^\s*function\s+([A-Za-z_][A-Za-z0-9_]*(?:[.:][A-Za-z_][A-Za-z0-9_]*)*)\s*\(")
FORBIDDEN_RUNTIME_RE = re.compile(r"\b(?:os\.execute|io\.popen|package\.loadlib|loadfile|dofile)\b")
REQUIRED_MODULES = ("state", "settings", "commands", "protocol", "ui", "lifecycle", "help")
REPORT_STATUSES = {
    "converted",
    "converted-with-review",
    "manual-action-required",
    "unsupported-blocker",
    "not-applicable",
    "intentionally-retired",
}


def _check_namespace(project: Project, errors: list[str]) -> None:
    namespace = project.metadata["namespace"]
    for record in project.objects:
        name = record.spec["name"]
        if not name.startswith(namespace + "."):
            errors.append(f"{record.category} object {name!r} must start with namespace {namespace!r}")
        if record.source is None:
            continue
        source_label = record.source.relative_to(project.root)
        for match in GLOBAL_ASSIGNMENT_RE.finditer(record.source_text):
            global_name = match.group(1)
            if global_name != namespace:
                errors.append(f"{source_label}: global assignment {global_name!r} is not namespaced")
        for match in GLOBAL_FUNCTION_RE.finditer(record.source_text):
            function_name = match.group(1)
            if not function_name.startswith((namespace + ".", namespace + ":")):
                errors.append(f"{source_label}: global function {function_name!r} is not namespaced")
        if FORBIDDEN_RUNTIME_RE.search(record.source_text):
            errors.append(f"{source_label}: unsafe file, shell, or native-library API requires manual review")


def _check_architecture(project: Project, errors: list[str]) -> None:
    namespace = project.metadata["namespace"]
    script_names = {record.spec["name"] for record in project.objects if record.category == "scripts"}
    if f"{namespace}.main" in script_names:
        return
    for module in REQUIRED_MODULES:
        expected = f"{namespace}.{module}"
        if expected not in script_names:
            errors.append(f"project is missing namespaced {module} script {expected!r}")


def _check_documentation(project: Project, errors: list[str]) -> None:
    for name in ("README.md", "HELP.md"):
        path = project.root / name
        if not path.is_file() or not path.read_text(encoding="utf-8").strip():
            errors.append(f"project is missing non-empty {name}")
    tests = project.root / "tests"
    if not tests.is_dir() or not any(path.is_file() for path in tests.rglob("*")):
        errors.append("project is missing tests")


def _check_paths(project: Project, errors: list[str]) -> None:
    source_root = project.root / "src"
    for path in source_root.rglob("*"):
        if path.is_symlink():
            errors.append(f"source file must not be a symlink: {path.relative_to(project.root)}")
    for path in iter_project_files(project):
        if path.is_symlink():
            errors.append(f"source file must not be a symlink: {path.relative_to(project.root)}")
    for record in project.objects:
        for field in ("resource", "resourcePath", "soundFile", "icon"):
            value = record.spec.get(field)
            if value in (None, ""):
                continue
            if not isinstance(value, str):
                errors.append(f"{record.category} object {record.spec['name']!r} has a non-string {field}")
                continue
            try:
                require_relative_path(value, f"{record.category} object {record.spec['name']!r} {field}")
            except ToolError as error:
                errors.append(str(error))


def _report_path(project: Project) -> Path | None:
    for candidate in (project.root / "reports" / "conversion-report.json", project.root / "conversion-report.json"):
        if candidate.exists():
            return candidate
    return None


def _check_report(project: Project, errors: list[str], release: bool) -> None:
    report = _report_path(project)
    if report is None:
        return
    try:
        value = load_json(report)
    except ToolError as error:
        errors.append(str(error))
        return
    decisions = value.get("decisions") if isinstance(value, dict) else None
    if not isinstance(decisions, list):
        errors.append("conversion-report.json must contain a decisions array")
        return
    decision_ids: set[str] = set()
    for decision in decisions:
        if not isinstance(decision, dict):
            errors.append("conversion-report.json contains an invalid decision")
            continue
        item_id = decision.get("item_id")
        if not isinstance(item_id, str) or not item_id:
            errors.append("conversion-report.json decision has no item_id")
        elif item_id in decision_ids:
            errors.append(f"conversion-report.json has duplicate disposition for {item_id}")
        else:
            decision_ids.add(item_id)
        if decision.get("status") not in REPORT_STATUSES:
            errors.append(f"conversion-report.json has invalid status for {item_id or 'unknown'}")
        if not isinstance(decision.get("reason"), str) or not decision["reason"].strip():
            errors.append(f"conversion-report.json decision {item_id or 'unknown'} has no reason")
        targets = decision.get("target_paths")
        if not isinstance(targets, list) or not all(isinstance(target, str) and target for target in targets):
            errors.append(f"conversion-report.json decision {item_id or 'unknown'} has invalid target_paths")
        elif any(_invalid_target_path(target) for target in targets):
            errors.append(f"conversion-report.json decision {item_id or 'unknown'} has unsafe target_paths")
        if decision.get("status") == "intentionally-retired":
            retirement = decision.get("retirement")
            if not isinstance(retirement, dict):
                errors.append(f"retired conversion item {item_id or 'unknown'} has no retirement metadata")
            else:
                for field in ("user_impact", "migration"):
                    value = retirement.get(field)
                    if not isinstance(value, str) or not value.strip():
                        errors.append(f"retired conversion item {item_id or 'unknown'} has no retirement {field}")
            if not isinstance(targets, list) or "reports/retirements.md" not in targets:
                errors.append(f"retired conversion item {item_id or 'unknown'} does not target reports/retirements.md")
        if release and decision.get("status") in {"manual-action-required", "unsupported-blocker"}:
            errors.append(f"release is blocked by conversion item {item_id or 'unknown'}")
        if isinstance(item_id, str) and item_id.startswith("notice:") and not targets:
            errors.append(f"notice {item_id} has no preservation target")
    inventory = project.root / "reports" / "inventory.json"
    if release and not inventory.is_file():
        errors.append("release conversion report is missing reports/inventory.json")
    if release and any(isinstance(decision, dict) and decision.get("status") == "intentionally-retired" for decision in decisions):
        retirements = project.root / "reports" / "retirements.md"
        if not retirements.is_file() or not retirements.read_text(encoding="utf-8").strip():
            errors.append("release conversion report is missing reports/retirements.md")
    elif inventory.is_file():
        try:
            value = load_json(inventory)
            items = value.get("items") if isinstance(value, dict) else None
            inventory_ids = {item.get("id") for item in items if isinstance(item, dict) and isinstance(item.get("id"), str)} if isinstance(items, list) else set()
            if not inventory_ids or len(inventory_ids) != len(items):
                errors.append("reports/inventory.json has invalid item IDs")
            elif inventory_ids != decision_ids:
                errors.append("conversion report decisions do not completely match reports/inventory.json")
        except ToolError as error:
            errors.append(str(error))


def _invalid_target_path(target: str) -> bool:
    try:
        require_relative_path(target, "conversion report target path")
    except ToolError:
        return True
    return False


def _check_native_output(project: Project, errors: list[str]) -> None:
    build = project.root / "build"
    xml_path = build / f"{project.metadata['name']}.xml"
    package_path = build / f"{project.metadata['name']}.mpackage"
    if not xml_path.exists() and not package_path.exists():
        return
    if xml_path.exists():
        try:
            root = ET.parse(xml_path).getroot()
            if root.tag != "MudletPackage":
                errors.append("native XML root must be MudletPackage")
            else:
                for category, info in CATEGORY_INFO.items():
                    package = root.find(info["package"])
                    generated = [] if package is None else [name.text for name in package.iter("name")]
                    expected = [record.spec["name"] for record in project.objects if record.category == category]
                    if generated != expected:
                        errors.append(f"native XML {category} objects do not match source-project order")
        except ET.ParseError as error:
            errors.append(f"native XML is invalid: {error}")
    if package_path.exists():
        try:
            with zipfile.ZipFile(package_path) as archive:
                names = archive.namelist()
                if len(names) != len(set(names)):
                    errors.append("native .mpackage has duplicate entries")
                if names != sorted(names):
                    errors.append("native .mpackage entries must be sorted")
                if any(name.startswith("/") or ".." in Path(name).parts for name in names):
                    errors.append("native .mpackage has an unsafe entry path")
                if f"{project.metadata['name']}.xml" not in names:
                    errors.append("native .mpackage is missing its XML entry")
                else:
                    xml_member = archive.read(f"{project.metadata['name']}.xml")
                    if xml_path.exists() and xml_member != xml_path.read_bytes():
                        errors.append("native XML and .mpackage XML entry differ")
                if "config.lua" not in names:
                    errors.append("native .mpackage is missing its Mudlet Package Manager metadata")
                else:
                    try:
                        config = archive.read("config.lua")
                        expected_config = package_config_lua(project.mfile)
                    except (UnicodeDecodeError, ToolError) as error:
                        errors.append(f"native .mpackage Package Manager metadata is invalid: {error}")
                    else:
                        if config != expected_config:
                            errors.append("native .mpackage Package Manager metadata differs from source project metadata")
                expected_resources = {
                    f"resources/{path.relative_to(project.root / 'src' / 'resources').as_posix()}"
                    for path in (project.root / "src" / "resources").rglob("*")
                    if path.is_file() and not path.is_symlink() and path.name not in {".gitkeep", "EMPTY-CATEGORY.md"}
                }
                actual_resources = {name for name in names if name.startswith("resources/")}
                if actual_resources != expected_resources:
                    errors.append("native .mpackage resources do not match source-project resources")
                for entry in archive.infolist():
                    if entry.date_time != (1980, 1, 1, 0, 0, 0):
                        errors.append(f"native .mpackage entry has non-normalized timestamp: {entry.filename}")
                    if (entry.external_attr >> 16) & 0o777 != 0o644:
                        errors.append(f"native .mpackage entry has non-normalized permissions: {entry.filename}")
        except zipfile.BadZipFile as error:
            errors.append(f"native .mpackage is invalid: {error}")


def validate(project_root: Path, release: bool = False, check_native_output: bool = True) -> list[str]:
    errors: list[str] = []
    try:
        project = load_project(project_root)
    except ToolError as error:
        return [str(error)]
    _check_namespace(project, errors)
    _check_architecture(project, errors)
    _check_documentation(project, errors)
    _check_paths(project, errors)
    _check_report(project, errors, release)
    if check_native_output:
        _check_native_output(project, errors)
    return sorted(errors)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--release", action="store_true", help="reject unresolved conversion behavior")
    parser.add_argument("--json", action="store_true", help="emit machine-readable validation output")
    args = parser.parse_args(argv)
    errors = validate(args.project, args.release)
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
