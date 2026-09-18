#!/usr/bin/env python3
"""Convert a numbered Pokémon anime-cry collection into Godot Ogg assets."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path


SPECIAL_SOURCE_FILES = {720: "720U.wav"}
NIDORAN_CRY_KEYS = {"nidoranf": "NIDORANfE", "nidoranm": "NIDORANmA"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--species-dir", required=True, type=Path)
    parser.add_argument("--fallback-cry-dir", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    return parser.parse_args()


def cry_key(species: dict[str, object]) -> str:
    showdown_id = str(species.get("showdown_id", ""))
    return NIDORAN_CRY_KEYS.get(showdown_id, showdown_id.upper().replace("-", ""))


def indexed_source_files(source_root: Path) -> dict[int, Path]:
    sources: dict[int, Path] = {}
    for source in source_root.rglob("*.wav"):
        match = re.fullmatch(r"(\d{1,3})\s*\.wav", source.name)
        if match:
            sources[int(match.group(1))] = source
    for dex_number, file_name in SPECIAL_SOURCE_FILES.items():
        if dex_number in sources:
            continue
        match = next(source_root.rglob(file_name), None)
        if match is not None:
            sources[dex_number] = match
    return sources


def indexed_species(species_dir: Path, fallback_cry_dir: Path) -> dict[int, str]:
    candidates: dict[int, list[tuple[int, str]]] = defaultdict(list)
    for species_file in species_dir.glob("*.json"):
        species = json.loads(species_file.read_text(encoding="utf-8"))
        dex_number = species.get("id")
        if not isinstance(dex_number, int) or not 1 <= dex_number <= 799:
            continue
        key = cry_key(species)
        if not key or not (fallback_cry_dir / f"{key}.ogg").is_file():
            continue
        canonical = str(species.get("species_id", "")) == str(species.get("showdown_id", ""))
        candidates[dex_number].append((0 if canonical else 1, key))

    return {
        dex_number: sorted(options)[0][1]
        for dex_number, options in candidates.items()
    }


def main() -> None:
    args = parse_args()
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("ffmpeg is required to convert anime cries")

    source_files = indexed_source_files(args.source_root)
    species_by_dex = indexed_species(args.species_dir, args.fallback_cry_dir)
    args.output_dir.mkdir(parents=True, exist_ok=True)

    converted = 0
    for dex_number, source in sorted(source_files.items()):
        key = species_by_dex.get(dex_number)
        if key is None:
            continue
        destination = args.output_dir / f"{key}.ogg"
        if destination.exists():
            raise SystemExit(f"Refusing to overwrite existing asset: {destination}")
        subprocess.run(
            [ffmpeg, "-v", "error", "-i", str(source), "-c:a", "libvorbis", "-q:a", "4", str(destination)],
            check=True,
        )
        converted += 1

    print(f"Converted {converted} anime cries into {args.output_dir}")


if __name__ == "__main__":
    main()
