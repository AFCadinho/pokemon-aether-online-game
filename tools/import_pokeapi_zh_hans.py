#!/usr/bin/env python3

"""Import verified Simplified Chinese Pokémon presentation from PokéAPI."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parent.parent
LANGUAGE_ID = "12"
SOURCE_REVISION = "c40a25c6544b97334a1ae8b1965a378fa3317c28"
EXPECTED_SHA256 = {
    "languages.csv": "fbb60019a6a461783d5671a995d5f590db61792a273e90faa0ed630d102a19b8",
    "moves.csv": "8aafd37bf78f19471495c05b201545180f50f0a08a2a2a844d69f9837dd39ac9",
    "move_names.csv": "99e23ee38ea53d1473474d463b87651deac3cd4928750f8186feae66da45c147",
    "abilities.csv": "4ef866a51da6230bcaad44104cce5c890aeeb9e0d2b5661923e8e1dbd414a12c",
    "ability_names.csv": "c451c060b5075664426fb2b79517f8b1d946d2eb47d6c9d1cd16e3e9e6a7c302",
    "items.csv": "f08cd6dc30b447cb91cbe9232c79052e8521f32f6105bb1489b5bfabf4ca3241",
    "item_names.csv": "7b1b4fe6edf7946110050a5dddabf62c3a1dc3e1616099c4ae97abcb5ebd0f97",
    "move_flavor_text.csv": "43177df8d76dac477fc837aa19b2a50d74ee2c94e47fb827506768c58b360087",
    "ability_flavor_text.csv": "2e9111602ae83744e53a1ea3cfd521548673660e0e271bbd25ff2fe3454d0ef9",
    "item_flavor_text.csv": "f85281c97e4a423fb6ae673a3d2cfab116ac2e7bb9fcdecfb43ac8b1e1fb8676",
}
REVIEWED_DESCRIPTION_OVERRIDES = {
    "moves": {
        "armor-cannon": "熊熊燃烧自己的铠甲，将其做成炮弹射出攻击。自己的防御和特防会降低。",
        "bitter-blade": "将对世间的留恋聚集于剑尖，并斩击对手。可以回复给予对手伤害的一半HP。",
        "hidden-power": "威力固定为 60。属性取决于使用该招式的宝可梦。",
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Replace machine-translated Pokémon presentation with verified zh-hans "
            f"values from PokéAPI revision {SOURCE_REVISION}."
        )
    )
    parser.add_argument(
        "--csv-dir",
        type=Path,
        required=True,
        help="Directory containing the pinned PokéAPI data/v2/csv files.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify that catalogs already match the import without writing files.",
    )
    return parser.parse_args()


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def serialized_json(value: dict[str, Any]) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def verify_snapshot(csv_dir: Path) -> None:
    for file_name, expected_digest in EXPECTED_SHA256.items():
        path = csv_dir / file_name
        if not path.is_file():
            raise FileNotFoundError(f"Missing PokéAPI snapshot file: {path}")
        actual_digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual_digest != expected_digest:
            raise ValueError(
                f"PokéAPI snapshot mismatch for {file_name}: "
                f"expected {expected_digest}, got {actual_digest}"
            )

    with (csv_dir / "languages.csv").open(encoding="utf-8", newline="") as handle:
        language = next(
            (row for row in csv.DictReader(handle) if row.get("id") == LANGUAGE_ID),
            None,
        )
    if language is None or language.get("identifier") != "zh-hans" or language.get("official") != "1":
        raise ValueError("PokéAPI language ID 12 is not the official zh-hans locale")


def localized_names(csv_dir: Path, plural: str, singular: str) -> dict[str, str]:
    with (csv_dir / f"{plural}.csv").open(encoding="utf-8", newline="") as handle:
        identifiers = {
            row["id"]: row["identifier"]
            for row in csv.DictReader(handle)
        }

    result: dict[str, str] = {}
    with (csv_dir / f"{singular}_names.csv").open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            source_id = row.get(f"{singular}_id", "")
            name = row.get("name", "").strip()
            if row.get("local_language_id") == LANGUAGE_ID and source_id in identifiers and name:
                result[identifiers[source_id]] = name
    return result


def normalized_flavor_text(value: str) -> str:
    return value.replace("\u00ad", "").replace("\r", "").replace("\n", "").strip()


def localized_flavor_texts(csv_dir: Path, plural: str, singular: str) -> dict[str, str]:
    with (csv_dir / f"{plural}.csv").open(encoding="utf-8", newline="") as handle:
        identifiers = {
            row["id"]: row["identifier"]
            for row in csv.DictReader(handle)
        }

    selected: dict[str, tuple[int, str]] = {}
    path = csv_dir / f"{singular}_flavor_text.csv"
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            source_id = row.get(f"{singular}_id", "")
            text = normalized_flavor_text(row.get("flavor_text", ""))
            if row.get("language_id") != LANGUAGE_ID or source_id not in identifiers or not text:
                continue
            if singular == "move" and "无法使用这个招式" in text:
                continue
            version_group_id = int(row.get("version_group_id", "0"))
            identifier = identifiers[source_id]
            if version_group_id >= selected.get(identifier, (-1, ""))[0]:
                selected[identifier] = (version_group_id, text)
    return {identifier: value[1] for identifier, value in selected.items()}


def replace_names(
    target: dict[str, Any],
    english: dict[str, Any],
    verified: dict[str, str],
) -> tuple[int, int]:
    verified_count = 0
    fallback_count = 0
    if set(target) != set(english):
        raise ValueError("Target and English catalogs do not contain the same IDs")
    for content_id, target_entry_value in target.items():
        english_entry_value = english[content_id]
        if not isinstance(target_entry_value, dict) or not isinstance(english_entry_value, dict):
            raise ValueError(f"Invalid presentation entry: {content_id}")
        english_name = str(english_entry_value.get("name", "")).strip()
        if not english_name:
            raise ValueError(f"English presentation name is empty: {content_id}")
        if content_id in verified:
            target_entry_value["name"] = verified[content_id]
            verified_count += 1
        else:
            target_entry_value["name"] = english_name
            fallback_count += 1
    return verified_count, fallback_count


def replace_overlay_names(
    target: dict[str, Any],
    english: dict[str, Any],
    verified: dict[str, str],
) -> None:
    for content_id, entry_value in target.items():
        if content_id not in english or not isinstance(entry_value, dict):
            continue
        if content_id in verified:
            entry_value["name"] = verified[content_id]


def replace_descriptions(
    target: dict[str, Any],
    english: dict[str, Any],
    verified: dict[str, str],
) -> tuple[int, int]:
    verified_count = 0
    fallback_count = 0
    if set(target) != set(english):
        raise ValueError("Target and English catalogs do not contain the same IDs")
    for content_id, target_entry_value in target.items():
        english_entry_value = english[content_id]
        if not isinstance(target_entry_value, dict) or not isinstance(english_entry_value, dict):
            raise ValueError(f"Invalid presentation entry: {content_id}")
        english_description = str(english_entry_value.get("shortDesc", "")).strip()
        if not english_description:
            target_entry_value.pop("shortDesc", None)
            continue
        if content_id in verified:
            target_entry_value["shortDesc"] = verified[content_id]
            verified_count += 1
        else:
            target_entry_value["shortDesc"] = english_description
            fallback_count += 1
    return verified_count, fallback_count


def replace_overlay_descriptions(
    target: dict[str, Any],
    verified: dict[str, str],
) -> None:
    for content_id, entry_value in target.items():
        if content_id in verified and isinstance(entry_value, dict) and "shortDesc" in entry_value:
            entry_value["shortDesc"] = verified[content_id]


def add_machine_item_names(
    item_names: dict[str, str],
    move_names: dict[str, str],
    english_items: dict[str, Any],
) -> None:
    prefixes = {
        "tm-": "招式学习器",
        "hm-": "秘传学习器",
    }
    for item_id in english_items:
        if item_id in item_names:
            continue
        for prefix, chinese_prefix in prefixes.items():
            if not item_id.startswith(prefix):
                continue
            move_id = item_id.removeprefix(prefix)
            if move_id in move_names:
                item_names[item_id] = f"{chinese_prefix}：{move_names[move_id]}"
            break


def add_machine_item_descriptions(
    item_descriptions: dict[str, str],
    move_names: dict[str, str],
    english_items: dict[str, Any],
) -> None:
    for item_id in english_items:
        if item_id in item_descriptions:
            continue
        for prefix in ("tm-", "hm-"):
            if not item_id.startswith(prefix):
                continue
            move_id = item_id.removeprefix(prefix)
            if move_id in move_names:
                item_descriptions[item_id] = f"让能够学习的宝可梦学会“{move_names[move_id]}”。"
            break


def stage_output(path: Path, value: dict[str, Any], check: bool) -> None:
    expected = serialized_json(value)
    if check:
        if path.read_text(encoding="utf-8") != expected:
            raise ValueError(f"Catalog is not synchronized with the verified import: {path}")
        return
    path.write_text(expected, encoding="utf-8")


def main() -> None:
    args = parse_args()
    csv_dir = args.csv_dir.resolve()
    verify_snapshot(csv_dir)

    generated_content_path = PROJECT_ROOT / "localization/content/generated/zh_CN.json"
    english_content_path = PROJECT_ROOT / "localization/content/generated/en.json"
    reviewed_content_path = PROJECT_ROOT / "localization/content/zh_CN.json"
    generated_items_path = PROJECT_ROOT / "localization/items/generated/zh_CN.json"
    english_items_path = PROJECT_ROOT / "localization/items/generated/en.json"
    reviewed_items_path = PROJECT_ROOT / "localization/items/zh_CN.json"

    generated_content = read_json(generated_content_path)
    english_content = read_json(english_content_path)
    reviewed_content = read_json(reviewed_content_path)
    generated_items = read_json(generated_items_path)
    english_items = read_json(english_items_path)
    reviewed_items = read_json(reviewed_items_path)

    name_coverage: dict[str, tuple[int, int]] = {}
    description_coverage: dict[str, tuple[int, int]] = {}
    verified_move_names = localized_names(csv_dir, "moves", "move")
    for kind, plural, singular in (
        ("moves", "moves", "move"),
        ("abilities", "abilities", "ability"),
    ):
        verified = verified_move_names if kind == "moves" else localized_names(csv_dir, plural, singular)
        target_entries = generated_content.get(kind)
        english_entries = english_content.get(kind)
        reviewed_entries = reviewed_content.get(kind)
        if not isinstance(target_entries, dict) or not isinstance(english_entries, dict):
            raise ValueError(f"Missing generated content section: {kind}")
        if not isinstance(reviewed_entries, dict):
            raise ValueError(f"Missing reviewed content section: {kind}")
        name_coverage[kind] = replace_names(target_entries, english_entries, verified)
        replace_overlay_names(reviewed_entries, english_entries, verified)
        verified_descriptions = localized_flavor_texts(csv_dir, plural, singular)
        verified_descriptions.update(REVIEWED_DESCRIPTION_OVERRIDES.get(kind, {}))
        description_coverage[kind] = replace_descriptions(
            target_entries,
            english_entries,
            verified_descriptions,
        )
        replace_overlay_descriptions(reviewed_entries, verified_descriptions)

    verified_items = localized_names(csv_dir, "items", "item")
    add_machine_item_names(verified_items, verified_move_names, english_items)
    name_coverage["items"] = replace_names(generated_items, english_items, verified_items)
    replace_overlay_names(reviewed_items, english_items, verified_items)
    verified_item_descriptions = localized_flavor_texts(csv_dir, "items", "item")
    add_machine_item_descriptions(verified_item_descriptions, verified_move_names, english_items)
    description_coverage["items"] = replace_descriptions(
        generated_items,
        english_items,
        verified_item_descriptions,
    )
    replace_overlay_descriptions(reviewed_items, verified_item_descriptions)

    stage_output(generated_content_path, generated_content, args.check)
    stage_output(reviewed_content_path, reviewed_content, args.check)
    stage_output(generated_items_path, generated_items, args.check)
    stage_output(reviewed_items_path, reviewed_items, args.check)

    mode = "Verified" if args.check else "Imported"
    name_summary = " · ".join(
        f"{kind}: {verified_count} verified, {fallback_count} English fallback"
        for kind, (verified_count, fallback_count) in name_coverage.items()
    )
    description_summary = " · ".join(
        f"{kind}: {verified_count} verified, {fallback_count} English fallback"
        for kind, (verified_count, fallback_count) in description_coverage.items()
    )
    print(
        f"{mode} PokéAPI {SOURCE_REVISION} zh-hans presentation\n"
        f"Names · {name_summary}\n"
        f"Descriptions · {description_summary}"
    )


if __name__ == "__main__":
    main()
