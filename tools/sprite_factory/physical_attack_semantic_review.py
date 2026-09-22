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


def compile_human_review(export_path: Path, catalog_path: Path,
                         species: set[str],
                         explicit_confirmations: set[str] | None = None) -> dict:
    """Validate confirmed browser choices and bind both clips to exact evidence."""
    explicit_confirmations = explicit_confirmations or set()
    if not explicit_confirmations <= species:
        raise ValueError("Explicit confirmations must be part of the selected species")
    exported = json.loads(export_path.read_text())
    catalog = json.loads(catalog_path.read_text())
    if exported.get("runtime_approved") is not False:
        raise ValueError("Human review export must remain runtime_approved=false")
    exported_entries = exported.get("entries", {})
    missing = sorted(species - set(exported_entries))
    if missing:
        raise ValueError("Human review is missing species: " + ", ".join(missing))
    catalog_entries = {entry["species"]: entry for entry in catalog.get("entries", [])
                       if entry.get("status") == "review_ready"}
    unavailable = sorted(species - set(catalog_entries))
    if unavailable:
        raise ValueError("Review evidence is missing species: " + ", ".join(unavailable))
    root = catalog_path.parent
    compiled = {}
    for name in sorted(species):
        exported_entry = exported_entries[name]
        explicitly_confirmed = name in explicit_confirmations
        if exported_entry.get("status") != "confirmed" and not explicitly_confirmed:
            raise ValueError(f"Human review is not confirmed for {name}")
        catalog_entry = catalog_entries[name]
        report_path = root / catalog_entry["report"]
        job = json.loads((report_path.parent / "job.json").read_text())
        clips = {}
        for action in ("physical_attack", "physical_attack_2"):
            choice = exported_entry.get("clips", {}).get(action, {})
            family = choice.get("family")
            if family not in FAMILIES or (not choice.get("confirmed") and not explicitly_confirmed):
                raise ValueError(f"Invalid or unconfirmed {action} choice for {name}")
            loop_path = report_path.parent / catalog_entry["loops"][action]
            source_action = job.get("actions", {}).get(action)
            if not source_action or not loop_path.is_file():
                raise ValueError(f"Missing {action} evidence for {name}")
            clips[action] = {
                "family": family,
                "source": "human_review",
                "source_action": source_action,
                "review_loop_sha256": file_sha256(loop_path),
            }
        compiled[name] = {
            "status": "confirmed",
            "confirmation_source": ("explicit_user_followup" if explicitly_confirmed
                                    else "browser_checkbox"),
            "note": exported_entry.get("note", ""),
            "prepared_sha256": job.get("prepared_sha256"),
            "clips": clips,
        }
    return {
        "schema": 1,
        "scope": "confirmed_human_review_evidence_not_runtime_mapping",
        "runtime_approved": False,
        "source_catalog_scope": catalog.get("scope"),
        "counts": {"total": len(compiled)},
        "entries": compiled,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--decisions", type=Path, default=Path(__file__).with_name(
        "physical_attack_semantic_decisions.json"))
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--human-review", type=Path,
                        help="browser-exported review-decisions.json to validate")
    parser.add_argument("--human-only",
                        help="comma-separated confirmed species to import")
    parser.add_argument("--human-confirm", default="",
                        help="comma-separated pending rows explicitly confirmed in follow-up")
    parser.add_argument("--human-output", type=Path)
    args = parser.parse_args()
    if bool(args.human_review) != bool(args.human_only) or bool(args.human_review) != bool(args.human_output):
        parser.error("--human-review, --human-only and --human-output must be used together")
    if args.human_review:
        selected = {value.strip() for value in args.human_only.split(",") if value.strip()}
        explicitly_confirmed = {value.strip() for value in args.human_confirm.split(",")
                                if value.strip()}
        if not selected:
            parser.error("--human-only must select at least one species")
        human = compile_human_review(args.human_review, args.catalog, selected,
                                     explicitly_confirmed)
        args.human_output.write_text(json.dumps(human, indent=2) + "\n")
    result = compile_review(args.decisions, args.catalog)
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")


if __name__ == "__main__":
    main()
