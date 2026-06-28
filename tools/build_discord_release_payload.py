#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


EMBED_COLOR = 5814783
FIELD_LIMIT = 1024


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build a Discord release announcement payload from CHANGELOG.md."
    )
    parser.add_argument("--version", required=True, help="Release version, for example 0.2.1.")
    parser.add_argument(
        "--release-notes",
        default="",
        help="Optional intro text shown before the changelog fields.",
    )
    parser.add_argument(
        "--changelog",
        default="CHANGELOG.md",
        help="Path to the changelog file.",
    )
    args = parser.parse_args()

    version = args.version.strip()
    if not version:
        raise SystemExit("--version is required")

    changelog_path = Path(args.changelog)
    sections = _parse_changelog_section(changelog_path, version)
    fields = _build_fields(sections)
    description = args.release_notes.strip() or "Open de launcher om de nieuwste build te downloaden."

    payload = {
        "username": "PokeAether",
        "content": "",
        "allowed_mentions": {"parse": []},
        "embeds": [
            {
                "title": f"PokeAether {version} is live",
                "description": description[:4096],
                "color": EMBED_COLOR,
                "fields": fields[:25],
            }
        ],
    }

    print(json.dumps(payload))


def _parse_changelog_section(changelog_path: Path, version: str) -> dict[str, list[str]]:
    if not changelog_path.is_file():
        return {}

    lines = changelog_path.read_text(encoding="utf-8").splitlines()
    release_header_pattern = re.compile(rf"^##\s+{re.escape(version)}(?:\s+-\s+.*)?$")
    sections: dict[str, list[str]] = {}
    in_release = False
    current_section = ""

    for line in lines:
        if line.startswith("## "):
            if in_release:
                break
            in_release = release_header_pattern.match(line.strip()) is not None
            continue

        if not in_release:
            continue

        stripped = line.strip()
        heading_match = re.match(r"^\*\*(.+?)\*\*$", stripped)
        if heading_match:
            current_section = heading_match.group(1).strip()
            sections.setdefault(current_section, [])
            continue

        if stripped.startswith("- ") and current_section:
            sections[current_section].append(stripped)

    return sections


def _build_fields(sections: dict[str, list[str]]) -> list[dict[str, object]]:
    fields: list[dict[str, object]] = []
    for section_name in ("Added", "Fixed", "Changed"):
        entries = sections.get(section_name, [])
        if not entries:
            continue

        chunks = _chunk_lines(entries, FIELD_LIMIT)
        for index, chunk in enumerate(chunks):
            name = section_name if index == 0 else f"{section_name} continued"
            fields.append({"name": name, "value": "\n".join(chunk), "inline": False})

    if not fields:
        fields.append({
            "name": "Release notes",
            "value": "Open de launcher om de nieuwste build te downloaden.",
            "inline": False,
        })
    return fields


def _chunk_lines(lines: list[str], limit: int) -> list[list[str]]:
    chunks: list[list[str]] = []
    current: list[str] = []
    current_length = 0

    for line in lines:
        normalized = line if len(line) <= limit else f"{line[:limit - 3]}..."
        added_length = len(normalized) + (1 if current else 0)
        if current and current_length + added_length > limit:
            chunks.append(current)
            current = []
            current_length = 0

        current.append(normalized)
        current_length += len(normalized) + (1 if current_length else 0)

    if current:
        chunks.append(current)
    return chunks


if __name__ == "__main__":
    main()
