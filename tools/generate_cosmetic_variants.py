#!/usr/bin/env python3
"""Generate gender-adaptive cosmetic rendering data from the backend catalog."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "data/cosmetic_variants.json"
SLOTS = {"hair", "headgear", "cape", "facial_hair", "facegear", "top", "bottom", "shoes"}


def build_catalog(items_dir: Path) -> dict:
    items = {}
    for path in sorted(items_dir.glob("*.json")):
        for item_id, item in json.loads(path.read_text()).items():
            if isinstance(item, dict) and item.get("category") == "cosmetics":
                items[item_id] = item
    parts = {}
    adaptive_items = set()
    battle = json.loads((ROOT / "assets/battles/trainers/player/manifest.json").read_text())
    for item_id, item in items.items():
        if item.get("data", {}).get("legacy_alias_of"):
            continue
        for unlock in item.get("data", {}).get("appearance_unlocks", []):
            variants = unlock.get("render_variants")
            if variants is None:
                continue
            slot, part_id = unlock.get("slot"), unlock.get("appearance_id")
            genders = unlock.get("genders", [])
            if slot not in SLOTS or not isinstance(part_id, str) or len(part_id) > 64 or not re.fullmatch(r"[A-Za-z0-9_]+", part_id):
                raise ValueError(f"{item_id}: invalid logical appearance")
            if not isinstance(genders, list) or not isinstance(variants, dict) or not variants or set(variants) != set(genders) or not set(genders) <= {"male", "female"}:
                raise ValueError(f"{item_id}: render_variants must cover exactly its unlock genders")
            if not isinstance(item.get("genders"), list) or not set(genders) <= set(item["genders"]):
                raise ValueError(f"{item_id}: item genders do not cover its variants")
            tint = unlock.get("tint")
            if tint and (slot not in {"hair", "facial_hair", "facegear", "top", "bottom", "shoes"} or tint != slot + "_color"):
                raise ValueError(f"{item_id}: invalid tint field for {slot}")
            battle_rendering = unlock.get("battle_rendering", "authored")
            if battle_rendering not in {"authored", "fallback"}:
                raise ValueError(f"{item_id}: invalid battle_rendering policy")
            for gender, sprite_id in variants.items():
                if not isinstance(sprite_id, str) or not re.fullmatch(r"[A-Za-z0-9_]+", sprite_id):
                    raise ValueError(f"{item_id}: invalid sprite ID")
                if not (ROOT / f"assets/player/{gender}/{slot}/{sprite_id}.png").is_file():
                    raise ValueError(f"{item_id}: missing {gender} overworld art")
                art = battle["genders"][gender]["categories"].get(slot, {}).get("parts", {}).get(sprite_id, {})
                # Overworld-only collections can explicitly retain the game's
                # normal portrait fallback; missing authored art still fails by default.
                if battle_rendering == "fallback" and not art:
                    continue
                if not art or not (ROOT / art["path"].removeprefix("res://")).is_file():
                    raise ValueError(f"{item_id}: missing {gender} battle art")
            definition = {"render_variants": variants, "item_id": item_id}
            if unlock.get("tint"):
                definition["tint"] = unlock["tint"]
            entries = parts.setdefault(slot, {})
            if part_id in entries:
                raise ValueError(f"Duplicate logical appearance: {slot}:{part_id}")
            for other_id, other in entries.items():
                for gender, sprite in variants.items():
                    if other["render_variants"].get(gender) == sprite:
                        raise ValueError(f"Ambiguous sprite: {slot}:{gender}:{sprite}")
            entries[part_id] = definition
            adaptive_items.add(item_id)

    def layers_for(item_id, ancestors=()):
        if item_id in ancestors or item_id not in items:
            raise ValueError(f"Invalid cosmetic bundle reference: {item_id}")
        data = items[item_id].get("data", {})
        if data.get("use_action") == "open_item_bundle":
            return [layer for content in data["bundle_contents"]
                    for layer in layers_for(content["item_id"], (*ancestors, item_id))]
        return [{"category": u["slot"], "id": u["appearance_id"], "genders": u.get("genders", items[item_id].get("genders", []))}
                for u in data.get("appearance_unlocks", [])]

    icon_items = {}
    for item_id, item in items.items():
        data = item.get("data", {})
        if item_id in adaptive_items or data.get("legacy_alias_of") in adaptive_items or (
            data.get("use_action") == "open_item_bundle"
            and any(content["item_id"] in adaptive_items for content in data["bundle_contents"])
        ):
            layers = layers_for(item_id)
            icon_items[item_id] = {"genders": item.get("genders", []), "bundle": data.get("use_action") == "open_item_bundle", "layers": layers}
            for content in data.get("bundle_contents", []):
                child_id = content["item_id"]
                child = items[child_id]
                icon_items[child_id] = {"genders": child.get("genders", []), "bundle": False, "layers": layers_for(child_id)}
    return {"version": 1, "parts": parts, "items": icon_items}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("items_dir", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    rendered = json.dumps(build_catalog(args.items_dir), indent=2, sort_keys=True) + "\n"
    if args.check:
        if not OUTPUT.is_file() or OUTPUT.read_text() != rendered:
            raise SystemExit("Cosmetic variant catalog is stale; regenerate it.")
        print("Cosmetic variant catalog and referenced art verified.")
    else:
        OUTPUT.write_text(rendered)
        print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
