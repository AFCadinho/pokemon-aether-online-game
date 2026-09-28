"""Pin exact local normal candidates and the remaining source review queue."""

import argparse
import hashlib
import json
from pathlib import Path


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(inventory, probes, exports, runtimes):
    source_rows = inventory["entries"]
    probe_rows = {row["species"]: row for row in probes["entries"]}
    export_rows = {row["species"]: row for row in exports["entries"]}
    runtime_rows = {row["species"]: row for row in runtimes["entries"]}
    if (len(source_rows) != inventory["remaining_species_count"]
            or len(probe_rows) != inventory["legacy_source_found_count"]
            or len(export_rows) != len(probe_rows)
            or len(runtime_rows) != exports["exported"]):
        raise ValueError("Incomplete or duplicated pipeline status")
    result = []
    for row in source_rows:
        species = row["species"]
        record = {"species": species, "national_dex": row["national_dex"],
                  "runtime_approved": False, "release_approved": False,
                  "shiny_status": "not_built"}
        source = row["legacy_source"]
        if source is None:
            record.update(status="source_missing")
        else:
            record["source"] = source
            probe, exported = probe_rows[species], export_rows[species]
            if exported["status"] == "exported":
                runtime = runtime_rows[species]
                if runtime["status"] != "converted":
                    raise ValueError(f"Exported scene not converted: {species}")
                export_report = json.loads(Path(exported["report"]).read_text())
                runtime_report = json.loads(Path(runtime["report"]).read_text())
                if len(runtime_report) != 1 or runtime_report[0]["species"] != species:
                    raise ValueError(f"Runtime identity mismatch: {species}")
                runtime_data = runtime_report[0]
                if (digest(export_report["path"]) != export_report["glb_sha256"]
                        or digest(runtime_data["runtime_path"]) != runtime_data["runtime_sha256"]
                        or runtime_data["glb_sha256"] != export_report["glb_sha256"]
                        or runtime_data["source_sha256"] != json.loads(
                            Path(exported["report"]).with_name("job.json").read_text())["source_sha256"]):
                    raise ValueError(f"Scene or source receipt mismatch: {species}")
                record.update(status="normal_technical_candidate", source_sha256=runtime_data["source_sha256"],
                              normal_glb_sha256=export_report["glb_sha256"],
                              normal_scene_sha256=runtime_data["runtime_sha256"],
                              normal_scene_path=runtime_data["runtime_path"],
                              actions=sorted(export_report["animations"]))
            else:
                record.update(status="review_hold", stage="source" if probe["status"] != "probed"
                              else "normal_export", reason=exported.get("reason", "unknown"))
        result.append(record)
    counts = {status: sum(row["status"] == status for row in result)
              for status in ("normal_technical_candidate", "review_hold", "source_missing")}
    if counts != {"normal_technical_candidate": exports["exported"],
                  "review_hold": exports["held"] + exports["blocked"],
                  "source_missing": inventory["legacy_source_missing_count"]}:
        raise ValueError("Pipeline counts do not reconcile")
    return {"schema": 1, "scope": "local_normal_diagnostics_not_catalog_approval",
            "base_species_total": inventory["canonical_species_count"],
            "existing_base_species": inventory["existing_base_species_count"],
            "remaining_base_species": len(result), "counts": counts,
            "runtime_approved": False, "release_approved": False, "published": False,
            "entries": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("inventory", "probes", "exports", "runtimes", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    report = build(*(json.loads(getattr(args, name).read_text())
                     for name in ("inventory", "probes", "exports", "runtimes")))
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(report["counts"])


if __name__ == "__main__":
    main()
