"""Append reviewed SCVI attack02 clips without changing established GLB data.

This is an offline candidate builder.  It never edits a runtime catalog or an
approval registry.  Every existing GLB component must remain a byte-identical
prefix; otherwise that species is blocked.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import struct
import subprocess
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def read_glb(path: Path) -> tuple[dict, bytes]:
    payload = path.read_bytes()
    if payload[:4] != b"glTF":
        raise ValueError("Not a binary glTF: " + str(path))
    json_length = struct.unpack_from("<I", payload, 12)[0]
    document = json.loads(payload[20:20 + json_length])
    offset = (20 + json_length + 3) // 4 * 4
    binary_length, chunk_type = struct.unpack_from("<I4s", payload, offset)
    if chunk_type != b"BIN\x00":
        raise ValueError("GLB has no binary chunk: " + str(path))
    return document, payload[offset + 8:offset + 8 + binary_length]


def verify_append_only(old_path: Path, new_path: Path, added_action: str) -> dict:
    old, old_binary = read_glb(old_path)
    new, new_binary = read_glb(new_path)
    ignored = {"animations", "accessors", "bufferViews", "buffers"}
    for key, value in old.items():
        if key not in ignored and new.get(key) != value:
            raise ValueError("Non-animation GLB data changed: " + key)
    for key in ("accessors", "bufferViews", "animations"):
        if new.get(key, [])[:len(old.get(key, []))] != old.get(key, []):
            raise ValueError("Existing GLB sequence changed: " + key)
    old_names = [item.get("name") for item in old.get("animations", [])]
    new_names = [item.get("name") for item in new.get("animations", [])]
    if new_names != old_names + [added_action]:
        raise ValueError("Expected exactly one appended animation")
    if new_binary[:len(old_binary)] != old_binary:
        raise ValueError("Existing GLB binary payload changed")
    return {
        "old_bytes": old_path.stat().st_size,
        "new_bytes": new_path.stat().st_size,
        "added_bytes": new_path.stat().st_size - old_path.stat().st_size,
        "preserved_animations": old_names,
        "added_animation": added_action,
        "existing_glb_prefix_identical": True,
    }


def _entry_index(path: Path) -> dict[str, dict]:
    return {entry["species"]: entry for entry in json.loads(path.read_text())["entries"]}


def _run_blender(command: list[str], log: Path) -> None:
    with log.open("w") as stream:
        subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT,
                       timeout=900, check=True)


def build_one(species: str, base_job_path: Path, alternate: dict, review: dict,
              output: Path, importer: Path, python_deps: Path, tools: Path) -> dict:
    if review.get("status") != "confirmed":
        raise ValueError("Human review is not confirmed")
    clip = review.get("clips", {}).get("physical_attack_2", {})
    motion = Path(alternate["motions"]["physical_attack_2"])
    channel_value = alternate.get("motion_channels", {}).get("physical_attack_2")
    channel = Path(channel_value) if channel_value else None
    if motion.stem != clip.get("source_action"):
        raise ValueError("Reviewed alternate differs from inventory")
    base_job = json.loads(base_job_path.read_text())
    source = Path(base_job["source"])
    source_import = source.with_name("import.json")
    old_glb = base_job_path.with_name("model.glb")
    if not all(path.is_file() for path in (source, source_import, old_glb)):
        raise ValueError("Base source/export evidence is incomplete")
    directory = output / species
    source_dir = directory / "source"
    export_dir = directory / "export"
    source_dir.mkdir(parents=True)
    export_dir.mkdir()
    upgraded = source_dir / source.name
    append_job = {
        "source": str(source), "source_sha256": digest(source),
        "source_import": str(source_import),
        "source_import_sha256": digest(source_import),
        "motion": str(motion), "motion_sha256": digest(motion),
        "category": "physical_attack_2", "importer": str(importer),
        "python_deps": str(python_deps), "output": str(upgraded),
        "report": str(source_dir / "append.json"),
    }
    if channel:
        append_job.update(motion_channel=str(channel),
                          motion_channel_sha256=digest(channel))
    append_job_path = directory / "append-job.json"
    write_json(append_job_path, append_job)
    append_command = [
        "flatpak", "run", "--unshare=network", "--nofilesystem=host",
        "--filesystem=" + str(output) + ":rw",
        "--filesystem=" + str(tools) + ":ro",
        "--filesystem=" + str(source.parent) + ":ro",
        "--filesystem=" + str(motion.parent) + ":ro",
        "--filesystem=" + str(importer) + ":ro",
        "--filesystem=" + str(python_deps) + ":ro",
        "org.blender.Blender", "--background", "--factory-startup",
        "--disable-autoexec", "--python-exit-code", "1", "--python",
        str(tools / "append_scvi_action_worker.py"), "--", str(append_job_path),
    ]
    _run_blender(append_command, directory / "append.log")

    export_job = base_job
    export_job.update(source=str(upgraded), source_sha256=digest(upgraded),
                      output=str(export_dir))
    export_job["actions"]["physical_attack_2"] = motion.stem
    intake = export_job["identity_intake"]
    intake["motions"]["physical_attack_2"] = str(motion)
    intake.setdefault("motion_channels", {})["physical_attack_2"] = (
        str(channel) if channel else None)
    intake.setdefault("alternatives", {})["physical_attack_2"] = alternate[
        "alternatives"]["physical_attack_2"]
    proof = intake["identity_evidence"]
    from scvi_identity import bind, read_catalog, validate_export_job, export_read_paths
    catalog = read_catalog(proof["catalog_path"])
    intake["identity_evidence"] = bind(
        intake, proof["identity"], catalog, proof["model_root"],
        proof["motion_root"], proof["species_path"])
    validate_export_job(export_job)
    export_job_path = export_dir / "job.json"
    write_json(export_job_path, export_job)
    grants = ["--filesystem=" + str(output) + ":rw",
              "--filesystem=" + str(tools) + ":ro"]
    grants.extend("--filesystem=" + value + ":ro"
                  for value in export_read_paths(export_job))
    export_command = ["flatpak", "run", "--unshare=network",
                      "--nofilesystem=host", *grants, "org.blender.Blender",
                      "--background", "--factory-startup", "--disable-autoexec",
                      "--python-exit-code", "1", "--python",
                      str(tools / "phase5_godot_export_worker.py"), "--",
                      str(export_job_path)]
    _run_blender(export_command, export_dir / "export.log")
    comparison = verify_append_only(old_glb, export_dir / "model.glb",
                                    "physical_attack_2")
    result = {"species": species, "status": "append_only_verified",
              "base_job": str(base_job_path), "comparison": comparison,
              "export": json.loads((export_dir / "export.json").read_text())}
    write_json(directory / "result.json", result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, required=True)
    parser.add_argument("--human-review", type=Path, required=True)
    parser.add_argument("--base-export-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--importer", type=Path, required=True)
    parser.add_argument("--python-deps", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--only")
    parser.add_argument("--job-override", action="append", default=[])
    args = parser.parse_args()
    if not 1 <= args.jobs <= 4 or args.output.exists():
        raise ValueError("Use 1-4 jobs and a new output directory")
    registry = json.loads(args.registry.read_text())["profiles"]
    inventory = _entry_index(args.inventory)
    reviews = json.loads(args.human_review.read_text())["entries"]
    overrides = dict(value.split("=", 1) for value in args.job_override)
    selected = sorted(registry)
    if args.only:
        wanted = set(filter(None, args.only.split(",")))
        if not wanted <= set(selected):
            raise ValueError("Unknown --only species")
        selected = [species for species in selected if species in wanted]
    args.output.mkdir(parents=True)
    tools = Path(__file__).resolve().parent

    def run(species: str) -> dict:
        job = Path(overrides.get(
            species, args.base_export_root / species / "job.json"))
        return build_one(species, job.resolve(), inventory[species],
                         reviews[species], args.output.resolve(),
                         args.importer.resolve(), args.python_deps.resolve(), tools)

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {pool.submit(run, species): species for species in selected}
        for future in concurrent.futures.as_completed(futures):
            species = futures[future]
            try:
                result = future.result()
                print("VERIFIED", species, flush=True)
            except Exception as error:
                result = {"species": species, "status": "blocked",
                          "error": str(error)}
                print("BLOCKED", species, error, flush=True)
            results.append(result)
            write_json(args.output / "catalog.json", {
                "schema": 1, "runtime_approved": False,
                "entries": sorted(results, key=lambda item: item["species"]),
            })
    if any(item["status"] != "append_only_verified" for item in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
