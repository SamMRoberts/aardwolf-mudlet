from __future__ import annotations

import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from export_aardwolf_map import ExportError, build_export, main  # noqa: E402


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
        ],
    )
    connection.executemany(
        "INSERT INTO exits VALUES (?, ?, ?, ?)",
        [("n", "1", "3", "0"), ("e", "3", "4", "0"), ("e", "4", "1", "0"), ("d", "1", "5", "0")],
    )
    connection.commit()
    connection.close()


class AardwolfMapExporterTests(unittest.TestCase):
    def test_layout_is_deterministic_and_retains_cross_area_edges(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "fixture.db"
            create_fixture(source)
            first, first_report = build_export(source)
            second, second_report = build_export(source)

        self.assertEqual(first, second)
        self.assertEqual(first_report, second_report)
        self.assertEqual(4, len(first["exits"]))
        self.assertEqual(1, first["layout"]["cross_area_edges_retained"])
        self.assertEqual(1, first["layout"]["source_coordinate_collisions"])
        self.assertGreaterEqual(first["layout"]["direction_constraint_conflicts"], 1)
        alpha_coordinates = {
            tuple(room["layout"])
            for room in first["rooms"]
            if room["area_uid"] == "alpha"
        }
        self.assertEqual(4, len(alpha_coordinates))

    def test_direction_validation_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "fixture.db"
            create_fixture(source)
            connection = sqlite3.connect(source)
            connection.execute("UPDATE exits SET dir = 'portal' WHERE fromuid = '1' AND touid = '3'")
            connection.commit()
            connection.close()
            with self.assertRaisesRegex(ExportError, "unsupported exit direction"):
                build_export(source)

    def test_missing_room_reference_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "fixture.db"
            create_fixture(source)
            connection = sqlite3.connect(source)
            connection.execute("UPDATE exits SET touid = '999' WHERE fromuid = '1' AND touid = '3'")
            connection.commit()
            connection.close()
            with self.assertRaisesRegex(ExportError, "references a missing room"):
                build_export(source)

    def test_command_writes_byte_identical_json_on_repeated_exports(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            source = temporary / "fixture.db"
            create_fixture(source)
            outputs = []
            for index in (1, 2):
                output = temporary / f"map-{index}.json"
                report = temporary / f"report-{index}.json"
                markdown = temporary / f"report-{index}.md"
                self.assertEqual(0, main(["--input", str(source), "--output", str(output), "--report-json", str(report), "--report-markdown", str(markdown)]))
                outputs.append((output.read_bytes(), report.read_bytes(), markdown.read_bytes()))
            self.assertEqual(outputs[0], outputs[1])

    def test_shipped_snapshot_counts_and_hash(self) -> None:
        source = ROOT / ".resources" / "Aardwolf.db"
        resource = ROOT / "mudlet" / "aardwolf-map" / "src" / "resources" / "aardwolf-map-v11.json"
        expected, report = build_export(source)
        shipped = json.loads(resource.read_text(encoding="utf-8"))

        self.assertEqual(expected["source"], shipped["source"])
        self.assertEqual({"rooms": 14257, "standard_exits": 53662, "populated_areas": 21, "source_areas": 236, "referenced_environments": 80}, shipped["counts"])
        self.assertEqual(14257, len(shipped["rooms"]))
        self.assertEqual(53662, len(shipped["exits"]))
        self.assertEqual(21, len(shipped["import_area_uids"]))
        self.assertEqual(236, len(shipped["areas"]))
        self.assertEqual(80, len(shipped["environments"]))
        self.assertTrue(all(report["reference_checks"].values()))


if __name__ == "__main__":
    unittest.main()
