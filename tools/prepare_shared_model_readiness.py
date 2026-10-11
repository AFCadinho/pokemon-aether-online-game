#!/usr/bin/env python3
"""Prepare an owned local installer fixture; read approved assets in place."""
import argparse
import hashlib
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-report", type=Path, required=True)
    parser.add_argument("--packs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    assert os.environ.get("POKEAETHER_SLOT") == ROOT.parent.name, "Use slot-env"
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    assert not output.exists(), "Keep previous evidence intact"
    read = lambda path: json.loads(path.read_bytes())
    original = read(ROOT / "release/approved_3d_bundles_v11_index.json")
    source = read(args.source_report.resolve())
    origins = {a["asset_id"]: a for a in source["assets"]}
    full = {a["asset_id"]: a for a in read(ROOT / "data/model_pair_catalog.json")["assets"]}
    compact = read(ROOT / "data/model_pair_qualified.json")
    proof = read(ROOT / "tools/shared_model_qualification_results.json")
    selected = set(proof["selection"]["shared_asset_ids"])
    assert len(selected) == 1082
    assert compact["qualification_sha256"] == hashlib.sha256((ROOT / "tools/shared_model_qualification_results.json").read_bytes()).hexdigest()
    paths, old_paths = {}, {}
    for row, old in zip(compact["assets"], original["assets"], strict=True):
        key = row["asset_id"]
        assert old["asset_id"] == key and origins[key]["candidate_asset"] == old
        old_path = Path(origins[key]["candidate_archive"])
        assert old_path.is_absolute() and old_path.stat().st_size == old["size_bytes"]
        old_paths[key] = str(old_path)
        if key in selected:
            asset = full[key]
            assert row == {"format": "model-pair-ref-v1", "asset_id": key, "sha256": asset["sha256"]}
            path = args.packs.resolve() / Path(asset["object_key"]).name
            assert path.stat().st_size == asset["size_bytes"]
            paths[key] = str(path)
        else:
            assert row == old
            paths[key] = str(old_path)
    # Physical hashes are independently checked by the real installer.
    output.mkdir(parents=True)
    config = {"schema": 1, "root": str(output), "sources": paths, "original_sources": old_paths,
              "index_sha256": hashlib.sha256((ROOT / "data/model_pair_qualified.json").read_bytes()).hexdigest(),
              "qualification_sha256": compact["qualification_sha256"]}
    (output / "input.json").write_text(json.dumps(config, indent=2) + "\n")
    print(output / "input.json")


if __name__ == "__main__":
    main()
