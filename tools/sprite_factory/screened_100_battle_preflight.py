#!/usr/bin/env python3
"""Separate measured battle candidates from placement and motion holds."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

try:
    from .screened_100_battle_candidates import PRODUCTION, entries, sha256
except ImportError:
    from screened_100_battle_candidates import PRODUCTION, entries, sha256


REQUIRED = {"idle", "physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"}


def preflight(reports: list[Path], motion_path: Path) -> dict:
    measured, sources = entries(reports)
    motion = json.loads(motion_path.read_text())
    production = {row["species"]: row for row in json.loads(PRODUCTION.read_text())["entries"]
                  if row["status"] == "technical_candidate"}
    if (motion.get("production_sha256") != sha256(PRODUCTION)
            or motion.get("report_sha256") != sources):
        raise ValueError("motion source or placement measurements changed")
    result = []
    for name, row in sorted(measured.items()):
        reasons = []
        clips = row["clips"]
        if REQUIRED - set(clips):
            reasons.append("missing mapped battle action")
        if name in motion.get("motion_holds", {}):
            reasons.append("motion bake: " + motion["motion_holds"][name])
        profile = motion.get("motion", {}).get(name)
        if profile is None:
            reasons.append("no motion profile")
        else:
            if (profile["sha256"] != production[name]["normal_glb_sha256"]
                    or not math.isclose(profile["scale"], row["scale"], rel_tol=1e-4, abs_tol=1e-4)
                    or not math.isclose(profile["lift"], row["candidate_lift"], rel_tol=1e-4, abs_tol=1e-4)
                    or (set(clips) - {"idle"}) - set(profile["clips"])):
                reasons.append("incomplete or changed motion profile")
            for action, baked in profile["clips"].items():
                if (action not in clips or len(baked["offsets"]) != math.ceil(baked["duration"] * 60) + 1
                        or not math.isclose(baked["duration"], clips[action]["duration"], rel_tol=1e-5)
                        or any(not math.isfinite(offset) or
                               offset < (-profile["lift"] if action == "sleep" else 0)
                               for offset in baked["offsets"])):
                    reasons.append("invalid runtime motion clearance")
                    break
        shots = row["shots"]
        if len(shots) != 16 or any(not shot["in_view"] for shot in shots):
            reasons.append("model moves outside battle camera")
        if any(shot["model_overlaps_hud_proxy"] for shot in shots):
            reasons.append("model overlaps battle HUD area")
        idle_heights = [shot["screen_rect"][3] for shot in shots if shot["action"] == "idle"]
        if len(idle_heights) != 4 or min(idle_heights) < 60:
            reasons.append("model too small at battle distance")
        if not all(math.isfinite(clip["minimum_y"]) and clip["samples"] ==
                   math.ceil(clip["duration"] * 60) + 1 for clip in clips.values()):
            reasons.append("incomplete 60 Hz pose sweep")
        result.append({"species": name, "status": "ready_for_battle_stress" if not reasons else "held",
                       "reasons": reasons, "normal_scn_sha256": production[name]["normal_scn_sha256"],
                       "shiny_scn_sha256": production[name]["shiny_scn_sha256"],
                       "scale": row["scale"], "lift": row["candidate_lift"],
                       "minimum_idle_pixels": round(min(idle_heights), 2) if idle_heights else None,
                       "sampled_poses": sum(clip["samples"] for clip in clips.values())})
    return {"schema": 1, "runtime_approved": False, "release_approved": False,
            "production_sha256": sha256(PRODUCTION), "motion_sha256": sha256(motion_path),
            "report_sha256": sources, "entries": result,
            "ready_for_battle_stress": sum(row["status"] == "ready_for_battle_stress" for row in result),
            "held": sum(row["status"] == "held" for row in result)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("motion", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("reports", nargs="+", type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("output must be new")
    result = preflight(args.reports, args.motion)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"{result['ready_for_battle_stress']} ready; {result['held']} placement/motion holds")


if __name__ == "__main__":
    main()
