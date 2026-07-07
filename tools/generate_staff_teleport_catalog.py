#!/usr/bin/env python3
"""Generate the backend staff teleport catalog from Godot overworld scenes."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_SCENE_ROOT = Path("scenes/overworld")
DEFAULT_OUTPUT = Path("generated/staff_teleport_catalog.json")
DEFAULT_OVERRIDES = Path("tools/staff_teleport_overrides.json")
TILE_SIZE = 32

EXT_RESOURCE_RE = re.compile(r'^\[ext_resource .* id="([^"]+)".*\]$')
PATH_RE = re.compile(r'path="([^"]+)"')
NODE_RE = re.compile(r'^\[node name="([^"]+)"(?: type="([^"]+)")?(?: parent="([^"]+)")?.*\]$')
EXT_REF_RE = re.compile(r'ExtResource\("([^"]+)"\)')
EXPORT_STRING_RE = re.compile(r'@export(?:_[^\s(]+(?:\([^)]*\))?)?\s+var\s+([A-Za-z0-9_]+)\s*(?::=\s*|=\s*)"([^"]*)"')
SCENE_STRING_RE = re.compile(r'^([A-Za-z0-9_]+)\s*=\s*"([^"]*)"$')
VECTOR2_RE = re.compile(r'Vector2\((-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\)')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scene-root", type=Path, default=DEFAULT_SCENE_ROOT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--overrides", type=Path, default=DEFAULT_OVERRIDES)
    args = parser.parse_args()

    overrides = _load_overrides(args.overrides)
    catalog: dict[str, dict[str, Any]] = {}
    for scene_path in sorted(args.scene_root.rglob("*.tscn")):
        entry = _catalog_entry_for_scene(scene_path, overrides)
        if entry is None:
            continue
        map_id = str(entry.pop("id"))
        catalog[map_id] = entry

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(catalog, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {len(catalog)} maps to {args.output}")
    return 0


def _load_overrides(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"maps": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def _catalog_entry_for_scene(scene_path: Path, overrides: dict[str, Any]) -> dict[str, Any] | None:
    lines = scene_path.read_text(encoding="utf-8").splitlines()
    ext_resources = _parse_ext_resources(lines)
    root_properties, root_script_path = _parse_root_metadata(lines, ext_resources)
    script_defaults = _parse_script_defaults(root_script_path) if root_script_path is not None else {}

    map_id = _metadata_value(root_properties, script_defaults, "map_id")
    if map_id == "":
        map_id = _scene_path_to_map_id(scene_path)
    region_name = _metadata_value(root_properties, script_defaults, "map_region_name", "Kanto")
    display_name = _metadata_value(root_properties, script_defaults, "map_display_name", _humanize_id(map_id))

    points = _parse_spawn_points(lines)
    if not points:
        return None

    map_override = overrides.get("maps", {}).get(map_id, {})
    point_overrides = map_override.get("points", {}) if isinstance(map_override, dict) else {}
    catalog_points: dict[str, dict[str, Any]] = {}
    for spawn_name, position in points.items():
        default_point_id = _to_snake_case(spawn_name)
        point_override = point_overrides.get(default_point_id, {}) if isinstance(point_overrides, dict) else {}
        point_id = str(point_override.get("id", default_point_id)).strip()
        x, y = position
        point_entry = {
            "label": point_override.get("label", _humanize_id(point_id)),
            "spawnMarker": spawn_name,
            "tile": _tile_from_position(x, y),
            "facingDirection": point_override.get("facingDirection", "down"),
            "safe": bool(point_override.get("safe", True)),
        }
        catalog_points[point_id] = point_entry

    return {
        "id": map_id,
        "label": map_override.get("label", display_name) if isinstance(map_override, dict) else display_name,
        "regionName": map_override.get("regionName", region_name) if isinstance(map_override, dict) else region_name,
        "scenePath": _res_path(scene_path),
        "points": catalog_points,
    }


def _parse_ext_resources(lines: list[str]) -> dict[str, str]:
    resources: dict[str, str] = {}
    for line in lines:
        match = EXT_RESOURCE_RE.match(line)
        if match is None:
            continue
        path_match = PATH_RE.search(line)
        if path_match is not None:
            resources[match.group(1)] = path_match.group(1)
    return resources


def _parse_root_metadata(lines: list[str], ext_resources: dict[str, str]) -> tuple[dict[str, str], Path | None]:
    properties: dict[str, str] = {}
    in_root = False
    root_script_path: Path | None = None
    for line in lines:
        node_match = NODE_RE.match(line)
        if node_match is not None:
            node_parent = node_match.group(3)
            if node_parent is None:
                in_root = True
                continue
            if in_root:
                break
        if not in_root:
            continue
        script_match = EXT_REF_RE.search(line)
        if line.startswith("script = ") and script_match is not None:
            script_resource_path = ext_resources.get(script_match.group(1), "")
            if script_resource_path.startswith("res://"):
                root_script_path = Path(script_resource_path.replace("res://", "", 1))
            continue
        scene_string_match = SCENE_STRING_RE.match(line)
        if scene_string_match is not None:
            properties[scene_string_match.group(1)] = scene_string_match.group(2)
    return properties, root_script_path


def _parse_script_defaults(script_path: Path) -> dict[str, str]:
    if not script_path.exists():
        return {}
    defaults: dict[str, str] = {}
    for line in script_path.read_text(encoding="utf-8").splitlines():
        match = EXPORT_STRING_RE.search(line)
        if match is not None:
            defaults[match.group(1)] = match.group(2)
    return defaults


def _parse_spawn_points(lines: list[str]) -> dict[str, tuple[float, float]]:
    points: dict[str, tuple[float, float]] = {}
    active_spawn_name = ""
    for line in lines:
        node_match = NODE_RE.match(line)
        if node_match is not None:
            name, node_type, parent = node_match.group(1), node_match.group(2), node_match.group(3)
            active_spawn_name = name if node_type == "Marker2D" and parent == "Spawns" else ""
            continue
        if active_spawn_name == "" or not line.startswith("position = "):
            continue
        vector_match = VECTOR2_RE.search(line)
        if vector_match is None:
            continue
        points[active_spawn_name] = (float(vector_match.group(1)), float(vector_match.group(2)))
        active_spawn_name = ""
    return points


def _metadata_value(properties: dict[str, str], script_defaults: dict[str, str], key: str, fallback: str = "") -> str:
    return properties.get(key, script_defaults.get(key, fallback)).strip()


def _tile_from_position(x: float, y: float) -> dict[str, int]:
    return {
        "x": int(round((x - (TILE_SIZE / 2)) / TILE_SIZE)),
        "y": int(round((y - (TILE_SIZE / 2)) / TILE_SIZE)),
    }


def _scene_path_to_map_id(scene_path: Path) -> str:
    parts = scene_path.with_suffix("").parts
    if "overworld" in parts:
        parts = parts[parts.index("overworld") + 1 :]
    return _to_snake_case("_".join(parts))


def _res_path(path: Path) -> str:
    return "res://" + path.as_posix()


def _to_snake_case(value: str) -> str:
    value = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", value)
    value = re.sub(r"(?<=[A-Za-z])(?=[0-9])", "_", value)
    value = re.sub(r"(?<=[0-9])(?=[A-Za-z])", "_", value)
    value = re.sub(r"[^A-Za-z0-9]+", "_", value)
    return value.strip("_").lower()


def _humanize_id(value: str) -> str:
    words = value.replace("_", " ").split()
    return " ".join(word.capitalize() for word in words)


if __name__ == "__main__":
    raise SystemExit(main())
