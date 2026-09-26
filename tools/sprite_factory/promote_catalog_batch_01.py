#!/usr/bin/env python3
"""Move the visually approved batch-01 pairs from screened to approved hashes."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
APPROVAL = ROOT / "tools/sprite_factory/catalog_production_batch_01_approval.json"
QUALIFICATION = ROOT / "tools/sprite_factory/catalog_production_batch_01_shiny_qualification.json"
PREFLIGHT = ROOT / "tools/sprite_factory/catalog_production_batch_01_bundle_preflight.json"
GAME_APPROVED = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
GAME_SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
LAUNCHER_APPROVED = ROOT / "launcher/data/reviewed_model_catalog.json"
LAUNCHER_SCREENED = ROOT / "launcher/data/screened_model_catalog.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def promote() -> None:
    approval = json.loads(APPROVAL.read_text())
    qualification = json.loads(QUALIFICATION.read_text())
    preflight = json.loads(PREFLIGHT.read_text())
    species = {row["species"]: row for row in qualification["entries"]}
    if (approval.get("schema") != 1 or approval.get("runtime_approved") is not True
            or approval.get("release_approved") is not True or approval.get("published") is not False
            or len(species) != 14 or set(approval.get("approved_species", [])) != set(species)
            or approval.get("qualification_sha256") != sha256(QUALIFICATION)
            or approval.get("bundle_preflight_sha256") != sha256(PREFLIGHT)
            or preflight.get("status") != "local_candidate_bundle_preflight_passed"
            or preflight.get("bundle_count") != 14
            or set(approval.get("held_shiny_species", [])) != {row["species"] for row in qualification["material_holds"]}):
        raise ValueError("batch-01 approval is incomplete or stale")
    if GAME_APPROVED.read_bytes() != LAUNCHER_APPROVED.read_bytes():
        raise ValueError("approved game/launcher snapshots differ")
    if GAME_SCREENED.read_bytes() != LAUNCHER_SCREENED.read_bytes():
        raise ValueError("screened game/launcher snapshots differ")
    approved = json.loads(GAME_APPROVED.read_text())
    screened = json.loads(GAME_SCREENED.read_text())
    if (len(approved["models"]) != 14 or len(approved["profiles"]) != 7
            or set(screened.get("catalog_batch_01_pairs", [])) != set(species)):
        raise ValueError("expected the original seven approvals and 14 screened pairs")
    for name, row in species.items():
        for identity, expected in ((name, row["normal_scn_sha256"]),
                                   (name + "@shiny", row["shiny_scn_sha256"])):
            model = screened["models"].pop(identity)
            if model["sha256"] != expected or model["profile"] != name or identity in approved["models"]:
                raise ValueError(f"screened identity mismatch: {identity}")
            approved["models"][identity] = model
        profile = screened["profiles"].pop(name)
        if name in approved["profiles"] or profile["motion"]["sha256"] != row["normal_scn_sha256"]:
            raise ValueError(f"screened profile mismatch: {name}")
        approved["profiles"][name] = profile
    if len(screened["models"]) != 75 or len(screened["profiles"]) != 75:
        raise ValueError("unrelated screened catalog changed")
    approved["catalog_batch_01_approval_sha256"] = sha256(APPROVAL)
    screened.pop("catalog_batch_01_pairs")
    screened.pop("catalog_batch_01_qualification_sha256")
    screened["normal_only"] = True
    screened["limitations"] = ["visual screening only", "normal forms only",
        "no arena grounding calibration", "no motion-clearance calibration",
        "not an approved or portable launcher pack"]
    for path in (GAME_APPROVED, LAUNCHER_APPROVED):
        path.write_bytes(encode(approved))
    for path in (GAME_SCREENED, LAUNCHER_SCREENED):
        path.write_bytes(encode(screened))
    print(f"Approved {len(species)} normal/shiny pairs; original 75 screened identities retained")


if __name__ == "__main__":
    promote()
