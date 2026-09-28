"""Bulk review-only shiny exports from pinned Biochao normals and official rare tables.

Each source and normal GLB is checked against the remaining-candidate manifest.
Unsupported material changes or mismatched packed images are held per species.
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

from catalog_shiny_production import replacements
from phase5_variant_parity import compare


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def export_one(row, args, manifest_sha, simple):
    species = row["species"]
    if row["status"] != "normal_technical_candidate":
        return {"species": species, "status": "held", "stage": row.get("stage", "source"),
                "reason": row.get("reason", "Default-form source missing")}
    if species in simple:
        return {"species": species, "status": "existing_simple_shiny",
                "report": simple[species]["report"]}
    directory = args.output / species
    source_path = None
    try:
        member = row["source"]["member"]
        match = re.search(r"(pm\d{4})(?:_00)?\.blend$", member)
        if not match:
            raise ValueError("Unmapped Biochao member")
        resource = match[1] + "_00_00"
        material_table = args.material_root / match[1] / resource / (resource + ".trmtr")
        if not material_table.is_file():
            raise ValueError("Official normal/rare material tables absent for this source")
        pairs, rare_hash, floats, colors = replacements(
            material_table, review_queue=True, include_float_overrides=True,
            include_color_overrides=True, material_scoped=True)
        if not pairs and not colors:
            raise ValueError("Rare table has no supported visible change")
        normal_dir = args.normal_root / f"{row['national_dex']:04d}-{species}"
        normal_job = json.loads((normal_dir / "job.json").read_text())
        normal_glb = normal_dir / "model.glb"
        if sha(normal_glb) != row["normal_glb_sha256"]:
            raise ValueError("Pinned normal GLB changed")
        directory.mkdir(parents=True, exist_ok=True)
        existing = directory / "export.json"
        if existing.is_file():
            result = json.loads(existing.read_text())
            if result.get("status") == "exported_for_review" and result.get("glb_sha256") == sha(directory / "model.glb"):
                parity = compare(normal_glb, directory / "model.glb")
                return {"species": species, "status": "exported", "report": str(existing),
                        "glb_sha256": result["glb_sha256"], "geometry_motion_sha256": parity,
                        "unrepresented_rare_parameters": len(result.get("unrepresented_rare_parameters", []))}
        original_name = Path(member).name
        if re.fullmatch(r"pm\d{4}\.blend", original_name):
            original_name = original_name[:-6] + "_00.blend"
        source_path = directory / original_name
        archive = args.archives / Path(row["source"]["archive"]).name
        with zipfile.ZipFile(archive) as zipped:
            info = zipped.getinfo(member)
            if info.file_size != row["source"]["bytes"] or f"{info.CRC:08x}" != row["source"]["crc32"]:
                raise ValueError("Biochao archive member changed")
            with zipped.open(info) as stream, source_path.open("xb") as target:
                while chunk := stream.read(1024 * 1024):
                    target.write(chunk)
        if sha(source_path) != row["source_sha256"]:
            raise ValueError("Biochao source hash differs from normal export")
        job = {"species": species, "source": str(source_path),
               "source_sha256": row["source_sha256"], "actions": normal_job["actions"],
               "output": str(directory), "scvi_pbr_probe": False,
               "material_source": str(material_table),
               "material_source_sha256": sha(material_table),
               "official_rare_material_source": str(material_table.with_name(resource + "_rare.trmtr")),
               "official_rare_material_sha256": rare_hash,
               "verified_texture_replacements": pairs,
               "verified_rare_float_overrides": floats,
               "verified_rare_color_overrides": colors,
               "legacy_material_diagnostic": True,
               "legacy_candidate_manifest": str(args.candidates),
               "legacy_candidate_manifest_sha256": manifest_sha,
               "legacy_normal_root": str(args.normal_root),
               "legacy_material_root": str(args.material_root)}
        job_path = directory / "job.json"
        job_path.write_text(json.dumps(job, indent=2) + "\n")
        worker = Path(__file__).with_name("phase5_godot_export_worker.py").resolve()
        command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
                   "--filesystem=" + str(args.output),
                   "--filesystem=" + str(worker.parent) + ":ro",
                   "--filesystem=" + str(args.normal_root) + ":ro",
                   "--filesystem=" + str(args.material_root) + ":ro",
                   "org.blender.Blender", "--background", "--factory-startup", "--disable-autoexec",
                   "--python-exit-code", "1", "--python", str(worker), "--", str(job_path)]
        with (directory / "export.log").open("w") as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=900, check=True)
        exported = json.loads(existing.read_text())
        variant = directory / "model.glb"
        if (exported.get("status") != "exported_for_review" or exported.get("runtime_approved") or
                exported.get("glb_sha256") != sha(variant)):
            raise ValueError("Shiny GLB report or bytes differ")
        parity = compare(normal_glb, variant)
        return {"species": species, "status": "exported", "report": str(existing),
                "glb_sha256": exported["glb_sha256"], "geometry_motion_sha256": parity,
                "rare_float_overrides": len(floats), "rare_color_overrides": len(colors),
                "rare_texture_replacements": len(pairs),
                "unrepresented_rare_parameters": len(exported.get("unrepresented_rare_parameters", []))}
    except (OSError, ValueError, KeyError, IndexError, TypeError, zipfile.BadZipFile,
            subprocess.SubprocessError) as error:
        log = directory / "export.log"
        failures = re.findall(r"(?:ValueError|RuntimeError|OSError): ([^\n]+)",
                              log.read_text(errors="replace") if log.exists() else "")
        return {"species": species, "status": "held", "stage": "shiny_material",
                "reason": failures[-1] if failures else type(error).__name__ + ": " + str(error)}
    finally:
        if source_path is not None:
            source_path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--normal-root", type=Path, required=True)
    parser.add_argument("--archives", type=Path, required=True)
    parser.add_argument("--material-root", type=Path, required=True)
    parser.add_argument("--simple-status", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--jobs", type=int, choices=(1, 2), default=2)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    for name in ("candidates", "normal_root", "archives", "material_root", "simple_status", "output"):
        setattr(args, name, getattr(args, name).resolve())
    if args.output.exists() and not args.resume:
        parser.error("--output must name a new directory")
    rows = json.loads(args.candidates.read_text())["entries"]
    simple = {row["species"]: row for row in json.loads(args.simple_status.read_text())["entries"]
              if row["status"] == "exported"}
    args.output.mkdir(parents=True, exist_ok=args.resume)
    results = []
    manifest_sha = sha(args.candidates)
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for result in pool.map(lambda row: export_one(row, args, manifest_sha, simple), rows):
            results.append(result)
            report = {"schema": 1, "scope": "local_shiny_diagnostics_not_catalog_approval",
                      "runtime_approved": False, "total": len(rows), "processed": len(results),
                      "exported": sum(row["status"] == "exported" for row in results),
                      "existing_simple_shiny": sum(row["status"] == "existing_simple_shiny" for row in results),
                      "held": sum(row["status"] == "held" for row in results),
                      "entries": results}
            (args.output / "status.json").write_text(json.dumps(report, indent=2) + "\n")
            print(result["species"], result["status"], flush=True)
    print("SHINY_REVIEW_BATCH_COMPLETE", report["exported"], "exported,",
          report["existing_simple_shiny"], "existing,", report["held"], "held", flush=True)


if __name__ == "__main__":
    main()
