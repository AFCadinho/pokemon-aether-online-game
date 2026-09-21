"""Bake reviewed 60 Hz clearance measurements; never overwrite an artifact."""
import argparse
import json
import math
from pathlib import Path


def bake(report, grounded_sleep):
    if report.get("errors") or report.get("review_schema") != 1:
        raise ValueError("A successful measurement report is required")
    result = {}
    for species, entry in report["entries"].items():
        if not entry.get("idle_verified"):
            raise ValueError("Idle verification required")
        lift = entry["candidate_lift"]
        profile = {"schema": 1, "sha256": entry["sha256"], "scale": entry["scale"],
                   "yaw_degrees": entry["yaw_degrees"], "lift": lift, "clips": {}}
        for action in ("physical_attack", "special_attack", "damage", "sleep"):
            if action == "sleep" and species not in grounded_sleep:
                continue
            clip = entry["clips"][action]
            minima = clip["minimum_y_samples"]
            if len(minima) != math.ceil(clip["duration"] * 60) + 1 or not all(math.isfinite(v) for v in minima):
                raise ValueError("Invalid pose samples")
            if action == "sleep":
                # Explicit resting intent, not automatically inferred from a low pose.
                offsets = [max(0, .030 - min(minima)) - lift] * len(minima)
            else:
                raw = [max(0, .030 - value - lift) for value in minima]
                # Conservative neighbour envelope covers sub-frame interpolation.
                offsets = [max(raw[max(0, i - 1):i + 2]) for i in range(len(raw))]
            profile["clips"][action] = {"duration": clip["duration"],
                "intent": "grounded_rest" if action == "sleep" else "clearance_only",
                "offsets": [round(value, 7) for value in offsets]}
        result[species] = profile
    if set(grounded_sleep) - set(result):
        raise ValueError("Unknown grounded-sleep species")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--grounded-sleep", nargs="*", default=[])
    args = parser.parse_args()
    profiles = bake(json.loads(args.report.read_text()), args.grounded_sleep)
    with args.output.open("x") as stream:
        json.dump(profiles, stream, indent=2)
        stream.write("\n")
