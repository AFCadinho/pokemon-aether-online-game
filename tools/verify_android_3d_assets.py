#!/usr/bin/env python3
"""Verify pinned optional Android assets locally or publicly, without publishing."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def checked(data, size, sha):
    if len(data) != size or hashlib.sha256(data).hexdigest() != sha:
        raise ValueError("Optional Android asset differs from its immutable pin")


def verify_archive(data, arena):
    import io
    checked(data, arena["archive_bytes"], arena["archive_sha256"])
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        if sorted(archive.namelist()) != ["forest-runtime/forest.json", "forest-runtime/forest.pck"]:
            raise ValueError("Unexpected Android arena ZIP members")
        checked(archive.read("forest-runtime/forest.pck"), arena["pack_bytes"], arena["pack_sha256"])


def verify_public(descriptor, release):
    def read(key, limit):
        if key.startswith("/") or ".." in key or ":" in key:
            raise ValueError("Invalid optional asset object key")
        request = Request("https://updates.pokeaether.com/" + key,
                          headers={"User-Agent": "PokeAetherAndroid3DPreflight/1.0", "Cache-Control": "no-cache"})
        with urlopen(request, timeout=120) as response:
            data = response.read(limit + 1)
        if len(data) > limit:
            raise ValueError("Optional asset exceeds its pin")
        return data
    if release["revision"] != descriptor["model_release"]:
        raise ValueError("Android experiment and approved model release do not match")
    pin = release["index"]
    data = read(pin["object_key"], pin["size_bytes"])
    checked(data, pin["size_bytes"], pin["sha256"])
    arena = descriptor["arena"]
    verify_archive(read(arena["object_key"], arena["archive_bytes"]), arena)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--public", action="store_true")
    mode.add_argument("--archive", type=Path)
    args = parser.parse_args()
    descriptor = json.loads((ROOT / "data/android_3d_experiment.json").read_text())
    release = json.loads((ROOT / "data/approved_3d_release_v11.json").read_text())
    if args.public:
        verify_public(descriptor, release)
    else:
        verify_archive(args.archive.read_bytes(), descriptor["arena"])
    print("ANDROID_3D_ASSETS_OK: pinned model index and/or exact Android arena archive; nothing published")


if __name__ == "__main__":
    main()
