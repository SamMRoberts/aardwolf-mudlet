"""Shared, standard-library helpers for Aardwolf Mudlet Dev tools."""

from __future__ import annotations

import hashlib
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any


LUA_NAMESPACE_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
MAX_INPUT_BYTES = 2 * 1024 * 1024


class ToolError(ValueError):
    """An expected command-line validation failure."""


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as error:
        raise ToolError(f"missing file: {path}") from error
    except json.JSONDecodeError as error:
        raise ToolError(f"invalid JSON in {path}: {error.msg}") from error


def write_json(path: Path, value: Any) -> None:
    write_text(path, json.dumps(value, indent=2, sort_keys=True) + "\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(value)
        os.replace(temporary, path)
    except BaseException:
        Path(temporary).unlink(missing_ok=True)
        raise


def require_relative_path(value: str, label: str) -> Path:
    candidate = Path(value)
    if not value or candidate.is_absolute() or ".." in candidate.parts:
        raise ToolError(f"{label} must be a non-empty relative path: {value!r}")
    return candidate


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9_]+", "_", value).strip("_").lower()
    return slug or "item"
