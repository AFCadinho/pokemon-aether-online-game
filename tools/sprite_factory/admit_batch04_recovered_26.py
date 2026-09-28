#!/usr/bin/env python3
"""Admit the 26 already reviewed batch-04 recovery pairs to local catalogs."""

import argparse
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OLD = ROOT / ".tmp/batch04-recovery"
WORK = ROOT / ".tmp/remaining-catalog-intake/recovered-26"
sys.path.insert(0, str(ROOT / "tools"))
from package_optional_3d_bundle_prototype import encoded


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def evidence():
    approved24 = HERE / "catalog_production_batch_04_recovery_approval.json"
    approved2 = HERE / "catalog_production_batch_04_sketchfab_approval.json"
    normal, sketch = read(approved24), read(approved2)
    assert normal["runtime_approved"] and sketch["runtime_approved"]
    assert not normal["published"] and not sketch["published"]
    assert len(normal["approved_species"]) == 24 and len(sketch["entries"]) == 2
    for approval in (normal, sketch):
        for relative, digest in approval["evidence_sha256"].items():
            assert sha(ROOT / relative) == digest, relative
    return approved24, approved2, normal, sketch


def sources():
    approved24, approved2, normal, sketch = evidence()
    source24 = read(OLD / "candidate-bundle-source-catalog.json")
    source2 = read(OLD / "sketchfab-bundle-source-v1.json")
    rows = {(row["species"], row["variant"]): row for row in source24 + source2}
    names = normal["approved_species"] + [row["species"] for row in sketch["entries"]]
    assert len(names) == len(set(names)) == 26
    assert set(rows) == {(name, variant) for name in names for variant in ("normal", "shiny")}
    recovered = {row["species"]: row for row in read(HERE / "catalog_production_batch_04_recovery.json")["entries"]}
    for variant in ("normal", "shiny"):
        for row in read(OLD / f"eye-motion-{variant}-runtime-uv2/report.json"):
            assert row["species"] in ("starly", "wattrel", "kilowattrel")
            recovered[row["species"]]["variants"][variant] = {
                "glb_sha256": row["glb_sha256"],
                "runtime_sha256": row["runtime_sha256"],
            }
    recovered.update({row["species"]: {"variants": {
        "normal": {"glb_sha256": row["normal_glb_sha256"], "runtime_sha256": row["normal_scn_sha256"]},
        "shiny": {"glb_sha256": row["shiny_glb_sha256"], "runtime_sha256": row["shiny_scn_sha256"]},
    }} for row in sketch["entries"]})
    assert set(recovered) >= set(names)
    for name in names:
        assert rows[name, "normal"]["action_timing"] == rows[name, "shiny"]["action_timing"]
        for variant in ("normal", "shiny"):
            row = rows[name, variant]
            expected = recovered[name]["variants"][variant]
            assert row["runtime_sha256"] == expected["runtime_sha256"]
            assert sha(Path(row["runtime_path"])) == row["runtime_sha256"]
    return approved24, approved2, names, rows, recovered


def prepare():
    _, _, names, rows, _ = sources()
    indexes = [OLD / "candidate-bundles/asset-index.json",
               OLD / "sketchfab-candidate-bundles-v1/asset-index.json"]
    inputs = [read(path) for path in indexes]
    assert all(index["runtime_contract"] == inputs[0]["runtime_contract"] for index in inputs)
    assets = sorted([asset for index in inputs for asset in index["assets"]],
                    key=lambda asset: (asset["national_dex"], asset["species_id"]))
    assert len(assets) == 26 and {asset["species_id"] for asset in assets} == set(names)
    WORK.mkdir(parents=True, exist_ok=True)
    bundles = WORK / "bundles"
    bundles.mkdir(exist_ok=True)
    for asset in assets:
        folder = OLD / ("sketchfab-candidate-bundles-v1" if asset["species_id"] in ("walking-wake", "iron-leaves") else "candidate-bundles")
        source = folder / Path(asset["object_key"]).name
        assert source.stat().st_size == asset["size_bytes"] and sha(source) == asset["sha256"]
        assert {entry["runtime_identity"]: entry["runtime_sha256"] for entry in asset["appearances"]} == {
            name: rows[asset["species_id"], variant]["runtime_sha256"]
            for variant, name in (("normal", asset["species_id"]),
                                  ("shiny", asset["species_id"] + "@shiny"))}
        target = bundles / source.name
        if target.exists():
            assert sha(target) == asset["sha256"]
        else:
            target.hardlink_to(source)
    index = {**{key: value for key, value in inputs[0].items() if key != "assets"},
             "catalog_revision": "batch04-recovered-26-local-approved-v1", "assets": assets}
    (bundles / "asset-index.json").write_bytes(encoded(index))
    print("RECOVERED_26_PREPARED bundles=26 bytes=", sum(a["size_bytes"] for a in assets))


