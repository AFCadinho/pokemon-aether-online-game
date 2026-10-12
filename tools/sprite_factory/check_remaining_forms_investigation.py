"""Check investigation coverage/provenance without admitting any model."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORT = Path(__file__).with_name("remaining_forms_investigation.json")


def read(path):
    return json.loads(path.read_text())


def check_pin(record):
    path = ROOT / record["path"]
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != record["sha256"]:
        raise ValueError("Evidence changed: " + str(path))
    return path


def validate(report):
    previous = read(check_pin(report["previous_result"]))
    evidence = read(check_pin(report["evidence"]))
    held = {r["species"]: r for r in previous["entries"] if r["status"] == "held"}
    rows = report["entries"]
    names = [r["species"] for r in rows]
    if len(names) != 53 or len(set(names)) != 53 or set(names) != set(held):
        raise ValueError("Audit must cover each of the exact 53 holds once")
    if dict(Counter(r["category"] for r in rows)) != report["summary"]:
        raise ValueError("Category totals differ from entries")
    if any(report[k] is not False for k in ("runtime_approved", "release_approved", "published")) or report["prepared_pairs_added"] != 0:
        raise ValueError("Research is not runtime qualification")
    for row in rows:
        if row["runtime_approved"] is not False or row["status"] != "investigated_not_qualified":
            raise ValueError("Research entry incorrectly claims qualification")
        if row["previous_stage"] != held[row["species"]]["stage"]:
            raise ValueError("Previous hold was rewritten")
        if not all(row.get(k) for k in ("finding", "next_step", "evidence")):
            raise ValueError("Missing per-form investigation")
        for reference in row["evidence"]:
            if reference.split("/")[0] not in evidence:
                raise ValueError("Unknown evidence section: " + reference)
    by_name = {r["species"]: r for r in rows}
    for name, pm, count in (("poltchageist-artisan", "pm1133", 77), ("sinistcha-masterpiece", "pm1134", 128)):
        if by_name[name]["resource_candidate"] != pm + "_12_00":
            raise ValueError("Tea source mapping regressed")
        comparison = evidence["skeleton_comparisons"][pm]
        if comparison["bone_counts"] != [count, count] or not all(comparison[k] for k in (
                "bone_records_equal", "other_skeleton_fields_equal", "only_transform_names_differ")):
            raise ValueError("Tea skeleton compatibility not established")
        if any(c["rig_indices"] != [-1, -1] for c in comparison["transform_changes"]):
            raise ValueError("Tea comparison renamed a skeletal bone")
    for pm in ("pm0382", "pm0383"):
        if evidence["skeleton_comparisons"][pm]["bone_records_equal"]:
            raise ValueError("Primal source mismatch was lost")
    for pm in ("pm0824", "pm0917", "pm0865", "pm1120", "pm1133", "pm1134"):
        family = evidence["families"][pm]
        if any(family[k] for k in ("sv_archive_motion_count", "sv_archive_sidechannel_count", "za_archive_motion_count")):
            raise ValueError("Source inventory changed; reconsider missing-channel findings")
    return evidence


def verify_local(value, seen):
    if isinstance(value, dict):
        if set(value) >= {"path", "sha256"}:
            key = (value["path"], value["sha256"])
            if key not in seen:
                check_pin(value)
                seen.add(key)
        for child in value.values():
            verify_local(child, seen)
    elif isinstance(value, list):
        for child in value:
            verify_local(child, seen)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, default=REPORT)
    parser.add_argument("--verify-local-evidence", action="store_true")
    args = parser.parse_args()
    evidence = validate(read(args.report))
    checked = set()
    if args.verify_local_evidence:
        verify_local(evidence, checked)
    print(f"PASS: exact 53-form coverage, tea mapping and source constraints; {len(checked)} local evidence pins checked; zero admissions")
