#!/usr/bin/env python3
"""Import mount art into the fixed 4x4 overworld sprite grid.

Mount deliveries may use an expanded canvas for their positioning preview. The
runtime assets must not: Godot expects four 64px columns and four 64px rows.
This importer crops only transparent trailing canvas space and rejects any
crop that would discard visible pixels.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops

from import_player_layered_sprites import write_texture_import


FRAME_SIZE = 64
GRID_SIZE = 4
SHEET_SIZE = FRAME_SIZE * GRID_SIZE
DEFAULT_SOURCE = Path("/home/adinho/Documents/outfit/lapras_surf")
DEFAULT_MOUNT_ID = "lapras"
GUIDE_ORIGIN = (20, 16)
RIDER_OFFSETS = (
    ((2, -16), (2, -14), (2, -14), (2, -14)),
    ((20, -4), (20, -4), (18, -2), (18, -2)),
    ((-20, -4), (-20, -4), (-18, -2), (-18, -2)),
    ((2, -2), (2, 0), (2, 0), (2, 2)),
)


def normalize_top_left_sheet(source_path: Path) -> Image.Image:
    image = Image.open(source_path).convert("RGBA")
    width, height = image.size
    if width < SHEET_SIZE or height < SHEET_SIZE:
        raise ValueError(
            f"{source_path} must be at least {SHEET_SIZE}x{SHEET_SIZE}, got {width}x{height}"
        )

    alpha_bounds = image.getchannel("A").getbbox()
    if alpha_bounds is not None:
        _, _, opaque_right, opaque_bottom = alpha_bounds
        if opaque_right > SHEET_SIZE or opaque_bottom > SHEET_SIZE:
            raise ValueError(
                f"{source_path} has visible pixels outside the top-left "
                f"{SHEET_SIZE}x{SHEET_SIZE} runtime grid"
            )
    return image.crop((0, 0, SHEET_SIZE, SHEET_SIZE))


def validate_mask(mask: Image.Image, source_path: Path) -> None:
    alpha = mask.getchannel("A")
    alpha_histogram = alpha.histogram()
    opaque_pixels = sum(alpha_histogram[1:])
    if opaque_pixels == 0:
        raise ValueError(f"{source_path} does not contain any rider occlusion pixels")
    if sum(alpha_histogram[1:255]) > 0:
        raise ValueError(f"{source_path} must use a binary alpha mask")


def build_expected_character_guide(
    body: Image.Image,
    mask: Image.Image,
    output_size: tuple[int, int],
) -> Image.Image:
    guide = Image.new("RGBA", output_size, (0, 0, 0, 0))
    origin_x, origin_y = GUIDE_ORIGIN
    for row in range(GRID_SIZE):
        for column in range(GRID_SIZE):
            source_box = (
                column * FRAME_SIZE,
                row * FRAME_SIZE,
                (column + 1) * FRAME_SIZE,
                (row + 1) * FRAME_SIZE,
            )
            frame = body.crop(source_box)
            offset_x, offset_y = RIDER_OFFSETS[row][column]
            guide.alpha_composite(
                frame,
                (
                    column * FRAME_SIZE + origin_x + offset_x,
                    row * FRAME_SIZE + origin_y + offset_y,
                ),
            )

    guide_pixels = guide.load()
    mask_pixels = mask.load()
    for y in range(SHEET_SIZE):
        for x in range(SHEET_SIZE):
            if mask_pixels[x, y][3] > 0:
                guide_pixels[x + origin_x, y + origin_y] = (0, 0, 0, 0)
    return guide


def verify_character_guide(
    source_root: Path,
    project_root: Path,
    mask: Image.Image,
    strict: bool,
) -> None:
    guide_path = source_root / "Character.png"
    body_path = (
        project_root
        / "assets/player/male/body/ride/Gen4_Base_v1_ride.png"
    )
    if not guide_path.exists() or not body_path.exists():
        return

    delivered = Image.open(guide_path).convert("RGBA")
    body = Image.open(body_path).convert("RGBA")
    expected = build_expected_character_guide(body, mask, delivered.size)
    difference = ImageChops.difference(expected, delivered)
    channels = difference.split()
    combined_difference = channels[0]
    for channel in channels[1:]:
        combined_difference = ImageChops.lighter(combined_difference, channel)
    difference_pixels = sum(combined_difference.histogram()[1:])
    if difference_pixels == 0:
        print(f"validated rider guide {guide_path}")
        return

    message = (
        f"{guide_path} contains {difference_pixels} pixels that do not match "
        "the validated rider offsets; it is reference-only and will not be imported"
    )
    if strict:
        raise ValueError(message)
    print(f"warning: {message}")


def import_mount(
    source_root: Path,
    project_root: Path,
    mount_id: str,
    strict_guide: bool,
) -> None:
    source_mount = source_root / "Lapras_Mount.png"
    source_mask = source_root / "Mask.png"
    if not source_mount.exists():
        raise FileNotFoundError(source_mount)
    if not source_mask.exists():
        raise FileNotFoundError(source_mask)

    mount = normalize_top_left_sheet(source_mount)
    mask = normalize_top_left_sheet(source_mask)
    validate_mask(mask, source_mask)
    verify_character_guide(source_root, project_root, mask, strict_guide)

    destination_root = project_root / "assets/mounts" / mount_id
    destination_root.mkdir(parents=True, exist_ok=True)
    destinations = {
        destination_root / "mount.png": mount,
        destination_root / "rider_mask.png": mask,
    }
    for destination, image in destinations.items():
        image.save(destination)
        write_texture_import(project_root, destination.relative_to(project_root))
        print(f"imported {destination} ({SHEET_SIZE}x{SHEET_SIZE})")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
    )
    parser.add_argument("--mount-id", default=DEFAULT_MOUNT_ID)
    parser.add_argument(
        "--strict-guide",
        action="store_true",
        help="Fail when the optional positioning guide contains stray pixels",
    )
    args = parser.parse_args()
    import_mount(args.source, args.project_root, args.mount_id, args.strict_guide)


if __name__ == "__main__":
    main()
