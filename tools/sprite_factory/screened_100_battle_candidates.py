"""Prepare hash-bound placement and motion candidates for the screened cohort.

This reads offline Godot measurements. It does not admit or publish a model.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

try:
    from .bake_motion_placement import bake
except ImportError:
    from bake_motion_placement import bake


ROOT = Path(__file__).resolve().parents[2]
PRODUCTION = ROOT / "tools/sprite_factory/screened_100_shiny_production_results.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def entries(reports: list[Path]) -> tuple[dict[str, dict], dict[str, str]]:
    expected = {row["species"]: row for row in json.loads(PRODUCTION.read_text())["entries"]
                if row["status"] == "technical_candidate"}
    if len(expected) != 61:
        raise ValueError("expected the 61 paired technical candidates")
    measured: dict[str, dict] = {}
    sources: dict[str, str] = {}
    for path in reports:
        report = json.loads(path.read_text())
        if (report.get("complete") is not True or report.get("runtime_approved") is not False
                or report.get("sample_hz") != 60):
            raise ValueError(f"incomplete placement report: {path}")
        sources[str(path.resolve())] = sha256(path)
        for row in report["entries"]:
            name = row["species"]
            if name not in expected:
                if name == "dragonite" and row.get("status") == "control":
                    continue
                raise ValueError(f"unexpected measured species: {name}")
            if name in measured or row.get("glb_sha256") != expected[name]["normal_glb_sha256"]:
                raise ValueError(f"duplicate or changed measured GLB: {name}")
            measured[name] = row
    if set(measured) != set(expected):
        raise ValueError(f"missing placement measurements: {sorted(set(expected) - set(measured))}")
    return measured, sources


def readability(reports: list[Path]) -> dict:
    measured, sources = entries(reports)
    scales = {}
    for name, row in measured.items():
        shots = [shot for shot in row["shots"] if shot["action"] == "idle"]
        if len(shots) != 4 or not all(math.isfinite(shot["screen_rect"][3])
                                       and shot["screen_rect"][3] > 0 for shot in shots):
            raise ValueError(f"incomplete idle camera views: {name}")
        minimum = min(shot["screen_rect"][3] for shot in shots)
        scales[name] = min(4.0, 66.0 / minimum) if minimum < 60.0 else 1.0
    return {"schema": 1, "runtime_approved": False, "production_sha256": sha256(PRODUCTION),
            "report_sha256": sources, "readability": scales, "motion": {}, "motion_holds": {}}


def motion(reports: list[Path], candidate_path: Path) -> dict:
    measured, sources = entries(reports)
    candidates = json.loads(candidate_path.read_text())
    if (candidates.get("production_sha256") != sha256(PRODUCTION)
            or set(candidates.get("readability", {})) != set(measured)):
        raise ValueError("readability candidate changed")
    profiles, holds = {}, {}
    for name, row in measured.items():
        if not math.isclose(float(row["scale"]), float(candidates["readability"][name]),
                            rel_tol=1e-4, abs_tol=1e-4):
            holds[name] = "Measured scale differs from readability candidate"
            continue
        try:
            data = dict(row, idle_verified=True, sha256=row["glb_sha256"])
            profiles.update(bake({"review_schema": 1, "errors": [], "entries": {name: data}}, [name]))
        except (ValueError, KeyError) as error:
            holds[name] = str(error)
    return {"schema": 1, "runtime_approved": False, "production_sha256": sha256(PRODUCTION),
            "readability_sha256": sha256(candidate_path), "report_sha256": sources,
            "readability": candidates["readability"], "motion": profiles, "motion_holds": holds}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=("readability", "motion"))
    parser.add_argument("output", type=Path)
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument("--candidate", type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("output must be new")
    if args.stage == "motion" and args.candidate is None:
        parser.error("motion requires --candidate")
    result = readability(args.reports) if args.stage == "readability" else motion(args.reports, args.candidate)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(f"{args.stage}: {len(result['readability'])} measured, {len(result.get('motion_holds', {}))} held")


if __name__ == "__main__":
    main()
