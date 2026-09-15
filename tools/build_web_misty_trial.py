#!/usr/bin/env python3
"""Export and inspect an isolated Misty trial; never changes the live web manifest."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess

from build_web_preview import run_export

ROOT = Path(__file__).resolve().parents[1]
MAX_TRIAL_BYTES = 32 * 1024 * 1024


def validate_pack_files(files, scope, catalog):
    paths = set(files)
    def contains(path):
        return path in paths or path + ".remap" in paths
    for map_id in scope["additionalMapIds"]:
        path = catalog["areas"][map_id]["scenePath"]
        if not contains(path):
            raise ValueError("Missing planned map: " + map_id)
    for transition_id in scope["newBlockedTransitionIds"]:
        target = catalog["transitions"][transition_id]["destination"]["mapId"]
        if contains(catalog["areas"][target]["scenePath"]):
            raise ValueError("Outside-demo map leaked into trial: " + target)
    for map_id, area in catalog["areas"].items():
        if map_id not in scope["additionalMapIds"] and contains(area["scenePath"]):
            raise ValueError("Unplanned map leaked into trial: " + map_id)
    for path in paths:
        if path.startswith("res://scenes/overworld/aether_clash/"):
            raise ValueError("Aether Clash must stay separate: " + path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--skip-export", action="store_true", help="Inspect this slot's existing trial pack")
    args = parser.parse_args()
    if ROOT.parent.name.startswith("slot-") and os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through ops/worktrees/slot-env SLOT -- COMMAND.")
    scope = json.loads((ROOT / "docs/browser-misty-scope.json").read_text())
    catalog = json.loads((ROOT.parent / "backend/account-service/generated/world_access_catalog.json").read_text())
    output = ROOT / "builds/web-misty-trial"
    output.mkdir(parents=True, exist_ok=True)
    ignore = ROOT / "builds/.gdignore"
    if not ignore.exists():
        ignore.write_text("")
    pack = output / "misty-maps.pck"
    if not args.skip_export:
        code = run_export([args.godot, "--headless", "--path", str(ROOT), "--export-pack",
                           "Web Misty Maps Trial", str(pack)], output / "export.log")
        if code:
            raise RuntimeError("Trial export failed; see export.log")
    if not pack.is_file() or not 0 < pack.stat().st_size <= MAX_TRIAL_BYTES:
        raise RuntimeError("Trial pack missing or above the 32 MiB experiment budget")
    probe = output / "probe"
    probe.mkdir(exist_ok=True)
    (probe / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Misty asset probe"\nrun/main_loop_type="MistyAssetProbe"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    (probe / "export_presets.cfg").write_text('[preset.0]\nname="Web Probe"\nplatform="Web"\nrunnable=true\ndedicated_server=false\ncustom_features=""\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter=""\nexport_path="../index.html"\nscript_export_mode=2\n[preset.0.options]\nvariant/thread_support=false\nhtml/canvas_resize_policy=2\n')
    # Generate only this probe source, never copy caches, sessions or game assets.
    probe_script = probe / "probe.gd"
    if probe_script.is_symlink():
        probe_script.unlink()
    probe_script.write_text((ROOT / "tests/web_misty_asset_probe.gd").read_text())
    with (probe / "project.godot").open("a") as config:
        config.write('\n[application]\nrun/main_scene="res://empty.tscn"\n')
    (probe / "empty.tscn").write_text('[gd_scene format=3]\n[node name="Probe" type="Node"]\n')
    with (output / "native-probe.log").open("w") as log:
        result = subprocess.run([args.godot, "--headless", "--path", str(probe), "--script",
                                 "res://probe.gd", "--", str(pack)], stdout=log, stderr=subprocess.STDOUT, timeout=120)
    lines = (output / "native-probe.log").read_text().splitlines()
    report = json.loads(next(line.removeprefix("MISTY_PROBE ") for line in lines if line.startswith("MISTY_PROBE ")))
    if result.returncode or not report["success"] or len(report["visuals"]) != 12:
        raise RuntimeError("Visual probe failed; see native-probe.log")
    validate_pack_files(report["files"], scope, catalog)
    payload = pack.read_bytes()
    report.update({"packBytes": len(payload), "gzipBytes": len(gzip.compress(payload, mtime=0)),
                   "sha256": hashlib.sha256(payload).hexdigest(), "maxTrialBytes": MAX_TRIAL_BYTES,
                   "scopeStatus": "trial-only-not-enabled",
                   "audioInPack": any("/assets/music/" in p for p in report["files"]),
                   "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()})
    (output / "trial-receipt.json").write_text(json.dumps(report, indent=2) + "\n")
    code = run_export([args.godot, "--headless", "--path", str(probe), "--export-release",
                       "Web Probe", str(output / "index.html")], output / "probe-export.log")
    if code:
        raise RuntimeError("Browser probe export failed")
    print("Trial validated: %.2f MiB PCK, %.2f MiB gzip; 16 maps, 12 visuals" % (len(payload)/1048576, report["gzipBytes"]/1048576))
    print("Serve builds/web-misty-trial on loopback port 8063; run node tests/web_misty_asset_probe.cjs")


if __name__ == "__main__":
    main()
