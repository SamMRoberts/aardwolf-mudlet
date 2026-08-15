from __future__ import annotations

import hashlib
import json
import os
import shutil
import stat
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from build_mudlet_package import build_muddler, build_native, main as package_main
from common import ToolError, write_json, write_text
from project_contract import load_project
from validate_aardwolf_mudlet_project import validate


def make_project(root: Path, *, tick_timer: bool = False, compact: bool = False) -> Path:
    namespace = "aw_tick_timer" if tick_timer else "aw_simple_alias"
    name = "aardwolf-tick-timer" if tick_timer else "simple-alias"
    write_json(root / "package-metadata.json", {
        "schema_version": 1,
        "name": name,
        "version": "1.0.0",
        "namespace": namespace,
        "minimum_mudlet_version": "4.14",
        "description": "Fixture project",
        "game": "Aardwolf",
    })
    write_json(root / "mfile", {"package": name, "version": "1.0.0"})
    for category in ("scripts", "aliases", "triggers", "timers", "keys", "resources"):
        (root / "src" / category / namespace).mkdir(parents=True, exist_ok=True)
    write_text(root / "README.md", "# Fixture\n")
    write_text(root / "HELP.md", "# Help\n")
    write_text(root / "tests" / "smoke.lua", "return true\n")
    modules = ["state", "settings", "commands", "protocol", "ui", "lifecycle", "help"]
    if compact:
        write_json(root / "src" / "scripts" / namespace / "scripts.json", [{"name": f"{namespace}.main"}])
        write_text(
            root / "src" / "scripts" / namespace / f"{namespace}_main.lua",
            "\n".join([
                f"{namespace} = {namespace} or {{}}",
                *(f"function {namespace}.{module}_entry() end" for module in modules),
            ]) + "\n",
        )
    else:
        write_json(root / "src" / "scripts" / namespace / "scripts.json", [
            {"name": f"{namespace}.{module}", "eventHandlerList": ["sysInstall"] if module == "lifecycle" else []}
            for module in modules
        ])
        for module in modules:
            body = f"function {namespace}.{module}_entry() end\n"
            if module == "lifecycle":
                body = f"{namespace} = {namespace} or {{}}\nfunction {namespace}.initialize() end\n"
            write_text(root / "src" / "scripts" / namespace / f"{namespace}_{module}.lua", body)
    write_json(root / "src" / "aliases" / namespace / "aliases.json", [{"name": f"{namespace}.greet", "regex": "^greet (.+)$"}])
    write_text(root / "src" / "aliases" / namespace / f"{namespace}_greet.lua", f"function {namespace}.greet() end\n")
    if tick_timer:
        write_json(root / "src" / "timers" / namespace / "timers.json", [{"name": f"{namespace}.second", "time": "00:00:01.000"}])
        write_text(root / "src" / "timers" / namespace / f"{namespace}_second.lua", f"function {namespace}.second() end\n")
    return root


