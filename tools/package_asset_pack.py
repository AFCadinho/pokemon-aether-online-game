#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description="Package one or more project folders as a launcher asset pack.")
    parser.add_argument("output_zip", help="Path to the generated asset pack zip.")
    parser.add_argument(
        "paths",
        nargs="+",
        help="Project-relative folders/files to include. Paths are preserved inside the zip.",
    )
    args = parser.parse_args()

    output_zip = Path(args.output_zip)
    if not output_zip.is_absolute():
        output_zip = PROJECT_ROOT / output_zip
    output_zip.parent.mkdir(parents=True, exist_ok=True)

    source_paths: list[Path] = []
    for path_text in args.paths:
        source_path = Path(path_text)
        if not source_path.is_absolute():
            source_path = PROJECT_ROOT / source_path
        if not source_path.exists():
            raise SystemExit(f"Missing asset pack source path: {source_path}")
        source_paths.append(source_path)

    _zip_paths(source_paths, output_zip)
    print(f"Wrote {_display_path(output_zip)}")


def _zip_paths(source_paths: list[Path], output_zip: Path) -> None:
    if output_zip.exists():
        output_zip.unlink()

    with ZipFile(output_zip, "w", ZIP_DEFLATED) as archive:
        for source_path in source_paths:
            if source_path.is_dir():
                for file_path in sorted(source_path.rglob("*")):
                    if file_path.is_file():
                        _write_file(archive, file_path)
            elif source_path.is_file():
                _write_file(archive, source_path)


def _write_file(archive: ZipFile, file_path: Path) -> None:
    relative_path = file_path.relative_to(PROJECT_ROOT).as_posix()
    info = ZipInfo.from_file(file_path, relative_path)
    info.compress_type = ZIP_DEFLATED
    info.external_attr = (file_path.stat().st_mode & 0xFFFF) << 16
    with file_path.open("rb") as file:
        archive.writestr(info, file.read())


def _display_path(file_path: Path) -> str:
    try:
        return str(file_path.relative_to(PROJECT_ROOT))
    except ValueError:
        return str(file_path)


if __name__ == "__main__":
    main()
