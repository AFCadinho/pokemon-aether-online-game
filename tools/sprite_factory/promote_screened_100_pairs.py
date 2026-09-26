#!/usr/bin/env python3
"""Admit battle-qualified pairs after user approval and local bundle preflight."""
from __future__ import annotations

import json
from pathlib import Path

try:
    from .screened_100_battle_candidates import PRODUCTION, sha256
except ImportError:
    from screened_100_battle_candidates import PRODUCTION, sha256


ROOT = Path(__file__).resolve().parents[2]
APPROVAL = ROOT / "tools/sprite_factory/screened_100_battle_approval.json"
QUALIFICATION = ROOT / "tools/sprite_factory/screened_100_battle_qualification.json"
PREFLIGHT = ROOT / "tools/sprite_factory/screened_100_bundle_preflight.json"
MOTION = ROOT / ".tmp/screened-100-battle-approval/motion-v2.json"
GAME_APPROVED = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
GAME_SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
LAUNCHER_APPROVED = ROOT / "launcher/data/reviewed_model_catalog.json"
LAUNCHER_SCREENED = ROOT / "launcher/data/screened_model_catalog.json"


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def promote() -> int:
    approval = json.loads(APPROVAL.read_text())
    qualification = json.loads(QUALIFICATION.read_text())
    preflight = json.loads(PREFLIGHT.read_text())
    motion = json.loads(MOTION.read_text())
    production = {row["species"]: row for row in json.loads(PRODUCTION.read_text())["entries"]
                  if row["status"] == "technical_candidate"}
    selected = {row["species"]: row for row in qualification["entries"]
                if row["status"] == "battle_qualified" and row["runtime_approved"] is True}
    if (approval.get("schema") != 1 or approval.get("visual_approved") is not True
            or approval.get("runtime_approved") is not True or approval.get("release_approved") is not True
            or approval.get("published") is not False or len(selected) != qualification.get("qualified")
            or len(selected) != preflight.get("bundle_count")
            or set(approval.get("approved_species", [])) != set(selected)
            or approval.get("qualification_sha256") != sha256(QUALIFICATION)
            or approval.get("bundle_preflight_sha256") != sha256(PREFLIGHT)
            or approval.get("motion_sha256") != sha256(MOTION)
            or preflight.get("qualification_sha256") != sha256(QUALIFICATION)
            or preflight.get("status") != "local_candidate_bundle_preflight_passed"
            or qualification.get("production_sha256") != sha256(PRODUCTION)
            or qualification.get("runtime_approved") is not True
            or qualification.get("release_approved") is not False):
        raise ValueError("screened-100 approval is incomplete or stale")
    if GAME_APPROVED.read_bytes() != LAUNCHER_APPROVED.read_bytes():
        raise ValueError("approved game/launcher snapshots differ")
    if GAME_SCREENED.read_bytes() != LAUNCHER_SCREENED.read_bytes():
        raise ValueError("screened game/launcher snapshots differ")
    approved = json.loads(GAME_APPROVED.read_text())
    screened = json.loads(GAME_SCREENED.read_text())
    if (len(approved["models"]) != 42 or len(approved["profiles"]) != 21
            or len(screened["models"]) != 75 or len(screened["profiles"]) != 75):
        raise ValueError("expected existing 21 approved pairs and 75 screened normals")
    for name, row in sorted(selected.items()):
        candidate = production[name]
        normal_hash = candidate["normal_scn_sha256"]
        shiny_hash = candidate["shiny_scn_sha256"]
        if (row["normal_scn_sha256"] != normal_hash or row["shiny_scn_sha256"] != shiny_hash
                or screened["models"].get(name, {}).get("sha256") != normal_hash
                or name + "@shiny" in approved["models"] or name in approved["models"]):
            raise ValueError(f"scene pin or admission collision: {name}")
        profile = screened["profiles"].pop(name)
        baked = dict(motion["motion"][name])
        if baked["sha256"] != candidate["normal_glb_sha256"]:
            raise ValueError(f"motion source changed: {name}")
        placement = {"scale": baked["scale"], "yaw_degrees": baked["yaw_degrees"]}
        profile["placement"] = placement
        profile["grounding"] = {**placement, "lift": baked["lift"], "sha256": normal_hash}
        profile["motion"] = {**baked, "sha256": normal_hash}
        approved["profiles"][name] = profile
        normal = screened["models"].pop(name)
        normal["profile"] = name
        approved["models"][name] = normal
        approved["models"][name + "@shiny"] = {
            "sha256": shiny_hash, "glb_sha256": candidate["shiny_glb_sha256"], "profile": name}
    if (len(approved["models"]) != 42 + 2 * len(selected)
            or len(approved["profiles"]) != 21 + len(selected)
            or len(screened["models"]) != 75 - len(selected)
            or len(screened["profiles"]) != 75 - len(selected)):
        raise ValueError("promotion did not preserve unrelated models")
    approved["screened_100_battle_approval_sha256"] = sha256(APPROVAL)
    screened["limitations"] = ["remaining candidates have only visual screening and normal forms",
                               "no arena grounding or motion-clearance approval",
                               "not an approved or portable launcher pack"]
    for path in (GAME_APPROVED, LAUNCHER_APPROVED):
        path.write_bytes(encoded(approved))
    for path in (GAME_SCREENED, LAUNCHER_SCREENED):
        path.write_bytes(encoded(screened))
    return len(selected)


if __name__ == "__main__":
    print(f"Promoted {promote()} normal/shiny pairs to exact reviewed hashes")
