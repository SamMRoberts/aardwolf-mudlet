#!/usr/bin/env python3
"""Build deterministic native Mudlet packages or invoke Muddler."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path
from typing import Any

from common import ToolError, write_text
from project_contract import CATEGORY_INFO, ObjectRecord, Project, load_project


def _add_text(parent: ET.Element, tag: str, text: str) -> None:
    child = ET.SubElement(parent, tag)
    child.text = text


def _active(spec: dict[str, Any]) -> str:
    return "yes" if spec.get("isActive", True) is not False else "no"


def _element_for(record: ObjectRecord) -> ET.Element:
    spec = record.spec
    info = CATEGORY_INFO[record.category]
    tag = info["group"] if spec.get("isFolder") is True else info["item"]
    attributes = {"isActive": _active(spec), "isFolder": "yes" if spec.get("isFolder") is True else "no"}
    if record.category == "timers":
        attributes.update({"isTempTimer": "no", "isOffsetTimer": "no"})
    if record.category == "triggers":
        attributes.update({
            "isTempTrigger": "no", "isMultiline": "yes" if spec.get("multiline") else "no",
            "isPerlSlashGOption": "yes" if spec.get("matchall") else "no",
            "isColorizerTrigger": "yes" if spec.get("highlight") else "no",
            "isFilterTrigger": "yes" if spec.get("filter") else "no",
            "isColorTrigger": "no", "isColorTriggerFg": "no", "isColorTriggerBg": "no",
        })
    element = ET.Element(tag, attributes)
    _add_text(element, "name", str(spec["name"]))
    if record.category == "keys":
        _add_text(element, "packageName", "")
        _add_text(element, "script", record.source_text)
        _add_text(element, "command", str(spec.get("command", "")))
        _add_text(element, "keyCode", str(spec.get("keyCode", "0")))
        _add_text(element, "keyModifier", str(spec.get("keyModifier", "0")))
    elif record.category == "aliases":
        _add_text(element, "script", record.source_text)
        _add_text(element, "command", str(spec.get("command", "")))
        _add_text(element, "packageName", "")
        _add_text(element, "regex", str(spec.get("regex", "")))
    elif record.category == "timers":
        _add_text(element, "script", record.source_text)
        _add_text(element, "command", str(spec.get("command", "")))
        _add_text(element, "packageName", "")
        _add_text(element, "time", str(spec.get("time", "00:00:01.000")))
    elif record.category == "scripts":
        _add_text(element, "script", record.source_text)
        _add_text(element, "packageName", "")
        event_list = ET.SubElement(element, "eventHandlerList")
        handlers = spec.get("eventHandlerList", [])
        if not isinstance(handlers, list) or not all(isinstance(event, str) for event in handlers):
            raise ToolError(f"script {spec['name']} eventHandlerList must be a string array")
        for event in handlers:
            _add_text(event_list, "string", event)
    else:
        _add_text(element, "script", record.source_text)
        _add_text(element, "triggerType", "0")
        _add_text(element, "conditonLineDelta", str(spec.get("multilineDelta", "0")))
        _add_text(element, "mStayOpen", str(spec.get("fireLength", "0")))
        _add_text(element, "mCommand", str(spec.get("command", "")))
        _add_text(element, "packageName", "")
        _add_text(element, "path", "")
        _add_text(element, "mFgColor", str(spec.get("highlightFG", "#ff0000")))
        _add_text(element, "mBgColor", str(spec.get("highlightBG", "#ffff00")))
        _add_text(element, "mSoundFile", str(spec.get("soundFile", "")))
        _add_text(element, "colorTriggerFgColor", "#000000")
        _add_text(element, "colorTriggerBgColor", "#000000")
        patterns = spec.get("patterns", [])
        if not isinstance(patterns, list) or not all(isinstance(pattern, dict) for pattern in patterns):
            raise ToolError(f"trigger {spec['name']} patterns must be an array")
        code_list = ET.SubElement(element, "regexCodeList")
        type_list = ET.SubElement(element, "regexCodePropertyList")
        type_map = {"substring": "0", "regex": "1", "startOfLine": "2", "exactMatch": "3", "lua": "4", "spacer": "5", "color": "6", "colour": "6", "prompt": "7"}
        for pattern in patterns:
            _add_text(code_list, "string", str(pattern.get("pattern", "")))
            _add_text(type_list, "integer", type_map.get(str(pattern.get("type", "substring")), "0"))
    return element


def native_xml(project: Project) -> bytes:
    root = ET.Element("MudletPackage", {"version": "1.001"})
    for category, info in CATEGORY_INFO.items():
        package = ET.SubElement(root, info["package"])
        for record in (candidate for candidate in project.objects if candidate.category == category):
            package.append(_element_for(record))
    ET.SubElement(root, "VariablePackage")
    body = ET.tostring(root, encoding="utf-8", xml_declaration=True, short_empty_elements=False)
    return body.replace(b"?>", b"?>\n<!DOCTYPE MudletPackage>", 1) + b"\n"


def _zip_write(name: str, payload: bytes, archive: zipfile.ZipFile) -> None:
    entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    entry.compress_type = zipfile.ZIP_DEFLATED
    entry.external_attr = 0o100644 << 16
    archive.writestr(entry, payload)


def package_config_lua(metadata: dict[str, Any]) -> bytes:
    """Render the metadata file read by Mudlet's Package Manager.

    Mudlet unpacks an ``.mpackage`` then evaluates ``config.lua`` in a
    restricted Lua state.  It reads the resulting string globals to populate
    the Package Manager; the source-control ``mfile`` is a Muddler input and
    is not consulted by Mudlet at install time.
    """
    package_name = metadata.get("package")
    if not isinstance(package_name, str) or not package_name:
        raise ToolError("package metadata requires a non-empty package name")
    fields = (("author", ""), ("title", ""), ("description", ""), ("version", ""))

    def literal(value: str) -> str:
        for depth in range(16):
            marker = "=" * depth
            closing = f"]{marker}]"
            if closing not in value:
                return f"[{marker}[{value}{closing}"
        raise ToolError("package metadata contains an unsupported Lua long-string delimiter sequence")

    lines = [("mpackage", package_name)]
    for field, default in fields:
        value = metadata.get(field, default)
        if not isinstance(value, str):
            raise ToolError(f"package metadata {field} must be a string")
        lines.append((field, value))
    return ("".join(f"{field} = {literal(value)}\n" for field, value in lines)).encode("utf-8")


def build_native(project: Project) -> dict[str, str]:
    output = project.root / "build"
    if output.is_symlink():
        raise ToolError("build output directory must not be a symbolic link")
    output.mkdir(exist_ok=True)
    xml_payload = native_xml(project)
    xml_path = output / f"{project.metadata['name']}.xml"
    write_text(xml_path, xml_payload.decode("utf-8"))
    package_path = output / f"{project.metadata['name']}.mpackage"
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{package_path.name}.", dir=output)
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        entries = [(xml_path.name, xml_payload), ("config.lua", package_config_lua(project.mfile))]
        resource_root = project.root / "src" / "resources"
        resources = sorted(resource_root.rglob("*"))
        for resource in resources:
            if resource.is_symlink():
                raise ToolError(f"resource must not be a symlink: {resource}")
            if not resource.is_file():
                continue
            if resource.name in {".gitkeep", "EMPTY-CATEGORY.md"}:
                continue
            relative = resource.relative_to(resource_root).as_posix()
            entries.append((f"resources/{relative}", resource.read_bytes()))
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, strict_timestamps=True) as archive:
            for name, payload in sorted(entries):
                _zip_write(name, payload, archive)
        os.replace(temporary, package_path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    return {"mpackage": str(package_path), "xml": str(xml_path)}


def build_muddler(project: Project) -> dict[str, str]:
    executable = shutil.which("muddle")
    if not executable:
        raise ToolError("Muddler backend requires a 'muddle' executable on PATH")
    build = project.root / "build"
    if build.is_symlink():
        raise ToolError("build output directory must not be a symbolic link")
    before = {
        path: (path.stat().st_mtime_ns, path.stat().st_size)
        for path in build.glob("*")
        if path.is_file()
    } if build.is_dir() else {}
    completed = subprocess.run([executable], cwd=project.root, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if completed.returncode != 0:
        raise ToolError(f"muddle failed with exit {completed.returncode}: {completed.stdout.strip()}")
    if build.is_symlink():
        raise ToolError("Muddler created a symbolic-link build output directory")
    packages = sorted(build.glob("*.mpackage"))
    xml_files = sorted(build.glob("*.xml"))
    if not packages or not xml_files:
        raise ToolError("muddle completed without producing both XML and .mpackage output")
    def changed(paths: list[Path]) -> list[Path]:
        return [
            path for path in paths
            if before.get(path) != (path.stat().st_mtime_ns, path.stat().st_size)
        ]
    changed_packages = changed(packages)
    changed_xml = changed(xml_files)
    return {
        "mpackage": str(changed_packages[0] if changed_packages else packages[0]),
        "xml": str(changed_xml[0] if changed_xml else xml_files[0]),
    }


def _release_gate(project: Project) -> None:
    report = next((candidate for candidate in (project.root / "reports" / "conversion-report.json", project.root / "conversion-report.json") if candidate.exists()), None)
    if report is None:
        return
    from common import load_json
    value = load_json(report)
    decisions = value.get("decisions") if isinstance(value, dict) else None
    if not isinstance(decisions, list):
        raise ToolError("conversion-report.json must contain decisions before packaging")
    unresolved = [item.get("item_id", "unknown") for item in decisions if item.get("status") in {"manual-action-required", "unsupported-blocker"}]
    if unresolved:
        raise ToolError("release packaging blocked by: " + ", ".join(sorted(unresolved)))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path)
    parser.add_argument("--backend", choices=("native", "muddler", "both"), default="native")
    args = parser.parse_args(argv)
    try:
        project = load_project(args.project)
        _release_gate(project)
        from validate_aardwolf_mudlet_project import validate
        # A previous native build may be stale after source changes. Validate
        # the source contract first, regenerate the artifacts, then validate
        # those artifacts below.
        release_errors = validate(project.root, release=True, check_native_output=False)
        if release_errors:
            raise ToolError("release validation failed: " + "; ".join(release_errors))
        outputs: dict[str, dict[str, str]] = {}
        if args.backend in {"native", "both"}:
            outputs["native"] = build_native(project)
        if args.backend in {"muddler", "both"}:
            outputs["muddler"] = build_muddler(project)
        output_errors = validate(project.root, release=True)
        if output_errors:
            raise ToolError("built output validation failed: " + "; ".join(output_errors))
        print(json.dumps(outputs, indent=2, sort_keys=True))
        return 0
    except (OSError, ToolError) as error:
        print(f"build failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
