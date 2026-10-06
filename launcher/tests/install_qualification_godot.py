#!/usr/bin/env python3
"""Fetch the exact official desktop engine archive used by qualification CI."""
import argparse
from pathlib import Path
import platform
import stat
import zipfile

from native_qualification_fixture import fetch, sha_file

ASSETS = {
    'Linux': ('linux.x86_64', '30e6b6d141f0cd5bebd629ad1d0ef1324e60091bb20662d026b402ba58c59937', 'Godot_v4.6.2-stable_linux.x86_64'),
    'Windows': ('win64.exe', '14293422efb54b24a51f79d4cb55ab4001ef3d936e064a6c8af32e1f984024be', 'Godot_v4.6.2-stable_win64_console.exe'),
    'Darwin': ('macos.universal', '666b2a64e4b5c59db0e4974605b888eb72eb7d4e60e870d2be6cc19727b50807', 'Godot.app/Contents/MacOS/Godot'),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    destination = args.destination.resolve()
    destination.mkdir(parents=True, exist_ok=False)
    name, digest, executable = ASSETS[platform.system()]
    archive_path = destination / 'engine.zip'
    fetch('https://github.com/godotengine/godot-builds/releases/download/4.6.2-stable/Godot_v4.6.2-stable_' + name + '.zip', archive_path, maximum=200 * 1024**2)
    if sha_file(archive_path) != digest:
        raise ValueError('Official engine archive checksum mismatch')
    with zipfile.ZipFile(archive_path) as archive:
        links = []
        for info in archive.infolist():
            path = Path(info.filename)
            if path.is_absolute() or '..' in path.parts or '\\' in info.filename or ':' in info.filename:
                raise ValueError('Unsafe engine archive path')
            target = destination / path
            mode = (info.external_attr >> 16) & 0o170000
            if mode == stat.S_IFLNK:
                link = archive.read(info).decode()
                if Path(link).is_absolute() or not (target.parent / link).resolve().is_relative_to(destination):
                    raise ValueError('Unsafe engine bundle symlink')
                links.append((target, link))
                continue
            archive.extract(info, destination)
            if not info.is_dir() and platform.system() != 'Windows':
                target.chmod((info.external_attr >> 16) & 0o777 or 0o644)
        for target, link in links:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(link)
    binary = destination / executable
    if not binary.is_file():
        raise ValueError('Native engine executable missing')
    if platform.system() != 'Windows':
        binary.chmod(0o755)
    print(binary)


if __name__ == '__main__':
    main()
