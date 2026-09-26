"""Export exact normal-SCN cohort shiny candidates from official rare albedos.

Only a rare material table with unchanged inspected material settings and
BaseColorMap-only substitutions is eligible. Every other species is held for
manual review. This produces local GLB evidence, never game admission.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess

from phase5_variant_parity import compare
from scvi_identity import export_read_paths, validate_export_job
from scvi_material_probe import inspect_materials


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replacements(normal_table: Path) -> tuple[list[dict], str]:
    rare_table = normal_table.with_name(normal_table.stem + "_rare.trmtr")
    if not rare_table.is_file():
        raise ValueError("Official rare material table missing")
    normal, rare = inspect_materials(normal_table), inspect_materials(rare_table)
    if not normal or len(normal) != len(rare):
        raise ValueError("Rare material count differs")
    mapping = {}
    for a, b in zip(normal, rare, strict=True):
        if {k: v for k, v in a.items() if k != "textures"} != {k: v for k, v in b.items() if k != "textures"}:
            raise ValueError("Rare material settings differ: " + a["name"])
        if a["textures"].keys() != b["textures"].keys():
            raise ValueError("Rare material texture channels differ: " + a["name"])
        for channel in a["textures"]:
            before, after = a["textures"][channel], b["textures"][channel]
            if before == after:
                continue
            if channel != "BaseColorMap" or Path(before).name != before or Path(after).name != after:
                raise ValueError("Rare material has a non-albedo change: " + a["name"] + "/" + channel)
            if before in mapping and mapping[before] != after:
                raise ValueError("One normal texture maps to different rare textures")
            mapping[before] = after
    if not mapping:
        raise ValueError("Rare material has no distinct official albedo")
    result = []
    for before, after in sorted(mapping.items()):
        normal_png = normal_table.parent / Path(before).with_suffix(".png")
        rare_png = normal_table.parent / Path(after).with_suffix(".png")
        if not normal_png.is_file() or not rare_png.is_file():
            raise ValueError("Official normal or rare PNG missing")
        if digest(normal_png) == digest(rare_png):
            raise ValueError("Normal and rare albedo are byte-identical")
        result.append({"normal": str(normal_png), "rare": str(rare_png),
                       "normal_sha256": digest(normal_png), "rare_sha256": digest(rare_png)})
    return result, digest(rare_table)


def prepare(row: dict, expected: dict, source_root: Path, output: Path) -> tuple[dict, list[str]]:
    species = row["species"]
    normal_path = Path(row["path"])
    if digest(normal_path) != row["glb_sha256"] or row["glb_sha256"] != expected["glb_sha256"]:
        raise ValueError("Normal GLB differs from batch identity")
    source_job = json.loads((source_root / species / "job.json").read_text())
    validate_export_job(source_job)
    normal_table = Path(source_job["material_source"])
    pairs, rare_table_sha = replacements(normal_table)
    directory = output / species
    directory.mkdir()
    job = {**source_job, "output": str(directory), "verified_texture_replacements": pairs,
           "official_rare_material_source": str(normal_table.with_name(normal_table.stem + "_rare.trmtr")),
           "official_rare_material_sha256": rare_table_sha}
    job_path = directory / "job.json"
    job_path.write_text(json.dumps(job, indent=2) + "\n")
    tools = Path(__file__).resolve().parent
    command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
               "--filesystem=" + str(output), "--filesystem=" + str(tools) + ":ro",
               "--filesystem=" + str(Path(job["source"]).parent) + ":ro"]
    command += ["--filesystem=" + path + ":ro" for path in export_read_paths(job)]
    command += ["org.blender.Blender", "--background", "--factory-startup", "--disable-autoexec",
                "--python-exit-code", "1", "--python", str(tools / "phase5_godot_export_worker.py"),
                "--", str(job_path)]
    evidence = {"species": species, "variant": "shiny", "runtime_approved": False,
                "normal_glb_sha256": row["glb_sha256"], "official_rare_material_sha256": rare_table_sha,
                "official_albedo_replacements": pairs}
    return evidence, command


def export_one(item: tuple[dict, list[str]], output: Path, normal: dict) -> dict:
    evidence, command = item
    species = evidence["species"]
    directory = output / species
    try:
        with (directory / "export.log").open("w") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        if result.returncode:
            raise ValueError("Blender export failed; inspect export.log")
        exported = json.loads((directory / "export.json").read_text())
        if exported.get("status") != "exported_for_review" or exported.get("runtime_approved"):
            raise ValueError("Shiny export did not remain a review candidate")
        glb = Path(exported["path"])
        if digest(glb) != exported["glb_sha256"]:
            raise ValueError("Shiny GLB hash changed after export")
        parity = compare(normal[species]["path"], glb)
        return {**evidence, **exported, "variant": "shiny", "geometry_motion_sha256": parity}
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        return {**evidence, "status": "held", "reason": str(error)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--normal", type=Path, required=True, help="Identity-gated normal export catalog")
    parser.add_argument("--batch-results", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--jobs", type=int, choices=[1, 2], default=2)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("--output must name a new directory")
    rows = json.loads(args.normal.read_text())["entries"]
    batch = json.loads(args.batch_results.read_text())
    expected = {row["species"]: row for row in batch["entries"] if row.get("runtime_sha256")}
    normal = {row["species"]: row for row in rows if row.get("status") == "exported_for_review"}
    if set(normal) != set(expected) or len(normal) != 18:
        raise ValueError("Normal cohort differs from the pinned 18-SCN batch")
    output.mkdir(parents=True)
    ready, held = [], []
    for species, row in normal.items():
        try:
            ready.append(prepare(row, expected[species], args.normal.parent, output))
        except (OSError, ValueError, KeyError) as error:
            held.append({"species": species, "variant": "shiny", "status": "held",
                         "runtime_approved": False, "reason": str(error)})
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda item: export_one(item, output, normal), ready))
    entries = sorted(held + results, key=lambda row: row["species"])
    (output / "catalog.json").write_text(json.dumps({"schema": 1, "runtime_approved": False,
                                                       "entries": entries}, indent=2) + "\n")
    for row in entries:
        print(row["species"], row["status"], row.get("reason", ""), flush=True)
    print("SHINY_BATCH_COMPLETE", sum(r["status"] == "exported_for_review" for r in entries),
          "exported,", sum(r["status"] == "held" for r in entries), "held", flush=True)


if __name__ == "__main__":
    main()
