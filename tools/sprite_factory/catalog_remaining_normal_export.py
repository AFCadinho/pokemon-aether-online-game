"""Bulk normal-form GLB diagnostics from source-probed Biochao archives.

Requires the six runtime actions. A missing faint loop holds the last faint pose.
No shiny, visual or runtime approval.
"""

import argparse
import concurrent.futures
import hashlib
import json
import re
import subprocess
import zipfile
from pathlib import Path


REQUIRED = {"idle", "physical_attack", "special_attack", "damage", "sleep",
            "faint_start"}
WISHIWASHI_SOLO_SOURCE_SHA256 = "028fdad10505fcea05f8e03ef5dac10ada2fec7ab1077066e5fd96663b6ba669"
EYE_DOMAIN_POLICY = "source-eye-domain-review-v1"


def choose_actions(report):
    direct = dict(report["unambiguous_actions"])
    # The archived solo Wishiwashi has no sleep clip or eyelid rig. Use its
    # own field-wait loop as a review candidate; its eyes remain open.
    # Keep this narrow and source-pinned; it still needs visual qualification.
    if (report.get("species") == "wishiwashi" and
            report.get("source_member") == "pm0820_11.blend" and
            report.get("source_sha256") == WISHIWASHI_SOLO_SOURCE_SHA256 and
            "sleep" not in direct):
        resting = [name for name in report.get("action_names", [])
                   if name == "pm0820_11_kw01_wait01"]
        if len(resting) == 1:
            direct["sleep"] = resting[0]
    selected = ""
    numeric_banks = {match[1] for key in REQUIRED if (match := re.search(
        r"^pm\d{4}_\d{2}_\d{2}_(\d)\d{4}_", direct.get(key, ""), re.I))}
    if REQUIRED <= direct.keys() and len(numeric_banks) <= 1:
        mapping = {key: direct[key] for key in REQUIRED}
        bank = "direct"
        optional = report.get("action_candidates", {}).get("faint_loop", [])
    else:
        complete = [(name, values, candidates.get("faint_loop", []))
                    for name, candidates in report.get("action_candidates_by_bank", {}).items()
                    if REQUIRED <= (values := {key: found[0] for key, found in candidates.items()
                                             if len(found) == 1}).keys()]
        if len(complete) != 1:
            selected = report.get("rig_selection", {}).get("rig", "").removesuffix(".trmdl")
            if not re.fullmatch(r"pm\d{4}(?:_\d{2}){1,2}", selected):
                return None, "missing_or_ambiguous_native_actions"
            candidates = report.get("action_candidates", {})
            own = {key: [name for name in candidates.get(key, [])
                         if name.startswith(selected + "_")] for key in REQUIRED}
            if not all(len(found) == 1 for found in own.values()):
                return None, "missing_or_ambiguous_native_actions"
            mapping = {key: own[key][0] for key in REQUIRED}
            banks = {match[1] for name in mapping.values() if (match := re.search(
                r"^pm\d{4}_\d{2}_\d{2}_(\d)\d{4}_", name, re.I))}
            if len(banks) > 1:
                return None, "missing_or_ambiguous_native_actions"
            bank = next(iter(banks), "selected_rig")
            optional = [name for name in candidates.get("faint_loop", [])
                        if name.startswith(selected + "_")]
        else:
            bank, mapping, optional = complete[0]
    second = report.get("second_physical_candidates", [])
    if selected:
        second = [name for name in second if name.startswith(selected + "_")]
    chosen_numeric_bank = next(iter(numeric_banks), None) if bank == "direct" else (bank if bank in ("0", "1", "2") else None)
    if len(optional) == 1:
        loop_bank = re.search(r"^pm\d{4}_\d{2}_\d{2}_(\d)\d{4}_", optional[0], re.I)
        if chosen_numeric_bank is None or loop_bank is None or loop_bank[1] == chosen_numeric_bank:
            mapping["faint_loop"] = optional[0]
    if chosen_numeric_bank is not None:
        second = [name for name in second if not (match := re.search(
            r"^pm\d{4}_\d{2}_\d{2}_(\d)\d{4}_", name, re.I)) or match[1] == chosen_numeric_bank]
    if len(second) == 1:
        mapping["physical_attack_2"] = second[0]
    return mapping, bank