class PackageToolsTests(unittest.TestCase):
    fixtures = ROOT / "tests" / "fixtures"

    def test_converted_fixture_matches_expected_native_xml(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = Path(temporary) / "simple_alias"
            shutil.copytree(self.fixtures / "projects" / "simple_alias", project_root)
            outputs = build_native(load_project(project_root))
            self.assertEqual(
                Path(outputs["xml"]).read_text(encoding="utf-8"),
                (self.fixtures / "expected" / "simple_alias.xml").read_text(encoding="utf-8"),
            )
            self.assertEqual(validate(project_root, release=True), [])

    def test_native_build_is_reproducible_and_valid(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project", tick_timer=True)
            project = load_project(project_root)
            first = build_native(project)
            first_hash = hashlib.sha256(Path(first["mpackage"]).read_bytes()).hexdigest()
            second = build_native(load_project(project_root))
            second_hash = hashlib.sha256(Path(second["mpackage"]).read_bytes()).hexdigest()
            self.assertEqual(first_hash, second_hash)
            with zipfile.ZipFile(first["mpackage"]) as archive:
                self.assertEqual(archive.namelist(), sorted(archive.namelist()))
                self.assertIn("aardwolf-tick-timer.xml", archive.namelist())
                self.assertEqual(json.loads(archive.read("mfile")), json.loads((project_root / "mfile").read_text(encoding="utf-8")))
            self.assertEqual(validate(project_root, release=True), [])

    def test_compact_main_script_is_a_valid_project_architecture(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project", compact=True)
            self.assertEqual(validate(project_root, release=True), [])
            outputs = build_native(load_project(project_root))
            self.assertTrue(Path(outputs["xml"]).is_file())

    def test_release_build_replaces_stale_native_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project")
            build_native(load_project(project_root))
            source = project_root / "src" / "scripts" / "aw_simple_alias" / "aw_simple_alias_state.lua"
            write_text(source, "function aw_simple_alias.state_entry() return 'changed' end\n")
            self.assertEqual(package_main([str(project_root), "--backend", "native"]), 0)
            self.assertEqual(validate(project_root, release=True), [])

    def test_namespace_violation_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project")
            path = project_root / "src" / "aliases" / "aw_simple_alias" / "aw_simple_alias_greet.lua"
            write_text(path, "function unsafe_global() end\n")
            self.assertTrue(any("not namespaced" in error for error in validate(project_root)))

    def test_resource_path_traversal_is_reported(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project")
            alias_metadata = project_root / "src" / "aliases" / "aw_simple_alias" / "aliases.json"
            write_json(alias_metadata, [{"name": "aw_simple_alias.greet", "regex": "^greet$", "soundFile": "../outside.wav"}])
            self.assertTrue(any("relative path" in error for error in validate(project_root)))

    def test_release_rejects_unresolved_conversion(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project")
            write_json(project_root / "conversion-report.json", {"decisions": [{"item_id": "unknown:1", "status": "unsupported-blocker", "target_paths": [], "reason": "DLL"}]})
            self.assertTrue(any("release is blocked" in error for error in validate(project_root, release=True)))

    def test_release_requires_retirement_metadata_and_ledger(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project")
            decision = {
                "item_id": "unknown:1",
                "status": "intentionally-retired",
                "target_paths": ["reports/retirements.md"],
                "reason": "No portable replacement.",
            }
            write_json(project_root / "conversion-report.json", {"decisions": [decision]})
            errors = validate(project_root, release=True)
            self.assertTrue(any("retirement metadata" in error for error in errors))
            decision["retirement"] = {"user_impact": "Feature unavailable.", "migration": "No replacement."}
            write_json(project_root / "conversion-report.json", {"decisions": [decision]})
            errors = validate(project_root, release=True)
            self.assertTrue(any("reports/retirements.md" in error for error in errors))

    def test_muddler_adapter_accepts_fake_executable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            project_root = make_project(temporary_path / "project")
            fake_bin = temporary_path / "bin"
            fake_bin.mkdir()
            fake = fake_bin / "muddle"
            write_text(fake, "#!/bin/sh\nmkdir -p build\nprintf x > build/fake.xml\nprintf x > build/fake.mpackage\n")
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
            with mock.patch.dict(os.environ, {"PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}"}):
                outputs = build_muddler(load_project(project_root))
            self.assertTrue(outputs["xml"].endswith("fake.xml"))
            self.assertTrue(outputs["mpackage"].endswith("fake.mpackage"))

    def test_muddler_adapter_uses_its_outputs_after_native_build(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            project_root = make_project(temporary_path / "project")
            build_native(load_project(project_root))
            fake_bin = temporary_path / "bin"
            fake_bin.mkdir()
            fake = fake_bin / "muddle"
            write_text(fake, "#!/bin/sh\nmkdir -p build\nprintf x > build/fake.xml\nprintf x > build/fake.mpackage\n")
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
            with mock.patch.dict(os.environ, {"PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}"}):
                outputs = build_muddler(load_project(project_root))
            self.assertTrue(outputs["xml"].endswith("fake.xml"))
            self.assertTrue(outputs["mpackage"].endswith("fake.mpackage"))

    def test_muddler_missing_is_explicit(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            project_root = make_project(Path(temporary) / "project")
            with mock.patch("build_mudlet_package.shutil.which", return_value=None):
                with self.assertRaisesRegex(ToolError, "requires a 'muddle'"):
                    build_muddler(load_project(project_root))


if __name__ == "__main__":
    unittest.main()
