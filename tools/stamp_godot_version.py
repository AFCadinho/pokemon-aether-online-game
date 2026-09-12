#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Stamp a Godot project/export preset with a release version.")
    parser.add_argument("--project", required=True, type=Path, help="Path to project.godot.")
    parser.add_argument("--version", required=True, help="Version value to write.")
    parser.add_argument(
        "--build-id",
        help="Optional immutable client build identifier to write to application/config/build_id.",
    )
    parser.add_argument(
        "--web-build-id",
        help="Optional immutable browser build identifier to write to application/config/web_build_id.",
    )
    parser.add_argument("--export-presets", type=Path, help="Optional path to export_presets.cfg.")
    args = parser.parse_args()

    project_path = args.project
    if not project_path.is_file():
        raise SystemExit(f"Missing project file: {project_path}")

    _replace_or_insert_project_setting(
        project_path,
        "application",
        "config/version",
        _quote(args.version),
    )
    if args.build_id is not None:
        _replace_or_insert_project_setting(
            project_path,
            "application",
            "config/build_id",
            _quote(args.build_id),
        )
    if args.web_build_id is not None:
        _replace_or_insert_project_setting(
            project_path,
            "application",
            "config/web_build_id",
            _quote(args.web_build_id),
        )

    if args.export_presets is not None:
        export_presets_path = args.export_presets
        if not export_presets_path.is_file():
            raise SystemExit(f"Missing export presets file: {export_presets_path}")

        _replace_setting(export_presets_path, "application/file_version", _quote(args.version))
        _replace_setting(export_presets_path, "application/product_version", _quote(args.version))


def _replace_or_insert_project_setting(path: Path, section_name: str, key: str, value: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    section_header = f"[{section_name}]"
    section_index = _find_line(lines, section_header)
    if section_index < 0:
        lines.append("")
        lines.append(section_header)
        lines.append(f"{key}={value}")
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return

    next_section_index = len(lines)
    for index in range(section_index + 1, len(lines)):
        if lines[index].startswith("[") and lines[index].endswith("]"):
            next_section_index = index
            break

    for index in range(section_index + 1, next_section_index):
        if lines[index].startswith(f"{key}="):
            lines[index] = f"{key}={value}"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            return

    lines.insert(section_index + 1, f"{key}={value}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _replace_setting(path: Path, key: str, value: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        if line.startswith(f"{key}="):
            lines[index] = f"{key}={value}"
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            return

    lines.append(f"{key}={value}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _find_line(lines: list[str], value: str) -> int:
    for index, line in enumerate(lines):
        if line == value:
            return index

    return -1


def _quote(value: str) -> str:
    escaped_value = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped_value}"'


if __name__ == "__main__":
    main()
