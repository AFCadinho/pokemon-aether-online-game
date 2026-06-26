#!/usr/bin/env python3
"""Import Delivery 2 layered player sprites into the project asset layout.

The game renderer expects every layer to be a 4x4 sheet with 64x64 frames
(256x256 total). Delivery 2 already follows that for most layers. Eyebrows are
delivered as smaller sheets, so this tool normalizes them to 256x256.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
from pathlib import Path

from PIL import Image


GRID_COLUMNS = 4
GRID_ROWS = 4
FRAME_SIZE = 64
SHEET_SIZE = FRAME_SIZE * GRID_COLUMNS

GENDER_SOURCES = {
    "male": "boy",
    "female": "girl",
}

LAYER_FILES = {
    "hair": ("Hair.png", "Hair"),
    "headgear": ("Cap.png", "Cap"),
    "eyes": ("Eyes.png", "Eyes"),
    "eyebrows": ("Eyebrows.png", "Eyebrows"),
    "top": ("Shirt.png", "Shirt"),
    "bottom": ("Trousers.png", "Trousers"),
    "shoes": ("Shoes.png", "Shoes"),
}

BODY_FILES = {
    "male": [
        ("boy/Gen4_Base_v1.png", "Gen4_Base_v1"),
        ("Gen4_Base_M_Dark.png", "Gen4_Base_M_Dark"),
        ("Gen4_Base_M_Tan.png", "Gen4_Base_M_Tan"),
    ],
    "female": [
        ("girl/Gen4_Base_v1.png", "Gen4_Base_F_v1"),
        ("Gen4_Base_F_Dark.png", "Gen4_Base_F_Dark"),
        ("Gen4_Base_F_Tan.png", "Gen4_Base_F_Tan"),
    ],
}

BODY_MANIFESTS = {
    "male": ["Gen4_Base_v1", "Gen4_Base_M_Dark", "Gen4_Base_M_Tan", "gen4_pa_base_boy"],
    "female": ["Gen4_Base_F_v1", "Gen4_Base_F_Dark", "Gen4_Base_F_Tan"],
}

PART_MANIFESTS = {
    "hair": ["Hair"],
    "headgear": ["Cap"],
    "facegear": [],
    "eyes": ["Eyes"],
    "eyebrows": ["Eyebrows"],
    "top": ["Shirt"],
    "bottom": ["Trousers"],
    "shoes": ["Shoes"],
}


def read_png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as file:
        header = file.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG file")
    return struct.unpack(">II", header[16:24])


def validate_sheet(path: Path) -> tuple[int, int]:
    width, height = read_png_size(path)
    if width != SHEET_SIZE or height != SHEET_SIZE:
        raise ValueError(f"{path} must be {SHEET_SIZE}x{SHEET_SIZE}, got {width}x{height}")
    return width // GRID_COLUMNS, height // GRID_ROWS


def normalize_sheet_to_64px_frames(source_path: Path, destination_path: Path) -> None:
    source_image = Image.open(source_path).convert("RGBA")
    source_width, source_height = source_image.size
    source_frame_width = source_width // GRID_COLUMNS
    source_frame_height = source_height // GRID_ROWS
    if source_frame_width <= 0 or source_frame_height <= 0:
        raise ValueError(f"{source_path} is too small to split into {GRID_COLUMNS}x{GRID_ROWS}")

    normalized = Image.new("RGBA", (SHEET_SIZE, SHEET_SIZE), (0, 0, 0, 0))
    for row in range(GRID_ROWS):
        for column in range(GRID_COLUMNS):
            left = column * source_frame_width
            top = row * source_frame_height
            frame = source_image.crop((left, top, left + source_frame_width, top + source_frame_height))
            frame = frame.resize((FRAME_SIZE, FRAME_SIZE), Image.Resampling.NEAREST)
            normalized.paste(frame, (column * FRAME_SIZE, row * FRAME_SIZE), frame)
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    normalized.save(destination_path)


def stable_uid(resource_path: str) -> str:
    digest = hashlib.sha1(resource_path.encode("utf-8")).hexdigest()
    value = int(digest[:16], 16)
    alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
    chars: list[str] = []
    while value:
        value, remainder = divmod(value, len(alphabet))
        chars.append(alphabet[remainder])
    return "uid://" + "".join(reversed(chars)).rjust(13, "0")[:13]


def write_texture_import(project_root: Path, relative_path: Path) -> None:
    resource_path = "res://" + relative_path.as_posix()
    import_path = project_root / relative_path.with_suffix(relative_path.suffix + ".import")
    imported_name = f"{relative_path.name}-{hashlib.md5(resource_path.encode('utf-8')).hexdigest()}.ctex"
    imported_path = f"res://.godot/imported/{imported_name}"
    import_path.write_text(
        "\n".join(
            [
                "[remap]",
                "",
                'importer="texture"',
                'type="CompressedTexture2D"',
                f'uid="{stable_uid(resource_path)}"',
                f'path="{imported_path}"',
                "metadata={",
                '"vram_texture": false',
                "}",
                "",
                "[deps]",
                "",
                f'source_file="{resource_path}"',
                f'dest_files=["{imported_path}"]',
                "",
                "[params]",
                "",
                "compress/mode=0",
                "compress/high_quality=false",
                "compress/lossy_quality=0.7",
                "compress/uastc_level=0",
                "compress/rdo_quality_loss=0.0",
                "compress/hdr_compression=1",
                "compress/normal_map=0",
                "compress/channel_pack=0",
                "mipmaps/generate=false",
                "mipmaps/limit=-1",
                "roughness/mode=0",
                'roughness/src_normal=""',
                "process/channel_remap/red=0",
                "process/channel_remap/green=1",
                "process/channel_remap/blue=2",
                "process/channel_remap/alpha=3",
                "process/fix_alpha_border=true",
                "process/premult_alpha=false",
                "process/normal_map_invert_y=false",
                "process/hdr_as_srgb=false",
                "process/hdr_clamp_exposure=false",
                "process/size_limit=0",
                "detect_3d/compress_to=1",
                "",
            ]
        )
    )


def write_json(path: Path, value: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def copy_sheet(source_path: Path, destination_path: Path, overwrite: bool) -> bool:
    if destination_path.exists() and not overwrite:
        print(f"skip existing {destination_path}")
        return False
    validate_sheet(source_path)
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, destination_path)
    print(f"imported {source_path} -> {destination_path}")
    return True


def import_delivery_2(source_root: Path, project_root: Path, overwrite: bool) -> None:
    for gender, body_files in BODY_FILES.items():
        body_dir = project_root / "assets" / "player" / gender / "body"
        for source_name, body_id in body_files:
            source_path = source_root / source_name
            if not source_path.exists():
                raise FileNotFoundError(source_path)
            destination = body_dir / f"{body_id}.png"
            copy_sheet(source_path, destination, overwrite)
            write_texture_import(project_root, destination.relative_to(project_root))
        write_json(body_dir / "body_manifest.json", BODY_MANIFESTS[gender])

    for gender, folder_name in GENDER_SOURCES.items():
        for category, (source_file, part_id) in LAYER_FILES.items():
            source_path = source_root / folder_name / source_file
            if not source_path.exists():
                raise FileNotFoundError(source_path)
            destination = project_root / "assets" / "player" / gender / category / f"{part_id}.png"
            if category == "eyebrows":
                if destination.exists() and not overwrite:
                    print(f"skip existing {destination}")
                else:
                    normalize_sheet_to_64px_frames(source_path, destination)
                    print(f"normalized {source_path} -> {destination}")
            else:
                copy_sheet(source_path, destination, overwrite)
            write_texture_import(project_root, destination.relative_to(project_root))

        for category, part_ids in PART_MANIFESTS.items():
            write_json(project_root / "assets" / "player" / gender / category / "parts_manifest.json", part_ids)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "source",
        nargs="?",
        default="/home/adinho/Documents/outfit/Delivery 2",
        help="Folder containing Delivery 2 sprites",
    )
    parser.add_argument("--project-root", default=Path(__file__).resolve().parents[1])
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    import_delivery_2(Path(args.source), Path(args.project_root), args.overwrite)


if __name__ == "__main__":
    main()
