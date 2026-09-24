#!/usr/bin/env python3
"""Build both optional browser map modules through ops/worktrees/slot-env."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from build_web_preview import run_export

ROOT = Path(__file__).resolve().parents[1]
MAX_MODULE_BYTES = 32 * 1024 * 1024


def build_module(godot, output, name, preset, scenes, required, forbidden):
    pack = output / f"{name}.pck"
    log = output.parent / f"{name}-export-console.log"
    code = run_export([godot, "--headless", "--log-file", str(output.parent / f"{name}-export.log"),
                       "--path", str(ROOT), "--export-pack", preset, str(pack)], log)
    if code:
        raise RuntimeError(f"{name} export exited with status {code}; see {log}")
    if not pack.is_file() or pack.stat().st_size <= 0:
        raise RuntimeError(f"{name} export did not create a non-empty pack; see {log}")
    if pack.stat().st_size > MAX_MODULE_BYTES:
        raise RuntimeError(
            f"{name} pack is {pack.stat().st_size / 1048576:.1f} MiB; "
            f"the limit is {MAX_MODULE_BYTES / 1048576:.0f} MiB."
        )
    with tempfile.TemporaryDirectory(prefix="pokeaether-module-index-") as directory:
        Path(directory, "project.godot").write_text('config_version=5\n')
        probe = subprocess.run([godot, "--headless", "--path", directory, "--script",
                                str(ROOT / "tests/web_module_files_probe.gd"), "--", str(pack)],
                               capture_output=True, text=True, timeout=120, check=True)
    files = set(json.loads(next(line.removeprefix("MODULE_FILES ") for line in probe.stdout.splitlines()
                               if line.startswith("MODULE_FILES "))))
    def contains(marker):
        path = "res://" + marker.decode()
        return path in files or path + ".remap" in files
    for marker in required:
        if not contains(marker):
            raise RuntimeError(f"{name} misses required marker: {marker.decode()}")
    for marker in forbidden:
        if contains(marker):
            raise RuntimeError(f"{name} contains outside-module marker: {marker.decode()}")
    with pack.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    print(f"{name} exported: {pack.stat().st_size / 1048576:.1f} MiB.")
    return {"file": pack.name, "bytes": pack.stat().st_size,
            "sha256": digest, "version": digest[:16], "scenes": scenes}


def import_project(godot, output):
    """Finish pending Godot imports before running isolated pack exports."""
    console_log = output.parent / "asset-module-import-console.log"
    engine_log = output.parent / "asset-module-import.log"
    code = run_export(
        [godot, "--headless", "--log-file", str(engine_log), "--path", str(ROOT), "--import"],
        console_log,
    )
    if code:
        raise RuntimeError(f"Godot asset import exited with status {code}; see {console_log}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    if ROOT.parent.name.startswith("slot-") and os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through ops/worktrees/slot-env SLOT -- COMMAND.")
    output = ROOT / "builds/web/modules"
    output.mkdir(parents=True, exist_ok=True)
    import_project(args.godot, output)
    scope = json.loads((ROOT / "docs/browser-misty-scope.json").read_text())
    catalog = json.loads((ROOT / "generated/world_access_catalog.json").read_text())
    misty_scenes = [catalog["areas"][map_id]["scenePath"] for map_id in scope["additionalMapIds"]]
    aether_scenes = ["res://scenes/overworld/aether_clash/" + name + ".tscn"
                     for name in ("waiting_area", "aether_clash_duel", "aether_clash_battle_royale")]
    modules = {}
    modules["aether-clash-maps"] = build_module(
        args.godot, output, "aether-clash-maps", "Web Aether Clash Maps", aether_scenes,
        tuple(path.removeprefix("res://").encode() for path in aether_scenes),
        (b"generated/tiled_visuals/lobby/lobby.visual.tscn",
         b"generated/tiled_visuals/pewter_city/pewter_city.visual.tscn",
         b"generated/tiled_visuals/route_3/route_3.visual.tscn"))
    forbidden = tuple(area["scenePath"].removeprefix("res://").encode()
                      for map_id, area in catalog["areas"].items() if map_id not in scope["additionalMapIds"])
    modules["kanto-through-misty-maps"] = build_module(
        args.godot, output, "kanto-through-misty-maps", "Web Misty Maps Trial", misty_scenes,
        tuple(path.removeprefix("res://").encode() for path in misty_scenes), forbidden)
    # Publish one manifest only after both packs pass validation.
    (output / "manifest.json").write_text(json.dumps({"schemaVersion": 1, "modules": modules}, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
