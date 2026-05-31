#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
  parser = argparse.ArgumentParser(
    description=(
      "Apply manual Showdown ID overrides to species JSON files so form "
      "species use canonical battle payload IDs."
    )
  )
  parser.add_argument(
    "--override-file",
    default="data/pokemon/showdown_id_overrides.json",
    help="Path to the mapping file."
  )
  parser.add_argument(
    "--species-dir",
    default="data/pokemon/species",
    help="Directory containing species JSON files."
  )
  parser.add_argument(
    "--dry-run",
    action="store_true",
    help="Report changes without writing files."
  )
  args = parser.parse_args()

  override_path = Path(args.override_file)
  species_dir = Path(args.species_dir)

  if not override_path.exists():
    raise SystemExit(f"Override file not found: {override_path}")

  overrides = json.loads(override_path.read_text(encoding="utf-8"))
  if not isinstance(overrides, dict):
    raise SystemExit("Override file must be a JSON object mapping species_id -> showdown_id")

  changed = []
  for file_path in sorted(species_dir.glob("*.json")):
    data = json.loads(file_path.read_text(encoding="utf-8"))
    species_id = data.get("species_id")
    if species_id not in overrides:
      continue

    mapped = str(overrides[species_id])
    if data.get("showdown_id") == mapped:
      continue

    if args.dry_run:
      changed.append((species_id, data.get("showdown_id"), mapped, None))
      continue

    old = data["showdown_id"]
    data["showdown_id"] = mapped
    file_path.write_text(
      json.dumps(data, ensure_ascii=False, indent=2) + "\n",
      encoding="utf-8",
    )
    changed.append((species_id, old, mapped, str(file_path)))

  if not changed:
    print("No changes required.")
    return 0

  for species_id, old, new, path in changed:
    if path is None:
      print(f"{species_id}: {old} -> {new} (dry run)")
    else:
      print(f"{species_id}: {old} -> {new} [{path}]")

  return 0


if __name__ == "__main__":
  raise SystemExit(main())
