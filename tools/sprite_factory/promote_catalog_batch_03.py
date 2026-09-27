#!/usr/bin/env python3
"""Admit the exactly reviewed batch-03 pairs to local game/launcher registries."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DECISION = HERE / "catalog_production_batch_03_approval.json"
REVIEW = HERE / "catalog_production_batch_03_exception_review.json"
PREFLIGHT = HERE / "catalog_production_batch_03_bundle_preflight.json"
INDEX = ROOT / ".tmp/catalog-production-03-candidate-bundles-2026-09-27/asset-index.json"
NORMAL_REPORTS = (
    ROOT / ".tmp/catalog-production-03-runtime-2026-09-27/report.json",
    ROOT / ".tmp/catalog-production-03-source-recovery-runtime-2026-09-27/report.json",
)
SHINY_REPORTS = (
    ROOT / ".tmp/catalog-production-03-shiny-runtime-2026-09-27/report.json",
    ROOT / ".tmp/catalog-production-03-shiny-held-runtime-2026-09-27/report.json",
    ROOT / ".tmp/catalog-production-03-source-recovery-shiny-runtime-2026-09-27/report.json",
)
MOTION_REPORTS = (
    ROOT / ".tmp/catalog-production-03-battle-final-candidates-2026-09-27.json",
    ROOT / ".tmp/catalog-production-03-source-recovery-final-candidates-2026-09-27.json",
)
GAME = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
LAUNCHER = ROOT / "launcher/data/reviewed_model_catalog.json"
SCREENED_GAME = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
SCREENED_LAUNCHER = ROOT / "launcher/data/screened_model_catalog.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def rows(paths: tuple[Path, ...]) -> dict[str, dict]:
    result = {}
    for path in paths:
        for row in json.loads(path.read_text()):
            name = row["species"].removesuffix("@shiny")
            if name in result or row.get("runtime_approved") is not False:
                raise ValueError("duplicate or approved source report: " + name)
            result[name] = row
    return result


def promote() -> None:
    decision = json.loads(DECISION.read_text())
    review = json.loads(REVIEW.read_text())
    preflight = json.loads(PREFLIGHT.read_text())
    index = json.loads(INDEX.read_text())
    names = decision.get("approved_species", [])
    selected = set(names)
    installed_path = Path(decision.get("installed_catalog", ""))
    if (decision.get("schema") != 1 or decision.get("runtime_approved") is not True
            or decision.get("release_approved") is not True or decision.get("published") is not False
            or len(names) != 75 or len(selected) != 75 or sha256(REVIEW) != decision.get("review_sha256")
            or sha256(PREFLIGHT) != decision.get("preflight_sha256")
            or sha256(INDEX) != decision.get("bundle_index_sha256")
            or not installed_path.is_file() or sha256(installed_path) != decision.get("installed_catalog_sha256")
            or preflight.get("status") != "local_candidate_bundle_preflight_passed"
            or preflight.get("bundle_count") != 75 or preflight.get("launcher_install_scenes_loaded") != 150
            or not preflight.get("launcher_no_op") or not preflight.get("launcher_restart")
            or index.get("catalog_revision") != "catalog-batch-03-candidate-v1"
            or len(index.get("assets", [])) != 75):
        raise ValueError("batch-03 approval evidence is incomplete or stale")
    if (review["original_65_battle"]["battle_gallery_feedback"] != "Allemaal goed"
            or review["battle_visual_feedback"] != "Allemaal goed"
            or review["shiny_pair_feedback"] != "Allemaal goed"
            or review["source_review_feedback"] != "Allemaal goed"
            or review["paired_battle_stress"]["species"] != 75
            or not review["paired_battle_stress"]["complete"]):
        raise ValueError("human visual or real battle qualification is missing")
    stress_names = set()
    for number in range(1, 9):
        path = ROOT / f".tmp/catalog-production-03-pair-stress-group-{number:02d}-2026-09-27/stress.json"
        if sha256(path) != review["artifacts_sha256"][str(path.relative_to(ROOT))]:
            raise ValueError("battle stress report changed")
        data = json.loads(path.read_text())
        if (not data.get("complete") or len(data.get("rounds", [])) != 3
                or any(r["pairs"] != len(data["species"]) or
                       r["faint_replacements"] != len(data["species"]) or
                       any(not s["covered"] for s in r["stalls_over_50ms"])
                       for r in data["rounds"])):
            raise ValueError("battle stress report incomplete")
        if stress_names.intersection(data["species"]):
            raise ValueError("duplicate battle stress species")
        stress_names.update(data["species"])
    if stress_names != selected:
        raise ValueError("battle stress species differ from approval")
    if GAME.read_bytes() != LAUNCHER.read_bytes() or SCREENED_GAME.read_bytes() != SCREENED_LAUNCHER.read_bytes():
        raise ValueError("game and launcher snapshots differ")
    registry = json.loads(GAME.read_text())
    screened = json.loads(SCREENED_GAME.read_text())
    if len(registry["profiles"]) != 154 or len(registry["models"]) != 308:
        raise ValueError("unexpected previous approval registry")
    normal, shiny = rows(NORMAL_REPORTS), rows(SHINY_REPORTS)
    if len(normal) != 80 or set(shiny) != selected:
        raise ValueError("source scenes differ from selected pair set")
    motion = {}
    for path in MOTION_REPORTS:
        data = json.loads(path.read_text())
        if data.get("runtime_approved") is not False or data.get("motion_holds"):
            raise ValueError("unresolved placement hold")
        for name, profile in data["motion"].items():
            if name in motion:
                raise ValueError("duplicate placement profile")
            motion[name] = profile
    if set(motion) != set(normal):
        raise ValueError("placement profiles differ from normal scenes")
    assets = {asset["species_id"]: asset for asset in index["assets"]}
    if set(assets) != selected:
        raise ValueError("bundle species differ from approval")
    for asset in assets.values():
        archive = INDEX.parent / Path(asset["object_key"]).name
        if (not archive.is_file() or archive.stat().st_size != asset["size_bytes"]
                or sha256(archive) != asset["sha256"]):
            raise ValueError("bundle archive changed: " + asset["species_id"])
    installed = {row["species"] + ("@shiny" if row["variant"] == "shiny" else ""): row
                 for row in json.loads(installed_path.read_text())}
    if len(installed) != 150:
        raise ValueError("installed catalog is incomplete")
    for name in names:
        base, rare = normal[name], shiny[name]
        profile = motion[name]
        if (base["action_timing"] != rare["action_timing"] or profile["sha256"] != base["glb_sha256"]
                or name in registry["profiles"] or name in screened["profiles"]):
            raise ValueError("profile, timing or GLB identity changed: " + name)
        placement = {"scale": profile["scale"], "yaw_degrees": profile["yaw_degrees"]}
        grounding = {**placement, "lift": profile["lift"], "sha256": base["runtime_sha256"]}
        registry["profiles"][name] = {
            "action_timing": base["action_timing"], "placement": placement,
            "grounding": grounding, "motion": {**profile, "sha256": base["runtime_sha256"]},
        }
        appearances = {entry["runtime_identity"]: entry for entry in assets[name]["appearances"]}
        if len(appearances) != 2:
            raise ValueError("bundle appearance pair incomplete: " + name)
        for identity, scene in ((name, base), (name + "@shiny", rare)):
            path = Path(scene["runtime_path"])
            if (identity in registry["models"] or identity in screened["models"]
                    or path.is_symlink() or not path.is_file() or sha256(path) != scene["runtime_sha256"]
                    or appearances[identity]["runtime_sha256"] != scene["runtime_sha256"]
                    or installed[identity]["runtime_sha256"] != scene["runtime_sha256"]):
                raise ValueError("scene, bundle or installed identity changed: " + identity)
            registry["models"][identity] = {"sha256": scene["runtime_sha256"],
                                             "glb_sha256": scene["glb_sha256"], "profile": name}
    registry["catalog_batch_03_approval_sha256"] = sha256(DECISION)
    content = (json.dumps(registry, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()
    GAME.write_bytes(content)
    LAUNCHER.write_bytes(content)
    print("CATALOG_BATCH_03_APPROVED pairs=75 scenes=150")


if __name__ == "__main__":
    promote()
