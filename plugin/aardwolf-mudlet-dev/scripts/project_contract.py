"""Validated source-project model shared by package tooling."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from common import LUA_NAMESPACE_RE, ToolError, load_json, slugify


CATEGORY_INFO = {
    "aliases": {"json": "aliases.json", "package": "AliasPackage", "item": "Alias", "group": "AliasGroup"},
    "triggers": {"json": "triggers.json", "package": "TriggerPackage", "item": "Trigger", "group": "TriggerGroup"},
    "timers": {"json": "timers.json", "package": "TimerPackage", "item": "Timer", "group": "TimerGroup"},
    "scripts": {"json": "scripts.json", "package": "ScriptPackage", "item": "Script", "group": "ScriptGroup"},
    "keys": {"json": "keys.json", "package": "KeyPackage", "item": "Key", "group": "KeyGroup"},
}
REQUIRED_SOURCE_DIRECTORIES = tuple((*CATEGORY_INFO, "resources"))
REQUIRED_METADATA = ("name", "version", "namespace", "minimum_mudlet_version", "description", "game")


@dataclass(frozen=True)
class ObjectRecord:
    category: str
    directory: Path
    spec: dict[str, Any]
    source: Path | None
    source_text: str


@dataclass(frozen=True)
class Project:
    root: Path
    metadata: dict[str, Any]
    mfile: dict[str, Any]
    objects: tuple[ObjectRecord, ...]


def _require_string(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ToolError(f"{label} must be a non-empty string")
    return value


def _object_source(directory: Path, spec: dict[str, Any], item_count: int) -> tuple[Path | None, str]:
    if spec.get("isFolder") is True:
        return None, ""
    name = _require_string(spec.get("name"), "object name")
    candidate = directory / f"{slugify(name)}.lua"
    if not candidate.exists() and item_count == 1:
        fallback = directory / "code.lua"
        if fallback.exists():
            candidate = fallback
    if not candidate.exists():
        raise ToolError(f"object {name!r} is missing Lua source {candidate.name}")
    if candidate.is_symlink():
        raise ToolError(f"Lua source must not be a symlink: {candidate}")
    return candidate, candidate.read_text(encoding="utf-8")


def load_project(root: Path) -> Project:
    root = root.resolve()
    if not root.is_dir():
        raise ToolError(f"project is not a directory: {root}")
    metadata = load_json(root / "package-metadata.json")
    if not isinstance(metadata, dict) or metadata.get("schema_version") != 1:
        raise ToolError("package-metadata.json must be a schema version 1 object")
    for field in REQUIRED_METADATA:
        _require_string(metadata.get(field), f"package metadata {field}")
    namespace = metadata["namespace"]
    if not LUA_NAMESPACE_RE.fullmatch(namespace):
        raise ToolError("package metadata namespace must be a valid Lua identifier")
    if metadata["minimum_mudlet_version"] != "4.14":
        raise ToolError("package metadata minimum_mudlet_version must be exactly '4.14'")
    if metadata["game"] != "Aardwolf":
        raise ToolError("package metadata game must be exactly 'Aardwolf'")

    mfile = load_json(root / "mfile")
    if not isinstance(mfile, dict) or mfile.get("package") != metadata["name"] or mfile.get("version") != metadata["version"]:
        raise ToolError("mfile package and version must match package-metadata.json")
    for field in ("author", "title", "description"):
        _require_string(mfile.get(field), f"mfile {field}")

    source_root = root / "src"
    if not source_root.is_dir():
        raise ToolError("project is missing src/")
    for directory_name in REQUIRED_SOURCE_DIRECTORIES:
        directory = source_root / directory_name
        if not directory.is_dir():
            raise ToolError(f"project is missing src/{directory_name}/")
        if directory.is_symlink():
            raise ToolError(f"source directory must not be a symlink: {directory}")

    records: list[ObjectRecord] = []
    for category, info in CATEGORY_INFO.items():
        category_root = source_root / category
        for metadata_path in sorted(category_root.rglob(info["json"])):
            if metadata_path.is_symlink():
                raise ToolError(f"object metadata must not be a symlink: {metadata_path}")
            data = load_json(metadata_path)
            if not isinstance(data, list) or not all(isinstance(item, dict) for item in data):
                raise ToolError(f"{metadata_path.relative_to(root)} must be a JSON array of object definitions")
            for spec in data:
                _require_string(spec.get("name"), f"{metadata_path.relative_to(root)} object name")
                source, source_text = _object_source(metadata_path.parent, spec, len(data))
                records.append(ObjectRecord(category, metadata_path.parent, spec, source, source_text))
    return Project(root, metadata, mfile, tuple(records))


def iter_project_files(project: Project) -> Iterable[Path]:
    source_root = project.root / "src"
    for path in sorted(source_root.rglob("*")):
        if path.is_file():
            yield path
