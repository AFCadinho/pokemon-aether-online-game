#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


def normalize_key(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def title_name(value: str) -> str:
    return "-".join(part[:1].upper() + part[1:] for part in value.split("-"))


def generation_from_pokedex_id(pokedex_id: int) -> int | None:
    if pokedex_id <= 151:
        return 1
    if pokedex_id <= 251:
        return 2
    if pokedex_id <= 386:
        return 3
    if pokedex_id <= 493:
        return 4
    if pokedex_id <= 649:
        return 5
    if pokedex_id <= 721:
        return 6
    if pokedex_id <= 809:
        return 7
    if pokedex_id <= 905:
        return 8
    # 9e generatie (tot nu toe 1025 in onze huidige data; inclusief nieuwe species-id-extensies).
    if pokedex_id <= 1025:
        return 9
    return None


def read_species(species_dir: Path):
    species = {}
    for path in sorted(species_dir.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        species_id = str(data.get("species_id", "")).lower()
        if not species_id:
            continue
        species[species_id] = data
    return species


def base_species_id(species_id: str, species_map: dict[str, dict]) -> str:
    # Try collapsing trailing form suffixes by matching an existing species file.
    current = species_id
    while "-" in current:
        prefix = current.rsplit("-", 1)[0]
        if not prefix:
            break
        if prefix in species_map:
            return prefix
        current = prefix
    return species_id


def sprite_exists(pokemon_home: set[str], candidates: list[str]) -> bool:
    for candidate in candidates:
        if not candidate:
            continue
        if normalize_key(candidate) in pokemon_home:
            return True
    return False


def build_pokemon_home_index(folder: Path) -> set[str]:
    return {
        normalize_key(path.stem)
        for path in folder.glob("*.png")
        if path.is_file()
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check home sprites coverage by generation using base species."
    )
    parser.add_argument("--species-dir", type=Path, default=Path("data/pokemon/species"))
    parser.add_argument("--home-dir", type=Path, default=Path("assets/sprites/pokemon/pokemon_home"))
    parser.add_argument("--start-generation", type=int, default=2)
    parser.add_argument("--end-generation", type=int, default=9)
    args = parser.parse_args()

    species_map = read_species(args.species_dir)
    home_index = build_pokemon_home_index(args.home_dir)

    missing_by_gen = defaultdict(list)
    present_by_gen = defaultdict(int)
    total_by_gen = defaultdict(int)

    for species_id, data in sorted(species_map.items(), key=lambda item: item[1].get("id", 0)):
        pokedex_id = int(data["id"])
        base_id = base_species_id(species_id, species_map)
        base_data = species_map.get(base_id)
        base_gen = generation_from_pokedex_id(int(base_data.get("id", pokedex_id))) if base_data else None
        if base_gen is None:
            base_gen = generation_from_pokedex_id(pokedex_id)

        if base_gen is None or base_gen < args.start_generation or base_gen > args.end_generation:
            continue

        if base_data is not None:
            base_gen = generation_from_pokedex_id(int(base_data.get("id", pokedex_id))) or base_gen

        candidates = [
            species_id,
            data.get("showdown_id", ""),
            data.get("name", ""),
            title_name(species_id),
            title_name(data.get("showdown_id", "")),
        ]
        if not sprite_exists(home_index, candidates):
            missing_by_gen[base_gen].append((pokedex_id, species_id, base_id))
        else:
            present_by_gen[base_gen] += 1

        total_by_gen[base_gen] += 1

    print("HOME SPRITE COVERAGE BY GENERATION (base species)")
    print(f"start-generation: {args.start_generation}")
    print(f"end-generation: {args.end_generation}")
    print()

    for gen in range(args.start_generation, args.end_generation + 1):
        missing = missing_by_gen[gen]
        total = total_by_gen[gen]
        present = present_by_gen[gen]
        pct = (present / total * 100.0) if total else 0.0
        print(
            f"Gen {gen}: present {present}/{total} "
            f"(missing {len(missing)}) [{pct:.1f}%]"
        )
        if missing:
            missing_ids = ", ".join(sid for _, sid, _ in missing)
            if len(missing_ids) > 240:
                missing_ids = missing_ids[:240] + "..."
            print(f"  missings: {missing_ids}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
