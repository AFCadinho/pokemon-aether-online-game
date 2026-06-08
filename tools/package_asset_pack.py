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
        nargs="*",
        help="Project-relative folders/files to include. Paths are preserved inside the zip.",
    )
    parser.add_argument(
        "--map",
        dest="mapped_paths",
        action="append",
        default=[],
        metavar="SOURCE:ARCHIVE_PATH",
        help="Include SOURCE at ARCHIVE_PATH inside the zip. Useful for packaging external asset folders.",
    )
    args = parser.parse_args()

    if not args.paths and not args.mapped_paths:
        raise SystemExit("Provide at least one source path or --map SOURCE:ARCHIVE_PATH")

    output_zip = Path(args.output_zip)
    if not output_zip.is_absolute():
        output_zip = PROJECT_ROOT / output_zip
    output_zip.parent.mkdir(parents=True, exist_ok=True)

    source_paths: list[tuple[Path, Path | None]] = []
    for path_text in args.paths:
        source_path = Path(path_text)
        if not source_path.is_absolute():
            source_path = PROJECT_ROOT / source_path
        if not source_path.exists():
            raise SystemExit(f"Missing asset pack source path: {source_path}")
        source_paths.append((source_path, None))

    for mapped_path in args.mapped_paths:
        source_text, archive_text = _parse_mapped_path(mapped_path)
        source_path = Path(source_text)
        if not source_path.is_absolute():
            source_path = PROJECT_ROOT / source_path
        if not source_path.exists():
            raise SystemExit(f"Missing mapped asset pack source path: {source_path}")

        archive_root = Path(archive_text)
        _validate_archive_path(archive_root)
        source_paths.append((source_path, archive_root))

    _zip_paths(source_paths, output_zip)
    print(f"Wrote {_display_path(output_zip)}")


def _parse_mapped_path(mapped_path: str) -> tuple[str, str]:
    source_text, separator, archive_text = mapped_path.partition(":")
    if separator == "" or source_text.strip() == "" or archive_text.strip() == "":
        raise SystemExit(f"Invalid --map value: {mapped_path}. Expected SOURCE:ARCHIVE_PATH")

    return source_text, archive_text


def _validate_archive_path(archive_path: Path) -> None:
    if archive_path.is_absolute():
        raise SystemExit(f"Archive path must be relative: {archive_path}")

    if any(part == ".." for part in archive_path.parts):
        raise SystemExit(f"Archive path cannot contain '..': {archive_path}")


def _zip_paths(source_paths: list[tuple[Path, Path | None]], output_zip: Path) -> None:
    if output_zip.exists():
        output_zip.unlink()

    with ZipFile(output_zip, "w", ZIP_DEFLATED) as archive:
        for source_path, archive_root in source_paths:
            if source_path.is_dir():
                for file_path in sorted(source_path.rglob("*")):
                    if file_path.is_file():
                        archive_path = _get_archive_path(source_path, file_path, archive_root)
                        _write_file(archive, file_path, archive_path)
            elif source_path.is_file():
                archive_path = archive_root
                if archive_path is None:
                    archive_path = source_path.relative_to(PROJECT_ROOT)
                _write_file(archive, source_path, archive_path)


def _get_archive_path(source_root: Path, file_path: Path, archive_root: Path | None) -> Path:
    if archive_root is None:
        return file_path.relative_to(PROJECT_ROOT)

    return archive_root / file_path.relative_to(source_root)


def _write_file(archive: ZipFile, file_path: Path, archive_path: Path) -> None:
    _validate_archive_path(archive_path)
    archive.write(file_path, archive_path.as_posix(), ZIP_DEFLATED)


def _display_path(file_path: Path) -> str:
    try:
        return str(file_path.relative_to(PROJECT_ROOT))
    except ValueError:
        return str(file_path)


if __name__ == "__main__":
    main()
