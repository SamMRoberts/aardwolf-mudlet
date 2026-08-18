#!/usr/bin/env python3
"""Convert an Aardwolf MUSHclient v11 map database into a Mudlet package resource.

The source is opened immutable and read-only. This tool only understands the
known Aardwolf v11 schema and fails closed for every schema or reference error.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import sys
import tempfile
from collections import Counter, deque
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = 1
DATABASE_USER_VERSION = 11
DIRECTION_ORDER = ("n", "e", "s", "w", "u", "d")
DIRECTION_INDEX = {direction: index for index, direction in enumerate(DIRECTION_ORDER)}
DIRECTION_OFFSETS = {
    "n": (0, 1, 0), "e": (1, 0, 0), "s": (0, -1, 0),
    "w": (-1, 0, 0), "u": (0, 0, 1), "d": (0, 0, -1),
}
REQUIRED_COLUMNS = {
    "areas": {"uid", "name", "texture", "color", "flags"},
    "bookmarks": {"uid", "notes"},
    "environments": {"uid", "name", "color"},
    "exits": {"dir", "fromuid", "touid", "level"},
    "rooms": {
        "uid", "name", "area", "building", "terrain", "info", "notes", "x", "y", "z",
        "norecall", "noportal", "ignore_exits_mismatch",
    },
    "storage": {"name", "data"},
    "terrain": set(),
}


class ExportError(ValueError):
    """The supplied source or requested output is unsafe or incompatible."""


def source_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def open_readonly_database(path: Path) -> sqlite3.Connection:
    if path.is_symlink():
        raise ExportError(f"source database must not be a symlink: {path}")
    if not path.is_file():
        raise ExportError(f"source database does not exist: {path}")
    uri = f"file:{path.resolve().as_posix()}?mode=ro&immutable=1"
    try:
        connection = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as error:
        raise ExportError(f"cannot open source database read-only: {error}") from error
    connection.execute("PRAGMA query_only = ON")
    return connection


def table_columns(connection: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')}


def validate_schema(connection: sqlite3.Connection) -> dict[str, int]:
    user_version = connection.execute("PRAGMA user_version").fetchone()[0]
    if user_version != DATABASE_USER_VERSION:
        raise ExportError(f"expected SQLite user_version {DATABASE_USER_VERSION}, found {user_version}")
    tables = {
        row[0] for row in connection.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
        )
    }
    missing = sorted(set(REQUIRED_COLUMNS) - tables)
    if missing:
        raise ExportError(f"missing required tables: {', '.join(missing)}")
    for table, required in REQUIRED_COLUMNS.items():
        missing_columns = sorted(required - table_columns(connection, table))
        if missing_columns:
            raise ExportError(f"table {table} missing required columns: {', '.join(missing_columns)}")
    return {table: connection.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0] for table in sorted(tables)}


def require_integer_uid(value: Any, label: str) -> int:
    text = str(value)
    try:
        number = int(text)
    except (TypeError, ValueError) as error:
        raise ExportError(f"{label} must be a numeric room uid, found {value!r}") from error
    if str(number) != text:
        raise ExportError(f"{label} must be a canonical numeric room uid, found {value!r}")
    return number


def nullable_text(value: Any) -> str | None:
    return None if value is None else str(value)


def nullable_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as error:
        raise ExportError(f"coordinate is not an integer: {value!r}") from error


def load_snapshot(connection: sqlite3.Connection) -> tuple[dict[str, Any], dict[str, bool]]:
    areas = [
        {"uid": str(row[0]), "name": nullable_text(row[1]) or "", "texture": nullable_text(row[2]), "color": nullable_text(row[3]), "flags": nullable_text(row[4])}
        for row in connection.execute("SELECT uid, name, texture, color, flags FROM areas ORDER BY uid COLLATE BINARY")
    ]
    environments = [
        {"uid": int(row[0]), "name": nullable_text(row[1]) or "", "color": nullable_text(row[2])}
        for row in connection.execute("SELECT uid, name, color FROM environments ORDER BY uid")
    ]
    areas_by_uid = {area["uid"]: area for area in areas}
    environments_by_name = {environment["name"]: environment for environment in environments}
    if len(areas_by_uid) != len(areas):
        raise ExportError("duplicate area uid")
    if len(environments_by_name) != len(environments):
        raise ExportError("duplicate environment name")

    rooms: list[dict[str, Any]] = []
    for row in connection.execute(
        "SELECT uid, name, area, building, terrain, info, notes, x, y, z, norecall, noportal, ignore_exits_mismatch FROM rooms"
    ):
        vnum = require_integer_uid(row[0], "room uid")
        area_uid = nullable_text(row[2]) or ""
        terrain = nullable_text(row[4]) or ""
        if area_uid not in areas_by_uid:
            raise ExportError(f"room {vnum} references missing area {area_uid!r}")
        if terrain not in environments_by_name:
            raise ExportError(f"room {vnum} references missing environment {terrain!r}")
        rooms.append({
            "vnum": vnum, "name": nullable_text(row[1]) or "", "area_uid": area_uid,
            "building": nullable_text(row[3]), "terrain": terrain,
            "terrain_uid": environments_by_name[terrain]["uid"],
            "info": nullable_text(row[5]), "notes": nullable_text(row[6]),
            "source_coordinates": [nullable_int(row[7]), nullable_int(row[8]), nullable_int(row[9])],
            "norecall": int(row[10] or 0), "noportal": int(row[11] or 0),
            "ignore_exits_mismatch": int(row[12] or 0),
        })
    rooms.sort(key=lambda room: room["vnum"])
    rooms_by_vnum = {room["vnum"]: room for room in rooms}
    if len(rooms_by_vnum) != len(rooms):
        raise ExportError("duplicate numeric room uid")

    exits: list[dict[str, Any]] = []
    for row in connection.execute("SELECT dir, fromuid, touid, level FROM exits"):
        direction = nullable_text(row[0]) or ""
        if direction not in DIRECTION_INDEX:
            raise ExportError(f"unsupported exit direction {direction!r}")
        source, destination = require_integer_uid(row[1], "exit source"), require_integer_uid(row[2], "exit destination")
        if source not in rooms_by_vnum or destination not in rooms_by_vnum:
            raise ExportError(f"exit {source} {direction} {destination} references a missing room")
        exits.append({"from_vnum": source, "to_vnum": destination, "direction": direction, "level": nullable_text(row[3]) or "0"})
    exits.sort(key=lambda row: (row["from_vnum"], DIRECTION_INDEX[row["direction"]], row["to_vnum"], row["level"]))

    referenced_environments = {room["terrain_uid"] for room in rooms}
    return {
        "areas": areas,
        "environments": [row for row in environments if row["uid"] in referenced_environments],
        "rooms": rooms,
        "exits": exits,
        "import_area_uids": sorted({room["area_uid"] for room in rooms}),
    }, {
        "all_room_area_references_resolve": True,
        "all_room_environment_references_resolve": True,
        "all_exit_room_references_resolve": True,
        "supported_standard_exit_directions_only": True,
        "all_room_uids_numeric": True,
    }


def spiral_offsets() -> Iterable[tuple[int, int]]:
    yield (0, 0)
    radius = 1
    while True:
        for x in range(-radius, radius + 1):
            yield (x, radius)
        for y in range(radius - 1, -radius - 1, -1):
            yield (radius, y)
        for x in range(radius - 1, -radius - 1, -1):
            yield (x, -radius)
        for y in range(-radius + 1, radius):
            yield (-radius, y)
        radius += 1


def nearest_free(occupied: set[tuple[int, int, int]], desired: tuple[int, int, int]) -> tuple[tuple[int, int, int], bool]:
    for dx, dy in spiral_offsets():
        candidate = (desired[0] + dx, desired[1] + dy, desired[2])
        if candidate not in occupied:
            return candidate, candidate != desired
    raise AssertionError("unreachable")


def generate_layout(rooms: list[dict[str, Any]], exits: list[dict[str, Any]]) -> dict[str, int]:
    """Assign deterministic area-local coordinates without discarding an exit."""
    rooms_by_vnum = {room["vnum"]: room for room in rooms}
    outbound: dict[int, list[dict[str, Any]]] = {room["vnum"]: [] for room in rooms}
    for exit_row in exits:
        if rooms_by_vnum[exit_row["from_vnum"]]["area_uid"] == rooms_by_vnum[exit_row["to_vnum"]]["area_uid"]:
            outbound[exit_row["from_vnum"]].append(exit_row)
    for edge_list in outbound.values():
        edge_list.sort(key=lambda row: (DIRECTION_INDEX[row["direction"]], row["to_vnum"]))

    occupied_by_area: dict[str, set[tuple[int, int, int]]] = {}
    coordinates: dict[int, tuple[int, int, int]] = {}
    queued: deque[int] = deque()
    stats: Counter[str] = Counter()
    for room in rooms:
        raw = room["source_coordinates"]
        if all(value is not None for value in raw):
            desired = (raw[0], raw[1], raw[2])
            occupied = occupied_by_area.setdefault(room["area_uid"], set())
            assigned, shifted = nearest_free(occupied, desired)
            occupied.add(assigned)
            coordinates[room["vnum"]] = assigned
            queued.append(room["vnum"])
            stats["source_coordinate_rooms"] += 1
            if shifted:
                stats["source_coordinate_collisions"] += 1

    def assign_from_queue() -> None:
        while queued:
            source_vnum = queued.popleft()
            source_room = rooms_by_vnum[source_vnum]
            source_coordinates = coordinates[source_vnum]
            occupied = occupied_by_area.setdefault(source_room["area_uid"], set())
            for exit_row in outbound[source_vnum]:
                destination_vnum = exit_row["to_vnum"]
                offset = DIRECTION_OFFSETS[exit_row["direction"]]
                desired = tuple(source_coordinates[index] + offset[index] for index in range(3))
                existing = coordinates.get(destination_vnum)
                if existing is not None:
                    if existing != desired:
                        stats["direction_constraint_conflicts"] += 1
                    continue
                assigned, shifted = nearest_free(occupied, desired)
                occupied.add(assigned)
                coordinates[destination_vnum] = assigned
                queued.append(destination_vnum)
                stats["traversed_room_assignments"] += 1
                if shifted:
                    stats["spiral_collision_resolutions"] += 1

    assign_from_queue()
    for room in rooms:
        if room["vnum"] in coordinates:
            continue
        occupied = occupied_by_area.setdefault(room["area_uid"], set())
        assigned, shifted = nearest_free(occupied, (0, 0, 0))
        occupied.add(assigned)
        coordinates[room["vnum"]] = assigned
        queued.append(room["vnum"])
        stats["component_roots"] += 1
        if shifted:
            stats["spiral_collision_resolutions"] += 1
        assign_from_queue()

    for room in rooms:
        room["layout"] = list(coordinates[room["vnum"]])
    stats["rooms_with_layout"] = len(coordinates)
    stats["cross_area_edges_retained"] = sum(
        1 for row in exits
        if rooms_by_vnum[row["from_vnum"]]["area_uid"] != rooms_by_vnum[row["to_vnum"]]["area_uid"]
    )
    return dict(sorted(stats.items()))


def build_export(source: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    connection = open_readonly_database(source)
    try:
        table_counts = validate_schema(connection)
        snapshot, integrity = load_snapshot(connection)
    finally:
        connection.close()
    layout = generate_layout(snapshot["rooms"], snapshot["exits"])
    source_info = {"file_name": source.name, "sha256": source_sha256(source), "sqlite_user_version": DATABASE_USER_VERSION}
    counts = {
        "rooms": len(snapshot["rooms"]), "standard_exits": len(snapshot["exits"]),
        "populated_areas": len(snapshot["import_area_uids"]), "source_areas": len(snapshot["areas"]),
        "referenced_environments": len(snapshot["environments"]),
    }
    map_data = {"schema_version": SCHEMA_VERSION, "source": source_info, **snapshot, "layout": layout, "counts": counts}
    report = {
        "schema_version": 1, "source": source_info,
        "source_schema": {"sqlite_user_version": DATABASE_USER_VERSION, "required_tables": sorted(REQUIRED_COLUMNS)},
        "source_table_counts": table_counts, "export_counts": counts, "reference_checks": integrity,
        "layout": layout,
        "omitted_source_tables": {
            "bookmarks": "empty; no map import equivalent",
            "terrain": "empty; the source uses environments for populated terrain values",
            "storage": "excluded from map data; contains application backup metadata",
            "rooms_lookup*": "SQLite FTS implementation tables; derived from rooms",
        },
    }
    return map_data, report


def stable_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"


def _assert_safe_output(path: Path, source: Path) -> None:
    if path == source or (path.exists() and path.resolve() == source.resolve()):
        raise ExportError("output path must not overwrite the source database")
    current = path.absolute()
    while True:
        if current.exists() and current.is_symlink():
            # macOS exposes the system temporary directory through /tmp, a
            # platform symlink that is safe for a caller-selected temp output.
            if current in {Path("/tmp"), Path("/var")}:
                current = current.resolve()
                continue
            raise ExportError(f"output path must not traverse a symlink: {current}")
        if current.parent == current:
            return
        current = current.parent


def write_atomic(path: Path, content: str, source: Path) -> None:
    _assert_safe_output(path, source)
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="\n") as destination:
            destination.write(content)
        os.replace(temporary_name, path)
    except BaseException:
        Path(temporary_name).unlink(missing_ok=True)
        raise


def markdown_report(report: dict[str, Any]) -> str:
    counts = report["export_counts"]
    table_rows = "\n".join(f"| `{name}` | {count} |" for name, count in sorted(report["source_table_counts"].items()))
    required_tables = ", ".join(f"`{name}`" for name in report["source_schema"]["required_tables"])
    omissions = "\n".join(f"- `{name}`: {reason}" for name, reason in report["omitted_source_tables"].items())
    return f"""# Aardwolf.db v11 export inventory

