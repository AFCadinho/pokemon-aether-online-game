#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


def main() -> None:
    parser = argparse.ArgumentParser(description="Package a directory as a zip while preserving file modes.")
    parser.add_argument("source_dir", help="Directory to package.")
    parser.add_argument("output_zip", help="Zip file to write.")
    args = parser.parse_args()

    source_dir = Path(args.source_dir).resolve()
    output_zip = Path(args.output_zip).resolve()
    if not source_dir.is_dir():
        raise SystemExit(f"Missing source directory: {source_dir}")

    output_zip.parent.mkdir(parents=True, exist_ok=True)
    if output_zip.exists():
        output_zip.unlink()

    with ZipFile(output_zip, "w", ZIP_DEFLATED) as archive:
        for file_path in sorted(source_dir.rglob("*")):
            if file_path.is_dir():
                continue

            relative_path = file_path.relative_to(source_dir).as_posix()
            info = ZipInfo.from_file(file_path, relative_path)
            info.compress_type = ZIP_DEFLATED
            info.external_attr = (file_path.stat().st_mode & 0xFFFF) << 16
            with file_path.open("rb") as file:
                archive.writestr(info, file.read())

    print(f"Wrote {output_zip}")


if __name__ == "__main__":
    main()
