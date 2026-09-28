#!/usr/bin/env python3
"""Admit the 200 fully reviewed batch-04 pairs to the local runtime registries."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

try:
    from .run_catalog_batch_04_main_stress import action_timings, profiles, selections
except ImportError:
    from run_catalog_batch_04_main_stress import action_timings, profiles, selections


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / ".tmp/batch04-main"
HERE = Path(__file__).resolve().parent
APPROVAL = HERE / "catalog_production_batch_04_main_approval.json"
GAME = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
LAUNCHER = ROOT / "launcher/data/reviewed_model_catalog.json"
SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
SCREENED_LAUNCHER = ROOT / "launcher/data/screened_model_catalog.json"
INDEX = WORK / "candidate-bundles-v2/asset-index.json"
STRESS = WORK / "battle-stress-full-v2"
INSTALL = WORK / "candidate-install-individual-v2"


def read(path: Path):
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def promote() -> None:
    approval = read(APPROVAL)
    names, selected, _ = selections()
    if (approval.get("schema") != 1 or approval.get("runtime_approved") is not True
            or approval.get("release_approved") is not True or approval.get("published") is not False
            or approval.get("approved_species") != names or len(names) != 200):
        raise ValueError("batch-04 main admission decision is incomplete")
    for relative, expected in approval["evidence_sha256"].items():
        if digest(ROOT / relative) != expected:
            raise ValueError("approval evidence changed: " + relative)
    feedback = read(WORK / "final-appearance-review-v2/user-feedback.json")
    if (feedback.get("visual_review") != "accepted"
            or feedback.get("receipt_sha256") != digest(WORK / "final-appearance-review-v2/receipt.json")
            or len(read(WORK / "final-appearance-review-v2/receipt.json")["species"]) != 147):
        raise ValueError("final normal/shiny appearance review is missing")
    review = read(HERE / "catalog_production_batch_04_main_review.json")
    previously_accepted = {entry["species"] for entry in review["appearance_acceptances"]}
    final_reviewed = set(read(WORK / "final-appearance-review-v2/receipt.json")["species"])
    if previously_accepted | final_reviewed | {"floragato"} != set(names):
        raise ValueError("appearance review does not cover all pairs")
    index = read(INDEX)
    assets = {asset["species_id"]: asset for asset in index["assets"]}
    if (digest(INDEX) != approval["bundle_index_sha256"] or len(assets) != 200
            or set(assets) != set(names)):
        raise ValueError("individual bundle index is incomplete")
    for name in names:
        asset = assets[name]
        archive = INDEX.parent / Path(asset["object_key"]).name
        if archive.stat().st_size != asset["size_bytes"] or digest(archive) != asset["sha256"]:
            raise ValueError("bundle archive changed: " + name)
        appearances = {row["runtime_identity"]: row for row in asset["appearances"]}
        for variant in ("normal", "shiny"):
            identity = name + ("@shiny" if variant == "shiny" else "")
            if appearances[identity]["runtime_sha256"] != selected[name][variant + "_scn_sha256"]:
                raise ValueError("bundle appearance changed: " + identity)
    installed_path = INSTALL / "installed-catalog.json"
    if digest(installed_path) != approval["installed_catalog_sha256"]:
        raise ValueError("launcher installed catalog changed")
    installed = {(row["species"], row["variant"]): row for row in read(installed_path)}
    if len(installed) != 400:
        raise ValueError("installed catalog is incomplete")
    for name in names:
        for variant in ("normal", "shiny"):
            row = installed[name, variant]
            if (row["runtime_sha256"] != selected[name][variant + "_scn_sha256"]
                    or digest(Path(row["runtime_path"])) != row["runtime_sha256"]):
                raise ValueError("installed scene changed: " + name + " " + variant)
    stressed = set()
    for number in range(1, 26):
        path = STRESS / f"group-{number:02d}/stress.json"
        data = read(path)
        if (not data.get("complete") or len(data.get("rounds", [])) != 3
                or data["species"] != names[(number - 1) * 8:number * 8]
                or any(round_["pairs"] != len(data["species"])
                       or round_["faint_replacements"] != len(data["species"])
                       for round_ in data["rounds"])):
            raise ValueError("real battle stress is incomplete: " + str(path))
        stressed.update(data["species"])
    if stressed != set(names):
        raise ValueError("real battle coverage differs from candidate set")
    if GAME.read_bytes() != LAUNCHER.read_bytes() or SCREENED.read_bytes() != SCREENED_LAUNCHER.read_bytes():
        raise ValueError("game and launcher catalog snapshots differ")
    registry = read(GAME)
    screened = read(SCREENED)
    placement = profiles(selected)
    timing = action_timings(selected)
    for name in names:
        if name in registry["profiles"]:
            raise ValueError("species already registered: " + name)
        if name in screened["profiles"]:
            if name not in screened["models"] or name + "@shiny" in screened["models"]:
                raise ValueError("unexpected screened appearance: " + name)
            del screened["profiles"][name]
            del screened["models"][name]
        profile = placement[name]
        pose = {"scale": profile["scale"], "yaw_degrees": profile["yaw_degrees"]}
        scene_hash = selected[name]["normal_scn_sha256"]
        registry["profiles"][name] = {
            "action_timing": timing[name], "placement": pose,
            "grounding": {**pose, "lift": profile["lift"], "sha256": scene_hash},
            "motion": {**profile, "sha256": scene_hash},
        }
        for variant in ("normal", "shiny"):
            identity = name + ("@shiny" if variant == "shiny" else "")
            if identity in registry["models"] or identity in screened["models"]:
                raise ValueError("appearance already registered: " + identity)
            registry["models"][identity] = {
                "sha256": selected[name][variant + "_scn_sha256"],
                "glb_sha256": selected[name][variant + "_glb_sha256"], "profile": name,
            }
    registry["catalog_batch_04_main_approval_sha256"] = digest(APPROVAL)
    payload = json.dumps(registry, indent=2, sort_keys=True, allow_nan=False) + "\n"
    GAME.write_text(payload)
    LAUNCHER.write_text(payload)
    screened_payload = json.dumps(screened, indent=2, sort_keys=True, allow_nan=False) + "\n"
    SCREENED.write_text(screened_payload)
    SCREENED_LAUNCHER.write_text(screened_payload)
    print("CATALOG_BATCH_04_MAIN_APPROVED pairs=200 scenes=400")


if __name__ == "__main__":
    promote()
