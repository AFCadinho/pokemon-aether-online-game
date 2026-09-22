"""Bind human physical-attack labels to reproducible, non-runtime evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

from physical_attack_review import FAMILIES


STATUSES = ("reviewed_candidate", "needs_human_review")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def compile_review(decisions_path: Path, catalog_path: Path) -> dict:
    decisions = json.loads(decisions_path.read_text())
    catalog = json.loads(catalog_path.read_text())
    if decisions.get("runtime_approved") is not False:
        raise ValueError("Semantic review must remain runtime_approved=false")
    catalog_entries = {entry["species"]: entry for entry in catalog.get("entries", [])
                       if entry.get("status") == "review_ready"}
    entries = decisions.get("entries", {})
    if set(entries) != set(catalog_entries):
        missing = sorted(set(catalog_entries) - set(entries))
        extra = sorted(set(entries) - set(catalog_entries))
        raise ValueError(f"Decision/catalog species mismatch: missing={missing}, extra={extra}")
    root = catalog_path.parent
    compiled = {}
    for species in sorted(entries):
        decision = entries[species]
        family = decision.get("family")
        status = decision.get("status")
        if family not in FAMILIES:
            raise ValueError(f"Unsupported family for {species}: {family}")
        if status not in STATUSES:
            raise ValueError(f"Unsupported status for {species}: {status}")
        if (family == "unclear") != (status == "needs_human_review"):
            raise ValueError(f"Unclear/status invariant failed for {species}")
        catalog_entry = catalog_entries[species]
        report_path = root / catalog_entry["report"]
        job_path = report_path.parent / "job.json"
        loop_path = report_path.parent / catalog_entry["loops"]["physical_attack_2"]
        job = json.loads(job_path.read_text())
        action = job.get("actions", {}).get("physical_attack_2")
        if not action or not loop_path.is_file():
            raise ValueError(f"Missing alternate evidence for {species}")
        compiled[species] = {
            **decision,
            "source_action": action,
            "prepared_sha256": job.get("prepared_sha256"),
            "review_loop_sha256": file_sha256(loop_path),
        }
    return {
        "schema": 1,
        "scope": decisions["scope"],
        "runtime_approved": False,
        "reviewed_action": "physical_attack_2",
        "source_catalog_scope": catalog.get("scope"),
        "counts": {
            "total": len(compiled),
            "statuses": dict(sorted(Counter(item["status"] for item in compiled.values()).items())),
            "families": dict(sorted(Counter(item["family"] for item in compiled.values()).items())),
        },
        "entries": compiled,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--decisions", type=Path, default=Path(__file__).with_name(
        "physical_attack_semantic_decisions.json"))
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = compile_review(args.decisions, args.catalog)
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
