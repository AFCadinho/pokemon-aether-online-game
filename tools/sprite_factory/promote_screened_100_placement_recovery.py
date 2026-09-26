#!/usr/bin/env python3
"""Admit six previously held normal/shiny pairs after measured battle recovery."""
from __future__ import annotations

import json
import math
from pathlib import Path

try:
    from .run_screened_100_pair_stress import sources
    from .screened_100_battle_candidates import PRODUCTION, sha256
except ImportError:
    from run_screened_100_pair_stress import sources
    from screened_100_battle_candidates import PRODUCTION, sha256


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / ".tmp/screened-100-placement-fix"
APPROVAL = ROOT / "tools/sprite_factory/screened_100_placement_recovery.json"
BASELINE = ROOT / "tools/sprite_factory/screened_100_battle_qualification.json"
GAME_APPROVED = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
GAME_SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
LAUNCHER_APPROVED = ROOT / "launcher/data/reviewed_model_catalog.json"
LAUNCHER_SCREENED = ROOT / "launcher/data/screened_model_catalog.json"


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()


def verified_recovery() -> tuple[list[str], dict, dict]:
    approval = json.loads(APPROVAL.read_text())
    baseline = json.loads(BASELINE.read_text())
    report_path = EVIDENCE / "validated-report.json"
    motion_path = EVIDENCE / "motion.json"
    stress_path = EVIDENCE / "stress.json"
    log_path = EVIDENCE / "stress.log"
    report = json.loads(report_path.read_text())
    motion = json.loads(motion_path.read_text())
    stress = json.loads(stress_path.read_text())
    log = log_path.read_text()
    names = approval.get("approved_species", [])
    held = {row["species"] for row in baseline["entries"] if row["status"] == "held"}
    if (approval.get("schema") != 1 or approval.get("scope") != "screened_100_placement_recovery"
            or any(approval.get(key) is not True for key in ("visual_approved", "runtime_approved", "release_approved"))
            or approval.get("published") is not False or len(names) != 6 or set(names) != held
            or approval.get("baseline_qualification_sha256") != sha256(BASELINE)
            or approval.get("validated_placement_report_sha256") != sha256(report_path)
            or approval.get("motion_sha256") != sha256(motion_path)
            or approval.get("battle_stress_sha256") != sha256(stress_path)
            or approval.get("battle_stress_log_sha256") != sha256(log_path)
            or report.get("complete") is not True or [row["species"] for row in report["entries"]] != names
            or set(motion) != set(names) or stress.get("complete") is not True
            or stress.get("species") != names or len(stress.get("rounds", [])) != 3
            or "BATCH01_STRESS_OK" not in log or "SCRIPT ERROR" in log or "ERROR:" in log):
        raise ValueError("placement recovery evidence is incomplete or changed")
    production = {row["species"]: row for row in json.loads(PRODUCTION.read_text())["entries"]
                  if row["status"] == "technical_candidate"}
    for row, pinned in zip(report["entries"], approval["entries"], strict=True):
        name = row["species"]
        idle = min(shot["screen_rect"][3] for shot in row["shots"] if shot["action"] == "idle")
        clearance = min(clip["minimum_y"] for clip in row["corrected_clearance_120hz"].values())
        baked = motion[name]
        if (pinned["species"] != name or row["glb_sha256"] != production[name]["normal_glb_sha256"]
                or pinned["normal_glb_sha256"] != row["glb_sha256"]
                or len(row["shots"]) != 16
                or any(not shot["in_view"] or shot["model_overlaps_hud_proxy"] for shot in row["shots"])
                or idle < 60 or clearance < .02
                or pinned["minimum_idle_pixels"] != round(idle, 3)
                or pinned["minimum_120hz_clearance"] != round(clearance, 6)
                or pinned["battle_views"] != 16
                or not math.isclose(pinned["scale"], row["scale"])
                or not math.isclose(pinned["lift"], row["candidate_lift"])
                or not math.isclose(baked["scale"], row["scale"])
                or not math.isclose(baked["lift"], row["candidate_lift"], abs_tol=1e-5)
                or baked["sha256"] != row["glb_sha256"]):
            raise ValueError(f"placement recovery failed: {name}")
    if [row["arena"] for row in stress["rounds"]] != ["classic", "stadium", "classic"]:
        raise ValueError("battle arena coverage changed")
    for round_data in stress["rounds"]:
        dispatch = max((span["ms"] for span in round_data["load_spans"]
                        if span["operation"] == "threaded load dispatch/collect"), default=0)
        if (round_data["pairs"] != 6 or round_data["faint_replacements"] != 6
                or not 0 < round_data["frame_p95_ms"] <= 20 or dispatch > 1000 / 60
                or round_data["retained_source_bytes"] > 64 * 1024 * 1024
                or any(stall["ms"] > 100 and not stall["covered"]
                       for stall in round_data["stalls_over_50ms"])):
            raise ValueError("battle stress exceeded the accepted limits")
    if stress["rounds"][2]["static_bytes"] - stress["rounds"][1]["static_bytes"] >= 1024 * 1024:
        raise ValueError("battle stress retained memory")
    if approval["battle_stress_p95_max_ms"] != round(max(row["frame_p95_ms"] for row in stress["rounds"]), 3):
        raise ValueError("battle stress receipt changed")
    sources(names)  # Verify both scene files against their production hashes.
    return names, production, motion


