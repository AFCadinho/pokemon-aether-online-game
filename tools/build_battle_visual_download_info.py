#!/usr/bin/env python3
"""Measure optional full collections for the offline first-run desktop chooser.

Read approved archive directories with --bundle-dir (repeatable). Missing
archives need only bounded public ZIP central-directory requests, not downloads.
--check verifies the committed snapshot against the release pins, offline.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
from urllib.request import Request, urlopen
import zipfile
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data/battle_visual_download_info.json"
PACKS = {
    "POKEMON_HOME": "pokemon_home", "POKEMON_HOME_SHINY": "pokemon_home_shiny",
    "POKEMON_FRONT": "front", "POKEMON_BACK": "back",
    "POKEMON_SHINY_FRONT": "shiny_front", "POKEMON_SHINY_BACK": "shiny_back",
}


def pins(revision="v11"):
    index_path = ROOT / f"release/approved_3d_bundles_{revision}_index.json"
    index = json.loads(index_path.read_text())
    workflow = (ROOT / ".github/workflows/deploy-desktop-r2.yml").read_text()
    packs = {}
    for key, directory in PACKS.items():
        version = re.search(rf"^  {key}_ASSET_VERSION: (\S+)$", workflow, re.M).group(1)
        size = int(re.search(rf"^  {key}_ASSET_SIZE: (\d+)$", workflow, re.M).group(1))
        packs[directory] = {"version": version, "download_bytes": size}
    return index, packs, hashlib.sha256(index_path.read_bytes()).hexdigest()


def measure_archive(asset, paths):
    name = Path(asset["object_key"]).name
    if name in paths:
        if paths[name].stat().st_size != asset["size_bytes"]:
            raise ValueError(f"Archive size does not match the release pin: {name}")
        with zipfile.ZipFile(paths[name]) as archive:
            return sum(entry.file_size for entry in archive.infolist() if not entry.is_dir())
    start = max(0, asset["size_bytes"] - 65536)
    request = Request("https://updates.pokeaether.com/" + asset["object_key"], headers={
        "Range": f"bytes={start}-", "User-Agent": "PokeAether/1.0"})
    with urlopen(request, timeout=30) as response:
        data = response.read(65537)
        if (response.status != 206 or len(data) != asset["size_bytes"] - start
                or response.headers.get("Content-Range") != f"bytes {start}-{asset['size_bytes'] - 1}/{asset['size_bytes']}"):
            raise ValueError(f"Unbounded or mismatched ZIP size response: {name}")
    # ZIP offsets are adjusted for the missing prefix; no file extraction.
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        return sum(entry.file_size for entry in archive.infolist() if not entry.is_dir())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--bundle-dir", type=Path, action="append", default=[])
    parser.add_argument("--archives-report", type=Path)
    parser.add_argument("--revision", choices=["v10", "v11"], default="v11")
    args = parser.parse_args()
    index, packs, digest = pins(args.revision)
    model_download = sum(asset["size_bytes"] for asset in index["assets"])
    if args.check:
        data = json.loads(OUTPUT.read_text())
        assert data["schema"] == 1
        assert data["3d"]["index_sha256"] == digest, "Regenerate chooser sizes for the new approved index."
        assert data["3d"]["download_bytes"] == model_download
        assert data["3d"]["bundle_count"] == len(index["assets"])
        assert data["3d"]["installed_bytes"] > 0
        if args.revision == "v11":
            previous, _, previous_digest = pins("v10")
            assert data["3d_v10"]["index_sha256"] == previous_digest
            assert data["3d_v10"]["download_bytes"] == sum(a["size_bytes"] for a in previous["assets"])
            assert data["3d_v10"]["installed_bytes"] > data["3d"]["installed_bytes"]
        assert data["2d"]["download_bytes"] == sum(pack["download_bytes"] for pack in packs.values())
        for directory, pin in packs.items():
            assert all(data["2d"]["packs"][directory][key] == value for key, value in pin.items()), "Regenerate chooser sizes for the new sprite packs."
            assert data["2d"]["packs"][directory]["installed_bytes"] > 0
        assert data["2d"]["installed_bytes"] == sum(p["installed_bytes"] for p in data["2d"]["packs"].values())
        print("PASS battle visual download sizes match release pins")
        return
    paths = {path.name: path for directory in args.bundle_dir for path in directory.rglob("*.zip")}
    if args.archives_report:
        for row in json.loads(args.archives_report.read_bytes())["assets"]:
            path = Path(row["candidate_archive"])
            paths[path.name] = path
            source = Path(row["source_archive"])
            paths[source.name] = source
    with ThreadPoolExecutor(max_workers=6) as pool:
        model_installed = sum(pool.map(lambda asset: measure_archive(asset, paths), index["assets"]))
    for directory, pack in packs.items():
        files = [p for p in (ROOT / "assets/sprites/pokemon" / directory).rglob("*")
                 if p.is_file() and p.suffix != ".import" and not p.name.startswith(".")]
        if not files:
            raise ValueError(f"Bootstrap the matching sprite assets first: {directory}")
        pack["installed_bytes"] = sum(p.stat().st_size for p in files)
    data = {"schema": 1,
            "2d": {"packs": packs, "download_bytes": sum(p["download_bytes"] for p in packs.values()),
                   "installed_bytes": sum(p["installed_bytes"] for p in packs.values())},
            "3d": {"index_sha256": digest, "bundle_count": len(index["assets"]),
                   "download_bytes": model_download, "installed_bytes": model_installed}}
    if args.revision == "v11":
        previous, _, previous_digest = pins("v10")
        with ThreadPoolExecutor(max_workers=6) as pool:
            previous_installed = sum(pool.map(lambda asset: measure_archive(asset, paths), previous["assets"]))
        data["3d_v10"] = {"index_sha256": previous_digest, "bundle_count": len(previous["assets"]),
                         "download_bytes": sum(a["size_bytes"] for a in previous["assets"]), "installed_bytes": previous_installed}
    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text(json.dumps(data, indent=2) + "\n")
    print(f"Measured {len(index['assets'])} approved model bundles and {len(packs)} sprite packs.")


if __name__ == "__main__":
    main()
