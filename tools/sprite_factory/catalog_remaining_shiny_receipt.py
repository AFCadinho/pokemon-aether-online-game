"""Pin normal/shiny diagnostics and every hold in the remaining base-species queue."""

import argparse
import hashlib
import json
from pathlib import Path

from phase5_variant_parity import compare


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def unique_rows(rows):
    by_species = {row["species"]: row for row in rows}
    if len(by_species) != len(rows):
        raise ValueError("Duplicate species in pipeline status")
    return by_species


def build(candidates, normal_root, simple_status, simple_runtime, review_status, review_runtime):
    rows = candidates["entries"]
    if len(rows) != 546 or candidates["counts"]["normal_technical_candidate"] != 297:
        raise ValueError("Remaining cohort differs from the pinned intake")
    simple = unique_rows(simple_status["entries"])
    reviewed = unique_rows(review_status["entries"])
    simple_scenes = unique_rows(simple_runtime["entries"])
    review_scenes = unique_rows(review_runtime["entries"])
    known = {row["species"] for row in rows}
    if set(simple) != known or set(reviewed) != known:
        raise ValueError("Shiny pipeline did not account for every species")
    result = []
    for row in rows:
        species = row["species"]
        record = {"species": species, "national_dex": row["national_dex"],
                  "runtime_approved": False, "release_approved": False}
        if row["status"] != "normal_technical_candidate":
            if simple[species]["status"] != "held" or reviewed[species]["status"] != "held":
                raise ValueError("Blocked normal source gained a shiny candidate: " + species)
            record.update(status=row["status"], stage=row.get("stage", "source"),
                          reason=row.get("reason", "Default-form source missing"))
            result.append(record)
            continue
        normal = normal_root / f"{row['national_dex']:04d}-{species}" / "model.glb"
        if (sha(normal) != row["normal_glb_sha256"] or
                sha(row["normal_scene_path"]) != row["normal_scene_sha256"]):
            raise ValueError("Normal candidate bytes changed: " + species)
        basic = simple[species]
        advanced = reviewed[species]
        if basic["status"] == "exported":
            if advanced["status"] != "existing_simple_shiny":
                raise ValueError("Simple shiny is missing from combined review status")
            selected, runtime = basic, simple_scenes.get(species)
        elif advanced["status"] == "exported":
            selected, runtime = advanced, review_scenes.get(species)
        else:
            if advanced["status"] != "held":
                raise ValueError("Unknown shiny status: " + species)
            record.update(status="shiny_hold", stage=advanced["stage"], reason=advanced["reason"],
                          normal_glb_sha256=row["normal_glb_sha256"],
                          normal_scene_sha256=row["normal_scene_sha256"])
            result.append(record)
            continue
        if runtime is None or runtime["status"] != "converted":
            raise ValueError("Shiny export lacks a standalone scene: " + species)
        export = json.loads(Path(selected["report"]).read_text())
        report = json.loads(Path(runtime["report"]).read_text())
        if len(report) != 1 or report[0]["species"] != species:
            raise ValueError("Shiny runtime identity differs: " + species)
        scene = report[0]
        if (export["status"] != "exported_for_review" or export.get("runtime_approved") or
                sha(export["path"]) != export["glb_sha256"] or
                scene["glb_sha256"] != export["glb_sha256"] or
                sha(scene["runtime_path"]) != scene["runtime_sha256"] or
                set(scene["action_timing"]) != set(row["actions"])):
            raise ValueError("Shiny bytes, clips, or runtime scene differ: " + species)
        parity = compare(normal, export["path"])
        if selected.get("geometry_motion_sha256") != parity:
            raise ValueError("Shiny geometry/animation parity differs: " + species)
        record.update(status="normal_shiny_technical_candidate",
                      normal_glb_sha256=row["normal_glb_sha256"],
                      normal_scene_sha256=row["normal_scene_sha256"],
                      normal_scene_path=row["normal_scene_path"],
                      shiny_glb_sha256=export["glb_sha256"],
                      shiny_scene_sha256=scene["runtime_sha256"],
                      shiny_scene_path=scene["runtime_path"],
                      geometry_motion_sha256=parity,
                      official_rare_material_sha256=export.get("official_rare_material_sha256"),
                      unrepresented_rare_parameters=export.get("unrepresented_rare_parameters", []),
                      material_limitations=export.get("material_limitations", ""),
                      actions=row["actions"])
        result.append(record)
    counts = {status: sum(row["status"] == status for row in result) for status in (
        "normal_shiny_technical_candidate", "shiny_hold", "review_hold", "source_missing")}
    expected = {"normal_shiny_technical_candidate": simple_status["exported"] + review_status["exported"],
                "shiny_hold": review_status["held"] - candidates["counts"]["review_hold"]
                - candidates["counts"]["source_missing"],
                "review_hold": candidates["counts"]["review_hold"],
                "source_missing": candidates["counts"]["source_missing"]}
    if counts != expected:
        raise ValueError("Bulk result counts do not reconcile: " + str(counts))
    return {"schema": 1, "scope": "local_normal_shiny_diagnostics_not_catalog_approval",
            "base_species_total": 1025, "remaining_base_species": 546,
            "runtime_approved": False, "release_approved": False, "published": False,
            "counts": counts, "entries": result}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("candidates", "simple_status", "simple_runtime", "review_status", "review_runtime", "output"):
        parser.add_argument("--" + name.replace("_", "-"), type=Path, required=True)
    parser.add_argument("--normal-root", type=Path, required=True)
    args = parser.parse_args()
    inputs = {name: json.loads(getattr(args, name).read_text()) for name in (
        "candidates", "simple_status", "simple_runtime", "review_status", "review_runtime")}
    report = build(inputs["candidates"], args.normal_root.resolve(), inputs["simple_status"],
                   inputs["simple_runtime"], inputs["review_status"], inputs["review_runtime"])
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(report["counts"])


if __name__ == "__main__":
    main()