def promote() -> int:
    names, production, motion = verified_recovery()
    if GAME_APPROVED.read_bytes() != LAUNCHER_APPROVED.read_bytes():
        raise ValueError("approved game/launcher registries differ")
    if GAME_SCREENED.read_bytes() != LAUNCHER_SCREENED.read_bytes():
        raise ValueError("screened game/launcher registries differ")
    approved = json.loads(GAME_APPROVED.read_text())
    screened = json.loads(GAME_SCREENED.read_text())
    if (len(approved["models"]) != 152 or len(approved["profiles"]) != 76
            or len(screened["models"]) != 20 or len(screened["profiles"]) != 20):
        raise ValueError("unexpected catalog before placement recovery")
    for name in names:
        source = production[name]
        normal_hash = source["normal_scn_sha256"]
        shiny_hash = source["shiny_scn_sha256"]
        if (screened["models"].get(name, {}).get("sha256") != normal_hash
                or name in approved["models"] or name + "@shiny" in approved["models"]):
            raise ValueError(f"catalog collision or changed scene: {name}")
        profile = screened["profiles"].pop(name)
        baked = dict(motion[name])
        placement = {"scale": baked["scale"], "yaw_degrees": baked["yaw_degrees"]}
        profile["placement"] = placement
        profile["grounding"] = {**placement, "lift": baked["lift"], "sha256": normal_hash}
        profile["motion"] = {**baked, "sha256": normal_hash}
        approved["profiles"][name] = profile
        normal = screened["models"].pop(name)
        normal["profile"] = name
        approved["models"][name] = normal
        approved["models"][name + "@shiny"] = {
            "sha256": shiny_hash, "glb_sha256": source["shiny_glb_sha256"], "profile": name}
    if (len(approved["models"]) != 164 or len(approved["profiles"]) != 82
            or len(screened["models"]) != 14 or len(screened["profiles"]) != 14):
        raise ValueError("placement recovery changed an unrelated catalog entry")
    approved["screened_100_placement_recovery_sha256"] = sha256(APPROVAL)
    for path in (GAME_APPROVED, LAUNCHER_APPROVED):
        path.write_bytes(encoded(approved))
    for path in (GAME_SCREENED, LAUNCHER_SCREENED):
        path.write_bytes(encoded(screened))
    return len(names)


if __name__ == "__main__":
    print(f"Promoted {promote()} recovered normal/shiny pairs")
