#!/usr/bin/env python3
"""Local renderer/actor evidence for the audited catalog, without publication.

Sources and packs are read in place. Batches have retained PNGs, native inputs,
logs and receipts. Resume pins the exact code/data and independently rechecks
completed results. A differing pixel is a review hold, never a tolerated pass.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import fcntl
import signal
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from PIL import Image
import audit_shared_model_catalog as audit

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_bytes())


def frozen_inputs():
    # Track all runtime code and shipped model corrections used by the real
    # presenter, plus diagnostic code and the two catalogs. No caches/config.
    names = ["project.godot", "data/model_pair_catalog.json", "data/model_pair_pilot.json",
             "release/approved_3d_bundles_v11_index.json", "release/approved_3d_lossless_binding.json",
             "tools/qualify_shared_model_catalog.py", "tools/run_model_texture_sharing_probe.py",
             "tools/audit_shared_model_catalog.py",
             "tests/shared_model_catalog_actor_check.gd"]
    for directory in ["scripts", "resources/battle/model_animations", "resources/battle/model_visibility",
                      "tools/sprite_factory"]:
        names += [str(p.relative_to(ROOT)) for p in (ROOT / directory).rglob("*")
                  if p.is_file() and p.suffix in (".gd", ".json", ".res", ".gdshader", ".tscn", ".tres")]
    return {name: audit.file_sha(ROOT / name) for name in sorted(set(names))}


def compare(render):
    report = read(render / "report.json")
    assert report["complete"] and report["renderer"] == "mobile" and report["device"]
    rows = []
    for row in report["records"]:
        controls = [row[key] for key in ("source", "repeat_source", "candidate")]
        keys = set(controls[0]["frames"])
        assert len(keys) >= 10 and all(set(c["frames"]) == keys for c in controls)
        for field in ["camera_size", "response_schema", "animation_signature", "pose_signatures", "corrections"]:
            assert all(c[field] == controls[0][field] for c in controls), (row["identity"], field)
        frames = []
        for key in sorted(keys):
            pixels = []
            modes = []
            for control in controls:
                matches = [Path(p) for p in control["paths"] if Path(p).stem == key]
                assert len(matches) == 1
                path = matches[0].resolve()
                path.relative_to(render.resolve())
                with Image.open(path) as image:
                    assert image.size == (512, 512) and image.mode in ("RGB", "RGBA")
                    pixels.append(image.tobytes())
                    modes.append(image.mode)
                assert audit.sha(pixels[-1]) == control["frames"][key]
            assert len(set(modes)) == 1
            frames.append({"frame": key, "first_exact": pixels[2] == pixels[0],
                           "repeat_exact": pixels[2] == pixels[1], "control_exact": pixels[0] == pixels[1]})
        rows.append({"identity": row["identity"], "source_sha256": row["source_sha256"],
                     "candidate_sha256": row["candidate_sha256"], "frames": frames,
                     "corrections": controls[0]["corrections"],
                     "animation_and_pose_exact": True,
                     "pixels_exact": all(f["first_exact"] or f["repeat_exact"] for f in frames)})
    assert rows and len({r["identity"] for r in rows}) == len(rows)
    return rows


def run(command, log, timeout, environment):
    with log.open("x") as stream:
        if audit.CANCELED.is_set():
            raise RuntimeError("Qualification canceled")
        child = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=stream, stderr=subprocess.STDOUT)
        with audit.CHILDREN_LOCK:
            audit.CHILDREN.add(child)
        try:
            code = child.wait(timeout=timeout)
        except BaseException:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
            raise
        finally:
            with audit.CHILDREN_LOCK:
                audit.CHILDREN.discard(child)
    if code or re.search(r"(?:SCRIPT ERROR|^ERROR:|CATALOG_.*_ABORT)", log.read_text(), re.M):
        raise RuntimeError("Diagnostic failed; inspect " + str(log))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--source-report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--species", nargs="*", help="Explicit diagnostic subset; omitted means all selected pairs")
    parser.add_argument("--batch-size", type=int, default=12)
    parser.add_argument("--workers", type=int, choices=[1, 2], default=1)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name or not 1 <= args.batch_size <= 24:
        parser.error("Use assigned slot-env and batch-size 1..24")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    retained = args.audit.resolve()
    storage = read(retained / "report.json")
    golden = read(ROOT / "tools/sprite_factory/shared_model_catalog_results.json")
    assert storage["pairs"] == golden["pairs"] and storage["complete"] and storage["selected_pairs"] == 1084
    assert audit.file_sha(args.source_report) == storage["source_report_sha256"]
    catalog = read(ROOT / "data/model_pair_catalog.json")
    draft = read(retained / "draft-index.json")
    assert catalog["assets"] == draft["assets"]
    assert catalog["storage_audit_sha256"] == audit.file_sha(ROOT / "tools/sprite_factory/shared_model_catalog_results.json")
    approved = read(ROOT / "release/approved_3d_bundles_v11_index.json")
    originals = {a["asset_id"]: a for a in approved["assets"]}
    origins = {a["asset_id"]: Path(a["candidate_archive"]) for a in read(args.source_report)["assets"]}
    bindings = read(ROOT / "release/approved_3d_lossless_binding.json")["models"]
    selected = [a for a, proof in zip(catalog["assets"], storage["pairs"], strict=True) if proof["selected"]]
    if args.species:
        selected = [a for a in selected if a["appearances"][0]["runtime_identity"] in args.species]
        assert len(selected) == len(set(args.species)), "Unknown/unselected requested pair"
    # Begin with the four corrected rigs so failures cannot hide late in a run.
    priority = ["gliscor", "garchomp-mega", "charmander", "roaring-moon"]
    selected.sort(key=lambda a: (priority.index(a["appearances"][0]["runtime_identity"])
                               if a["appearances"][0]["runtime_identity"] in priority else 4, a["asset_id"]))
    config = {"schema": 1, "prototype_only": True, "production_approved": False,
              "full_selected_catalog": not bool(args.species), "assets": [a["asset_id"] for a in selected],
              "batch_size": args.batch_size, "workers": args.workers, "inputs": frozen_inputs(),
              "source_report_sha256": audit.file_sha(args.source_report),
              "storage_report_sha256": audit.file_sha(retained / "report.json"),
              "godot": subprocess.check_output(["godot", "--version"], text=True).strip()}
    output.mkdir(parents=True, exist_ok=args.resume)
    if args.resume:
        assert read(output / "configuration.json") == config, "Frozen qualification inputs changed"
    else:
        audit.write_json(output / "configuration.json", config)
    started = time.monotonic()
    results = []
    project_lock = (ROOT / ".tmp/diagnostic-project.lock").open("a+")
    fcntl.flock(project_lock, fcntl.LOCK_SH | fcntl.LOCK_NB)
    def interrupt(_signal, _frame):
        audit.cancel_children()
        raise KeyboardInterrupt("Qualification interrupted; retained completed evidence")
    signal.signal(signal.SIGTERM, interrupt)

    def process_batch(offset):
        codec = audit.Zstd()
        assets = selected[offset:offset + args.batch_size]
        batch = output / f"batch-{offset:04d}"
        receipt_path = output / f"batch-{offset:04d}.receipt.json"
        for asset in assets:
            pack = retained / "packs" / Path(asset["object_key"]).name
            assert pack.stat().st_size == asset["size_bytes"] and audit.file_sha(pack) == asset["sha256"]
            original = originals[asset["asset_id"]]
            archive = origins[asset["asset_id"]]
            assert archive.stat().st_size == original["size_bytes"] and audit.file_sha(archive) == original["sha256"]
        if receipt_path.exists():
            receipt = read(receipt_path)
            assert receipt["assets"] == [a["asset_id"] for a in assets]
            completed = Path(receipt["directory"])
            completed.resolve().relative_to(output)
            assert receipt["render"] == compare(completed / "render")
            assert receipt["actor_receipt_sha256"] == audit.file_sha(completed / "actors.json")
            assert read(completed / "actors.json")["complete"]
            return receipt["render"]
        # Interrupted batches are retained and require a fresh attempt directory.
        attempt = batch
        number = 0
        while attempt.exists():
            number += 1
            attempt = output / f"batch-{offset:04d}-attempt-{number}"
        attempt.mkdir()
        environment = os.environ.copy()
        for variable in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME"]:
            private = attempt / "runtime" / variable.lower()
            private.mkdir(parents=True)
            environment[variable] = str(private)
        fixture = {"schema": 1, "packs": [], "models": [], "pairs": []}
        for asset in assets:
            identity = asset["appearances"][0]["runtime_identity"]
            models, _installed = audit.prepare_sources(originals[asset["asset_id"]], origins[asset["asset_id"]],
                                                        attempt / "sources" / identity, bindings, codec)
            pack = retained / "packs" / Path(asset["object_key"]).name
            fixture["packs"].append({"path": str(pack), "asset": asset})
            fixture["pairs"].append(identity)
            for source, appearance in zip(models, asset["appearances"], strict=True):
                assert source["identity"] == appearance["runtime_identity"] and source["sha256"] == appearance["source_sha256"]
                fixture["models"].append({"identity": source["identity"], "variant": source["variant"],
                    "source_path": source["path"], "source_sha256": source["sha256"], "source_bytes": source["bytes"],
                    "candidate_path": asset["pair_manifest"]["resource_root"] + "/" + appearance["runtime_path"],
                    "candidate_sha256": appearance["runtime_sha256"], "candidate_bytes": appearance["bytes"],
                    "pack_path": str(pack), "pair_asset": asset})
        audit.write_json(attempt / "input.json", fixture)
        print("CATALOG_BATCH_START", offset, "/", len(selected), flush=True)
        run([sys.executable, str(ROOT / "tools/run_model_texture_sharing_probe.py"), "--mode", "catalog-render",
             "--input", str(attempt / "input.json"), "--output", str(attempt / "render"), "--timeout", "1800"],
            attempt / "render-driver.log", 1830, environment)
        rendered = compare(attempt / "render")
        assert {r["identity"] for r in rendered} == {m["identity"] for m in fixture["models"]}
        run(["godot", "--path", str(ROOT), "--rendering-method", "mobile", "--resolution", "640x480",
             "--log-file", str(attempt / "actors.engine.log"), "--script", "res://tests/shared_model_catalog_actor_check.gd",
             "--", str(attempt / "input.json"), str(attempt / "actors.json")], attempt / "actors.log", 1800, environment)
        actors = read(attempt / "actors.json")
        assert actors["complete"] and actors["pairs"] == fixture["pairs"]
        receipt = {"directory": str(attempt), "assets": [a["asset_id"] for a in assets], "render": rendered,
                   "actor_receipt_sha256": audit.file_sha(attempt / "actors.json")}
        audit.write_json(attempt / "receipt.json", receipt)
        audit.write_json(receipt_path, receipt)
        return rendered

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        pending = [pool.submit(process_batch, offset) for offset in range(0, len(selected), args.batch_size)]
        try:
            for future in as_completed(pending):
                results.extend(future.result())
                audit.write_json(output / "progress.json", {"pairs": len(results) // 2, "total": len(selected),
                    "render_holds": [r["identity"] for r in results if not r["pixels_exact"]], "elapsed_seconds": time.monotonic() - started})
                print("CATALOG_BATCH_DONE", len(results) // 2, "/", len(selected), "holds=", sum(not r["pixels_exact"] for r in results), flush=True)
        except BaseException:
            audit.cancel_children()
            for future in pending:
                future.cancel()
            raise
    results.sort(key=lambda row: row["identity"])
    assert frozen_inputs() == config["inputs"], "Qualification inputs changed during run"
    report = {**config, "complete": True, "appearances": len(results), "records": results,
              "candidate_frames": sum(len(r["frames"]) for r in results),
              "pixels_exact": all(r["pixels_exact"] for r in results), "elapsed_seconds": time.monotonic() - started}
    audit.write_json(output / "report.json", report)
    print("CATALOG_QUALIFICATION_COMPLETE", report["appearances"], "frames=", report["candidate_frames"], "pixels_exact=", report["pixels_exact"])


if __name__ == "__main__":
    main()
