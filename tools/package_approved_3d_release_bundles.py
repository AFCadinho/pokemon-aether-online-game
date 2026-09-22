#!/usr/bin/env python3
"""Build exactly the seven release-approved Pokemon 3D species bundles."""
from __future__ import annotations

import argparse
from pathlib import Path

try:
    from .package_optional_3d_bundle_prototype import build
except ImportError:  # Direct CLI execution from tools/.
    from package_optional_3d_bundle_prototype import build


SPECIES = (
    "arcanine",
    "articuno",
    "dragonite",
    "lucario",
    "pikachu",
    "roaring-moon",
    "snorlax",
)
DEX = {
    "arcanine": 59,
    "articuno": 144,
    "dragonite": 149,
    "lucario": 448,
    "pikachu": 25,
    "roaring-moon": 1005,
    "snorlax": 143,
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--version", type=int, default=1)
    parser.add_argument("--revision", default="approved-pokemon-3d-v1")
    args = parser.parse_args()
    index = build(
        args.catalog.resolve(),
        args.output.absolute(),
        args.version,
        args.revision,
        species_set=SPECIES,
        dex=DEX,
    )
    total = 0
    for asset in index["assets"]:
        total += asset["size_bytes"]
        print(f"{asset['asset_id']}: {asset['size_bytes']} bytes {asset['sha256']}")
    print(f"Total: {total} bytes")
    print(f"Index: {args.output.absolute() / 'asset-index.json'}")


if __name__ == "__main__":
    main()
