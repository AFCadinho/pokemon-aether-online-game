#!/usr/bin/env python3
"""Verify individual local candidate archives against the battle qualification."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import zipfile

try:
    from .screened_100_battle_candidates import sha256
except ImportError:
    from screened_100_battle_candidates import sha256


def preflight(qualification_path: Path, bundle_dir: Path) -> dict:
    qualification = json.loads(qualification_path.read_text())
    selected = {row["species"]: row for row in qualification["entries"]
                if row["status"] == "battle_qualified" and row["runtime_approved"] is True}
    receipt_path = bundle_dir / "candidate-receipt.json"
    index_path = bundle_dir / "asset-index.json"
    receipt = json.loads(receipt_path.read_text())
    index = json.loads(index_path.read_text())
    if (qualification.get("runtime_approved") is not True or len(selected) != qualification["qualified"]
            or receipt.get("release_approved") is not False
            or receipt.get("qualification_sha256") != sha256(qualification_path)
            or receipt.get("index_sha256") != sha256(index_path)
            or index.get("catalog_revision") != "screened-100-battle-candidate-v1"
            or len(index.get("assets", [])) != len(selected)
            or len(receipt.get("bundles", [])) != len(selected)):
        raise ValueError("candidate index or battle qualification changed")
    seen = set()
    for asset, pinned in zip(index["assets"], receipt["bundles"], strict=True):
        name = asset["species_id"]
        archive = bundle_dir / Path(asset["object_key"]).name
        if (name not in selected or name in seen or asset["asset_id"] != pinned["asset_id"]
                or asset["sha256"] != pinned["sha256"] or asset["size_bytes"] != pinned["size_bytes"]
                or archive.is_symlink() or not archive.is_file()
                or archive.stat().st_size != asset["size_bytes"] or sha256(archive) != asset["sha256"]):
            raise ValueError(f"candidate archive changed: {name}")
        expected = {name: selected[name]["normal_scn_sha256"],
                    name + "@shiny": selected[name]["shiny_scn_sha256"]}
        if {row["runtime_identity"]: row["runtime_sha256"] for row in asset["appearances"]} != expected:
            raise ValueError(f"normal/shiny manifest changed: {name}")
        with zipfile.ZipFile(archive) as packed:
            if set(packed.namelist()) != {"bundle.json", "models/normal.scn", "models/shiny.scn"}:
                raise ValueError(f"bundle members changed: {name}")
            manifest = json.loads(packed.read("bundle.json"))
            if (manifest["species_id"] != name or manifest["version"] != 1
                    or {row["runtime_identity"]: row["runtime_sha256"]
                        for row in manifest["appearances"]} != expected):
                raise ValueError(f"bundle manifest changed: {name}")
            for variant, identity in (("normal", name), ("shiny", name + "@shiny")):
                if hashlib.sha256(packed.read(f"models/{variant}.scn")).hexdigest() != expected[identity]:
                    raise ValueError(f"bundle scene changed: {identity}")
        seen.add(name)
    if seen != set(selected):
        raise ValueError("candidate bundle list is incomplete")
    return {"schema": 1, "status": "local_candidate_bundle_preflight_passed",
            "release_approved": False, "bundle_count": len(selected),
            "appearance_count": len(selected) * 2,
            "bundle_bytes": sum(asset["size_bytes"] for asset in index["assets"]),
            "index_sha256": sha256(index_path), "receipt_sha256": sha256(receipt_path),
            "qualification_sha256": sha256(qualification_path)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("qualification", type=Path)
    parser.add_argument("bundle_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("output must be new")
    result = preflight(args.qualification, args.bundle_dir)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Verified {result['bundle_count']} individual bundles")


if __name__ == "__main__":
    main()
