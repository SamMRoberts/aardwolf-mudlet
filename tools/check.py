#!/usr/bin/env python3
"""Build and verify the aardwolf-vibe Mudlet package."""
from pathlib import Path
import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from xml.etree import ElementTree


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
MUDDLER_URL = "https://github.com/demonnic/muddler/releases/download/1.1.0/muddle-shadow-1.1.0.zip"
MUDDLER_SHA256 = "94f2d6e794d8a822f749370aeef405d9f9ab5da6d805f418723e881f91baa932"
ARTIFACT = ROOT / "build/aardwolf-vibe.mpackage"
DETERMINISTIC_CREATED = b"created = [[1970-01-01T00:00:00+0000]]"


def bootstrap():
    TOOLS.mkdir(exist_ok=True)
    archive = TOOLS / "muddler.zip"
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != MUDDLER_SHA256:
        with urllib.request.urlopen(MUDDLER_URL, timeout=120) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != MUDDLER_SHA256:
            raise RuntimeError("Muddler download checksum mismatch")
        archive.write_bytes(data)
    destination = TOOLS / "muddle-shadow-1.1.0"
    if not (destination / "lib/muddle-1.1.0-all.jar").exists():
        with zipfile.ZipFile(archive) as package:
            for name in package.namelist():
                if not (TOOLS / name).resolve().is_relative_to(TOOLS.resolve()):
                    raise RuntimeError("Unsafe Muddler archive path")
            package.extractall(TOOLS)


def java_command():
    java_home = os.environ.get("JAVA_HOME")
    if java_home:
        return str(Path(java_home) / "bin/java")
    candidates = list(TOOLS.glob("jdk-*/Contents/Home/bin/java")) + list(TOOLS.glob("jdk-*/bin/java"))
    return str(candidates[0]) if candidates else shutil.which("java")


def normalize_artifact():
    with zipfile.ZipFile(ARTIFACT) as package:
        members = {name: package.read(name) for name in package.namelist()}
    config = members.get("config.lua")
    if config is None:
        raise RuntimeError("Muddler artifact has no config.lua")
    config, replacements = re.subn(
        rb"created = \[\[[^\r\n]*\]\]", DETERMINISTIC_CREATED, config, count=1)
    if replacements != 1:
        raise RuntimeError("Cannot normalize Muddler creation timestamp")
    members["config.lua"] = config
    generated_config = ROOT / "build/tmp/config.lua"
    if generated_config.exists():
        generated_config.write_bytes(config)

    temporary = ARTIFACT.with_suffix(".mpackage.tmp")
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
        for name in sorted(members):
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            package.writestr(info, members[name], compress_type=zipfile.ZIP_DEFLATED,
                             compresslevel=9)
    os.replace(temporary, ARTIFACT)


def build():
    jar = TOOLS / "muddle-shadow-1.1.0/lib/muddle-1.1.0-all.jar"
    java = java_command()
    if not java or not jar.exists():
        raise RuntimeError("Run with --bootstrap and provide Java 17 through JAVA_HOME or PATH")
    digests = []
    for _ in range(2):
        subprocess.run([java, "-jar", str(jar)], cwd=ROOT, check=True)
        normalize_artifact()
        digests.append(hashlib.sha256(ARTIFACT.read_bytes()).hexdigest())
    if digests[0] != digests[1]:
        raise RuntimeError("Muddler build is not reproducible after normalization")
    print(f"Reproducible artifact SHA-256: {digests[0]}")


def inspect_artifact():
    if not ARTIFACT.exists():
        raise RuntimeError(f"Missing artifact: {ARTIFACT}")
    with zipfile.ZipFile(ARTIFACT) as package:
        if package.testzip():
            raise RuntimeError("Artifact CRC failure")
        names = package.namelist()
        if len(names) != len(set(names)):
            raise RuntimeError("Artifact contains duplicate entries")
        for name in names:
            parts = Path(name).parts
            if name.startswith("/") or ".." in parts or ".DS_Store" in name or "__MACOSX" in name:
                raise RuntimeError(f"Unsafe or unwanted archive entry: {name}")
        resources = {path.name for path in (ROOT / "src/resources").iterdir() if path.is_file()}
        expected = {"aardwolf-vibe.xml", "config.lua"} | resources
        if set(names) != expected:
            raise RuntimeError(
                f"Archive members differ from source: missing={sorted(expected - set(names))} "
                f"extra={sorted(set(names) - expected)}")
        ElementTree.fromstring(package.read("aardwolf-vibe.xml"))
        if package.read("aardwolf-vibe.xml") != (ROOT / "build/aardwolf-vibe.xml").read_bytes():
            raise RuntimeError("Artifact/XML mismatch")
        if DETERMINISTIC_CREATED not in package.read("config.lua"):
            raise RuntimeError("Artifact creation metadata is not normalized")
        if package.read("config.lua") != (ROOT / "build/tmp/config.lua").read_bytes():
            raise RuntimeError("Artifact/config.lua mismatch")
        for source in (ROOT / "src/resources").iterdir():
            if source.is_file() and package.read(source.name) != source.read_bytes():
                raise RuntimeError(f"Artifact/source mismatch: {source.name}")
    print(f"Artifact verified: {ARTIFACT}")


def syntax_check():
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    loader = lua.eval("function(source,name) local fn,e=loadstring(source,name); return fn,e or false end")
    for path in sorted((ROOT / "src").rglob("*.lua")):
        function, error = loader(path.read_text(), "@" + str(path.relative_to(ROOT)))
        if function is None:
            raise RuntimeError(f"Lua 5.1 syntax error in {path}: {error}")
    print("Lua 5.1 syntax verified.")


def tests():
    subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", "check_*.py", "-v"],
                   cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bootstrap", action="store_true", help="download pinned Muddler 1.1.0")
    args = parser.parse_args()
    if args.bootstrap:
        bootstrap()
    syntax_check()
    build()
    inspect_artifact()
    tests()


if __name__ == "__main__":
    main()
