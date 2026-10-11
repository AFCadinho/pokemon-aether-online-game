#!/usr/bin/env python3
"""Qualified compact references must exactly follow the recorded whole-pair verdict."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def check(wire, catalog, original, proof):
    assert wire["prototype_only"] is True and wire["production_approved"] is False
    assert wire["catalog_revision"] == "shared-model-qualified-test-v1"
    assert wire["runtime_contract"] == {"godot": "4.6", "pokemon_3d": 2}
    assert wire["qualification_run_sha256"] == proof["run_report_sha256"]
    selected = set(proof["selection"]["shared_asset_ids"])
    assert len(selected) == 1082 and len(wire["assets"]) == 1200
    for row, source, old in zip(wire["assets"], catalog["assets"], original["assets"], strict=True):
        key = row["asset_id"]
        assert key == source["asset_id"] == old["asset_id"]
        expected = {"asset_id": key, "format": "model-pair-ref-v1", "sha256": source["sha256"]} if key in selected else old
        assert row == expected, key


def main():
    read = lambda name: json.loads((ROOT / name).read_bytes())
    wire = read("data/model_pair_qualified.json")
    catalog = read("data/model_pair_catalog.json")
    original = read("release/approved_3d_bundles_v11_index.json")
    proof = read("tools/shared_model_qualification_results.json")
    payload = (ROOT / "data/model_pair_qualified.json").read_bytes()
    assert payload == (ROOT / "launcher/data/model_pair_qualified.json").read_bytes()
    assert (ROOT / "scripts/services/model_pair_pilot.gd").read_bytes() == (ROOT / "launcher/scripts/model_pair_pilot.gd").read_bytes()
    assert wire["qualification_sha256"] == hashlib.sha256((ROOT / "tools/shared_model_qualification_results.json").read_bytes()).hexdigest()
    assert len(payload) <= 1024 * 1024
    check(wire, catalog, original, proof)
    for mutation in ("held", "hash", "fallback", "duplicate"):
        changed = copy.deepcopy(wire)
        if mutation == "held":
            i = next(i for i, a in enumerate(catalog["assets"]) if a["asset_id"] == "pokemon_3d:greninja:base")
            a = catalog["assets"][i]
            changed["assets"][i] = {"asset_id": a["asset_id"], "format": "model-pair-ref-v1", "sha256": a["sha256"]}
        elif mutation == "hash":
            changed["assets"][0]["sha256"] = "0" * 64
        elif mutation == "fallback":
            next(a for a in changed["assets"] if a.get("format") != "model-pair-ref-v1")["size_bytes"] -= 1
        else:
            changed["assets"][1] = changed["assets"][0]
        try:
            check(changed, catalog, original, proof)
        except AssertionError:
            continue
        raise AssertionError("Accepted " + mutation)
    print("SHARED_MODEL_QUALIFIED_METADATA_CHECK_OK shared=1082 original=118 index_bytes=" + str(len(payload)))


if __name__ == "__main__":
    main()
