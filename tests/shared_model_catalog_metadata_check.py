#!/usr/bin/env python3
"""Reconcile the debug catalog with the independently committed storage audit."""
import copy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from shared_source_repair_binding import historical


def reconcile(catalog, audit, original, bindings):
    catalog = historical(catalog, 'model_pair_catalog')
    assert catalog["prototype_only"] and not catalog["production_approved"]
    assert catalog["catalog_revision"] == "shared-model-catalog-test-v1"
    assert catalog["runtime_contract"] == {"godot": "4.6", "pokemon_3d": 2}
    assert len(catalog["assets"]) == len(audit["pairs"]) == len(original["assets"]) == 1200
    selected = 0
    for asset, proof, old in zip(catalog["assets"], audit["pairs"], original["assets"], strict=True):
        assert asset["asset_id"] == proof["asset_id"] == old["asset_id"]
        if not proof["selected"]:
            assert asset == old, "Unselected pair changed"
            continue
        selected += 1
        assert proof["eligible"] and proof["physical_checks"]["shared"]["scenes_exact"] == 2
        assert asset["format"] == "model-pair-pck-v1"
        assert asset["sha256"] == proof["shared_pack_sha256"]
        assert asset["size_bytes"] == proof["shared_pck_bytes"]
        assert asset["size_bytes"] < old["size_bytes"]
        assert asset["pair_manifest"]["appearances"] == asset["appearances"]
        assert asset["dependencies"] == old["dependencies"]
        files = {f["path"]: f for f in asset["pair_manifest"]["files"]}
        assert len(files) == len(asset["pair_manifest"]["files"]) <= 127
        for appearance, source, model in zip(asset["appearances"], old["appearances"], proof["models"], strict=True):
            identity = appearance["runtime_identity"]
            assert identity == source["runtime_identity"] == model["identity"]
            assert appearance["source_sha256"] == source["runtime_sha256"] == model["sha256"]
            assert appearance["runtime_sha256"] == model["candidate_sha256"]
            assert appearance["semantic_sha256"] == model["semantic_sha256"]
            assert appearance["cache_source_bytes"] == bindings[identity]["cache_source_bytes"]
            assert files[appearance["runtime_path"]]["sha256"] == appearance["runtime_sha256"]
            assert files[appearance["runtime_path"]]["bytes"] == appearance["bytes"]
    assert selected == 1084


def main():
    def read(name):
        return json.loads((ROOT / name).read_bytes())
    catalog = read("data/model_pair_catalog.json")
    audit = read("tools/sprite_factory/shared_model_catalog_results.json")
    original = read("release/approved_3d_bundles_v11_index.json")
    bindings = read("release/approved_3d_lossless_binding.json")["models"]
    assert (ROOT / "data/model_pair_catalog.json").read_bytes() == (ROOT / "launcher/data/model_pair_catalog.json").read_bytes()
    assert catalog["storage_audit_sha256"] == hashlib.sha256((ROOT / "tools/sprite_factory/shared_model_catalog_results.json").read_bytes()).hexdigest()
    reconcile(catalog, audit, original, bindings)
    for mutation in ["source", "candidate", "cache", "fallback", "duplicate"]:
        changed = copy.deepcopy(catalog)
        first = next(a for a in changed["assets"] if a.get("format") == "model-pair-pck-v1")
        appearance = first["appearances"][0]
        if mutation == "source":
            appearance["source_sha256"] = "0" * 64
        elif mutation == "candidate":
            appearance["runtime_sha256"] = "0" * 64
        elif mutation == "cache":
            appearance["cache_source_bytes"] -= 1
        elif mutation == "fallback":
            next(a for a in changed["assets"] if a.get("format") != "model-pair-pck-v1")["size_bytes"] -= 1
        else:
            changed["assets"][1] = first
        try:
            reconcile(changed, audit, original, bindings)
        except AssertionError:
            continue
        raise AssertionError("Invalid " + mutation + " binding accepted")
    print("SHARED_MODEL_CATALOG_METADATA_CHECK_OK selected=1084 unchanged=116 negative_cases=5")


if __name__ == "__main__":
    main()
