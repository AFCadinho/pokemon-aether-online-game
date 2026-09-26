#!/usr/bin/env python3
"""Build one local, unreleased normal/shiny bundle per battle-qualified species."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from .package_optional_3d_bundle_prototype import build, encoded
    from .sprite_factory.run_screened_100_pair_stress import NORMAL, SHINY_REPORTS, sha256
    from .sprite_factory.screened_100_battle_candidates import PRODUCTION
except ImportError:
    from package_optional_3d_bundle_prototype import build, encoded
    from sprite_factory.run_screened_100_pair_stress import NORMAL, SHINY_REPORTS, sha256
    from sprite_factory.screened_100_battle_candidates import PRODUCTION


ROOT = Path(__file__).resolve().parents[1]
IDENTITIES = ROOT / "tools/sprite_factory/catalog_100_identity_results.json"
REVISION = "screened-100-battle-candidate-v1"


def package(qualification_path: Path, output: Path) -> dict:
    qualification = json.loads(qualification_path.read_text())
    production = {row["species"]: row for row in json.loads(PRODUCTION.read_text())["entries"]
                  if row["status"] == "technical_candidate"}
    selected = sorted(row["species"] for row in qualification["entries"]
                      if row["status"] == "battle_qualified" and row["runtime_approved"] is True)
    if (qualification.get("runtime_approved") is not True or qualification.get("release_approved") is not False
            or qualification.get("production_sha256") != sha256(PRODUCTION)
            or len(selected) != qualification.get("qualified") or not selected
            or len(qualification.get("entries", [])) != 61 or set(selected) - set(production)):
        raise ValueError("battle qualification is incomplete or changed")
    dex = {row["species"]: row["national_dex_id"]
           for row in json.loads(IDENTITIES.read_text())["entries"] if row["identity_verified"]}
    if not set(selected) <= set(dex):
        raise ValueError("National Dex identity not verified")
    normals = {row["species"]: row for row in json.loads(NORMAL.read_text())}
    shinies = {row["species"].removesuffix("@shiny"): row for report in SHINY_REPORTS
               for row in json.loads(report.read_text())}
    catalog, hashes = [], {}
    for name in selected:
        for variant, source in (("normal", normals[name]), ("shiny", shinies[name])):
            identity = name + ("@shiny" if variant == "shiny" else "")
            expected = production[name][variant + "_scn_sha256"]
            path = Path(source["runtime_path"])
            if source["runtime_sha256"] != expected or path.is_symlink() or sha256(path) != expected:
                raise ValueError(f"candidate scene changed: {identity}")
            hashes[identity] = expected
            catalog.append({"species": name, "variant": variant, "runtime_schema": 1,
                            "runtime_path": str(path), "runtime_sha256": expected})
    catalog_path = output.parent / (output.name + "-source-catalog.json")
    if catalog_path.exists() or output.exists():
        raise ValueError("bundle output or source catalog already exists")
    catalog_path.write_bytes(encoded(catalog))
    try:
        index = build(catalog_path, output, revision=REVISION, species_set=tuple(selected),
                      dex=dex, candidate_hashes=hashes)
    except BaseException:
        catalog_path.unlink()
        raise
    receipt = {"schema": 1, "kind": "pokeaether-screened-100-local-candidate-bundles",
               "release_approved": False, "qualification_sha256": sha256(qualification_path),
               "catalog_sha256": sha256(catalog_path),
               "index_sha256": sha256(output / "asset-index.json"),
               "bundles": [{key: asset[key] for key in ("asset_id", "object_key", "size_bytes", "sha256")}
                           for asset in index["assets"]]}
    (output / "candidate-receipt.json").write_bytes(encoded(receipt))
    return receipt


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("qualification", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = package(args.qualification.resolve(), args.output.absolute())
    print(f"Built {len(result['bundles'])} individual local candidate bundles")
    print(f"Index SHA-256: {result['index_sha256']}")


if __name__ == "__main__":
    main()
