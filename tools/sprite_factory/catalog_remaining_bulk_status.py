#!/usr/bin/env python3
"""Reconcile the entire still-unapproved base-species intake after bulk processing."""

import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / ".tmp/remaining-catalog-intake"


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def main():
    inventory_path = WORK / "inventory.json"
    previous_path = HERE / "catalog_remaining_shiny_results.json"
    recovered_path = HERE / "catalog_remaining_rig_recovered_candidates.json"
    shiny_path = WORK / "rig-recovered-shiny-pinned/status.json"
    admission_path = HERE / "catalog_batch04_recovered_26_admission.json"
    registry_path = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
    inventory, previous, recovered, shiny = map(read,
        (inventory_path, previous_path, recovered_path, shiny_path))
    admission, registry = read(admission_path), read(registry_path)
    assert admission["runtime_approved"] and admission["installed_production_registry_check_passed"]
    approved_four = set(read(HERE / "catalog_remaining_four_admission.json")["species"])
    assert len(approved_four) == 4
    recovery_path = HERE / "catalog_shiny_151_first_32_admission.json"
    recovery = read(recovery_path)
    assert recovery["runtime_approved"] and not recovery["published"]
    assert registry["catalog_shiny_151_first_32_admission_sha256"] == sha(recovery_path)
    approved_recovery = set(recovery["species"])
    assert len(approved_recovery) == 32 and not approved_four.intersection(approved_recovery)
    twelve_path = HERE / "catalog_shiny_twelve_admission.json"
    twelve = read(twelve_path)
    assert twelve["runtime_approved"] and not twelve["published"]
    assert registry["catalog_shiny_twelve_admission_sha256"] == sha(twelve_path)
    approved_twelve = set(twelve["species"])
    assert len(approved_twelve) == 12 and not (approved_four | approved_recovery).intersection(approved_twelve)
    material_path = HERE / "catalog_shiny_21_material_admission.json"
    material = read(material_path)
    assert material["runtime_approved"] and not material["published"]
    assert registry["catalog_shiny_21_material_admission_sha256"] == sha(material_path)
    approved_material = set(material["species"])
    assert len(approved_material) == 4 and not (approved_four | approved_recovery | approved_twelve).intersection(approved_material)
    approved_intake = approved_four | approved_recovery | approved_twelve | approved_material
    assert len(registry["profiles"]) == 688 and len(registry["models"]) == 1376
    assert inventory["canonical_species_count"] == 1025
    assert inventory["remaining_species_count"] == 390
    expected = {row["species"] for row in inventory["entries"]}
    assert expected.intersection(registry["profiles"]) == approved_intake
    old_by_name = {row["species"]: row for row in previous["entries"]}
    assert expected <= set(old_by_name)
    recovered_by_name = {row["species"]: row for row in recovered["entries"]}
    shiny_by_name = {row["species"]: row for row in shiny["entries"]}
    assert set(recovered_by_name) == set(shiny_by_name) and len(shiny_by_name) == 14
    rows = []
    for entry in inventory["entries"]:
        name = entry["species"]
        if name in approved_intake:
            continue
        old = old_by_name[name]
        if name not in recovered_by_name:
            rows.append({"national_dex": entry["national_dex"], "species": name,
                         "status": old["status"], "stage": old["stage"],
                         "reason": old.get("reason", ""), "runtime_approved": False})
            continue
        candidate = recovered_by_name[name]
        normal_report = read(WORK / f"rig-recovered-runtime/{name}/runtime/report.json")[0]
        assert normal_report["runtime_sha256"] == candidate["normal_scene_sha256"]
        assert sha(Path(normal_report["runtime_path"])) == candidate["normal_scene_sha256"]
        rare = shiny_by_name[name]
        row = {"national_dex": entry["national_dex"], "species": name,
               "status": "pair_technical_candidate" if rare["status"] == "exported" else "shiny_hold",
               "stage": "appearance_and_battle_review" if rare["status"] == "exported" else "shiny_material",
               "reason": "visual and battle qualification pending" if rare["status"] == "exported" else rare["reason"],
               "runtime_approved": False,
               "normal_glb_sha256": candidate["normal_glb_sha256"],
               "normal_scene_sha256": candidate["normal_scene_sha256"]}
        if rare["status"] == "exported":
            shiny_report = read(WORK / f"rig-recovered-shiny-runtime/{name}/runtime/report.json")[0]
            assert sha(Path(shiny_report["runtime_path"])) == shiny_report["runtime_sha256"]
            assert rare["glb_sha256"] == shiny_report["glb_sha256"]
            row["shiny_glb_sha256"] = rare["glb_sha256"]
            row["shiny_scene_sha256"] = shiny_report["runtime_sha256"]
            row["geometry_motion_sha256"] = rare["geometry_motion_sha256"]
        rows.append(row)
    counts = Counter(row["status"] for row in rows)
    assert len(rows) == 338 and counts == {
        "review_hold": 214, "shiny_hold": 103, "source_missing": 21}
    evidence = [inventory_path, previous_path, recovered_path, shiny_path,
                admission_path, HERE / "catalog_remaining_four_admission.json", recovery_path, twelve_path, material_path,
                WORK / "rig-recovered-normal/status.json",
                WORK / "rig-recovered-runtime/status.json",
                WORK / "rig-recovered-shiny-runtime/status.json",
                WORK / "new-pairs-captures/review.json",
                HERE / "catalog_remaining_bulk_status.py", HERE / "catalog_remaining_normal_export.py",
                HERE / "catalog_remaining_legacy_material.py"]
    receipt = {
        "schema": 1, "date": "2026-09-29",
        "scope": "all 1025 base species after 48 additional shiny-recovery pair approvals",
        "base_species_total": 1025,
        "approved_base_species": 687,
        "approved_with_mega_profiles": 688,
        "remaining_base_species": 338,
        "counts": dict(counts),
        "runtime_approved": False,
        "release_approved": False,
        "published": False,
        "evidence_sha256": {str(path.relative_to(ROOT)): sha(path) for path in evidence},
        "entries": rows,
    }
    output = HERE / "catalog_remaining_bulk_status.json"
    output.write_text(json.dumps(receipt, indent=2) + "\n")
    print("REMAINING_BULK_STATUS", dict(counts))


if __name__ == "__main__":
    main()
