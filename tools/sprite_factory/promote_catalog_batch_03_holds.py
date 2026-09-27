#!/usr/bin/env python3
"""Admit the 25 reviewed batch-03 hold recoveries to the local registries."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / ".tmp/catalog-production-03-clear-holds-2026-09-27"
APPROVAL = HERE / "catalog_production_batch_03_hold_recovery_approval.json"
GAME = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
LAUNCHER = ROOT / "launcher/data/reviewed_model_catalog.json"
NORMAL = (
    WORK / "meloetta-runtime/report.json",
    WORK / "eyelid-runtime/report.json",
    WORK / "dynamic-runtime/report.json",
    WORK / "sand-runtime/report.json",
    WORK / "transparent-eight-runtime-v2/report.json",
    WORK / "transparent-mimikyu-runtime-v2/report.json",
)
SHINY = (
    WORK / "meloetta-shiny-runtime/report.json",
    WORK / "eyelid-shiny-runtime/report.json",
    WORK / "dynamic-shiny-runtime/report.json",
    WORK / "sand-shiny-runtime/report.json",
    WORK / "braviary-shiny-runtime/report.json",
    WORK / "skrelp-shiny-runtime/report.json",
    WORK / "transparent-eight-shiny-runtime-v2/report.json",
    WORK / "transparent-mimikyu-shiny-runtime-v2/report.json",
)
PRIOR_NORMAL = {
    "braviary": ROOT / ".tmp/catalog-production-03-source-recovery-runtime-2026-09-27/report.json",
    "skrelp": ROOT / ".tmp/catalog-production-03-runtime-2026-09-27/report.json",
}
MOTION = (
    WORK / "meloetta-motion-profile.json",
    WORK / "battle-candidates.json",
    WORK / "battle-ten-motion-profiles.json",
    WORK / "battle-nine-motion-profiles.json",
)
PRIOR_MOTION = {
    "braviary": ROOT / ".tmp/catalog-production-03-source-recovery-final-candidates-2026-09-27.json",
    "skrelp": ROOT / ".tmp/catalog-production-03-battle-final-candidates-2026-09-27.json",
}
INDEX = WORK / "hold-recovery-bundles/asset-index.json"
CATALOG = WORK / "hold-recovery-candidate-catalog.json"


def digest(path: Path) -> str:
    with path.open("rb") as source:
        h = hashlib.sha256()
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def selected_rows(paths: tuple[Path, ...], variant: str) -> dict[str, dict]:
    rows: dict[str, dict] = {}
    for path in paths:
        for row in json.loads(path.read_text()):
            name = row["species"].removesuffix("@shiny")
            if (name in rows or row.get("runtime_approved") is not False
                    or (row.get("variant") == "shiny") != (variant == "shiny")):
                raise ValueError(f"duplicate or invalid {variant} source: {name}")
            rows[name] = row
    return rows


def promote() -> None:
    approval = json.loads(APPROVAL.read_text())
    names = approval["approved_species"]
    selected = set(names)
    if (approval.get("schema") != 1 or approval.get("runtime_approved") is not True
            or approval.get("published") is not False or len(names) != 25
            or len(selected) != 25 or names != sorted(names)
            or approval.get("source_pair_visual_feedback") != "Allemaal goed"
            or approval.get("battle_visual_feedback") != "Allemaal goed"):
        raise ValueError("visual approval or exact 25-species selection missing")
    for relative, expected in approval["evidence_sha256"].items():
        if digest(ROOT / relative) != expected:
            raise ValueError("approval evidence changed: " + relative)
    nine = json.loads((WORK / "battle-nine-runtime-calibrated-v2/battle-review.json").read_text())
    if (nine.get("complete") is not True or nine.get("runtime_catalog_sha256") is None
            or {row["species"] for row in nine["entries"] if row["species"] != "dragonite"}
            != set(json.loads((WORK / "battle-nine-motion-profiles.json").read_text())["motion"])):
        raise ValueError("transparent battle measurement incomplete")
    for row in nine["entries"]:
        if row["species"] == "dragonite":
            continue
        if (min(clip["minimum_y"] for clip in row["corrected_clearance_120hz"].values()) < 0
                or any(not shot["in_view"] or shot["model_overlaps_hud_proxy"] for shot in row["shots"])):
            raise ValueError("transparent battle pose failed: " + row["species"])
    stressed: set[str] = set()
    uncovered_contexts: list[str] = []
    for relative in approval["battle_stress_reports"]:
        report = json.loads((ROOT / relative).read_text())
        species = report.get("species", [])
        if (report.get("complete") is not True or len(report.get("rounds", [])) != 3
                or set(species) & stressed or any(
                    round_["pairs"] != len(species) or round_["faint_replacements"] != len(species)
                    or round_["frame_p95_ms"] > 25.0 for round_ in report["rounds"])):
            raise ValueError("paired battle stress incomplete: " + relative)
        for round_ in report["rounds"]:
            uncovered = [stall for stall in round_["stalls_over_50ms"] if not stall["covered"]]
            if (len(uncovered) > 1 or any(stall["ms"] > 400.0 or
                    stall["context"] not in {"load axew", "load drizzile"} for stall in uncovered)):
                raise ValueError("unexpected uncovered frame stall: " + relative)
            uncovered_contexts.extend(stall["context"] for stall in uncovered)
        stressed.update(species)
    if (stressed != selected or sorted(uncovered_contexts) !=
            ["load axew"] * 3 + ["load drizzile"] * 3):
        raise ValueError("paired battle stress differs from approval")
    reversed_pair = json.loads((WORK / "stress-reversed-pair.json").read_text())
    if (reversed_pair.get("complete") is not True or reversed_pair.get("species") != ["axew", "avalugg"]
            or len(reversed_pair.get("rounds", [])) != 3 or any(
                not stall["covered"] for round_ in reversed_pair["rounds"]
                for stall in round_["stalls_over_50ms"])):
        raise ValueError("shader warmup comparison changed")
    index = json.loads(INDEX.read_text())
    if (index.get("catalog_revision") != "catalog-batch-03-hold-recovery-v1"
            or len(index.get("assets", [])) != 25
            or {asset["species_id"] for asset in index["assets"]} != selected):
        raise ValueError("candidate bundle index changed")
    for asset in index["assets"]:
        archive = INDEX.parent / Path(asset["object_key"]).name
        if digest(archive) != asset["sha256"] or archive.stat().st_size != asset["size_bytes"]:
            raise ValueError("candidate bundle changed: " + asset["species_id"])
    installed = Path(approval["installed_catalog"])
    if digest(installed) != approval["installed_catalog_sha256"]:
        raise ValueError("installed catalog changed")
    installed_rows = {row["species"] + ("@shiny" if row["variant"] == "shiny" else ""): row
                      for row in json.loads(installed.read_text())}
    if len(installed_rows) != 50:
        raise ValueError("candidate install incomplete")
    normal = selected_rows(NORMAL, "normal")
    if len(normal) != 23 or set(normal) & set(PRIOR_NORMAL):
        raise ValueError("unexpected dedicated normal reports")
    for name, path in PRIOR_NORMAL.items():
        matches = [row for row in json.loads(path.read_text()) if row["species"] == name]
        if len(matches) != 1:
            raise ValueError("missing prior normal source: " + name)
        normal[name] = matches[0]
    shiny = selected_rows(SHINY, "shiny")
    if set(normal) != selected or set(shiny) != selected:
        raise ValueError("source pair set differs from approval")
    profiles: dict[str, dict] = {}
    for path in MOTION:
        data = json.loads(path.read_text())
        if data.get("runtime_approved") is not False or data.get("motion_holds"):
            raise ValueError("motion report has holds: " + str(path))
        for name, profile in data["motion"].items():
            if name in profiles:
                raise ValueError("duplicate motion profile: " + name)
            profiles[name] = profile
    for name, path in PRIOR_MOTION.items():
        profiles[name] = json.loads(path.read_text())["motion"][name]
    if set(profiles) != selected:
        raise ValueError("motion profiles differ from approval")
    if GAME.read_bytes() != LAUNCHER.read_bytes():
        raise ValueError("game and launcher registries differ")
    registry = json.loads(GAME.read_text())
    assets = {asset["species_id"]: asset for asset in index["assets"]}
    candidate_rows = {row["species"] + ("@shiny" if row["variant"] == "shiny" else ""): row
                      for row in json.loads(CATALOG.read_text())["entries"]}
    if len(candidate_rows) != 50:
        raise ValueError("candidate source catalog incomplete")
    for name in names:
        base, rare, profile = normal[name], shiny[name], profiles[name]
        if (name in registry["profiles"] or base["action_timing"] != rare["action_timing"]
                or profile["sha256"] != base["glb_sha256"]):
            raise ValueError("timing or profile identity changed: " + name)
        appearances = {row["runtime_identity"]: row for row in assets[name]["appearances"]}
        if len(appearances) != 2:
            raise ValueError("bundle pair incomplete: " + name)
        for identity, row in ((name, base), (name + "@shiny", rare)):
            scene = Path(row["runtime_path"])
            if (identity in registry["models"] or digest(scene) != row["runtime_sha256"]
                    or candidate_rows[identity]["runtime_sha256"] != row["runtime_sha256"]
                    or appearances[identity]["runtime_sha256"] != row["runtime_sha256"]
                    or installed_rows[identity]["runtime_sha256"] != row["runtime_sha256"]):
                raise ValueError("scene identity changed: " + identity)
            registry["models"][identity] = {"sha256": row["runtime_sha256"],
                                             "glb_sha256": row["glb_sha256"], "profile": name}
        placement = {"scale": profile["scale"], "yaw_degrees": profile["yaw_degrees"]}
        registry["profiles"][name] = {
            "action_timing": base["action_timing"], "placement": placement,
            "grounding": {**placement, "lift": profile["lift"], "sha256": base["runtime_sha256"]},
            "motion": {**profile, "sha256": base["runtime_sha256"]},
        }
    registry["catalog_batch_03_hold_recovery_approval_sha256"] = digest(APPROVAL)
    encoded = (json.dumps(registry, indent=2, sort_keys=True, allow_nan=False) + "\n").encode()
    GAME.write_bytes(encoded)
    LAUNCHER.write_bytes(encoded)
    print("CATALOG_BATCH_03_HOLDS_APPROVED pairs=25 scenes=50")


if __name__ == "__main__":
    promote()
