#!/usr/bin/env python3
"""Admit the 144 reviewed pairs and their individual bundles to local catalogs."""

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / ".tmp/remaining-pairs-battle"
sys.path.insert(0, str(ROOT / "tools"))
from package_optional_3d_bundle_prototype import encoded


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def input_evidence():
    appearance_path = HERE / "catalog_remaining_144_appearance_review.json"
    battle_path = HERE / "catalog_remaining_144_battle_qualification.json"
    profiles_path = HERE / "catalog_remaining_144_battle_profiles.json"
    appearance, battle, candidate = map(read, (appearance_path, battle_path, profiles_path))
    assert appearance["user_review"]["appearance_approved"]
    assert battle["user_review"]["battle_approved"]
    assert battle["profiles_sha256"] == sha(profiles_path)
    assert battle["runtime_lifecycle_check_passed"] and battle["camera_grounding_checks_passed"]
    for relative, digest in battle["evidence_sha256"].items():
        assert sha(ROOT / relative) == digest, relative
    names = set(candidate["profiles"])
    assert len(names) == 144 and names == {row["species"] for row in appearance["entries"]}
    assert set(candidate["models"]) == names | {name + "@shiny" for name in names}
    assert all(model["profile"] in names for model in candidate["models"].values())
    return appearance_path, battle_path, profiles_path, candidate, names


def bundle_evidence(candidate, names):
    index_path = WORK / "bundles-all/asset-index.json"
    installed_path = WORK / "installed-all/installed-catalog.json"
    index, installed = read(index_path), read(installed_path)
    assert index["catalog_revision"] == "remaining-144-local-approved-v1"
    assert len(index["assets"]) == 144
    assert {asset["species_id"] for asset in index["assets"]} == names
    assert len(installed) == 288
    installed_by_identity = {
        row["species"] + ("@shiny" if row["variant"] == "shiny" else ""): row
        for row in installed
    }
    assert set(installed_by_identity) == set(candidate["models"])
    for identity, row in installed_by_identity.items():
        assert row["runtime_sha256"] == candidate["models"][identity]["sha256"]
        assert sha(Path(row["runtime_path"])) == row["runtime_sha256"]
    for asset in index["assets"]:
        archive = index_path.parent / Path(asset["object_key"]).name
        assert archive.stat().st_size == asset["size_bytes"]
        assert sha(archive) == asset["sha256"]
        assert asset["version"] == 1 and len(asset["appearances"]) == 2
        assert {row["runtime_identity"]: row["runtime_sha256"] for row in asset["appearances"]} == {
            identity: candidate["models"][identity]["sha256"]
            for identity in (asset["species_id"], asset["species_id"] + "@shiny")
        }
    log_path = WORK / "install-all.log"
    log = log_path.read_text()
    assert "REMAINING_144_BUNDLES_OK bundles=144 scenes=288 resumed=0 no_op=true restart=true" in log
    assert "ERROR:" not in log and "SCRIPT ERROR:" not in log
    return index_path, installed_path, log_path, index


def catalog_paths():
    return (ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json",
            ROOT / "launcher/data/reviewed_model_catalog.json")


def admit():
    appearance_path, battle_path, profiles_path, candidate, names = input_evidence()
    index_path, installed_path, log_path, index = bundle_evidence(candidate, names)
    game, launcher = catalog_paths()
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    screened = read(ROOT / "scripts/battle/battle_ui/screened_model_catalog.json")
    assert not names.intersection(registry["profiles"])
    assert not set(candidate["models"]).intersection(registry["models"])
    assert not set(candidate["models"]).intersection(screened["models"])
    registry["profiles"].update(candidate["profiles"])
    registry["models"].update(candidate["models"])
    receipt = {
        "schema": 1,
        "date": "2026-09-29",
        "runtime_approved": False,
        "release_approved": False,
        "published": False,
        "species": [asset["species_id"] for asset in index["assets"]],
        "species_count": 144,
        "scene_count": 288,
        "bundle_count": 144,
        "bundle_size_bytes": sum(asset["size_bytes"] for asset in index["assets"]),
        "bundle_index": index,
        "evidence_sha256": {
            str(path.relative_to(ROOT)): sha(path)
            for path in (appearance_path, battle_path, profiles_path,
                         index_path, installed_path, log_path)
        },
        "remaining": ["installed production registry battle check", "release certification and publication"],
    }
    receipt_path = HERE / "catalog_remaining_144_bundle_qualification.json"
    receipt_path.write_bytes(encoded(receipt))
    registry["remaining_144_bundle_qualification_sha256"] = sha(receipt_path)
    payload = encoded(registry)
    game.write_bytes(payload)
    launcher.write_bytes(payload)
    print("Admitted 144 pairs to local game/launcher catalogs; not published")


def finalize():
    _, _, _, candidate, names = input_evidence()
    _, installed_path, _, _ = bundle_evidence(candidate, names)
    path = WORK / "production-registry-stress.json"
    log_path = WORK / "production-registry-stress.log"
    stress = read(path)
    log = log_path.read_text()
    assert stress["complete"] and len(stress["species"]) == 144
    assert set(stress["species"]) == names
    assert stress["catalog_sha256"] == sha(installed_path)
    assert "BATCH01_STRESS_OK" in log and "SCRIPT ERROR:" not in log and "ERROR:" not in log
    assert [row["arena"] for row in stress["rounds"]] == ["classic", "stadium", "classic"]
    for row in stress["rounds"]:
        assert row["pairs"] == row["faint_replacements"] == 144
        assert 0 < row["frame_p95_ms"] <= 20
        assert row["retained_source_bytes"] <= 64 * 1024 * 1024
        assert not any(span["ms"] > 100 and not span["covered"] for span in row["stalls_over_50ms"])
    receipt_path = HERE / "catalog_remaining_144_bundle_qualification.json"
    receipt = read(receipt_path)
    for relative, digest in receipt["evidence_sha256"].items():
        assert sha(ROOT / relative) == digest, relative
    receipt["runtime_approved"] = True
    receipt["installed_production_registry_check_passed"] = True
    receipt["installed_runtime_rounds"] = [
        {key: row[key] for key in ("arena", "pairs", "faint_replacements", "frame_p95_ms", "retained_source_bytes")}
        for row in stress["rounds"]
    ]
    receipt["evidence_sha256"][str(path.relative_to(ROOT))] = sha(path)
    receipt["evidence_sha256"][str(log_path.relative_to(ROOT))] = sha(log_path)
    receipt["remaining"] = ["release certification and publication"]
    receipt_path.write_bytes(encoded(receipt))
    game, launcher = catalog_paths()
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert all(name in registry["profiles"] for name in names)
    registry["remaining_144_bundle_qualification_sha256"] = sha(receipt_path)
    payload = encoded(registry)
    game.write_bytes(payload)
    launcher.write_bytes(payload)
    print("Installed production registry battle checks passed; 144 local pairs qualified")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("admit", "finalize"))
    args = parser.parse_args()
    {"admit": admit, "finalize": finalize}[args.phase]()
