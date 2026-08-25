#!/usr/bin/env python3
"""Audit the technical PokeAether localization release gates.

The normal invocation reports catalog integrity and remaining hardcoded
player-facing candidates. Pass --strict to return a non-zero exit status while any
candidate remains. Candidates require classification: the scanner deliberately
prefers false positives over silently missing player-facing English.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLIENT_CATALOGS = {
    "en": ROOT / "localization/en.json",
    "nl": ROOT / "localization/nl.json",
    "pt_BR": ROOT / "localization/pt_BR.json",
    "zh_CN": ROOT / "localization/zh_CN.json",
}
LAUNCHER_CATALOGS = {
    "en": ROOT / "launcher/localization/en.json",
    "nl": ROOT / "launcher/localization/nl.json",
    "pt_BR": ROOT / "launcher/localization/pt_BR.json",
    "zh_CN": ROOT / "launcher/localization/zh_CN.json",
}
PLACEHOLDER_PATTERN = re.compile(r"\{[A-Za-z0-9_]+\}")
SEMANTIC_KEY_PATTERN = re.compile(
    r"^(?:ui|common|battle|notification|error|backend|language)\.[A-Za-z0-9_.-]+$"
)
SCRIPT_ASSIGNMENT_PATTERN = re.compile(
    r"(?:\.text|\.tooltip_text|\.placeholder_text|\.title|dialog_text)"
    r'\s*=\s*"((?:[^"\\]|\\.)*[A-Za-z](?:[^"\\]|\\.)*)"'
)
PLAYER_MESSAGE_PATTERN = re.compile(
    r"(?:add_system_message|add_system_pokemon_message|show_status|show_error|"
    r"show_notification|show_message|_show_error|_show_status|_set_message)"
    r'\s*\(\s*"((?:[^"\\]|\\.)*[A-Za-z](?:[^"\\]|\\.)*)"'
)
CALL_GROUP_MESSAGE_PATTERN = re.compile(
    r'"add_system_(?:pokemon_)?message"\s*,\s*'
    r'"((?:[^"\\]|\\.)*[A-Za-z](?:[^"\\]|\\.)*)"'
)
SCENE_PROPERTY_PATTERN = re.compile(
    r'^(?:text|tooltip_text|placeholder_text|title|dialog_text)\s*=\s*'
    r'"((?:[^"\\]|\\.)*[A-Za-z](?:[^"\\]|\\.)*)"',
    re.MULTILINE,
)
NON_LINGUISTIC_VALUES = {
    "PokeAether",
    "Discord",
    "S",
    "Z",
    "X",
    "OK",
    "VS",
    "EXP",
    "XP",
    "PM",
    "HP",
    "ATK",
    "DEF",
    "SP. ATK",
    "SP. DEF",
    "#RRGGBB",
    "#rrggbb",
}
PREVIEW_SCENES = {
    "scenes/interface/party_slot.tscn",
    "scenes/battle/party_slot.tscn",
    "scenes/battle/pokemon_info_hud.tscn",
}


def load_catalogs(paths: dict[str, Path]) -> tuple[dict[str, dict], list[str]]:
    catalogs: dict[str, dict] = {}
    errors: list[str] = []
    for locale, path in paths.items():
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            errors.append(f"{path.relative_to(ROOT)}: {error}")
            value = {}
        if not isinstance(value, dict):
            errors.append(f"{path.relative_to(ROOT)} is not a JSON object")
            value = {}
        catalogs[locale] = value
    return catalogs, errors


def validate_catalogs(name: str, catalogs: dict[str, dict]) -> list[str]:
    errors: list[str] = []
    english = catalogs.get("en", {})
    english_keys = set(english)
    for locale, catalog in catalogs.items():
        keys = set(catalog)
        for key in sorted(english_keys - keys):
            errors.append(f"{name}:{locale} is missing {key}")
        for key in sorted(keys - english_keys):
            errors.append(f"{name}:{locale} has non-English extra key {key}")
        for key in sorted(english_keys & keys):
            expected = sorted(PLACEHOLDER_PATTERN.findall(str(english[key])))
            actual = sorted(PLACEHOLDER_PATTERN.findall(str(catalog[key])))
            if actual != expected:
                errors.append(
                    f"{name}:{locale}:{key} placeholders {actual} do not match {expected}"
                )
            if not str(catalog[key]).strip():
                errors.append(f"{name}:{locale}:{key} is empty")
    return errors


def is_candidate(value: str, launcher_english: dict) -> bool:
    decoded = bytes(value, "utf-8").decode("unicode_escape")
    stripped = decoded.strip()
    if not stripped or SEMANTIC_KEY_PATTERN.fullmatch(stripped):
        return False
    if stripped in NON_LINGUISTIC_VALUES:
        return False
    if stripped in launcher_english:
        return False
    if not re.search(r"[A-Za-z]{2,}", stripped):
        return False
    # Pure formatting shells without an English word carry no translatable content.
    without_formats = re.sub(r"%[-+0-9.*]*[a-zA-Z]", "", stripped)
    without_placeholders = PLACEHOLDER_PATTERN.sub("", without_formats)
    if not re.search(r"[A-Za-z]{2,}", without_placeholders):
        return False
    return True


def scan_candidates(launcher_english: dict) -> list[tuple[str, int, str]]:
    candidates: set[tuple[str, int, str]] = set()
    for script_root in (ROOT / "scripts",):
        for path in script_root.rglob("*.gd"):
            source = path.read_text(encoding="utf-8", errors="replace")
            for pattern in (
                SCRIPT_ASSIGNMENT_PATTERN,
                PLAYER_MESSAGE_PATTERN,
                CALL_GROUP_MESSAGE_PATTERN,
            ):
                for match in pattern.finditer(source):
                    value = match.group(1)
                    if is_candidate(value, launcher_english):
                        line = source.count("\n", 0, match.start()) + 1
                        candidates.add((str(path.relative_to(ROOT)), line, value))

    for path in (ROOT / "scenes").rglob("*.tscn"):
        relative = str(path.relative_to(ROOT))
        if relative in PREVIEW_SCENES:
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for match in SCENE_PROPERTY_PATTERN.finditer(source):
            value = match.group(1)
            if is_candidate(value, launcher_english):
                line = source.count("\n", 0, match.start()) + 1
                candidates.add((relative, line, value))
    return sorted(candidates)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--strict",
        action="store_true",
        help="fail while hardcoded player-facing candidates remain",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=40,
        help="maximum candidate rows to print (default: 40; 0 prints all)",
    )
    args = parser.parse_args()

    client_catalogs, errors = load_catalogs(CLIENT_CATALOGS)
    launcher_catalogs, launcher_errors = load_catalogs(LAUNCHER_CATALOGS)
    errors.extend(launcher_errors)
    errors.extend(validate_catalogs("client", client_catalogs))
    errors.extend(validate_catalogs("launcher", launcher_catalogs))

    candidates = scan_candidates(launcher_catalogs.get("en", {}))
    by_file = Counter(path for path, _line, _value in candidates)

    print("PokeAether localization release audit")
    print(f"Client catalog keys: {len(client_catalogs.get('en', {}))}")
    print(f"Launcher catalog keys: {len(launcher_catalogs.get('en', {}))}")
    print(f"Catalog errors: {len(errors)}")
    print(f"Hardcoded player-facing candidates: {len(candidates)}")
    if by_file:
        print("Largest candidate sources:")
        for path, count in by_file.most_common(12):
            print(f"  {count:3}  {path}")

    if errors:
        print("Catalog failures:")
        for error in errors:
            print(f"  - {error}")

    limit = len(candidates) if args.limit == 0 else max(args.limit, 0)
    if candidates and limit:
        print(f"Candidate sample ({min(limit, len(candidates))}/{len(candidates)}):")
        for path, line, value in candidates[:limit]:
            print(f"  - {path}:{line}: {value}")

    if errors:
        return 1
    if args.strict and candidates:
        print("STRICT RESULT: FAIL — remaining candidates must be migrated or explicitly classified.")
        return 1
    print("RESULT: PASS" if not candidates else "RESULT: CATALOGS PASS; COMPLETENESS GATE REMAINS OPEN")
    return 0


if __name__ == "__main__":
    sys.exit(main())
