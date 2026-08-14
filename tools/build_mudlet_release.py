#!/usr/bin/env python3
"""Validate and publish deterministic native Mudlet release artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "plugin" / "aardwolf-mudlet-dev" / "scripts"))

from build_mudlet_package import build_native  # noqa: E402
from project_contract import load_project  # noqa: E402
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


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


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
