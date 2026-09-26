#!/usr/bin/env python3
"""Package approved normal/shiny Mega Dragonite as its own local bundle."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from .package_optional_3d_bundle_prototype import build, encoded
except ImportError:
    from package_optional_3d_bundle_prototype import build, encoded


def read_base_index(base_index_path: Path) -> dict:
    base_index = json.loads(base_index_path.read_text())
    if (base_index.get("schema") != 1 or
            base_index.get("kind") != "pokeaether-optional-asset-index" or
            base_index.get("runtime_contract") != {"pokemon_3d": 1, "godot": "4.6"}):
        raise ValueError("incompatible base asset index")
    assets = base_index.get("assets")
    if not isinstance(assets, list):
        raise ValueError("base asset index has no assets")
    ids = {asset.get("asset_id") for asset in assets}
    if "pokemon_3d:dragonite:base" not in ids or "pokemon_3d:dragonite:mega" in ids:
        raise ValueError("base index must contain Dragonite base and no Mega bundle")
    return base_index


def combined_index(base_index: dict, mega_index: dict, output: Path) -> Path:
    merged = dict(base_index)
    merged["catalog_revision"] = mega_index["catalog_revision"]
    merged["assets"] = base_index["assets"] + mega_index["assets"]
    path = output / "combined-index.json"
    path.write_bytes(encoded(merged))
    return path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--revision", default="approved-mega-dragonite-v1")
    parser.add_argument("--base-index", required=True, type=Path,
                        help="Existing approved index containing Dragonite base; writes a valid combined index.")
    args = parser.parse_args()
    # Validate before building the archive, so a bad base index leaves no output directory.
    base_index = read_base_index(args.base_index)
    index = build(
        args.catalog.resolve(), args.output.absolute(), args.version,
        args.revision, species_set=("dragonite",), dex={"dragonite": 149},
        form_id="mega", runtime_suffix="-mega",
        dependencies=("pokemon_3d:dragonite:base",),
    )
    combined = combined_index(base_index, index, args.output.absolute())
    asset = index["assets"][0]
    print(f"{asset['asset_id']}: {asset['size_bytes']} bytes {asset['sha256']}")
    print(f"Combined index: {combined}")


if __name__ == "__main__":
    main()
