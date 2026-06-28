#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MAP_PATH = PROJECT_ROOT / "data" / "follower_sprite_map.json"
DEFAULT_FOLLOWERS_DIR = PROJECT_ROOT / "assets" / "followers"
DEFAULT_SHINY_FOLLOWERS_DIR = PROJECT_ROOT / "assets" / "followers_shiny"
DEFAULT_BACKEND_SPECIES_DIR = (
    PROJECT_ROOT.parent
    / "pokemon-aether-backend"
    / "pokemon-data"
    / "data"
    / "species"
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate follower sprite species-to-asset mappings.")
    parser.add_argument("--map", type=Path, default=DEFAULT_MAP_PATH)
    parser.add_argument("--followers", type=Path, default=DEFAULT_FOLLOWERS_DIR)
    parser.add_argument("--shiny-followers", type=Path, default=DEFAULT_SHINY_FOLLOWERS_DIR)
    parser.add_argument("--species-dir", type=Path, default=DEFAULT_BACKEND_SPECIES_DIR)
    parser.add_argument("--require-shiny", action="store_true", help="Require shiny follower assets for every mapped form.")
    parser.add_argument(
        "--strict-discovery",
        action="store_true",
        help="Fail when a backend form appears to have numbered follower assets but no manifest entry.",
    )
    args = parser.parse_args()

    errors: list[str] = []
    warnings: list[str] = []

    sprite_map = _load_sprite_map(args.map, errors)
    normal_assets = _asset_stems(args.followers)
    shiny_assets = _asset_stems(args.shiny_followers)

    for species_id, mapped_value in sorted(sprite_map.items()):
        values = mapped_value if isinstance(mapped_value, list) else [mapped_value]
        for value in values:
            if not isinstance(value, str) or not value:
                errors.append(f"{species_id}: mapped value must be a non-empty string, got {value!r}")
                continue
            if value not in normal_assets:
                errors.append(f"{species_id}: missing normal follower asset {value}.png")
            if args.require_shiny and value not in shiny_assets:
                warnings.append(f"{species_id}: missing shiny follower asset {value}.png")

    if args.species_dir.exists():
        for species_id, asset_names in _discover_unmapped_numbered_forms(args.species_dir, normal_assets, sprite_map):
            message = f"{species_id}: possible follower form assets exist but no manifest entry ({', '.join(asset_names)})"
            if args.strict_discovery:
                errors.append(message)
            else:
                warnings.append(message)

    for warning in warnings:
        print(f"warning: {warning}", file=sys.stderr)
    for error in errors:
        print(f"error: {error}", file=sys.stderr)

    return 1 if errors else 0


def _load_sprite_map(path: Path, errors: list[str]) -> dict[str, object]:
    try:
        with path.open() as file:
            value = json.load(file)
    except OSError as exc:
        errors.append(f"could not read {path}: {exc}")
        return {}
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON in {path}: {exc}")
        return {}

    if not isinstance(value, dict):
        errors.append(f"{path} must contain a JSON object")
        return {}

    return value


def _asset_stems(directory: Path) -> set[str]:
    return {path.stem for path in directory.glob("*.png")}


def _discover_unmapped_numbered_forms(
    species_dir: Path,
    normal_assets: set[str],
    sprite_map: dict[str, object],
) -> list[tuple[str, list[str]]]:
    numbered_assets_by_base: dict[str, set[str]] = {}
    for asset in normal_assets:
        match = re.fullmatch(r"([A-Z0-9]+)_\d+", asset)
        if match:
            numbered_assets_by_base.setdefault(match.group(1), set()).add(asset)

    unmapped: list[tuple[str, list[str]]] = []
    for species_path in sorted(species_dir.glob("*.json")):
        species_id = species_path.stem
        if "-" not in species_id or species_id in sprite_map:
            continue

        try:
            data = json.loads(species_path.read_text())
        except (OSError, json.JSONDecodeError):
            continue

        base_species = str(data.get("base_species", "")).strip()
        if not base_species:
            continue

        base_key = _normalize_asset_base(base_species)
        assets = sorted(numbered_assets_by_base.get(base_key, []))
        if assets:
            unmapped.append((species_id, assets))

    return unmapped


def _normalize_asset_base(value: str) -> str:
    normalized = value.upper()
    for old, new in {
        " ": "",
        "-": "",
        "'": "",
        ".": "",
        ":": "",
        "♀": "F",
        "♂": "M",
    }.items():
        normalized = normalized.replace(old, new)
    return normalized


if __name__ == "__main__":
    raise SystemExit(main())
