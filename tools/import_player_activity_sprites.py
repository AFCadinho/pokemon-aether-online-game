#!/usr/bin/env python3
"""Import Delivery 3 activity pose sprites into the layered player layout.

Activity pose assets are not selectable customization items. They are runtime
overrides for the current body/clothing parts:

  assets/player/{gender}/{category}/{activity}/{part_id}_{activity}.png

Delivery 3 names the riding/surfing pose as Surf. In the project layout that
pose is stored as `ride`, because surf and mount riding share the same player
pose while their vehicle/mount visuals are separate.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image

from import_player_layered_sprites import SHEET_SIZE, read_png_size, write_texture_import


BODY_IDS = {
    "male": {
        "M_Light": "Gen4_Base_v1",
        "M_Tan": "Gen4_Base_M_Tan",
        "M_Dark": "Gen4_Base_M_Dark",
    },
    "female": {
        "F_Light": "Gen4_Base_F_v1",
        "F_Tan": "Gen4_Base_F_Tan",
        "F_Dark": "Gen4_Base_F_Dark",
    },
}

PART_IDS = {
    "Shirt": ("top", "Shirt"),
    "Trousers": ("bottom", "Trousers"),
    "Shoes": ("shoes", "Shoes"),
}

SOURCE_POSES = {
    "Fish": "fish",
    "Surf": "ride",
}

GENDER_SUFFIXES = {
    "male": "M",
    "female": "F",
}


def copy_or_normalize_sheet(source_path: Path, destination_path: Path, overwrite: bool) -> bool:
    if destination_path.exists() and not overwrite:
        print(f"skip existing {destination_path}")
        return False

    width, height = read_png_size(source_path)
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    if width == SHEET_SIZE and height == SHEET_SIZE:
        shutil.copy2(source_path, destination_path)
        print(f"imported {source_path} -> {destination_path}")
        return True

    if height != SHEET_SIZE or width < SHEET_SIZE:
        raise ValueError(f"{source_path} must be at least {SHEET_SIZE}x{SHEET_SIZE}, got {width}x{height}")

    source_image = Image.open(source_path).convert("RGBA")
    left = (width - SHEET_SIZE) // 2
    right = left + SHEET_SIZE
    alpha_bounds = source_image.getbbox()
    if alpha_bounds != None:
        bounds_left, _, bounds_right, _ = alpha_bounds
        if bounds_left < left or bounds_right > right:
            raise ValueError(
                f"{source_path} has opaque pixels outside the centered {SHEET_SIZE}px crop"
            )

    normalized = source_image.crop((left, 0, right, SHEET_SIZE))
    normalized.save(destination_path)
    print(f"normalized {source_path} ({width}x{height}) -> {destination_path}")
    return True


def import_activity_bodies(source_root: Path, project_root: Path, overwrite: bool) -> None:
    for gender, body_ids in BODY_IDS.items():
        body_dir = project_root / "assets" / "player" / gender / "body"
        for source_key, body_id in body_ids.items():
            for source_pose, activity in SOURCE_POSES.items():
                source_path = source_root / f"Gen4_Base_{source_key}_{source_pose}.png"
                if not source_path.exists():
                    raise FileNotFoundError(source_path)

                destination = body_dir / activity / f"{body_id}_{activity}.png"
                copy_or_normalize_sheet(source_path, destination, overwrite)
                write_texture_import(project_root, destination.relative_to(project_root))


def import_activity_parts(source_root: Path, project_root: Path, overwrite: bool) -> None:
    clothes_root = source_root / "Clothes"
    for gender, gender_suffix in GENDER_SUFFIXES.items():
        for source_part, part_config in PART_IDS.items():
            category, part_id = part_config
            for source_pose, activity in SOURCE_POSES.items():
                source_path = clothes_root / f"{source_part}_{gender_suffix}_{source_pose}.png"
                if not source_path.exists():
                    raise FileNotFoundError(source_path)

                destination = (
                    project_root
                    / "assets"
                    / "player"
                    / gender
                    / category
                    / activity
                    / f"{part_id}_{activity}.png"
                )
                copy_or_normalize_sheet(source_path, destination, overwrite)
                write_texture_import(project_root, destination.relative_to(project_root))


def import_delivery_3(source_root: Path, project_root: Path, overwrite: bool) -> None:
    import_activity_bodies(source_root, project_root, overwrite)
    import_activity_parts(source_root, project_root, overwrite)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "source",
        nargs="?",
        default="/home/adinho/Documents/outfit/Delivery 3",
        help="Folder containing Delivery 3 sprites",
    )
    parser.add_argument("--project-root", default=Path(__file__).resolve().parents[1])
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    import_delivery_3(Path(args.source), Path(args.project_root), args.overwrite)


if __name__ == "__main__":
    main()
