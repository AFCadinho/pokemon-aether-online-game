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
        for action in ("physical_attack", "special_attack", "damage", "sleep", "faint_start", "faint_loop"):
            if action not in entry["clips"]:
                continue
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
                if action == "faint_loop":
                    # A steady resting root prevents bobbing at loop wrap.
                    offsets = [max(offsets)] * len(offsets)
            profile["clips"][action] = {"duration": clip["duration"],
                "intent": "grounded_rest" if action == "sleep" else "clearance_only",
                "offsets": [round(value, 7) for value in offsets]}
        clips = profile["clips"]
        if "faint_start" in clips and "faint_loop" in clips:
            start_min = entry["clips"]["faint_start"]["minimum_y_samples"][-1]
            loop_min = entry["clips"]["faint_loop"]["minimum_y_samples"][0]
            if abs(start_min - loop_min) > .002:
                raise ValueError("Faint endpoint mismatch requires asset review")
            start = clips["faint_start"]["offsets"]
            end = max(start[-1], clips["faint_loop"]["offsets"][0])
            clips["faint_loop"]["offsets"] = [end] * len(clips["faint_loop"]["offsets"])
            # Approach the loop's conservative height in the last 0.2 seconds.
            count = min(12, len(start) - 1)
            for i in range(count + 1):
                weight = i / count
                weight = weight * weight * (3 - 2 * weight)
                index = len(start) - count - 1 + i
                start[index] = round(max(start[index], start[index] * (1 - weight) + end * weight), 7)
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
