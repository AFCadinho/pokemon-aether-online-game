#!/usr/bin/env python3
"""Safely extract browser-readable Gen 5 sheets from an existing asset-pack zip."""
from __future__ import annotations

import argparse
from pathlib import Path, PurePosixPath
import shutil
import zipfile


SIDES = ("front", "back", "shiny_front", "shiny_back")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--side", choices=SIDES, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    prefix = PurePosixPath(f"assets/sprites/pokemon/gen5/{args.side}")
    output = args.output.resolve()
    shutil.rmtree(output, ignore_errors=True)
    output.mkdir(parents=True)
    extracted = 0
    with zipfile.ZipFile(args.archive) as archive:
        for info in archive.infolist():
            name = PurePosixPath(info.filename)
            if info.is_dir() or not name.is_relative_to(prefix):
                continue
            relative = name.relative_to(prefix)
            if len(relative.parts) != 2 or relative.name not in {"animation.json", "sheet.png"}:
                continue
            if any(part in {"", ".", ".."} for part in relative.parts):
                raise SystemExit(f"Unsafe archive member: {info.filename}")
            target = output.joinpath(*relative.parts)
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(info) as source, target.open("wb") as destination:
                shutil.copyfileobj(source, destination)
            extracted += 1
    if extracted == 0 or not (output / "pikachu/animation.json").is_file() or not (output / "pikachu/sheet.png").is_file():
        raise SystemExit(f"Archive has no complete {args.side} browser sprite catalog")
    print(f"Extracted {extracted} browser sprite files for {args.side}")


if __name__ == "__main__":
    main()
