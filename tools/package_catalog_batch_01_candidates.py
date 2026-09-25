#!/usr/bin/env python3
"""Build local, unreleased bundles for the 14 qualified batch-01 candidate pairs."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from .package_optional_3d_bundle_prototype import build, encoded, source_entries
except ImportError:
    from package_optional_3d_bundle_prototype import build, encoded, source_entries


ROOT = Path(__file__).resolve().parents[1]
QUALIFICATION = ROOT / "tools/sprite_factory/catalog_production_batch_01_shiny_qualification.json"
DEX = {
    "charmeleon": 5, "dunsparce": 206, "flaaffy": 180, "houndoom": 229,
    "houndour": 228, "igglybuff": 174, "mareep": 179, "persian": 53,
    "phanpy": 231, "skiploom": 188, "slowking": 199, "stantler": 234,
    "teddiursa": 216, "ursaring": 217,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def candidate_hashes(catalog: Path, qualification: Path) -> dict[str, str]:
    result = json.loads(qualification.read_text(encoding="utf-8"))
    entries = result.get("entries", [])
    if (result.get("schema") != 1 or result.get("runtime_approved") is not False
            or result.get("release_approved") is not False or len(entries) != len(DEX)
            or {entry.get("species") for entry in entries} != set(DEX)
            or len(result.get("material_holds", [])) != 4):
        raise ValueError("batch-01 candidate qualification is incomplete or changed")
    for name, expected in result["evidence_sha256"].items():
        path = ROOT / name
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"candidate evidence changed: {name}")
    source = source_entries(catalog)
    expected_keys = set(DEX) | {species + "@shiny" for species in DEX}
    if set(source) != expected_keys:
        raise ValueError("catalog must contain exactly the 14 normal/shiny pairs")
    hashes = {}
    for entry in entries:
        if entry.get("status") != "paired_runtime_screen_passed" or entry.get("runtime_approved") is not False:
            raise ValueError(f"candidate pair is not screened: {entry.get('species')}")
        species = entry["species"]
        for variant, field in (("normal", "normal_scn_sha256"), ("shiny", "shiny_scn_sha256")):
            identity = species + ("@shiny" if variant == "shiny" else "")
            catalog_entry, path = source[identity]
            expected = entry[field]
            if (catalog_entry.get("runtime_sha256") != expected or not path.is_file()
                    or path.is_symlink() or sha256(path) != expected):
                raise ValueError(f"candidate scene changed: {identity}")
            hashes[identity] = expected
    return hashes


def package(catalog: Path, output: Path, qualification: Path = QUALIFICATION) -> dict:
    catalog, output, qualification = catalog.resolve(), output.absolute(), qualification.resolve()
    hashes = candidate_hashes(catalog, qualification)
    index = build(catalog, output, revision="catalog-batch-01-candidate-v1",
                  species_set=tuple(sorted(DEX)), dex=DEX, candidate_hashes=hashes)
    receipt = {
        "schema": 1,
        "kind": "pokeaether-unreleased-3d-candidate-bundles",
        "release_approved": False,
        "catalog_sha256": sha256(catalog),
        "qualification_sha256": sha256(qualification),
        "index_sha256": sha256(output / "asset-index.json"),
        "bundles": [{"asset_id": asset["asset_id"], "object_key": asset["object_key"],
                     "size_bytes": asset["size_bytes"], "sha256": asset["sha256"]}
                    for asset in index["assets"]],
    }
    (output / "candidate-receipt.json").write_bytes(encoded(receipt))
    return receipt


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--qualification", type=Path, default=QUALIFICATION)
    args = parser.parse_args()
    receipt = package(args.catalog, args.output, args.qualification)
    print(f"Built {len(receipt['bundles'])} unreleased candidate bundles")
    print(f"Index SHA-256: {receipt['index_sha256']}")
    print(f"Receipt: {args.output.absolute() / 'candidate-receipt.json'}")


if __name__ == "__main__":
    main()
