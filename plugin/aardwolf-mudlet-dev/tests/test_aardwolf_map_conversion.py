from __future__ import annotations

import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TESTS = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(TESTS))

from build_mudlet_package import build_native  # noqa: E402
from common import write_json  # noqa: E402
from convert_aardwolf_map_database import ExportError, build_export, main, source_sha256  # noqa: E402
from project_contract import load_project  # noqa: E402
from test_package_tools import make_project  # noqa: E402
from validate_aardwolf_map_conversion import validate  # noqa: E402


def create_fixture(path: Path) -> None:
    connection = sqlite3.connect(path)
    connection.executescript(
        """
        PRAGMA user_version = 11;
        CREATE TABLE areas(uid TEXT PRIMARY KEY, name, texture, color, flags);
        CREATE TABLE bookmarks(uid TEXT PRIMARY KEY, notes);
        CREATE TABLE environments(uid TEXT PRIMARY KEY, name, color);
        CREATE TABLE exits(dir TEXT, fromuid TEXT, touid TEXT, level TEXT);
        CREATE TABLE rooms(uid TEXT PRIMARY KEY, name, area, building, terrain, info, notes, x, y, z, norecall, noportal, ignore_exits_mismatch);
        CREATE TABLE storage(name, data);
        CREATE TABLE terrain(uid TEXT PRIMARY KEY, value TEXT);
        """
    )
    connection.executemany(
        "INSERT INTO areas VALUES (?, ?, ?, ?, ?)",
        [("alpha", "Alpha", None, None, None), ("beta", "Beta", None, None, None)],
    )
    connection.execute("INSERT INTO environments VALUES (1, 'grass', 'green')")
    connection.executemany(
        "INSERT INTO rooms VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
            ("1", "Pinned one", "alpha", None, "grass", None, None, 0, 0, 0, 0, 0, 0),
            ("2", "Pinned collision", "alpha", None, "grass", None, None, 0, 0, 0, 0, 0, 0),
            ("3", "North", "alpha", None, "grass", None, None, None, None, None, 0, 0, 0),
            ("4", "East", "alpha", None, "grass", None, None, None, None, None, 0, 0, 0),
            ("5", "Other area", "beta", None, "grass", None, None, None, None, None, 0, 0, 0),
            ("6", "Upper floor", "alpha", None, "grass", None, None, None, None, None, 0, 0, 0),
            ("7", "Disconnected", "beta", None, "grass", None, None, None, None, None, 0, 0, 0),
        ],
    )
    connection.executemany(
        "INSERT INTO exits VALUES (?, ?, ?, ?)",
        [("n", "1", "3", "0"), ("e", "3", "4", "0"), ("e", "4", "1", "0"), ("u", "4", "6", "0"), ("d", "6", "4", "0"), ("d", "1", "5", "0")],
    )
    connection.commit()
    connection.close()


