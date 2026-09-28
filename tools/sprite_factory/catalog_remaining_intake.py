"""Inventory remaining base species and optionally probe archived Biochao scenes.

This is a source gate. It never edits the runtime catalog or approves a model.
"""

import argparse
import concurrent.futures
import csv
import hashlib
import io
import json
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path


MEMBER = re.compile(r"(?:^|/)pm(\d{4})(?:_00)?\.blend$")
FORM_ONLY_BASE = {
    550: "basculin-red-striped", 555: "darmanitan-standard",
    592: "frillish-male", 593: "jellicent-male", 647: "keldeo-ordinary",
    668: "pyroar-male", 678: "meowstic-male", 681: "aegislash-shield",
    710: "pumpkaboo-average", 711: "gourgeist-average", 718: "zygarde-50",
}


def source_members(archive, generation):
    with zipfile.ZipFile(archive) as zipped:
        dex_for_dev = {}
        if generation >= 6:
            tables = [name for name in zipped.namelist() if name.endswith("_pokemon_dev_numbers.csv")]
            if len(tables) != 1:
                raise ValueError(f"Expected one developer-number table in {archive}")
            for row in csv.DictReader(io.StringIO(zipped.read(tables[0]).decode("utf-8-sig"))):
                dex, dev = row.get("#", ""), row.get("Dev #") or row.get("dev_number")
                if dex and dex.isdecimal() and dev and dev.isdecimal():
                    dev, dex = int(dev), int(dex)
                    if dev in dex_for_dev and dex_for_dev[dev] != dex:
                        raise ValueError(f"Conflicting developer number {dev}")
                    dex_for_dev[dev] = dex
        selected = {}
        for info in zipped.infolist():
            match = MEMBER.search(info.filename)
            if not match or info.is_dir() or info.file_size > 1024**3:
                continue
            number = int(match[1])
            dex = dex_for_dev.get(number) if generation >= 6 else number
            if dex is None:
                continue
            old = selected.get(dex)
            if old is None or (info.filename.endswith("_00.blend") and not old.filename.endswith("_00.blend")):
                selected[dex] = info
        return selected


def inventory(frontend, backend, archive_root):
    species_root = backend / "pokemon-data/data/species"
    species = {}
    form_only = {}
    for path in species_root.glob("*.json"):
        row = json.loads(path.read_text())
        dex, name = row.get("id"), row.get("species_id")
        if (type(dex) is int and 1 <= dex <= 1025 and name
                and row.get("catch_rate_source", {}).get("pokemon_species") == name):
            if dex in species and species[dex] != name:
                raise ValueError(f"Conflicting canonical species at #{dex}")
            species[dex] = name
        elif type(dex) is int and 1 <= dex <= 1025 and name:
            form_only.setdefault(dex, set()).add(name)
    registry = json.loads((frontend / "scripts/battle/battle_ui/reviewed_model_catalog.json").read_text())
    ready = {name for name in registry["models"] if "@" not in name}
    batch = json.loads((frontend / "tools/sprite_factory/catalog_production_batch_04.json").read_text())
    ready.update(entry["species"] for entry in batch["entries"])
    for dex, names in form_only.items():
        if dex in species:
            continue
        selected = FORM_ONLY_BASE.get(dex)
        if selected in names:
            species[dex] = selected
    unrepresented = sorted(set(form_only) - set(species))
    if unrepresented:
        raise ValueError(f"No canonical or reviewed form for Dex numbers {unrepresented}")
    remaining = {dex: name for dex, name in species.items() if name not in ready}
    available = {}
    for generation in range(1, 9):
        archive = archive_root / f"Gen{generation}.zip"
        for dex, info in source_members(archive, generation).items():
            if dex in remaining:
                available[dex] = {"archive": str(archive), "member": info.filename,
                                  "bytes": info.file_size, "crc32": f"{info.CRC:08x}"}
    rows = [{"national_dex": dex, "species": name, "legacy_source": available.get(dex)}
            for dex, name in sorted(remaining.items())]
    return {"schema": 1, "scope": "base_species_legacy_source_inventory_no_approval",
            "canonical_species_count": len(species), "existing_catalog_species_count": len(ready),
            "existing_base_species_count": len(set(species.values()) & ready),
            "remaining_species_count": len(rows), "legacy_source_found_count": len(available),
            "legacy_source_missing_count": len(rows) - len(available), "entries": rows}


