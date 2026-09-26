#!/usr/bin/env python3
"""Build local, unreleased individual bundles for screened batch-02 pairs."""
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
QUALIFICATION = ROOT / "tools/sprite_factory/catalog_production_batch_02_battle_qualification.json"
NORMAL = ROOT / ".tmp/catalog-production-02-runtime/report.json"


def sha256(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def candidate_inputs(catalog: Path, qualification: Path) -> tuple[dict[str, str], dict[str, int]]:
    record = json.loads(qualification.read_text())
    if (record.get("schema") != 1 or record.get("runtime_approved") is not False
            or record.get("release_approved") is not False or len(record.get("entries", [])) != 100):
        raise ValueError("batch-02 qualification is incomplete or approved for release")
    for name, expected in record["evidence_sha256"].items():
        path = ROOT / name
        if not path.is_file() or sha256(path) != expected:
            raise ValueError(f"candidate evidence changed: {name}")
    pairs = {row["species"]: row for row in record["entries"]
             if row["status"] in {"paired_battle_screen_passed_visual_review_pending", "paired_battle_reviewed"}}
    if len(pairs) != 69:
        raise ValueError("expected 69 screened normal/shiny pairs")
    source = source_entries(catalog)
    identities = set(pairs) | {name + "@shiny" for name in pairs}
    if set(source) != identities:
        raise ValueError("candidate catalog differs from screened pairs")
    normals = {row["species"]: row for row in json.loads(NORMAL.read_text())}
    hashes, dex = {}, {}
    for species, row in pairs.items():
        identity = normals[species]["identity_evidence"]["identity"]
        if identity["species"] != species or identity["form"] != 0 or identity["gender_code"] != 0:
            raise ValueError(f"normal identity changed: {species}")
        number = identity["national_dex_id"]
        if not isinstance(number, (int, float)) or int(number) != number or number < 1:
            raise ValueError(f"invalid National Dex number: {species}")
        dex[species] = int(number)
        for variant in ("normal", "shiny"):
            key = species + ("@shiny" if variant == "shiny" else "")
            entry, path = source[key]
            expected = row[variant + "_scn_sha256"]
            if (entry.get("runtime_sha256") != expected or path.is_symlink()
                    or not path.is_file() or sha256(path) != expected):
                raise ValueError(f"candidate scene changed: {key}")
            hashes[key] = expected
    return hashes, dex


def package(catalog: Path, output: Path, qualification: Path = QUALIFICATION) -> dict:
    catalog, output, qualification = catalog.resolve(), output.absolute(), qualification.resolve()
    hashes, dex = candidate_inputs(catalog, qualification)
    index = build(catalog, output, revision="catalog-batch-02-candidate-v1",
                  species_set=tuple(sorted(dex)), dex=dex, candidate_hashes=hashes)
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