def export_one(entry, probe_status, output, worker):
    species = entry["species"]
    directory = output / f"{entry['national_dex']:04d}-{species}"
    directory.mkdir(parents=True, exist_ok=True)
    prior = probe_status.get(species)
    if prior is None or prior["status"] != "probed":
        return {"species": species, "status": "held", "reason": "source_probe_not_passed"}
    report = json.loads(Path(prior["report"]).read_text())
    mapping, bank = choose_actions(report)
    if mapping is None:
        return {"species": species, "status": "held", "reason": bank}
    existing_report = directory / "export.json"
    if existing_report.is_file():
        current = json.loads(existing_report.read_text())
        if set(current["animations"]) != set(mapping):
            return {"species": species, "status": "held",
                    "reason": "existing_diagnostic_has_different_action_set"}
        if (species == "unown" and current.get("body_review_candidate", {}).get("policy")
                != "unown-a-body-eye-review-v2"):
            return {"species": species, "status": "held",
                    "reason": "stale_unown_face_candidate_requires_new_output"}
        if species in ("darmanitan-standard", "wishiwashi", "silvally", "obstagoon", "cursola"):
            if current.get("eye_domain_review_candidate", {}).get("policy") != EYE_DOMAIN_POLICY:
                return {"species": species, "status": "held",
                        "reason": "stale_eye_domain_candidate_requires_new_output"}
        return {"species": species, "status": "exported", "bank": bank,
                "physical_attack_2": "physical_attack_2" in mapping,
                "report": str(existing_report)}
    source = entry["legacy_source"]
    source_name = Path(source["member"]).name
    if re.fullmatch(r"pm\d{4}\.blend", source_name):
        source_name = source_name[:-6] + "_00.blend"
    extracted = directory / source_name
    try:
        with zipfile.ZipFile(source["archive"]) as zipped:
            info = zipped.getinfo(source["member"])
            if info.file_size != source["bytes"] or f"{info.CRC:08x}" != source["crc32"]:
                raise ValueError("Archive member changed since inventory")
            with zipped.open(info) as stream, extracted.open("wb") as target:
                while chunk := stream.read(1024 * 1024):
                    target.write(chunk)
        digest = hashlib.sha256(extracted.read_bytes()).hexdigest()
        if digest != report["source_sha256"]:
            raise ValueError("Source differs from successful probe")
        job = {"species": species, "source": str(extracted), "source_sha256": digest,
               "actions": mapping, "output": str(directory), "scvi_pbr_probe": False}
        (directory / "job.json").write_text(json.dumps(job, indent=2) + "\n")
        command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
                   "--filesystem=" + str(directory), "--filesystem=" + str(worker.parent) + ":ro",
                   "org.blender.Blender", "--background", "--factory-startup", "--disable-autoexec",
                   "--python-exit-code", "1", "--python", str(worker), "--", str(directory / "job.json")]
        with (directory / "export.log").open("w") as log:
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=600, check=True)
        result = json.loads((directory / "export.json").read_text())
        if result["status"] != "exported_for_review" or set(result["animations"]) != set(mapping):
            raise ValueError("Export report differs from selected native actions")
        if species == "unown":
            from catalog_remaining_unown_body import repair
            eye_bake = directory / "unown-a-authored-eye.png"
            eye_worker = Path(__file__).with_name("catalog_remaining_unown_eye_worker.py").resolve()
            eye_command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
                           "--filesystem=" + str(directory), "--filesystem=" + str(eye_worker.parent) + ":ro",
                           "org.blender.Blender", "--background", "--factory-startup", "--disable-autoexec",
                           "--python-exit-code", "1", "--python", str(eye_worker), "--",
                           str(extracted), str(eye_bake)]
            with (directory / "eye-bake.log").open("w") as log:
                subprocess.run(eye_command, stdout=log, stderr=subprocess.STDOUT,
                               timeout=120, check=True)
            corrected = directory / "model-unown-face-review.glb"
            result["body_review_candidate"] = repair(directory / "model.glb", corrected, digest,
                                                      eye_bake)
            result["path"] = str(corrected)
            result["glb_sha256"] = result["body_review_candidate"]["sha256"]
            result["bytes"] = corrected.stat().st_size
            (directory / "export.json").write_text(json.dumps(result, indent=2) + "\n")
        if species in ("darmanitan-standard", "wishiwashi", "silvally", "obstagoon", "cursola"):
            from catalog_remaining_eye_domain import repair
            corrected = directory / "model-source-eyes-review.glb"
            face = repair(species, extracted, directory / "model.glb", corrected)
            result["eye_domain_review_candidate"] = {"policy": EYE_DOMAIN_POLICY,
                                                       "source_sha256": digest,
                                                       "eye_materials": face["eye_materials"],
                                                       "runtime_approved": False}
            result["path"] = str(corrected)
            result["glb_sha256"] = face["glb_sha256"]
            result["bytes"] = corrected.stat().st_size
            (directory / "export.json").write_text(json.dumps(result, indent=2) + "\n")
        return {"species": species, "status": "exported", "bank": bank,
                "physical_attack_2": "physical_attack_2" in mapping,
                "report": str(directory / "export.json")}
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        log = directory / "export.log"
        failures = re.findall(r"(?:ValueError|RuntimeError|OSError): ([^\n]+)",
                              log.read_text(errors="replace") if log.exists() else "")
        return {"species": species, "status": "blocked",
                "reason": failures[-1] if failures else type(error).__name__ + ": " + str(error)}
    finally:
        extracted.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--probe-status", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    if not 1 <= args.workers <= 2:
        parser.error("Use one or two Blender workers to limit memory use")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    entries = [row for row in json.loads(args.inventory.read_text())["entries"] if row["legacy_source"]]
    if args.limit is not None:
        entries = entries[:args.limit]
    probes = {row["species"]: row for row in json.loads(args.probe_status.read_text())["entries"]}
    worker = Path(__file__).with_name("phase5_godot_export_worker.py").resolve()
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(lambda row: export_one(row, probes, output, worker), entries):
            results.append(result)
            (output / "status.json").write_text(json.dumps({"schema": 1, "total": len(entries),
                "processed": len(results), "exported": sum(r["status"] == "exported" for r in results),
                "held": sum(r["status"] == "held" for r in results),
                "blocked": sum(r["status"] == "blocked" for r in results),
                "entries": results}, indent=2) + "\n")
            print(result["species"], result["status"], flush=True)


if __name__ == "__main__":
    main()
