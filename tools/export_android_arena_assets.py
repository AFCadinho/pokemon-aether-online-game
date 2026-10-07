#!/usr/bin/env python3
"""Export art-only desktop/ETC2 candidates from the existing trusted source.

Run through slot-env. No source assets, caches, userdata or credentials are
copied. Temporary source project/preset/UID/import metadata edits are restored.
ETC2 is a quality-review candidate, not a lossless or production-approved pack.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

from audit_web_texture_memory import entries, texture_dimensions
from package_forest_asset_pack import archive_bytes

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tools/sprite_factory/arena_art_export_probe.gd"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def audit(path):
    rows, files = [], []
    with path.open("rb") as stream:
        for name, offset, size in entries(stream):
            files.append(name)
            if name.endswith(".ctex"):
                stream.seek(offset)
                width, height = texture_dimensions(stream.read(min(16, size)))
                stream.seek(offset)
                texture_hash = hashlib.sha256(stream.read(size)).hexdigest()
                rows.append({"path": name, "width": width, "height": height,
                             "packed_bytes": size, "sha256": texture_hash})
    return {"bytes": path.stat().st_size, "sha256": digest(path),
            "files": files, "textures": rows,
            "limit": "Packed texture bytes are not measured resident RAM/VRAM."}


def restore(snapshot):
    for path, content in snapshot.items():
        if content is None:
            path.unlink(missing_ok=True)
        else:
            path.write_bytes(content)


def compressed_archive(pack, folder, variant):
    # ZIP compression changes transport bytes only. Extracted PCK is identical.
    version = "battle-environment-" + variant + "-" + digest(pack)[:12]
    target = folder / (version + ".zip")
    with ZipFile(target, "w", ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in [("forest-runtime/forest.json", b'{"schema": 1, "pack": "forest.pck"}\n'),
                           ("forest-runtime/forest.pck", pack.read_bytes())]:
            item = ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            item.compress_type = ZIP_DEFLATED
            item.external_attr = 0o100644 << 16
            archive.writestr(item, data, compress_type=ZIP_DEFLATED, compresslevel=9)
    with ZipFile(target) as archive:
        if hashlib.sha256(archive.read("forest-runtime/forest.pck")).hexdigest() != digest(pack):
            raise ValueError("Compressed transport altered the PCK")
    return version, target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if ROOT.parent.name.startswith("slot-") and os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through ops/worktrees/slot-env SLOT")
    source, output = args.source.resolve(), args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    # Only the already isolated purchased project is accepted, never a game
    # checkout or an unrelated third-party tree.
    if source.is_relative_to(ROOT) or not (source / "scenes/world/test_world.res").is_file():
        parser.error("Expected the existing isolated purchased forest project")
    output.mkdir(parents=True, exist_ok=True)
    marker = output / ".android-arena-export"
    if any(output.iterdir()) and not marker.exists():
        parser.error("Refusing an unrelated nonempty output directory")
    marker.touch()
    project, presets, uids = [source / name for name in
                              ["project.godot", "export_presets.cfg", "forest_uids.json"]]
    snapshot = {path: path.read_bytes() if path.exists() else None
                for path in [project, presets, uids, *source.rglob("*.import")]}
    assets = [path for directory in [source / "entities", source / "common"]
              for path in directory.rglob("*") if path.is_file()
              and path.suffix not in {".import", ".uid"}]
    hashes = {str(path.relative_to(source)): digest(path) for path in assets}
    reference = args.reference.resolve()
    original_pack = audit(reference)
    results = {"schema": 1, "source_assets": hashes, "reference": original_pack,
               "production_approved": False, "candidates": {}}

    def run(command, name):
        with (output / (name + ".log")).open("w") as log:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                code = child.wait()
                if code:
                    raise subprocess.CalledProcessError(code, command)
            except BaseException:
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
                raise

    roots_file = output / "resource-roots.json"
    run(["godot", "--headless", "--path", str(ROOT), "--script", str(PROBE),
         "--", "roots", str(roots_file)], "roots")
    roots = json.loads(roots_file.read_text())
    if not roots or any(not path.startswith("res://entities/nature/") for path in roots):
        raise ValueError("Unexpected runtime art roots")
    for path in roots:
        if not (source / path.removeprefix("res://")).is_file():
            raise ValueError("Missing source art: " + path)
    def interrupted(_signal, _frame):
        raise KeyboardInterrupt("Arena export interrupted; restoring source metadata")
    signal.signal(signal.SIGTERM, interrupted)
    try:
        # Generate only missing ETC2 import variants in this source project's
        # own cache. Nothing is seeded from another project's .godot directory.
        config = snapshot[project].decode()
        config = config.replace("[rendering]", '[rendering]\ntextures/vram_compression/import_etc2_astc=true\ntextures/vram_compression/import_s3tc_bptc=true')
        project.write_text(config)
        run(["godot", "--headless", "--path", str(source), "--import"], "source-import")
        run(["godot", "--headless", "--path", str(source), "--script", str(PROBE),
             "--", "uids", str(uids)], "uids")
        preset_text = snapshot[presets].decode()
        next_index = max(map(int, re.findall(r'\[preset\.(\d+)\]', preset_text))) + 1
        for variant in ["desktop-art", "android-etc2-art"]:
            mobile = variant == "android-etc2-art"
            name = "PokeAether " + variant
            section = f"preset.{next_index}"
            block = f'''\n[{section}]
name={json.dumps(name)}
platform="Linux"
runnable=false
export_filter="resources"
export_files=PackedStringArray({', '.join(json.dumps(path) for path in roots)})
include_filter="forest_uids.json,addons/terrain_3d/LICENSE.txt"
exclude_filter="addons/terrain_3d/utils/*"
script_export_mode=1

[{section}.options]
texture_format/s3tc_bptc={'false' if mobile else 'true'}
texture_format/etc2_astc={'true' if mobile else 'false'}
binary_format/architecture="x86_64"
'''
            presets.write_text(preset_text + block)
            folder = output / variant
            folder.mkdir(exist_ok=True)
            pack = folder / "forest.pck"
            run(["godot", "--headless", "--path", str(source), "--export-pack",
                 name, str(pack)], variant + "-export")
            info = audit(pack)
            if any(path.startswith("scenes/world/") or "terrain3d" in path.lower()
                   for path in info["files"]):
                raise ValueError("Candidate unexpectedly includes world/terrain data")
            if mobile and any(".s3tc." in row["path"] or ".bptc." in row["path"]
                              for row in info["textures"]):
                raise ValueError("Android candidate still contains desktop texture variants")
            version, archive, size, sha = archive_bytes(pack, folder)
            compressed_version, compressed = compressed_archive(pack, folder, variant)
            (folder / "forest.json").write_text('{"schema": 1, "pack": "forest.pck"}\n')
            info.update({"archive": str(archive.relative_to(output)), "archive_bytes": size,
                         "archive_sha256": sha, "version": version,
                         "compressed_archive": str(compressed.relative_to(output)),
                         "compressed_version": compressed_version,
                         "compressed_archive_bytes": compressed.stat().st_size,
                         "compressed_archive_sha256": digest(compressed),
                         "quality": "ETC2 transcoding needs review" if mobile else "Same source/import settings as desktop"})
            results["candidates"][variant] = info
    finally:
        restore(snapshot)
    if hashes != {str(path.relative_to(source)): digest(path) for path in assets}:
        raise RuntimeError("Source art changed during export")
    results["source_art_unchanged"] = True
    old_textures = {row["path"]: row["sha256"] for row in original_pack["textures"]}
    desktop = results["candidates"]["desktop-art"]["textures"]
    results["desktop_texture_payloads_identical_to_reference"] = all(
        old_textures.get(row["path"]) == row["sha256"] for row in desktop)
    if not results["desktop_texture_payloads_identical_to_reference"]:
        raise ValueError("Desktop art-only export changed approved texture payloads")
    (output / "report.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps({name: {key: item[key] for key in ["bytes", "sha256", "archive_bytes"]}
                      for name, item in results["candidates"].items()}, indent=2))


if __name__ == "__main__":
    main()
