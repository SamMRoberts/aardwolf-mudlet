#!/usr/bin/env python3
"""Measure offline mapper refresh cost; does not measure native Mudlet painting."""
import argparse
import json
from pathlib import Path
import statistics
import sys
import time

from lupa.lua51 import LuaRuntime


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from lua_support import install_json


def measure(source, side, repeats, outside):
    lua = LuaRuntime(unpack_returned_tuples=True)
    install_json(lua)
    lua.execute((ROOT / "tests/mapper_api.lua").read_text())
    lua.globals().factory = lua.execute(source)
    lua.execute('''
      settings={backupDir="/profile/backups",ensureDirectory=function() return true end}
      mapper=factory.new(_G,settings);assert(mapper:start())
    ''')
    lua.execute((ROOT / "tests/mapper_grid.lua").read_text())
    lua.globals().fresh = lua.globals().seedMapperGrid(side, outside)
    lua.execute("countMapperAPI()")
    samples = []
    for _ in range(repeats):
        lua.execute("apiCounts={}")
        start = time.perf_counter()
        lua.execute("assert(mapper:receive(fresh)); assert(mapper.reflowedRooms==0 and mapper.layoutConflicts==0)")
        samples.append((time.perf_counter() - start) * 1000)
    return {"area_rooms": side * side, "outside_rooms": outside,
            "median_ms": round(statistics.median(samples), 3),
            "api_calls": dict(lua.globals().apiCounts.items())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=ROOT / "src/resources/mapper.lua")
    parser.add_argument("--sides", type=int, nargs="+", default=[10, 20, 30])
    parser.add_argument("--repeats", type=int, default=3)
    parser.add_argument("--outside", type=int, default=0)
    args = parser.parse_args()
    if min(args.sides) < 3 or args.repeats < 1 or args.outside < 0:
        parser.error("sides must be >= 3, repeats >= 1, and outside >= 0")
    source = args.source.read_text()
    for side in args.sides:
        print(json.dumps(measure(source, side, args.repeats, args.outside)), flush=True)


if __name__ == "__main__":
    main()
