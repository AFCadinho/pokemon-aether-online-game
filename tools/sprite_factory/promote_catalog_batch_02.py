#!/usr/bin/env python3
"""Add the visually accepted batch-02 pairs to local reviewed registries."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REVIEW = ROOT / "tools/sprite_factory/catalog_production_batch_02_battle_visual_review.json"
APPROVAL = ROOT / "tools/sprite_factory/catalog_production_batch_02_approval.json"
QUALIFICATION = ROOT / "tools/sprite_factory/catalog_production_batch_02_battle_qualification.json"
PREFLIGHT = ROOT / "tools/sprite_factory/catalog_production_batch_02_bundle_preflight.json"
NORMAL = ROOT / ".tmp/catalog-production-02-runtime/report.json"
SHINY = ROOT / ".tmp/catalog-production-02-shiny-runtime-2026-09-26/report.json"
MOTION = ROOT / ".tmp/catalog-production-02-battle-calibration-2026-09-26/motion-candidates.json"
SLEEP_MOTION = ROOT / ".tmp/catalog-production-02-sleep-calibration-2026-09-26/motion-candidates.json"
GAME_APPROVED = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
LAUNCHER_APPROVED = ROOT / "launcher/data/reviewed_model_catalog.json"
GAME_SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
LAUNCHER_SCREENED = ROOT / "launcher/data/screened_model_catalog.json"


def sha256(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def promote() -> None:
    approval = json.loads(APPROVAL.read_text())
    qualification = json.loads(QUALIFICATION.read_text())
    review = json.loads(REVIEW.read_text())
    preflight = json.loads(PREFLIGHT.read_text())
    pairs = {row["species"]: row for row in qualification["entries"]
             if row["status"] == "paired_battle_screen_passed_visual_review_pending"}
    if (approval.get("schema") != 1 or approval.get("runtime_approved") is not True
            or approval.get("release_approved") is not True or approval.get("published") is not False
            or len(pairs) != 69 or set(approval.get("approved_species", [])) != set(pairs)
            or approval.get("qualification_sha256") != sha256(QUALIFICATION)
            or approval.get("visual_review_sha256") != sha256(REVIEW)
            or approval.get("bundle_preflight_sha256") != sha256(PREFLIGHT)
            or preflight.get("status") != "local_candidate_bundle_preflight_passed"
            or preflight.get("bundle_count") != 69
            or not set(pairs).issubset(set(review.get("species", [])))):
        raise ValueError("batch-02 approval is incomplete or stale")
    if GAME_APPROVED.read_bytes() != LAUNCHER_APPROVED.read_bytes():
        raise ValueError("approved game/launcher snapshots differ")
    if GAME_SCREENED.read_bytes() != LAUNCHER_SCREENED.read_bytes():
        raise ValueError("screened game/launcher snapshots differ")
    registry = json.loads(GAME_APPROVED.read_text())
    screened = json.loads(GAME_SCREENED.read_text())
    if len(registry["profiles"]) != 83 or len(registry["models"]) != 166:
        raise ValueError("unexpected previous approval registry")
    normals = {row["species"]: row for row in json.loads(NORMAL.read_text())}
    shinies = {row["species"].removesuffix("@shiny"): row for row in json.loads(SHINY.read_text())}
    motion = json.loads(MOTION.read_text())["motion"] | json.loads(SLEEP_MOTION.read_text())["motion"]
    for name, pair in pairs.items():
        base = normals[name]
        rare = shinies[name]
        if base["runtime_sha256"] != pair["normal_scn_sha256"] or rare["runtime_sha256"] != pair["shiny_scn_sha256"]:
            raise ValueError(f"scene report differs: {name}")
        if base["action_timing"] != rare["action_timing"] or motion[name]["sha256"] != base["glb_sha256"]:
            raise ValueError(f"pair timing or motion differs: {name}")
        profile_motion = dict(motion[name])
        profile_motion["sha256"] = base["runtime_sha256"]
        placement = {"scale": profile_motion["scale"], "yaw_degrees": profile_motion["yaw_degrees"]}
        grounding = {**placement, "lift": profile_motion["lift"], "sha256": base["runtime_sha256"]}
        if name in registry["profiles"] or name in screened["profiles"]:
            raise ValueError(f"profile already exists: {name}")
        registry["profiles"][name] = {"action_timing": base["action_timing"], "placement": placement,
                                       "grounding": grounding, "motion": profile_motion}
        for identity, row in ((name, base), (name + "@shiny", rare)):
            if identity in registry["models"] or identity in screened["models"]:
                raise ValueError(f"model already exists: {identity}")
            path = Path(row["runtime_path"])
            if path.is_symlink() or not path.is_file() or sha256(path) != row["runtime_sha256"]:
                raise ValueError(f"scene bytes changed: {identity}")
            registry["models"][identity] = {"sha256": row["runtime_sha256"],
                                            "glb_sha256": row["glb_sha256"], "profile": name}
    registry["catalog_batch_02_approval_sha256"] = sha256(APPROVAL)
    content = encoded(registry)
    GAME_APPROVED.write_bytes(content)
    LAUNCHER_APPROVED.write_bytes(content)
    print(f"Approved {len(pairs)} local normal/shiny pairs; 10 shiny-material holds remain")


if __name__ == "__main__":
    promote()
