#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageSequence


DEFAULT_SOURCE_ROOT = Path("/home/adinho/Desktop/pokemon_sprites")
DEFAULT_OUTPUT_FOLDER_NAME = "generated_sheets"
SIDES = ("front", "back")


def read_gif_frames(path: Path) -> tuple[tuple[int, int], list[Image.Image], list[float]]:
    with Image.open(path) as gif:
        canvas_size = gif.size
        frames: list[Image.Image] = []
        durations: list[float] = []

        for frame in ImageSequence.Iterator(gif):
            duration_ms = float(frame.info.get("duration", 100))
            durations.append(max(duration_ms / 1000.0, 0.01))

            canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
            canvas.alpha_composite(frame.convert("RGBA"))
            frames.append(canvas)

    return canvas_size, frames, durations


def read_png_frame_folder(path: Path, fps: float) -> tuple[tuple[int, int], list[Image.Image], list[float]]:
    frame_paths = sorted(path.glob("frame_*.png"))
    if not frame_paths:
        raise ValueError(f"No frame_*.png files in {path}")

    frames = [Image.open(frame_path).convert("RGBA") for frame_path in frame_paths]
    canvas_size = frames[0].size
    durations = [1.0 / fps for _frame in frames]
    return canvas_size, frames, durations


def sample_frames(frames: list[Image.Image], durations: list[float], max_frames: int | None) -> tuple[list[Image.Image], list[float]]:
    if max_frames is None or len(frames) <= max_frames:
        return frames, durations

    selected_frames: list[Image.Image] = []
    selected_durations: list[float] = []
    frame_count = len(frames)

    for index in range(max_frames):
        start = round(index * frame_count / max_frames)
        end = round((index + 1) * frame_count / max_frames)
        frame_index = min(start, frame_count - 1)
        selected_frames.append(frames[frame_index])
        selected_durations.append(sum(durations[start:max(end, start + 1)]))

    return selected_frames, selected_durations


def export_sheet(
    side: str,
    species: str,
    source_path: Path,
    output_side_dir: Path,
    max_frames: int | None,
    folder_fps: float,
    dry_run: bool,
) -> tuple[Path, Path, int]:
    if source_path.is_file() and source_path.suffix.lower() == ".gif":
        canvas_size, frames, durations = read_gif_frames(source_path)
    elif source_path.is_dir():
        canvas_size, frames, durations = read_png_frame_folder(source_path, folder_fps)
    else:
        raise ValueError(f"Unsupported source: {source_path}")

    frames, durations = sample_frames(frames, durations, max_frames)
    frame_width, frame_height = canvas_size
    columns = math.ceil(math.sqrt(len(frames)))
    rows = math.ceil(len(frames) / columns)

    output_dir = output_side_dir / species
    sheet_path = output_dir / "sheet.png"
    metadata_path = output_dir / "animation.json"

    if dry_run:
        return sheet_path, metadata_path, len(frames)

    output_dir.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (columns * frame_width, rows * frame_height), (0, 0, 0, 0))
    metadata_frames: list[dict[str, float | int]] = []

    for index, frame in enumerate(frames):
        column = index % columns
        row = index // columns
        x = column * frame_width
        y = row * frame_height
        sheet.alpha_composite(frame, (x, y))
        metadata_frames.append({
            "x": x,
            "y": y,
            "w": frame_width,
            "h": frame_height,
            "duration": durations[index],
        })

    sheet.save(sheet_path)
    metadata = {
        "source": str(source_path),
        "image": sheet_path.name,
        "speed": 1.0,
        "frame_width": frame_width,
        "frame_height": frame_height,
        "frames": metadata_frames,
    }
    metadata_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    return sheet_path, metadata_path, len(frames)


def discover_sources(source_root: Path) -> list[tuple[str, str, Path]]:
    sources: list[tuple[str, str, Path]] = []
    for side in SIDES:
        side_dir = source_root / side
        if not side_dir.exists():
            continue

        side_sources: dict[str, Path] = {}
        for gif_path in sorted(side_dir.glob("*.gif")):
            side_sources[gif_path.stem.lower()] = gif_path

        for folder in sorted(path for path in side_dir.iterdir() if path.is_dir()):
            species = folder.name.lower()
            if species not in side_sources and list(folder.glob("frame_*.png")):
                side_sources[species] = folder

        sources.extend((side, species, side_sources[species]) for species in sorted(side_sources))

    return sources


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--output-root", type=Path)
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--side", choices=SIDES)
    parser.add_argument("--species")
    parser.add_argument("--max-frames", type=int, default=32)
    parser.add_argument("--folder-fps", type=float, default=30.0)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()

    if args.max_frames < 2:
        raise SystemExit("--max-frames must be at least 2")

    source_root = args.source_root.expanduser().resolve()
    if args.output_root is None:
        output_root = source_root / DEFAULT_OUTPUT_FOLDER_NAME
    else:
        output_root = args.output_root.expanduser().resolve()

    if args.all:
        sources = discover_sources(source_root)
    else:
        if args.side is None or args.species is None:
            raise SystemExit("Use --all or provide --side and --species")

        species = args.species.lower()
        side_dir = source_root / args.side
        gif_path = side_dir / f"{species}.gif"
        folder_path = side_dir / species
        source_path = gif_path if gif_path.exists() else folder_path
        sources = [(args.side, species, source_path)]

    if args.summary:
        side_counts = {side: 0 for side in SIDES}
        for side, _species, _source_path in sources:
            side_counts[side] += 1

        print(f"Found {len(sources)} animation sources in {source_root}")
        for side in SIDES:
            print(f"{side}: {side_counts[side]}")
        return

    for side, species, source_path in sources:
        sheet_path, metadata_path, frame_count = export_sheet(
            side,
            species,
            source_path,
            output_root / side,
            args.max_frames,
            args.folder_fps,
            args.dry_run,
        )
        prefix = "Would export" if args.dry_run else "Exported"
        print(f"{prefix} {side}/{species}: {frame_count} frames -> {sheet_path} + {metadata_path}")

    print(f"Processed {len(sources)} animation sources.")


if __name__ == "__main__":
    main()
