#!/usr/bin/env python3
"""Import the female-only Aether Blossom walking cosmetics."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from PIL import Image

from import_player_layered_sprites import (
    SHEET_SIZE,
    merge_json_ids,
    read_png_size,
    write_texture_import,
)


WALKING_ASSETS = {
    "hair": {
        "Aether_Blossom_Hair": ("Colored", "Hair.png"),
        "Aether_Blossom_Hair_Chroma": ("BlackWhite", "Hair.png"),
    },
    "facegear": {
        "Aether_Blossom_Earrings": ("Colored", "Earrings.png"),
        "Aether_Blossom_Earrings_Chroma": ("BlackWhite", "Earrings.png"),
    },
    "top": {
        "Aether_Blossom_Dress": ("Colored", "Dress.png"),
    },
    "shoes": {
        "Aether_Blossom_Shoes": ("Colored", "Shoes.png"),
        "Aether_Blossom_Shoes_Chroma": ("BlackWhite", "Shoes.png"),
    },
}

ACTIVITY_ASSETS = [
    ("Fishing/Colored/Dress.png", "top", "fish", "Aether_Blossom_Dress"),
    ("Fishing/Colored/Shoes.png", "shoes", "fish", "Aether_Blossom_Shoes"),
    (
        "Fishing/BlackWhite/Wishmaker_Jirachi_Fishing.png",
        "shoes",
        "fish",
        "Aether_Blossom_Shoes_Chroma",
    ),
    ("Mount/Colored/Dress.png", "top", "ride", "Aether_Blossom_Dress"),
    ("Mount/Colored/Shoes.png", "shoes", "ride", "Aether_Blossom_Shoes"),
    ("Mount/BlackWhite/Shoes.png", "shoes", "ride", "Aether_Blossom_Shoes_Chroma"),
]


def import_sheet(source_path: Path, destination_path: Path, overwrite: bool) -> None:
    if destination_path.exists() and not overwrite:
        print(f"skip existing {destination_path}")
        return

    width, height = read_png_size(source_path)
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    if (width, height) == (SHEET_SIZE, SHEET_SIZE):
        shutil.copy2(source_path, destination_path)
        print(f"imported {source_path} -> {destination_path}")
        return
    if (width, height) == (SHEET_SIZE // 2, SHEET_SIZE // 2):
        image = Image.open(source_path).convert("RGBA")
        image.resize((SHEET_SIZE, SHEET_SIZE), Image.Resampling.NEAREST).save(destination_path)
        print(f"scaled {source_path} ({width}x{height}) -> {destination_path}")
        return
    raise ValueError(
        f"{source_path} must be {SHEET_SIZE}x{SHEET_SIZE} or "
        f"{SHEET_SIZE // 2}x{SHEET_SIZE // 2}, got {width}x{height}"
    )


def import_aether_blossom(source_root: Path, project_root: Path, overwrite: bool) -> None:
    walking_root = source_root / "Walking"
    for category, entries in WALKING_ASSETS.items():
        destination_dir = project_root / "assets" / "player" / "female" / category
        for appearance_id, (source_variant, source_name) in entries.items():
            source_path = walking_root / source_variant / source_name
            if not source_path.exists():
                raise FileNotFoundError(source_path)
            destination_path = destination_dir / f"{appearance_id}.png"
            import_sheet(source_path, destination_path, overwrite)
            write_texture_import(project_root, destination_path.relative_to(project_root))
        merge_json_ids(destination_dir / "parts_manifest.json", list(entries))

    for source_name, category, movement_style, appearance_id in ACTIVITY_ASSETS:
        source_path = source_root / source_name
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        destination_path = (
            project_root
            / "assets"
            / "player"
            / "female"
            / category
            / movement_style
            / f"{appearance_id}_{movement_style}.png"
        )
        import_sheet(source_path, destination_path, overwrite)
        write_texture_import(project_root, destination_path.relative_to(project_root))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "source",
        nargs="?",
        default="/home/adinho/Documents/outfit/Wishmaker Jirachi",
        help="Folder containing the Wishmaker Jirachi Walking, Fishing and Mount deliveries",
    )
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    import_aether_blossom(Path(args.source), args.project_root, args.overwrite)


if __name__ == "__main__":
    main()