Source SHA-256: `{report['source']['sha256']}`

The source database was opened read-only with SQLite `query_only` enabled and validated as schema v{report['source']['sqlite_user_version']}.

## Validated source schema

Required tables: {required_tables}.

| Exported resource | Count |
| --- | ---: |
| Rooms | {counts['rooms']} |
| Standard exits | {counts['standard_exits']} |
| Populated areas | {counts['populated_areas']} |
| Source area records | {counts['source_areas']} |
| Referenced terrain records | {counts['referenced_environments']} |

## Source table inventory

| Table | Rows |
| --- | ---: |
{table_rows}

## Reference checks

{json.dumps(report['reference_checks'], sort_keys=True, indent=2)}

## Provisional layout

{json.dumps(report['layout'], sort_keys=True, indent=2)}

## Omitted source tables

{omissions}
"""


def parse_args(arguments: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="read-only Aardwolf.db v11 snapshot")
    parser.add_argument("--output", required=True, type=Path, help="generated package JSON resource")
    parser.add_argument("--report-json", required=True, type=Path, help="generated machine-readable inventory")
    parser.add_argument("--report-markdown", required=True, type=Path, help="generated human-readable inventory")
    return parser.parse_args(arguments)


def main(arguments: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if arguments is None else arguments)
    outputs = (args.output, args.report_json, args.report_markdown)
    if len({path.absolute() for path in outputs}) != len(outputs):
        print("error: output paths must be distinct", file=sys.stderr)
        return 2
    try:
        map_data, report = build_export(args.input)
        write_atomic(args.output, stable_json(map_data), args.input)
        write_atomic(args.report_json, json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n", args.input)
        write_atomic(args.report_markdown, markdown_report(report), args.input)
    except ExportError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
