#!/usr/bin/env python3
"""Build the real Muddler artifact, check its contents, then run Lua 5.1 tests."""
from pathlib import Path
import argparse
import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.tools'
MUDDLER_URL = 'https://github.com/demonnic/muddler/releases/download/1.1.0/muddle-shadow-1.1.0.zip'
MUDDLER_SHA = '94f2d6e794d8a822f749370aeef405d9f9ab5da6d805f418723e881f91baa932'
JAVA_VERSION = '17.0.16_8'


def run(*command):
    subprocess.run(command, cwd=ROOT, check=True)


def download(url, destination, digest=None):
    with urllib.request.urlopen(url, timeout=120) as response:
        data = response.read()
    if digest and hashlib.sha256(data).hexdigest() != digest:
        raise RuntimeError('Download checksum mismatch: ' + destination.name)
    destination.write_bytes(data)


def bootstrap():
    CACHE.mkdir(exist_ok=True)
    archive = CACHE / 'muddler.zip'
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != MUDDLER_SHA:
        download(MUDDLER_URL, archive, MUDDLER_SHA)
    with zipfile.ZipFile(archive) as package:
        for name in package.namelist():
            if not (CACHE / name).resolve().is_relative_to(CACHE.resolve()):
                raise RuntimeError('Unsafe archive path')
        package.extractall(CACHE)
    java = os.environ.get('JAVA_HOME')
    if not java:
        system = {'Darwin': 'mac', 'Linux': 'linux'}.get(platform.system())
        arch = {'arm64': 'aarch64', 'aarch64': 'aarch64', 'x86_64': 'x64'}.get(platform.machine())
        if not system or not arch:
            raise RuntimeError('Set JAVA_HOME to Temurin 17.0.16+8 on this platform')
        name = f'OpenJDK17U-jre_{arch}_{system}_hotspot_{JAVA_VERSION}.tar.gz'
        url = 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.16%2B8/' + name
        with urllib.request.urlopen(url + '.sha256.txt', timeout=120) as response:
            digest = response.read().decode().split()[0]
        archive = CACHE / name
        if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
            download(url, archive, digest)
        with tarfile.open(archive) as package:
            package.extractall(CACHE, filter='data')
    environment = ROOT / '.venv'
    if not environment.exists():
        run(sys.executable, '-m', 'venv', str(environment))
    python = environment / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    run(str(python), '-m', 'pip', 'install', '-r', 'requirements-dev.txt')


def inspect():
    with zipfile.ZipFile(ROOT / 'build/AardwolfToolbox.mpackage') as package:
        if package.testzip():
            raise RuntimeError('Archive CRC failure')
        names = package.namelist()
        if len(names) != len(set(names)):
            raise RuntimeError('Duplicate archive entries')
        for name in names:
            if '..' in Path(name).parts or name.startswith('/') or '.DS_Store' in name or '__MACOSX' in name:
                raise RuntimeError('Unexpected archive entry: ' + name)
        ElementTree.fromstring(package.read('AardwolfToolbox.xml'))
        for path in (ROOT / 'src/resources').glob('*.lua'):
            if package.read(path.name) != path.read_bytes():
                raise RuntimeError('Artifact/source mismatch: ' + path.name)
    print('Archive integrity, XML and resources verified.', flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--bootstrap', action='store_true', help='Download pinned tools into ignored local directories')
    args = parser.parse_args()
    if args.bootstrap:
        bootstrap()
    jar = Path(os.environ.get('MUDDLER_JAR', CACHE / 'muddle-shadow-1.1.0/lib/muddle-1.1.0-all.jar'))
    java_home = os.environ.get('JAVA_HOME')
    candidates = list(CACHE.glob('jdk-*/Contents/Home/bin/java')) + list(CACHE.glob('jdk-*/bin/java'))
    java = str(Path(java_home)/'bin/java') if java_home else str(candidates[0]) if candidates else shutil.which('java')
    if not java or not jar.exists():
        raise RuntimeError('Run python3 tools/check.py --bootstrap, or set JAVA_HOME and MUDDLER_JAR')
    run(java, '-jar', str(jar))
    inspect()
    python = ROOT / '.venv' / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
    run(str(python) if python.exists() else sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'check_*.py')
    run(str(python) if python.exists() else sys.executable, 'tests/benchmark_mobs.py')


if __name__ == '__main__':
    main()
