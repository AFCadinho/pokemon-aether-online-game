#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
POKEMON_SPRITES = ROOT / "assets" / "sprites" / "pokemon"
REFERENCE_GLOBS = ("scenes/**/*.tscn", "scripts/**/*.gd")
FRAME_RE = re.compile(r"assets/sprites/pokemon/(front|back)/([^\"\\s]+)/frame_\d+\.png")


def referenced_frames() -> set[Path]:
    references: set[Path] = set()

    for pattern in REFERENCE_GLOBS:
        for path in ROOT.glob(pattern):
            text = path.read_text(encoding="utf-8")
            for match in FRAME_RE.finditer(text):
                references.add(ROOT / match.group(0))

    return references


def evenly_spaced(paths: list[Path], limit: int) -> set[Path]:
    if len(paths) <= limit:
        return set(paths)

    selected: set[Path] = set()
    last = len(paths) - 1
    for index in range(limit):
        selected.add(paths[round(index * last / (limit - 1))])

    return selected


def optimize(max_frames: int, dry_run: bool) -> tuple[int, int]:
    references = referenced_frames()
    keep: set[Path] = set(references)
    remove: list[Path] = []

    for side in ("front", "back"):
        side_dir = POKEMON_SPRITES / side
        for pokemon_dir in side_dir.iterdir():
            if not pokemon_dir.is_dir():
                continue

            frames = sorted(pokemon_dir.glob("frame_*.png"))
            if not frames:
                continue

            keep.add(frames[0])
            keep.update(evenly_spaced(frames, max_frames))

            for frame in frames:
                if frame not in keep:
                    remove.append(frame)

    if dry_run:
        return len(keep), len(remove)

    for frame in remove:
        frame.unlink()
        import_file = frame.with_suffix(frame.suffix + ".import")
        if import_file.exists():
            import_file.unlink()

    return len(keep), len(remove)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-frames", type=int, default=4)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.max_frames < 2:
        raise SystemExit("--max-frames must be at least 2")

    kept, removed = optimize(args.max_frames, args.dry_run)
    mode = "Would remove" if args.dry_run else "Removed"
    print(f"Kept {kept} referenced/sampled frames.")
    print(f"{mode} {removed} extra frames.")


if __name__ == "__main__":
    main()