def admit():
    approved24, approved2, names, rows, recovered = sources()
    index_path = WORK / "bundles/asset-index.json"
    installed_path = WORK / "installed/installed-catalog.json"
    log_path = WORK / "install.log"
    index, installed = read(index_path), read(installed_path)
    assert len(index["assets"]) == 26 and len(installed) == 52
    assert "REMAINING_144_BUNDLES_OK bundles=26 scenes=52 resumed=0 no_op=true restart=true" in log_path.read_text()
    assert "SCRIPT ERROR:" not in log_path.read_text() and "ERROR:" not in log_path.read_text()
    for row in installed:
        assert row["runtime_sha256"] == rows[row["species"], row["variant"]]["runtime_sha256"]
        assert sha(Path(row["runtime_path"])) == row["runtime_sha256"]
    motions = read(OLD / "battle-motion-profiles.json")
    motions["giratina"] = read(OLD / "battle-giratina-input/candidates.json")["motion"]["giratina"]
    motions["walking-wake"] = read(OLD / "sketchfab-battle-wake-v6/candidates.json")["motion"]["walking-wake"]
    motions["iron-leaves"] = read(OLD / "sketchfab-battle-v5/candidates.json")["motion"]["iron-leaves"]
    assert set(motions) == set(names)
    game = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
    launcher = ROOT / "launcher/data/reviewed_model_catalog.json"
    screened_game = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
    screened_launcher = ROOT / "launcher/data/screened_model_catalog.json"
    assert game.read_bytes() == launcher.read_bytes()
    assert screened_game.read_bytes() == screened_launcher.read_bytes()
    registry, screened = read(game), read(screened_game)
    for name in names:
        assert name not in registry["profiles"]
        if name in screened["profiles"]:
            assert name == "murkrow" and name in screened["models"]
            del screened["profiles"][name]
            del screened["models"][name]
        motion = motions[name]
        pose = {"scale": motion["scale"], "yaw_degrees": motion["yaw_degrees"]}
        scene_hash = rows[name, "normal"]["runtime_sha256"]
        registry["profiles"][name] = {
            "action_timing": rows[name, "normal"]["action_timing"],
            "placement": pose,
            "grounding": {**pose, "lift": motion["lift"], "sha256": scene_hash},
            "motion": {**motion, "sha256": scene_hash},
        }
        for variant in ("normal", "shiny"):
            identity = name + ("@shiny" if variant == "shiny" else "")
            assert identity not in registry["models"] and identity not in screened["models"]
            registry["models"][identity] = {
                "sha256": rows[name, variant]["runtime_sha256"],
                "glb_sha256": recovered[name]["variants"][variant]["glb_sha256"],
                "profile": name,
            }
    receipt = {
        "schema": 1, "runtime_approved": True, "release_approved": False,
        "published": False, "species": names, "bundle_index": index,
        "bundle_size_bytes": sum(asset["size_bytes"] for asset in index["assets"]),
        "source_attribution_required_for_release": ["walking-wake", "iron-leaves"],
        "evidence_sha256": {str(path.relative_to(ROOT)): sha(path) for path in
                            (approved24, approved2,
                             OLD / "eye-motion-normal-runtime-uv2/report.json",
                             OLD / "eye-motion-shiny-runtime-uv2/report.json",
                             index_path, installed_path, log_path)},
        "remaining": ["release credits, certification and publication"],
    }
    receipt_path = HERE / "catalog_batch04_recovered_26_admission.json"
    receipt_path.write_bytes(encoded(receipt))
    registry["catalog_batch04_recovered_26_admission_sha256"] = sha(receipt_path)
    payload = encoded(registry)
    game.write_bytes(payload)
    launcher.write_bytes(payload)
    payload = encoded(screened)
    screened_game.write_bytes(payload)
    screened_launcher.write_bytes(payload)
    print("RECOVERED_26_ADMITTED pairs=26 scenes=52 published=false")


def finalize():
    _, _, names, _, _ = sources()
    report_path = WORK / "production-stress.json"
    log_path = WORK / "production-stress.log"
    report = read(report_path)
    log = log_path.read_text()
    assert report["complete"] and set(report["species"]) == set(names)
    assert report["catalog_sha256"] == sha(WORK / "installed/installed-catalog.json")
    assert "BATCH01_STRESS_OK" in log and "SCRIPT ERROR:" not in log and "ERROR:" not in log
    assert [row["arena"] for row in report["rounds"]] == ["classic", "stadium", "classic"]
    for row in report["rounds"]:
        assert row["pairs"] == row["faint_replacements"] == 26
        assert 0 < row["frame_p95_ms"] <= 20
        assert not any(stall["ms"] > 100 and not stall["covered"]
                       for stall in row["stalls_over_50ms"])
    receipt_path = HERE / "catalog_batch04_recovered_26_admission.json"
    receipt = read(receipt_path)
    for relative, digest in receipt["evidence_sha256"].items():
        assert sha(ROOT / relative) == digest, relative
    receipt["installed_production_registry_check_passed"] = True
    receipt["runtime_rounds"] = [
        {key: row[key] for key in ("arena", "pairs", "frame_p95_ms")}
        for row in report["rounds"]]
    receipt["evidence_sha256"][str(report_path.relative_to(ROOT))] = sha(report_path)
    receipt["evidence_sha256"][str(log_path.relative_to(ROOT))] = sha(log_path)
    receipt_path.write_bytes(encoded(receipt))
    game = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
    launcher = ROOT / "launcher/data/reviewed_model_catalog.json"
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert set(names) <= set(registry["profiles"])
    registry["catalog_batch04_recovered_26_admission_sha256"] = sha(receipt_path)
    payload = encoded(registry)
    game.write_bytes(payload)
    launcher.write_bytes(payload)
    print("RECOVERED_26_RUNTIME_OK pairs=26 rounds=3")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=("prepare", "admit", "finalize"))
    args = parser.parse_args()
    {"prepare": prepare, "admit": admit, "finalize": finalize}[args.phase]()
