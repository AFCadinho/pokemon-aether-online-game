#!/usr/bin/env python3
"""Build optional web asset modules; run through ops/worktrees/slot-env SLOT."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

from build_web_preview import pack_contains, run_export


ROOT = Path(__file__).resolve().parents[1]
MODULE_NAME = "aether-clash-maps"
MAX_MODULE_BYTES = 32 * 1024 * 1024
REQUIRED_MARKERS = (
    b"generated/tiled_visuals/waiting_area/waiting_area.visual.tscn",
    b"generated/tiled_visuals/aether_clash_duel/aether_clash_duel.visual.tscn",
    b"generated/tiled_visuals/aether_clash_battle_royale/aether_clash_battle_royale.visual.tscn",
)
FORBIDDEN_MARKERS = (
    b"generated/tiled_visuals/lobby/lobby.visual.tscn",
    b"generated/tiled_visuals/pewter_city/pewter_city.visual.tscn",
    b"generated/tiled_visuals/route_3/route_3.visual.tscn",
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    if ROOT.parent.name.startswith("slot-") and os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run slot builds through ops/worktrees/slot-env SLOT -- COMMAND.")

    output = ROOT / "builds/web/modules"
    output.mkdir(parents=True, exist_ok=True)
    pack_path = output / f"{MODULE_NAME}.pck"
    console_log = output.parent / f"{MODULE_NAME}-export-console.log"
    returncode = run_export(
        [
            args.godot,
            "--headless",
            "--log-file",
            str(output.parent / f"{MODULE_NAME}-export.log"),
            "--path",
            str(ROOT),
            "--export-pack",
            "Web Aether Clash Maps",
            str(pack_path),
        ],
        console_log,
    )
    if returncode != 0:
        tail = console_log.read_text(errors="replace").splitlines()[-80:]
        raise RuntimeError("Aether Clash module export failed:\n" + "\n".join(tail))
    if not pack_path.is_file() or pack_path.stat().st_size == 0:
        raise RuntimeError("Aether Clash module export did not produce a PCK.")

    for marker in REQUIRED_MARKERS:
        if not pack_contains(pack_path, marker):
            raise RuntimeError(f"Aether Clash module misses required marker: {marker.decode()}")
    for marker in FORBIDDEN_MARKERS:
        if pack_contains(pack_path, marker):
            raise RuntimeError(f"Aether Clash module contains core marker: {marker.decode()}")

    module_bytes = pack_path.stat().st_size
    if module_bytes > MAX_MODULE_BYTES:
        raise RuntimeError(
            f"Aether Clash module is {module_bytes / 1048576:.1f} MiB; "
            f"the module budget is {MAX_MODULE_BYTES / 1048576:.0f} MiB."
        )
    with pack_path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    manifest = {
        "schemaVersion": 1,
        "modules": {
            MODULE_NAME: {
                "file": pack_path.name,
                "bytes": module_bytes,
                "sha256": digest,
                "version": digest[:16],
                "scenes": [
                    "res://scenes/overworld/aether_clash/waiting_area.tscn",
                    "res://scenes/overworld/aether_clash/aether_clash_duel.tscn",
                    "res://scenes/overworld/aether_clash/aether_clash_battle_royale.tscn",
                ],
            }
        },
    }
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Aether Clash web module exported: {module_bytes / 1048576:.1f} MiB.")


if __name__ == "__main__":
    main()
