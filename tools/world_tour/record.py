#!/usr/bin/env python3
"""Record a repeatable world tour using the assigned slot's Godot environment."""
import argparse
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from catalog import check_coverage

ROOT = Path(__file__).resolve().parents[2]


def validate(route):
    if route.get("coverage") == "all_outdoor_maps":
        check_coverage(route)
    for key in ("width", "height", "fps"):
        value = route.get(key)
        if type(value) is not int or value <= 0:
            raise ValueError(f"{key} must be a positive integer")
    if route["width"] % 2 or route["height"] % 2:
        raise ValueError("Video dimensions must be even")
    for key in ("shot_seconds", "transition_seconds"):
        value = route.get(key)
        if not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
            raise ValueError(f"{key} must be a positive finite number")
    if route["transition_seconds"] >= route["shot_seconds"]:
        raise ValueError("Transition must be shorter than a shot")
    if not math.isclose(route["shot_seconds"] * route["fps"], round(route["shot_seconds"] * route["fps"])):
        raise ValueError("Shot duration must contain a whole number of frames")
    if not isinstance(route.get("shots"), list) or len(route["shots"]) < 2:
        raise ValueError("At least two shots are required for circular crossfades")
    for shot in route["shots"]:
        scene = shot["scene"]
        if not scene.startswith("res://generated/tiled_visuals/") or not scene.endswith(".visual.tscn"):
            raise ValueError("Use generated .visual.tscn scenes, not gameplay scenes")
        path = (ROOT / scene.removeprefix("res://")).resolve()
        if not path.is_relative_to(ROOT / "generated/tiled_visuals") or not path.is_file():
            raise ValueError(f"Missing visual scene: {scene}")
        if 'type="Script"' in path.read_text() or 'type="PackedScene"' in path.read_text():
            raise ValueError(f"Visual scene must not include scripts or nested scenes: {scene}")
        for key in ("from", "to"):
            point = shot.get(key)
            if not isinstance(point, list) or len(point) != 2 or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in point):
                raise ValueError(f"{key} must be a finite [x, y] position")
        if not isinstance(shot.get("view_width"), (int, float)) or not math.isfinite(shot["view_width"]) or shot["view_width"] <= 0:
            raise ValueError("view_width must be positive")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--route", type=Path, default=Path(__file__).with_name("route.json"))
    parser.add_argument("--output", type=Path, help="New output directory (inside the assigned slot)")
    parser.add_argument("--preview", action="store_true", help="One PNG per shot; no video or installation")
    parser.add_argument("--check", action="store_true", help="Validate route without rendering")
    parser.add_argument("--install", action="store_true", help="Replace this slot's login background after successful encoding")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    route = json.loads(args.route.read_text())
    validate(route)
    if args.check:
        print(f"Valid route: {len(route['shots'])} shots, {len(route['shots']) * route['shot_seconds']} seconds")
        return
    slot_root = ROOT.parent
    if slot_root.name not in ("slot-a", "slot-b", "slot-c") or slot_root.parent.name != ".worktrees":
        parser.error("Record from an assigned task slot, not the integration checkout")
    if args.preview and args.install:
        parser.error("--preview cannot be combined with --install")
    workspace = slot_root.parent.parent
    output = args.output.resolve() if args.output else slot_root / ".tmp" / "world-tour"
    if not output.is_relative_to(slot_root) or output.exists():
        parser.error("Output must be a NEW directory inside this slot; previous recordings are retained")
    if not shutil.which(args.godot) or not shutil.which("ffmpeg"):
        parser.error("Godot and FFmpeg must be installed")
    output.mkdir(parents=True)
    frames = output / "frames"
    frames.mkdir()
    route_path = output / "route.json"
    route_path.write_text(json.dumps(route, indent=2) + "\n")
    command = [str(workspace / "ops/worktrees/slot-env"), slot_root.name, "--", args.godot,
               "--path", str(ROOT), "--rendering-method", "gl_compatibility",
               "--audio-driver", "Dummy", "--resolution", f"{route['width']}x{route['height']}",
               "--fixed-fps", str(route["fps"]), "--disable-vsync",
               "--script", "res://tools/world_tour/capture.gd", "--", str(route_path), str(frames)]
    if args.preview:
        command.append("--preview")
    with (output / "capture.log").open("w") as log:
        subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
    expected = len(route["shots"]) if args.preview else round(len(route["shots"]) * route["shot_seconds"] * route["fps"])
    if len(list(frames.glob("*.png"))) != expected:
        raise RuntimeError(f"Incomplete capture; inspect {output / 'capture.log'}")
    if "ERROR:" in (output / "capture.log").read_text():
        raise RuntimeError(f"Godot reported errors; inspect {output / 'capture.log'}")
    if args.preview:
        print(f"Preview frames: {frames}")
        return
    common = ["ffmpeg", "-v", "error", "-nostdin", "-framerate", str(route["fps"]),
              "-i", str(frames / "%06d.png"), "-an"]
    # q:v is Theora's quality scale (0–10); q6 is a good quality/size balance.
    # A longer GOP improves compression without reducing the per-frame quality.
    subprocess.run(common + ["-c:v", "libtheora", "-q:v", "6", "-g:v", "64", "-pix_fmt", "yuv420p", str(output / "login_background.ogv")], check=True)
    subprocess.run(common + ["-c:v", "libx264", "-crf", "20", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(output / "preview.mp4")], check=True)
    if args.install:
        target = ROOT / "assets/video/login_background.ogv"
        # Keep the existing tracked video intact until the complete replacement is ready.
        with tempfile.NamedTemporaryFile(dir=target.parent, suffix=".ogv", delete=False) as staging:
            staged_path = Path(staging.name)
        try:
            shutil.copyfile(output / "login_background.ogv", staged_path)
            os.replace(staged_path, target)
        finally:
            staged_path.unlink(missing_ok=True)
    print(f"Recorded {expected} frames: {output / 'preview.mp4'}")


if __name__ == "__main__":
    main()
