"""Resolve all outdoor maps to their actual visual scenes, including templates."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "generated/world_access_catalog.json"


def visual_scenes(scene, seen=None):
    seen = set() if seen is None else seen
    if not scene or scene in seen:
        return set()
    seen.add(scene)
    path = ROOT / scene.removeprefix("res://")
    if not path.is_file():
        raise ValueError(f"Missing map scene: {scene}")
    if scene.startswith("res://generated/tiled_visuals/"):
        return {scene}
    result = set()
    for child in re.findall(r'\[ext_resource type="PackedScene"[^\n]*path="([^\"]+)"', path.read_text()):
        if child.startswith(("res://scenes/overworld/", "res://generated/tiled_visuals/")):
            result.update(visual_scenes(child, seen))
    return result


def coverage():
    areas = json.loads(CATALOG.read_text())["areas"]
    groups = {}
    unbuilt = {}
    for area_id, area in areas.items():
        if area["areaType"] not in ("exterior", "route", "wilderness"):
            continue
        # Wilderness also includes underground maps in the world-access catalog.
        if "/caves/" in area["scenePath"]:
            continue
        if not area["scenePath"]:
            unbuilt[area_id] = area["label"]
            continue
        visuals = visual_scenes(area["scenePath"])
        if not visuals:
            raise ValueError(f"Map has no recordable visual scene: {area_id}")
        for scene in sorted(visuals):
            groups.setdefault(scene, []).append(area_id)
    return groups, unbuilt


def check_coverage(route):
    groups, _ = coverage()
    excluded = route.get("excluded_visuals", {})
    additional = route.get("additional_visuals", {})
    if not isinstance(excluded, dict) or any(not isinstance(reason, str) or not reason.strip() for reason in excluded.values()):
        raise ValueError("Excluded visuals require a written reason")
    if not isinstance(additional, dict) or any(not isinstance(reason, str) or not reason.strip() for reason in additional.values()):
        raise ValueError("Additional visuals require a written reason")
    if set(excluded) - set(groups):
        raise ValueError("An excluded visual no longer exists in the outdoor catalog; update the route")
    for scene in additional:
        path = ROOT / scene.removeprefix("res://")
        if not scene.startswith("res://generated/tiled_visuals/") or not path.is_file():
            raise ValueError("An additional visual is missing or invalid: " + scene)
    if set(additional) & (set(groups) | set(excluded)):
        raise ValueError("Additional visuals must be separate from outdoor and excluded visuals")
    recorded = {shot["scene"] for shot in route["shots"]}
    missing = set(groups) - recorded - set(excluded)
    if missing:
        raise ValueError("Tour is missing map visuals: " + ", ".join(sorted(missing)))
    unexpected = recorded - set(groups) - set(additional)
    if unexpected:
        raise ValueError("Outdoor tour contains non-outdoor map visuals: " + ", ".join(sorted(unexpected)))
    if recorded & set(excluded):
        raise ValueError("An excluded visual is still present in the tour")
    if set(additional) - recorded:
        raise ValueError("An additional visual is not present in the tour")
    return groups


if __name__ == "__main__":
    groups, unbuilt = coverage()
    for scene, areas in groups.items():
        print(scene, ":", ", ".join(areas))
    print("Not built:", unbuilt)