def probe_one(entry, output, worker):
    source = entry["legacy_source"]
    directory = output / "probes" / f"{entry['national_dex']:04d}-{entry['species']}"
    directory.mkdir(parents=True, exist_ok=True)
    report = directory / "report.json"
    if report.is_file():
        existing = json.loads(report.read_text())
        has_current_fields = all(key in existing for key in ("action_candidates_by_bank",
                              "second_physical_candidates", "image_names"))
        needs_extensionless_recheck = (existing.get("action_count", 0) > 0
            and not any(existing.get("action_candidates", {}).values())
            and "action_names" not in existing)
        if has_current_fields and not needs_extensionless_recheck:
            return {"species": entry["species"], "status": "probed", "report": str(report)}
    try:
        with tempfile.TemporaryDirectory(prefix="legacy-", dir=directory) as temporary:
            # Older archives use a bare pm####.blend name even when the file
            # contains several rigs. Give the disposable copy an explicit
            # default-form identity so the existing rig selector can demand
            # positive, exclusive texture evidence for pm####_00.
            original_name = Path(source["member"]).name
            extracted_name = (original_name[:-6] + "_00.blend"
                              if re.fullmatch(r"pm\d{4}\.blend", original_name)
                              else original_name)
            extracted = Path(temporary) / extracted_name
            with zipfile.ZipFile(source["archive"]) as zipped:
                info = zipped.getinfo(source["member"])
                if info.file_size != source["bytes"] or f"{info.CRC:08x}" != source["crc32"]:
                    raise ValueError("Archive member changed since inventory")
                with zipped.open(info) as stream, extracted.open("xb") as target:
                    while chunk := stream.read(1024 * 1024):
                        target.write(chunk)
            digest = hashlib.sha256(extracted.read_bytes()).hexdigest()
            job = {"species": entry["species"], "source": str(extracted),
                   "source_sha256": digest, "archive": source["archive"],
                   "member": source["member"], "output": str(report)}
            job_path = Path(temporary) / "job.json"
            job_path.write_text(json.dumps(job))
            command = ["flatpak", "run", "--unshare=network", "--nofilesystem=host",
                       "--filesystem=" + str(directory), "--filesystem=" + str(worker.parent) + ":ro",
                       "org.blender.Blender", "--background", "--factory-startup", "--disable-autoexec",
                       "--python-exit-code", "1", "--python", str(worker), "--", str(job_path)]
            with (directory / "probe.log").open("w") as log:
                subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=300, check=True)
        return {"species": entry["species"], "status": "probed", "report": str(report)}
    except (OSError, ValueError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        log = directory / "probe.log"
        failures = re.findall(r"(?:ValueError|RuntimeError|OSError): ([^\n]+)",
                              log.read_text(errors="replace") if log.exists() else "")
        return {"species": entry["species"], "status": "blocked",
                "reason": failures[-1] if failures else type(error).__name__ + ": " + str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frontend", type=Path, required=True)
    parser.add_argument("--backend", type=Path, required=True)
    parser.add_argument("--archives", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--probe", action="store_true")
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    if not 1 <= args.workers <= 2:
        parser.error("Use one or two Blender workers to limit memory use")
    args.frontend = args.frontend.resolve()
    args.backend = args.backend.resolve()
    args.archives = args.archives.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = inventory(args.frontend, args.backend, args.archives)
    (args.output / "inventory.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"remaining={manifest['remaining_species_count']} legacy_sources={manifest['legacy_source_found_count']} "
          f"missing={manifest['legacy_source_missing_count']}", flush=True)
    if args.probe:
        entries = [row for row in manifest["entries"] if row["legacy_source"]]
        if args.limit is not None:
            entries = entries[:args.limit]
        worker = Path(__file__).with_name("catalog_remaining_legacy_worker.py").resolve()
        results = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            for result in pool.map(lambda row: probe_one(row, args.output, worker), entries):
                results.append(result)
                (args.output / "probe-status.json").write_text(json.dumps({
                    "schema": 1, "total": len(entries), "processed": len(results),
                    "probed": sum(row["status"] == "probed" for row in results),
                    "blocked": sum(row["status"] == "blocked" for row in results),
                    "entries": results}, indent=2) + "\n")
                print(result["species"], result["status"], flush=True)


if __name__ == "__main__":
    main()