class AardwolfMapConversionTests(unittest.TestCase):
    def test_test_only_lua_stub_documents_merge_safe_import_contract(self) -> None:
        stub = (TESTS / "fixtures" / "map_importer_stub.lua").read_text(encoding="utf-8")
        self.assertIn('"aardwolf-map:vnum:" .. room.vnum', stub)
        self.assertIn('getRoomUserData(existing, "aardwolf_map.owner")', stub)
        self.assertIn('aardwolf_map.state.resume = { sha256 = snapshot.source.sha256', stub)
        self.assertIn('centerview(id)', stub)
        self.assertIn('killAnonymousEventHandler(aardwolf_map.event)', stub)
        for forbidden in ("clearMap", "closeMap", "loadMap", "send(", "setRoomEnv"):
            self.assertNotIn(forbidden, stub)

    def test_export_is_deterministic_and_leaves_source_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "fixture.db"
            create_fixture(source)
            before = source_sha256(source)
            first, first_report = build_export(source)
            second, second_report = build_export(source)
            self.assertEqual(before, source_sha256(source))
        self.assertEqual(first, second)
        self.assertEqual(first_report, second_report)
        self.assertEqual(6, len(first["exits"]))
        self.assertEqual(1, first["layout"]["cross_area_edges_retained"])
        self.assertEqual(1, first["layout"]["source_coordinate_collisions"])
        self.assertGreaterEqual(first["layout"]["direction_constraint_conflicts"], 1)
        self.assertGreaterEqual(first["layout"]["component_roots"], 1)

    def test_command_writes_byte_identical_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "fixture.db"
            create_fixture(source)
            outputs = []
            for suffix in ("one", "two"):
                resource = directory / f"map-{suffix}.json"
                report = directory / f"report-{suffix}.json"
                markdown = directory / f"report-{suffix}.md"
                self.assertEqual(0, main(["--input", str(source), "--output", str(resource), "--report-json", str(report), "--report-markdown", str(markdown)]))
                outputs.append(tuple(path.read_bytes() for path in (resource, report, markdown)))
        self.assertEqual(outputs[0], outputs[1])

    def test_schema_and_reference_errors_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "fixture.db"
            create_fixture(source)
            connection = sqlite3.connect(source)
            try:
                connection.execute("UPDATE exits SET dir = 'portal' WHERE fromuid = '1' AND touid = '3'")
                connection.commit()
            finally:
                connection.close()
            with self.assertRaisesRegex(ExportError, "unsupported exit direction"):
                build_export(source)

            source.unlink()
            create_fixture(source)
            connection = sqlite3.connect(source)
            try:
                connection.execute("UPDATE exits SET touid = '999' WHERE fromuid = '1' AND touid = '3'")
                connection.commit()
            finally:
                connection.close()
            with self.assertRaisesRegex(ExportError, "references a missing room"):
                build_export(source)

            source.unlink()
            create_fixture(source)
            connection = sqlite3.connect(source)
            try:
                connection.execute("UPDATE rooms SET uid = '01' WHERE uid = '1'")
                connection.commit()
            finally:
                connection.close()
            with self.assertRaisesRegex(ExportError, "canonical numeric room uid"):
                build_export(source)

            source.unlink()
            create_fixture(source)
            connection = sqlite3.connect(source)
            try:
                connection.execute("ALTER TABLE rooms RENAME COLUMN notes TO old_notes")
                connection.commit()
            finally:
                connection.close()
            with self.assertRaisesRegex(ExportError, "missing required columns"):
                build_export(source)

            wrong_version = directory / "wrong-version.db"
            create_fixture(wrong_version)
            connection = sqlite3.connect(wrong_version)
            try:
                connection.execute("PRAGMA user_version = 10")
                connection.commit()
            finally:
                connection.close()
            with self.assertRaisesRegex(ExportError, "expected SQLite user_version 11"):
                build_export(wrong_version)

    def test_output_symlink_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "fixture.db"
            create_fixture(source)
            target = directory / "target"
            target.mkdir()
            linked = directory / "linked"
            linked.symlink_to(target, target_is_directory=True)
            self.assertEqual(2, main(["--input", str(source), "--output", str(linked / "map.json"), "--report-json", str(directory / "report.json"), "--report-markdown", str(directory / "report.md")]))

    def test_source_symlink_malformed_coordinate_and_source_overwrite_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "fixture.db"
            create_fixture(source)
            linked_source = directory / "linked.db"
            linked_source.symlink_to(source)
            with self.assertRaisesRegex(ExportError, "must not be a symlink"):
                build_export(linked_source)
            self.assertEqual(2, main(["--input", str(source), "--output", str(source), "--report-json", str(directory / "report.json"), "--report-markdown", str(directory / "report.md")]))
            connection = sqlite3.connect(source)
            try:
                connection.execute("UPDATE rooms SET x = 'not-a-coordinate' WHERE uid = '1'")
                connection.commit()
            finally:
                connection.close()
            with self.assertRaisesRegex(ExportError, "coordinate is not an integer"):
                build_export(source)

    def test_validator_accepts_exact_resource_reports_and_native_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "fixture.db"
            create_fixture(source)
            project = make_project(directory / "project")
            resource = project / "src" / "resources" / "aardwolf-map-v11.json"
            report = project / "reports" / "aardwolf-db-inventory.json"
            markdown = project / "reports" / "aardwolf-db-inventory.md"
            self.assertEqual(0, main(["--input", str(source), "--output", str(resource), "--report-json", str(report), "--report-markdown", str(markdown)]))
            build_native(load_project(project))
            self.assertEqual([], validate(source, project, []))
            self.assertTrue((project / "build" / "simple-alias.mpackage").is_file())

    def test_validator_rejects_resource_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = directory / "fixture.db"
            create_fixture(source)
            project = make_project(directory / "project")
            resource = project / "src" / "resources" / "aardwolf-map-v11.json"
            report = project / "reports" / "aardwolf-db-inventory.json"
            markdown = project / "reports" / "aardwolf-db-inventory.md"
            self.assertEqual(0, main(["--input", str(source), "--output", str(resource), "--report-json", str(report), "--report-markdown", str(markdown)]))
            data = json.loads(resource.read_text(encoding="utf-8"))
            data["counts"]["rooms"] = 999
            write_json(resource, data)
            self.assertIn("generated map resource does not exactly match the validated database export", validate(source, project))


if __name__ == "__main__":
    unittest.main()
