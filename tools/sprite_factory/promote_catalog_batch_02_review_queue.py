#!/usr/bin/env python3
"""Admit the two reviewed batch-02 follow-up pairs to local registries only."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = Path(__file__).with_name("catalog_production_batch_02_review_queue_approval.json")
NORMAL = ROOT / ".tmp/catalog-production-02-runtime/report.json"
MOTION = ROOT / ".tmp/catalog-production-02-battle-calibration-2026-09-26/motion-candidates.json"
BUNDLES = ROOT / ".tmp/catalog-production-02-review-queue-bundles-2026-09-26/asset-index.json"
INSTALLED = ROOT / ".tmp/catalog-production-02-review-queue-install-2026-09-26/generations/cd7106afae367812f90779c29165e0f8dd9289c549d2ecfdd285b0d05e995c50/runtime-catalog.json"
GAME = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
LAUNCHER = ROOT / "launcher/data/reviewed_model_catalog.json"
SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
SHINY = {
    "bronzong": ROOT / ".tmp/catalog-production-02-bronzong-shiny-runtime-2026-09-26/report.json",
    "shroomish": ROOT / ".tmp/catalog-production-02-held-shiny-runtime-2026-09-26/report.json",
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    decision = json.loads(EVIDENCE.read_text())
    rows = decision["entries"]
    names = {row["species"] for row in rows}
    if (decision.get("schema") != 1 or decision.get("runtime_approved") is not True
            or decision.get("release_approved") is not True or decision.get("published") is not False
            or names != set(SHINY) or len(rows) != len(names)
            or sha256(BUNDLES) != decision["bundle_index_sha256"]
            or sha256(INSTALLED) != decision["bundle_install_catalog_sha256"]):
        raise ValueError("review-queue approval or bundle index changed")
    if GAME.read_bytes() != LAUNCHER.read_bytes():
        raise ValueError("game and launcher registries differ")
    registry = json.loads(GAME.read_text())
    screened = json.loads(SCREENED.read_text())
    if len(registry["profiles"]) != 152 or len(registry["models"]) != 304:
        raise ValueError("unexpected previous registry size")
    normals = {row["species"]: row for row in json.loads(NORMAL.read_text())}
    motions = json.loads(MOTION.read_text())["motion"]
    assets = {asset["species_id"]: asset for asset in json.loads(BUNDLES.read_text())["assets"]}
    if set(assets) != names:
        raise ValueError("bundle species differ from approved pairs")
    for approval in rows:
        name = approval["species"]
        if approval["visual_review"] != "user_approved_normal_shiny_idle_attack_sleep_faint":
            raise ValueError("visual review is missing")
        base = normals[name]
        rare = json.loads(SHINY[name].read_text())[0]
        if (rare["species"] != name + "@shiny" or base["runtime_sha256"] != approval["normal_scn_sha256"]
                or rare["runtime_sha256"] != approval["shiny_scn_sha256"]
                or rare["glb_sha256"] != approval["shiny_glb_sha256"]
                or base["action_timing"] != rare["action_timing"]
                or motions[name]["sha256"] != base["glb_sha256"]):
            raise ValueError(f"source identity, timing or pose changed: {name}")
        motion_root = ROOT / f".tmp/catalog-production-02-{'bronzong-shiny' if name == 'bronzong' else 'held-shiny'}-motion-2026-09-26"
        stress_root = ROOT / f".tmp/catalog-production-02-{name}-pair-stress-2026-09-26"
        page = ROOT / f".tmp/catalog-production-02-{name}-review-2026-09-26/index.html"
        if (sha256(motion_root / "review.json") != approval["motion_review_sha256"]
                or sha256(stress_root / "stress.json") != approval["stress_report_sha256"]
                or sha256(page) != approval["visual_page_sha256"]):
            raise ValueError(f"review evidence changed: {name}")
        stress = json.loads((stress_root / "stress.json").read_text())
        if not stress.get("complete") or len(stress["rounds"]) != 3 or any(
                round_["pairs"] != 1 or round_["faint_replacements"] != 1 for round_ in stress["rounds"]):
            raise ValueError(f"battle stress incomplete: {name}")
        if name in registry["profiles"] or name in screened["profiles"]:
            raise ValueError(f"profile already registered: {name}")
        profile_motion = {**motions[name], "sha256": base["runtime_sha256"]}
        placement = {"scale": profile_motion["scale"], "yaw_degrees": profile_motion["yaw_degrees"]}
        grounding = {**placement, "lift": profile_motion["lift"], "sha256": base["runtime_sha256"]}
        registry["profiles"][name] = {"action_timing": base["action_timing"],
                                      "placement": placement, "grounding": grounding,
                                      "motion": profile_motion}
        appearances = {item["runtime_identity"]: item for item in assets[name]["appearances"]}
        for identity, scene in ((name, base), (name + "@shiny", rare)):
            path = Path(scene["runtime_path"])
            if (identity in registry["models"] or identity in screened["models"]
                    or path.is_symlink() or not path.is_file() or sha256(path) != scene["runtime_sha256"]
                    or appearances[identity]["runtime_sha256"] != scene["runtime_sha256"]):
                raise ValueError(f"scene or bundle identity changed: {identity}")
            registry["models"][identity] = {"sha256": scene["runtime_sha256"],
                                            "glb_sha256": scene["glb_sha256"], "profile": name}
    registry["catalog_batch_02_review_queue_approval_sha256"] = sha256(EVIDENCE)
    encoded = (json.dumps(registry, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()
    GAME.write_bytes(encoded)
    LAUNCHER.write_bytes(encoded)
    print("CATALOG_BATCH_02_REVIEW_QUEUE_APPROVED pairs=2 scenes=4")


if __name__ == "__main__":
    main()
