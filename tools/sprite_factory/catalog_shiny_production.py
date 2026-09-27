"""Export normal-SCN cohort shiny candidates from official rare material tables.

Rare material tables with unchanged inspected settings and BaseColorMap-only
substitutions are eligible. A small, explicitly reviewed set of differences
can be opted into for held candidates. Unrepresented source floats remain
explicit limitations pending visual review. This produces local GLB evidence,
never game admission.
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


def replacements(normal_table: Path, *, review_queue: bool = False,
                 include_float_overrides: bool = False):
    rare_table = normal_table.with_name(normal_table.stem + "_rare.trmtr")
    if not rare_table.is_file():
        raise ValueError("Official rare material table missing")
    normal, rare = inspect_materials(normal_table), inspect_materials(rare_table)
    if not normal or len(normal) != len(rare):
        raise ValueError("Rare material count differs")
    if review_queue:
        # The source table may reorder materials without changing their
        # bindings. Match explicit unique names before comparing settings.
        names = [material["name"] for material in normal]
        rare_by_name = {material["name"]: material for material in rare}
        if len(set(names)) != len(names) or len(rare_by_name) != len(rare) or set(names) != set(rare_by_name):
            raise ValueError("Rare material names differ or are ambiguous")
        rare = [rare_by_name[name] for name in names]
    mapping = {}
    float_overrides = []
    for a, b in zip(normal, rare, strict=True):
        settings_a = {k: v for k, v in a.items() if k != "textures"}
        settings_b = {k: v for k, v in b.items() if k != "textures"}
        if review_queue and settings_a != settings_b:
            # An omitted, zero-valued point light is the sole setting
            # exception. The source renderer has no contribution in either
            # case; every other float/shader difference remains held.
            floats_a = dict(settings_a["floats"])
            floats_b = dict(settings_b["floats"])
            if floats_a.get("PointLight0_Intensity") is None and floats_b.get("PointLight0_Intensity") == 0.0:
                floats_b.pop("PointLight0_Intensity")
            if (include_float_overrides and a["name"] in ("l_eye", "r_eye")
                    and any(shader["name"] in ("Eye", "EyeClearCoat") for shader in a["shaders"])):
                for key in ("EmissionIntensityLayer1", "EmissionIntensityLayer2",
                            "EmissionIntensityLayer3", "EmissionIntensityLayer4", "EmissionIntensityLayer5",
                            "NormalHeight1", "RoughnessHighlight"):
                    if key in floats_a and key in floats_b and floats_a[key] != floats_b[key]:
                        # Layers 1-4 have importer shader inputs and are applied
                        # below. The other source floats have no such input in
                        # the pinned importer; expose that limitation for
                        # human review instead of silently calling it parity.
                        mode = "apply" if key in {"EmissionIntensityLayer1", "EmissionIntensityLayer2",
                                                   "EmissionIntensityLayer3", "EmissionIntensityLayer4"} else "unrepresented"
                        float_overrides.append({"material": a["name"], "key": key,
                                                "normal": floats_a[key], "rare": floats_b[key],
                                                "mode": mode})
                        floats_b[key] = floats_a[key]
            settings_a["floats"], settings_b["floats"] = floats_a, floats_b
            shaders_a = json.loads(json.dumps(settings_a["shaders"]))
            shaders_b = json.loads(json.dumps(settings_b["shaders"]))
            if (len(shaders_a) == len(shaders_b) == 1
                    and shaders_a[0]["name"] == shaders_b[0]["name"] == "Standard"
                    and shaders_a[0]["values"].get("NumMaterialLayer") == "1"
                    and shaders_b[0]["values"].get("NumMaterialLayer") == "1"
                    and shaders_a[0]["values"].get("NumRequiredUV") == "1"
                    and "NumRequiredUV" not in shaders_b[0]["values"]):
                # Single-layer Standard defaults to one UV in this source;
                # source geometry parity is checked after export.
                shaders_a[0]["values"].pop("NumRequiredUV")
            settings_a["shaders"], settings_b["shaders"] = shaders_a, shaders_b
        if settings_a != settings_b:
            raise ValueError("Rare material settings differ: " + a["name"])
        if a["textures"].keys() != b["textures"].keys():
            raise ValueError("Rare material texture channels differ: " + a["name"])
        for channel in a["textures"]:
            before, after = a["textures"][channel], b["textures"][channel]
            if before == after:
                continue
            review_channels = {"UpperEyelidColorMap", "LowerEyelidColorMap", "EmissionColorMap",
                               "RoughnessMap", "NormalMap", "LayerMaskMap"}
            if ((channel != "BaseColorMap" and (not review_queue or channel not in review_channels))
                    or Path(before).name != before or Path(after).name != after):
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
            # Some official rare tables point at a distinct filename with the
            # same pixels. Keep the embedded normal texture for that channel.
            continue
        result.append({"normal": str(normal_png), "rare": str(rare_png),
                       "normal_sha256": digest(normal_png), "rare_sha256": digest(rare_png)})
    if not result:
        raise ValueError("Normal and rare albedo are byte-identical")
    if include_float_overrides:
        return result, digest(rare_table), float_overrides
    return result, digest(rare_table)


def prepare(row: dict, expected: dict, source_root: Path, output: Path,
            *, review_queue: bool = False) -> tuple[dict, list[str]]:
    species = row["species"]
    normal_path = Path(row["path"])
    if digest(normal_path) != row["glb_sha256"] or row["glb_sha256"] != expected["glb_sha256"]:
        raise ValueError("Normal GLB differs from batch identity")
    source_job = json.loads((source_root / species / "job.json").read_text())
    validate_export_job(source_job)
    normal_table = Path(source_job["material_source"])
    pairs, rare_table_sha, float_overrides = replacements(
        normal_table, review_queue=review_queue, include_float_overrides=True)
    directory = output / species
    directory.mkdir()
    job = {**source_job, "output": str(directory), "verified_texture_replacements": pairs,
           "official_rare_material_source": str(normal_table.with_name(normal_table.stem + "_rare.trmtr")),
           "official_rare_material_sha256": rare_table_sha,
           "verified_rare_float_overrides": float_overrides}
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
                "official_albedo_replacements": pairs,
                "official_rare_float_overrides": float_overrides}
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
    parser.add_argument("--species", action="append", help="Export only these species from the pinned cohort")
    parser.add_argument("--review-queue", action="store_true", help="Allow narrow audited source defaults")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("--output must name a new directory")
    rows = json.loads(args.normal.read_text())["entries"]
    batch = json.loads(args.batch_results.read_text())
    expected = {row["species"]: row for row in batch["entries"] if row.get("runtime_sha256")}
    normal = {row["species"]: row for row in rows if row.get("status") == "exported_for_review"}
    if (batch.get("runtime_approved") is not False or set(normal) != set(expected)
            or len(normal) != batch.get("standalone_models")):
        raise ValueError("Normal cohort differs from the pinned standalone-SCN batch")
    if args.review_queue and not args.species:
        raise ValueError("Review-queue exceptions require explicit species selection")
    if args.species:
        requested = set(args.species)
        if len(requested) != len(args.species) or not requested <= set(normal):
            raise ValueError("Species selection has duplicates or is outside the pinned cohort")
        normal = {species: row for species, row in normal.items() if species in requested}
    output.mkdir(parents=True)
    ready, held = [], []
    for species, row in normal.items():
        try:
            ready.append(prepare(row, expected[species], args.normal.parent, output,
                                 review_queue=args.review_queue))
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
