#!/usr/bin/env python3
"""Close the 61-pair technical gate from measured placement and battle stress."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from .screened_100_battle_candidates import PRODUCTION, sha256
except ImportError:
    from screened_100_battle_candidates import PRODUCTION, sha256


def qualify(preflight_path: Path, stress_dir: Path) -> dict:
    preflight = json.loads(preflight_path.read_text())
    production = json.loads(PRODUCTION.read_text())
    if (preflight.get("runtime_approved") is not False or len(preflight.get("entries", [])) != 61
            or preflight.get("production_sha256") != sha256(PRODUCTION)
            or production.get("paired_technical_candidates") != 61):
        raise ValueError("screened production or placement preflight changed")
    ready = [row["species"] for row in preflight["entries"] if row["status"] == "ready_for_battle_stress"]
    reports = []
    for index, start in enumerate(range(0, len(ready), 10), 1):
        group = ready[start:start + 10]
        catalog_path = stress_dir / f"stress-{index:02d}-catalog.json"
        report_path = stress_dir / f"stress-{index:02d}.json"
        log_path = stress_dir / f"stress-{index:02d}.log"
        report = json.loads(report_path.read_text())
        log = log_path.read_text()
        if (report.get("complete") is not True or report.get("screenshots_enabled") is not False
                or report.get("species") != group or report.get("catalog_sha256") != sha256(catalog_path)
                or len(report.get("rounds", [])) != 3 or "BATCH01_STRESS_OK" not in log
                or "SCRIPT ERROR" in log or "ERROR:" in log):
            raise ValueError(f"incomplete battle stress: {index}")
        if [row["arena"] for row in report["rounds"]] != ["classic", "stadium", "classic"]:
            raise ValueError(f"arena coverage changed: {index}")
        for round_data in report["rounds"]:
            dispatch = max((span["ms"] for span in round_data["load_spans"]
                            if span["operation"] == "threaded load dispatch/collect"), default=0)
            if (round_data["pairs"] != len(group) or round_data["faint_replacements"] != len(group)
                    or not 0 < round_data["frame_p95_ms"] <= 20 or dispatch > 1000 / 60
                    or round_data["retained_source_bytes"] > 64 * 1024 * 1024
                    or any(stall["ms"] > 100 and not stall["covered"]
                           for stall in round_data["stalls_over_50ms"])):
                raise ValueError(f"performance/lifecycle hold in stress {index}, {round_data['arena']}")
        growth = report["rounds"][2]["static_bytes"] - report["rounds"][1]["static_bytes"]
        if growth >= 1024 * 1024:
            raise ValueError(f"repeated battle memory growth in stress {index}")
        reports.append({"species": group, "catalog_sha256": sha256(catalog_path),
                        "stress_sha256": sha256(report_path), "log_sha256": sha256(log_path),
                        "p95_max_ms": round(max(row["frame_p95_ms"] for row in report["rounds"]), 3),
                        "static_growth_bytes": growth})
    rows = []
    for row in preflight["entries"]:
        accepted = row["species"] in ready
        rows.append({**row, "status": "battle_qualified" if accepted else "held",
                     "runtime_approved": accepted})
    return {"schema": 1, "scope": "screened_100_normal_shiny_battle_qualification",
            "runtime_approved": True, "release_approved": False,
            "visual_review_basis": "user confirmed prior review and authorized approval if system checks pass",
            "production_sha256": sha256(PRODUCTION), "preflight_sha256": sha256(preflight_path),
            "qualified": len(ready), "held": len(rows) - len(ready), "stress_groups": reports,
            "entries": rows}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("preflight", type=Path)
    parser.add_argument("stress_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError("output must be new")
    result = qualify(args.preflight, args.stress_dir)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Battle-qualified {result['qualified']} pairs; held {result['held']}")


if __name__ == "__main__":
    main()
