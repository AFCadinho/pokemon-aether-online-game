#!/usr/bin/env python3
"""Verify retained evidence and write the compact checked-in local receipt."""
import argparse
import copy
import os
from pathlib import Path
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from shared_model_qualification_evidence_check import read, sha, reconcile, retained_check, reference_reconciliation, frozen_commit_check
from check_shared_model_reference_variation import inspect


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Use assigned slot-env")
    directory = args.run.resolve()
    directory.relative_to(ROOT / ".tmp")
    target = ROOT / "tools/shared_model_qualification_results.json"
    assert not target.exists(), "Do not replace a committed receipt implicitly"
    report = read(directory / "report.json")
    reconcile(report, read(ROOT / "data/model_pair_catalog.json"))
    for name, digest in report["inputs"].items():
        assert sha(ROOT / name) == digest
    report["qualified_source_commit"] = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report["evidence_tools"] = {name: sha(ROOT / name) for name in [
        "tools/collect_shared_model_qualification.py", "tools/check_shared_model_reference_variation.py",
        "tests/shared_model_qualification_evidence_check.py", "tests/shared_model_reference_repeat.gd",
        "tests/shared_model_qualification_comparator_check.py", "tests/shared_model_catalog_metadata_check.py",
        "tests/shared_model_catalog_binding_check.gd"]}
    frozen_commit_check(report)
    physical = retained_check(directory, report, read(ROOT / "data/model_pair_catalog.json"))
    artifacts = {"report.json": sha(directory / "report.json"), "configuration.json": sha(directory / "configuration.json")}
    holds = {}
    for pointer in sorted(directory.glob("batch-*.receipt.json")):
        receipt = read(pointer)
        batch = Path(receipt["directory"])
        for path in [pointer, batch / "receipt.json", batch / "input.json", batch / "actors.json", batch / "render/report.json"]:
            artifacts[str(path.relative_to(directory))] = sha(path)
        fixture = read(batch / "input.json")
        render = read(batch / "render/report.json")
        for row in receipt["render"]:
            if not row["pixels_exact"]:
                holds[row["identity"]] = (next(m for m in fixture["models"] if m["identity"] == row["identity"]),
                                          next(r for r in render["records"] if r["identity"] == row["identity"]))
    variation = read(directory / "reference-variation/report.json")
    assert variation["complete"] and variation["original_verdicts_preserved"] and variation["zero_pixel_tolerance"]
    assert {r["identity"] for r in variation["records"]} == set(holds)
    extras = []
    for row in variation["records"]:
        model, rendered = holds[row["identity"]]
        path = Path(row["reference_report"]).resolve()
        path.relative_to(directory)
        assert inspect(path, rendered, model) == row
        artifacts[str(path.relative_to(directory))] = sha(path)
        for sidecar in [path.parent.parent / "input.json", path.parent.parent / "receipt.json"]:
            artifacts[str(sidecar.relative_to(directory))] = sha(sidecar)
        stored = copy.deepcopy(row)
        stored["reference_report"] = str(path.relative_to(directory))
        extras.append(stored)
    artifacts["reference-variation/report.json"] = sha(directory / "reference-variation/report.json")
    accepted = {r["identity"] for r in report["records"] if r["pixels_exact"]}
    accepted.update(r["identity"] for r in extras if r["all_held_frames_reproduced_by_unchanged_source"])
    report.update({"run_report_sha256": sha(directory / "report.json"), "artifact_sha256": artifacts,
                   "physical_evidence": physical, "reference_variation": extras,
                   "qualified_appearances": len(accepted),
                   "qualified_pairs": sum(identity in accepted and identity + "@shiny" in accepted
                                          for identity in {i.removesuffix("@shiny") for i in accepted})})
    reference_reconciliation(report)
    import json
    rows = report.pop("records")
    target.write_text(json.dumps(report, indent=2)[:-2] + ',\n  "records": [\n' +
                      ',\n'.join('    ' + json.dumps(r, sort_keys=True, separators=(',', ':')) for r in rows) + '\n  ]\n}\n')
    print("SHARED_MODEL_QUALIFICATION_COLLECTED", physical, "qualified_pairs=", report["qualified_pairs"],
          "qualified_appearances=", report["qualified_appearances"], "primary_holds=", len(holds))


if __name__ == "__main__":
    main()
