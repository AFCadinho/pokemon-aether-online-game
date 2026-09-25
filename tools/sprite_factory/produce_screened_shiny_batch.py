"""Produce fail-closed shiny GLB candidates from the pinned screened normal catalog.

This reuses the existing rare-albedo exporter. Output is local review evidence;
it does not admit models to battles or build release bundles.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil

from catalog_shiny_production import export_one, prepare


ROOT = Path(__file__).resolve().parents[2]
SCREENED = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"


def digest(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def produce(batch_path: Path, catalog_path: Path, report_path: Path, output: Path, jobs: int = 2) -> dict:
    batch_path, catalog_path, report_path, output = map(Path, (batch_path, catalog_path, report_path, output))
    if output.exists() or output.is_symlink():
        raise ValueError("Output must be a new directory")
    if jobs not in (1, 2):
        raise ValueError("Only one or two parallel Blender exports are supported")
    batch = json.loads(batch_path.read_text())
    names = batch.get("species", [])
    if batch.get("schema") != 1 or not isinstance(names, list) or not names or len(names) != len(set(names)):
        raise ValueError("Batch must name distinct species")
    screened = json.loads(SCREENED.read_text())
    catalog = {row["species"]: row for row in json.loads(catalog_path.read_text())}
    normal = {row["species"]: row for row in json.loads(report_path.read_text())}
    if len(screened["models"]) != 75 or len(catalog) != 75 or not set(names) <= set(screened["models"]):
        raise ValueError("Batch does not match the 75-model screened catalog")
    output.mkdir(parents=True)
    source_root = output / "input-jobs"
    ready, held = [], []
    for species in names:
        try:
            model = screened["models"][species]
            selected = catalog[species]
            row = normal[species]
            scene = Path(selected["runtime_path"])
            if (selected.get("variant") != "normal" or selected.get("runtime_sha256") != model["sha256"]
                    or row.get("runtime_sha256") != model["sha256"]
                    or row.get("glb_sha256") != model["glb_sha256"]
                    or not scene.is_file() or digest(scene) != model["sha256"]):
                raise ValueError("Normal scene/export is not the screened identity")
            job = Path(row["path"]).parent / "job.json"
            if not job.is_file():
                raise ValueError("Normal export job is missing")
            destination = source_root / species
            destination.mkdir(parents=True)
            shutil.copyfile(job, destination / "job.json")
            ready.append(prepare(row, model, source_root, output))
        except (KeyError, OSError, ValueError) as error:
            held.append({"species": species, "variant": "shiny", "status": "held",
                         "runtime_approved": False, "reason": str(error)})
    usable = {name: normal[name] for name in names if name in normal}
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        exported = list(pool.map(lambda item: export_one(item, output, usable), ready))
    entries = sorted([*held, *exported], key=lambda row: row["species"])
    result = {"schema": 1, "scope": "screened_normal_shiny_export_candidates",
              "runtime_approved": False, "release_approved": False,
              "batch_sha256": digest(batch_path), "screened_registry_sha256": digest(SCREENED),
              "local_catalog_sha256": digest(catalog_path), "normal_report_sha256": digest(report_path),
              "requested": len(names),
              "exported": sum(row.get("status") == "exported_for_review" for row in entries),
              "held": sum(row.get("status") == "held" for row in entries), "entries": entries}
    (output / "catalog.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch", required=True, type=Path)
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--normal-report", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--jobs", type=int, default=2)
    args = parser.parse_args()
    result = produce(args.batch.resolve(), args.catalog.resolve(), args.normal_report.resolve(),
                     args.output.resolve(), args.jobs)
    for row in result["entries"]:
        print(row["species"], row["status"], row.get("reason", ""), flush=True)
    print("SCREENED_SHINY_BATCH", result["exported"], "exported,", result["held"], "held", flush=True)


if __name__ == "__main__":
    main()
