#!/usr/bin/env python3
"""Import the Adinho walking cosmetics without making them starter cosmetics."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

from import_player_layered_sprites import validate_sheet, write_texture_import


ASSETS = {
    "hair": {
        "Adinho_Hair": ("Colors", "Hair.png"),
    },
    "facial_hair": {
        "Adinho_Beard": ("Colors", "Beard.png"),
    },
    "facegear": {
        "Adinho_Glasses": ("Colors", "Glasses.png"),
        "Adinho_Glasses_Chroma": ("Black_White", "Glasses.png"),
    },
    "top": {
        "Adinho_Shirt": ("Colors", "Shirt.png"),
        "Adinho_Shirt_Chroma": ("Black_White", "Shirt.png"),
    },
    "bottom": {
        "Adinho_Trousers": ("Colors", "Trousers.png"),
        "Adinho_Trousers_Chroma": ("Colors", "Trousers.png"),
    },
    "shoes": {
        "Adinho_Shoes": ("Colors", "Shoes.png"),
        "Adinho_Shoes_Chroma": ("Colors", "Shoes.png"),
    },
    "eyebrows": {
        "Adinho_Eyebrows": ("Colors", "Eyebrows.png"),
    },
}


def read_manifest(path: Path) -> list[str]:
    if not path.exists():
        return []
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError(f"{path} must contain a JSON array")
    return [str(value) for value in payload if str(value).strip()]


def write_manifest(path: Path, ids: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(ids, indent=2) + "\n", encoding="utf-8")


def import_adinho(source_root: Path, project_root: Path, overwrite: bool) -> None:
    for category, entries in ASSETS.items():
        destination_dir = project_root / "assets" / "player" / "male" / category
        manifest_path = destination_dir / "parts_manifest.json"
        manifest_ids = read_manifest(manifest_path)
        for appearance_id, (source_dir, source_name) in entries.items():
            source_path = source_root / source_dir / source_name
            if not source_path.exists():
                raise FileNotFoundError(source_path)
            validate_sheet(source_path)
            destination_path = destination_dir / f"{appearance_id}.png"
            if destination_path.exists() and not overwrite:
                print(f"skip existing {destination_path}")
            else:
                destination_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source_path, destination_path)
                print(f"imported {source_path} -> {destination_path}")
            write_texture_import(project_root, destination_path.relative_to(project_root))
            if appearance_id not in manifest_ids:
                manifest_ids.append(appearance_id)
        write_manifest(manifest_path, manifest_ids)

    female_facial_hair_manifest = (
        project_root / "assets" / "player" / "female" / "facial_hair" / "parts_manifest.json"
    )
    if not female_facial_hair_manifest.exists():
        write_manifest(female_facial_hair_manifest, [])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "source",
        nargs="?",
        default="/home/adinho/Documents/outfit/Adinho_Character/Adinho_Character_Walking",
    )
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    import_adinho(Path(args.source), args.project_root, args.overwrite)


if __name__ == "__main__":
    main()
