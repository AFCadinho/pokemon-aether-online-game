#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


EMBED_COLOR = 5814783
DESCRIPTION_LIMIT = 4096
EMBED_LIMIT = 6000
FIELD_COUNT_LIMIT = 25
FIELD_NAME_LIMIT = 256
FIELD_LIMIT = 1024
TITLE_LIMIT = 256


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
    if not any(sections.values()):
        raise SystemExit(f"No release notes found for version {version} in {changelog_path}.")
    fields = _build_fields(sections)
    description = args.release_notes.strip() or "Open the launcher to download the latest build."
    payloads = _build_payloads(version, description[:DESCRIPTION_LIMIT], fields)
    _validate_payloads(payloads)

    print(json.dumps({"payloads": payloads}))


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
        heading_match = re.match(r"^(?:###\s+(.+?)|\*\*(.+?)\*\*)$", stripped)
        if heading_match:
            current_section = next(group for group in heading_match.groups() if group).strip()
            sections.setdefault(current_section, [])
            continue

        if stripped.startswith("- "):
            # Release notes may be grouped under Added/Fixed/Changed, but
            # direct bullets under the version heading are valid too.
            section = current_section or "Release notes"
            sections.setdefault(section, []).append(stripped)

    return sections


def _build_fields(sections: dict[str, list[str]]) -> list[dict[str, object]]:
    fields: list[dict[str, object]] = []
    for section_name, entries in sections.items():
        if not entries:
            continue

        chunks = _chunk_lines(entries, FIELD_LIMIT)
        for index, chunk in enumerate(chunks):
            name = section_name if index == 0 else f"{section_name} continued"
            fields.append(
                {
                    "name": _truncate(name, FIELD_NAME_LIMIT),
                    "value": "\n".join(chunk),
                    "inline": False,
                }
            )

    return fields


def _build_payloads(
    version: str, description: str, fields: list[dict[str, object]]
) -> list[dict[str, object]]:
    payload_fields: list[list[dict[str, object]]] = []
    remaining = list(fields)

    while remaining:
        part_index = len(payload_fields)
        # Reserve enough title space for the final part counter before packing.
        title = _payload_title(version, part_index, 999999)
        part_description = description if part_index == 0 else ""
        used = len(title) + len(part_description)
        current: list[dict[str, object]] = []

        while remaining and len(current) < FIELD_COUNT_LIMIT:
            field = remaining[0]
            field_size = len(str(field["name"])) + len(str(field["value"]))
            if current and used + field_size > EMBED_LIMIT:
                break
            if used + field_size > EMBED_LIMIT:
                raise ValueError("A Discord field does not fit inside a single embed.")
            current.append(remaining.pop(0))
            used += field_size

        payload_fields.append(current)

    total_parts = len(payload_fields)
    payloads: list[dict[str, object]] = []
    for index, part_fields in enumerate(payload_fields):
        title = _payload_title(version, index, total_parts)
        embed: dict[str, object] = {
            "title": title,
            "color": EMBED_COLOR,
            "fields": part_fields,
        }
        if index == 0:
            embed["description"] = description
        payloads.append(
            {
                "username": "PokeAether",
                "content": "",
                "allowed_mentions": {"parse": []},
                "embeds": [embed],
            }
        )

    return payloads


def _payload_title(version: str, index: int, total_parts: int | None = None) -> str:
    title = f"PokeAether {version} is live"
    if index:
        title = f"PokeAether {version} release notes continued"
    if total_parts and total_parts > 1:
        title = f"{title} ({index + 1}/{total_parts})"
    return _truncate(title, TITLE_LIMIT)


def _validate_payloads(payloads: list[dict[str, object]]) -> None:
    if not payloads:
        raise ValueError("Discord release payload contains no messages.")

    for payload in payloads:
        embeds = payload.get("embeds")
        if not isinstance(embeds, list) or len(embeds) != 1:
            raise ValueError("Each Discord message must contain exactly one embed.")
        embed = embeds[0]
        fields = embed.get("fields")
        if not isinstance(fields, list) or not fields:
            raise ValueError("Discord release payload contains no release-note fields.")
        if len(fields) > FIELD_COUNT_LIMIT:
            raise ValueError("Discord release payload exceeds the field count limit.")

        title = str(embed.get("title", ""))
        description = str(embed.get("description", ""))
        if len(title) > TITLE_LIMIT or len(description) > DESCRIPTION_LIMIT:
            raise ValueError("Discord release payload contains oversized embed text.")
        total_size = len(title) + len(description)
        for field in fields:
            name = str(field.get("name", ""))
            value = str(field.get("value", ""))
            if len(name) > FIELD_NAME_LIMIT or len(value) > FIELD_LIMIT:
                raise ValueError("Discord release payload contains an oversized field.")
            total_size += len(name) + len(value)
        if total_size > EMBED_LIMIT:
            raise ValueError("Discord release payload exceeds the embed size limit.")


def _chunk_lines(lines: list[str], limit: int) -> list[list[str]]:
    chunks: list[list[str]] = []
    current: list[str] = []
    current_length = 0

    expanded_lines: list[str] = []
    for line in lines:
        expanded_lines.extend(line[index : index + limit] for index in range(0, len(line), limit))

    for normalized in expanded_lines:
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


def _truncate(value: str, limit: int) -> str:
    if len(value) <= limit:
        return value
    return f"{value[:limit - 3]}..."


if __name__ == "__main__":
    main()
