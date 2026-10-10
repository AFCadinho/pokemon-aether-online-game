#!/usr/bin/env python3
"""Measure exact full-catalog pack/installation costs without runtime admission.

Approved v11 ZIPs are read in place. Native graph production and physical pack
validation run in independent headless processes. Only owned derived work is
discarded after a successful batch; source archives, logs and receipts remain.
"""
import argparse
import copy
from concurrent.futures import ThreadPoolExecutor, as_completed
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import struct
import subprocess
import sys
import threading
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/sprite_factory"))
from native_resource_compression_probe import Zstd, decode, encode

SCRIPT = "res://tools/sprite_factory/shared_model_catalog_probe.gd"
PROOF_INPUTS = ["release/approved_3d_bundles_v11_index.json", "release/approved_3d_lossless_binding.json",
                "scripts/battle/battle_ui/reviewed_model_catalog.json", "data/model_pair_pilot.json",
                "tools/audit_shared_model_catalog.py", "tools/sprite_factory/shared_model_catalog_probe.gd",
                "tools/sprite_factory/native_resource_compression_probe.py",
                "tools/sprite_factory/model_texture_audit.gd", "scripts/services/model_pair_pack.gd",
                "tools/sprite_factory/model_pair_bundle_contract.gd"]
CHILDREN = set()
CHILDREN_LOCK = threading.Lock()
CANCELED = threading.Event()


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""):
            digest.update(chunk)
    return digest.hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode()


def write_json(path, value):
    path.write_bytes(encoded(value))


def read_rows(path):
    return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []


def checkpoints(rows, assets, output, origins):
    """Resume only complete source-bound receipts with intact retained packs."""
    known = {asset["asset_id"]: (position, asset) for position, asset in enumerate(assets)}
    done = {}
    for row in rows:
        identity = row["asset_id"]
        if identity not in known or identity in done:
            raise ValueError("Unknown or duplicate checkpoint: " + identity)
        position, source = known[identity]
        if row["source_archive_sha256"] != source["sha256"] or row["source_download_bytes"] != source["size_bytes"]:
            raise ValueError("Checkpoint source binding changed: " + identity)
        archive = origins[Path(source["object_key"]).name]
        if archive.stat().st_size != source["size_bytes"] or file_sha(archive) != source["sha256"]:
            raise ValueError("Checkpoint source archive changed: " + identity)
        if "shared_pck_bytes" in row:
            candidate = json.loads((output / "candidate-assets" / str(position) / "asset.json").read_bytes())
            if (candidate["asset_id"] != identity or candidate["sha256"] != row["shared_pack_sha256"]
                    or candidate["size_bytes"] != row["shared_pck_bytes"]):
                raise ValueError("Checkpoint candidate metadata changed: " + identity)
            if row["eligible"]:
                pack = output / "packs" / Path(candidate["object_key"]).name
                if pack.stat().st_size != candidate["size_bytes"] or file_sha(pack) != candidate["sha256"]:
                    raise ValueError("Checkpoint retained pack changed: " + identity)
        done[identity] = row
    return done


def cancel_children():
    CANCELED.set()
    with CHILDREN_LOCK:
        for child in CHILDREN:
            child.terminate()


def native(raw, codec):
    data = encode(raw, 262144, 9, codec)
    if decode(data, codec) != raw:
        raise ValueError("Native reframe changed decoded bytes")
    return data


def unpack_native(data, codec):
    return data[4:] if data[:4] == b"RSRC" and data[-4:] == b"RSRC" else decode(data, codec)


def prepare_sources(asset, source, directory, bindings, codec):
    if source.stat().st_size != asset["size_bytes"] or file_sha(source) != asset["sha256"]:
        raise ValueError("Approved source archive checksum/size mismatch: " + asset["asset_id"])
    directory.mkdir(parents=True)
    with zipfile.ZipFile(source) as archive:
        if sorted(archive.namelist()) != ["bundle.json", "models/normal.scn", "models/shiny.scn"]:
            raise ValueError("Unexpected approved source member set: " + asset["asset_id"])
        manifest_bytes = archive.read("bundle.json")
        manifest = json.loads(manifest_bytes)
        for field in ("asset_id", "species_id", "form_id", "version", "dependencies", "appearances"):
            if field == "appearances":
                continue # Index rows omit the native size present in the manifest.
            if manifest.get(field) != asset.get(field):
                raise ValueError("Approved source manifest mismatch: " + field)
        models = []
        installed = len(manifest_bytes)
        for row in asset["appearances"]:
            data = archive.read("models/" + row["variant"] + ".scn")
            identity = row["runtime_identity"]
            binding = bindings[identity]
            digest = sha(data)
            matching = next(x for x in manifest["appearances"] if x["variant"] == row["variant"])
            if any(matching.get(key) != value for key, value in row.items()):
                raise ValueError("Approved source appearance metadata differs from index: " + identity)
            if digest != row["runtime_sha256"] or digest != binding["candidate_sha256"] or matching["runtime_sha256"] != digest or matching["bytes"] != len(data):
                raise ValueError("Approved native source mismatch: " + identity)
            raw = unpack_native(data, codec)
            if sha(raw) != binding["decoded_sha256"]:
                raise ValueError("Lossless decoded source binding mismatch: " + identity)
            target = directory / (row["variant"] + ".scn")
            target.write_bytes(data)
            models.append({"identity": identity, "variant": row["variant"], "path": str(target),
                           "sha256": digest, "bytes": len(data), "decoded_sha256": sha(raw),
                           "source_container": data[:4].decode("ascii"),
                           "codec_control_method": "reframe-original-rscc" if data[:4] == b"RSCC" else "serialize-rsrc-first",
                           "cache_source_bytes": binding["cache_source_bytes"]})
            installed += len(data)
    if file_sha(source) != asset["sha256"]:
        raise ValueError("Approved archive changed while reading")
    return models, installed


def build_pack(asset, produced, models, kind, directory, codec, versions):
    directory.mkdir(parents=True)
    resource_root = produced["resource_root"] if kind == "shared" else "res://pokemon-pairs/" + sha((produced["resource_root"] + kind).encode())
    payloads, appearances = {}, []
    for row, source in zip(produced["models"], models, strict=True):
        # RSRC uses absolute resource offsets including its four-byte magic.
        # Removing that magic and wrapping the unchanged stream in RSCC makes
        # those offsets invalid. Its equal-codec control therefore needs the
        # same verified nonsharing serializer used by the serializer control.
        # Only already-compressed RSCC sources qualify byte-exact reframing.
        if kind == "codec_control" and source["source_container"] == "RSCC":
            path = source["path"]
        elif kind in ("codec_control", "serializer_control"):
            path = row["serializer_control_path"]
        else:
            path = row["shared_path"]
        original = Path(path).read_bytes()
        raw = unpack_native(original, codec)
        data = native(raw, codec)
        name = "models/" + row["variant"] + ".scn"
        payloads[name] = data
        appearances.append({"variant": row["variant"], "runtime_identity": row["identity"],
                            "runtime_path": name, "runtime_sha256": sha(data), "bytes": len(data),
                            "source_sha256": source["sha256"], "cache_source_bytes": source["cache_source_bytes"],
                            "semantic_sha256": row["semantic_sha256"]})
    if kind == "shared":
        for path in sorted((Path(produced["directory"]) / "textures").glob("*.res")):
            payloads["textures/" + path.name] = native(unpack_native(path.read_bytes(), codec), codec)
    version = max(asset["version"], versions.get(asset["asset_id"], 0)) + 1
    manifest = {"schema": 1, "kind": "pokeaether-model-pair", "asset_id": asset["asset_id"],
                "species_id": asset["species_id"], "form_id": asset["form_id"], "version": version,
                "dependencies": asset["dependencies"], "appearances": appearances, "resource_root": resource_root,
                "files": [{"path": name, "bytes": len(data), "sha256": sha(data),
                           "decoded_bytes": struct.unpack_from("<I", data, 12)[0]} for name, data in sorted(payloads.items())]}
    payloads["bundle.json"] = encoded(manifest)
    files = []
    for name, data in sorted(payloads.items()):
        path = directory / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        files.append({"virtual_path": resource_root + "/" + name, "source_path": str(path)})
    candidate = {key: copy.deepcopy(value) for key, value in asset.items()
                 if key not in ("sha256", "size_bytes", "object_key", "appearances", "version")}
    candidate.update(format="model-pair-pck-v1", version=version, appearances=appearances, pair_manifest=manifest)
    return {"asset": candidate, "path": str(directory.with_suffix(".pck")), "files": files}


class ProbeFailure(RuntimeError):
    def __init__(self, mode, log, text):
        super().__init__(f"{mode} probe failed; inspect {log}")
        markers = re.findall(r"CATALOG_(?:PRODUCE|VALIDATE)_BEGIN (\S+)", text)
        self.asset_id = markers[-1] if markers else None
        self.log_sha256 = file_sha(log)


def run_probe(mode, request, output, timeout):
    if CANCELED.is_set():
        raise InterruptedError("Catalog audit canceled")
    input_path = output.with_suffix(".input.json")
    write_json(input_path, request)
    log = output.with_suffix(".log")
    # Each role has its own minimal project/cache. In particular, physical
    # verification never inherits the producer's resource UID mappings.
    project = output.parent / "projects" / output.name
    project.mkdir(parents=True, exist_ok=True)
    (project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Offline Shared Catalog Audit"\n')
    for name in ("tools/sprite_factory/shared_model_catalog_probe.gd", "tools/sprite_factory/model_texture_audit.gd",
                 "tools/sprite_factory/model_pair_bundle_contract.gd", "scripts/services/model_pair_pack.gd"):
        path = project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes((ROOT / name).read_bytes()) # Tracked code only, no assets/cache transfer.
    env = os.environ.copy()
    env["POKEAETHER_CATALOG_WORK_ROOT"] = str(ROOT / ".tmp")
    for kind in ("data", "config", "cache"):
        path = project / "runtime" / kind
        path.mkdir(parents=True, exist_ok=True)
        env[f"XDG_{kind.upper()}_HOME"] = str(path)
    with log.open("w") as stream:
        child = subprocess.Popen(["godot", "--log-file", str(output.with_suffix(".engine.log")),
                                  "--headless", "--path", str(project), "--script", SCRIPT,
                                  "--", mode, str(input_path), str(output)], env=env, stdout=stream, stderr=subprocess.STDOUT)
        with CHILDREN_LOCK:
            CHILDREN.add(child)
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
            with CHILDREN_LOCK:
                CHILDREN.discard(child)
    text = log.read_text()
    if code or re.search(r"(?:SCRIPT ERROR|^ERROR:|CATALOG_PROBE_ERROR)", text, re.M):
        raise ProbeFailure(mode, log, text)


def probe_pairs(mode, request, output):
    """Keep successful checkpoints and isolate a data-dependent failing pair."""
    remaining = list(request["jobs"])
    completed, failures, attempt = {}, {}, 0
    while remaining:
        folder = output.with_name(output.name + "-" + str(attempt))
        failure = None
        try:
            run_probe(mode, {**request, "jobs": remaining}, folder, 1800)
        except ProbeFailure as error:
            failure = error
        rows = read_rows(folder / "receipts.jsonl")
        if any(not isinstance(row, dict) or "asset_id" not in row for row in rows):
            if failure is None:
                raise ValueError("Probe emitted an invalid successful receipt")
            # A GDScript assertion can return a default empty dictionary
            # before the queued error exit. It is never a completed pair.
            rows = [row for row in rows if isinstance(row, dict) and "asset_id" in row]
        completed.update({row["asset_id"]: row for row in rows})
        def identity(job):
            return job.get("asset_id", job.get("asset", {}).get("asset_id"))
        if failure is not None:
            if failure.asset_id not in {identity(job) for job in remaining}:
                raise failure # Parser/infrastructure failures are not asset verdicts.
            completed.pop(failure.asset_id, None)
            failures[failure.asset_id] = {"error": str(failure), "log_sha256": failure.log_sha256}
            print("CATALOG_PAIR_NEEDS_REVIEW", failure.asset_id, mode, flush=True)
        remaining = [job for job in remaining if identity(job) not in completed and identity(job) not in failures]
        if failure is None and remaining:
            raise ValueError("Probe exited successfully without complete pair receipts")
        attempt += 1
    return completed, failures



def audit_batch(entries, output, origins, bindings, versions, hashes, compression_workers):
    codec = Zstd()
    # A new attempt directory preserves any interrupted earlier work/logs.
    batch = output / "work" / ("batch-" + str(entries[0][0]) + "-" + str(time.time_ns()))
    batch.mkdir(parents=True)
    jobs = []
    for position, asset in entries:
        source = origins[Path(asset["object_key"]).name]
        models, installed = prepare_sources(asset, source, batch / "sources" / str(position), bindings, codec)
        jobs.append({"position": position, "asset": asset, "models": models,
                     "source_archive": str(source), "source_installed_bytes": installed})
    recipe_hash = sha(encoded(hashes))
    produced, producer_failures = probe_pairs("produce", {"recipe_hash": recipe_hash, "jobs": jobs}, batch / "produced")
    pack_jobs, validation = [], []
    for job in jobs:
        asset = job["asset"]
        if asset["asset_id"] in producer_failures:
            continue
        pair = produced[asset["asset_id"]]
        kinds = ("codec_control", "serializer_control", "shared")
        with ThreadPoolExecutor(max_workers=compression_workers) as pool:
            futures = {kind: pool.submit(build_pack, asset, pair, job["models"], kind,
                                        batch / "members" / str(job["position"]) / kind, codec, versions) for kind in kinds}
            packs = {kind: futures[kind].result() for kind in kinds}
        pack_jobs.extend(packs.values())
        validation.append({"asset_id": asset["asset_id"], "models": pair["models"], "packs": packs})
    run_probe("pack", [{"path": p["path"], "files": p["files"]} for p in pack_jobs], batch / "packed", 1800)
    for pin in pack_jobs:
        path = Path(pin["path"])
        asset = pin["asset"]
        asset.update(sha256=file_sha(path), size_bytes=path.stat().st_size)
        asset["object_key"] = f'optional-assets/pokemon_3d/{asset["species_id"]}/{asset["form_id"]}/v{asset["version"]}-{asset["sha256"]}.pck'
        pin.pop("files")
    verified, validation_failures = probe_pairs("validate", {"jobs": validation}, batch / "validated")
    if set(verified) | set(validation_failures) | set(producer_failures) != {j["asset"]["asset_id"] for j in jobs}:
        raise ValueError("Incomplete physical validation")
    validation_by_id = {j["asset_id"]: j for j in validation}
    archive_pins = []
    for job in jobs:
        asset_id = job["asset"]["asset_id"]
        if asset_id in producer_failures or asset_id in validation_failures:
            failure = producer_failures.get(asset_id, validation_failures.get(asset_id))
            archive_pins.append({"asset_id": asset_id, "runtime_identity": job["models"][0]["identity"],
                                 "source_archive_sha256": job["asset"]["sha256"],
                                 "source_download_bytes": job["asset"]["size_bytes"],
                                 "source_installed_bytes": job["source_installed_bytes"],
                                 "eligible": False, "selected": False, "physical_checks": {},
                                 "needs_review": failure, "models": [{k: v for k, v in m.items() if k != "path"} for m in job["models"]]})
            if file_sha(job["source_archive"]) != job["asset"]["sha256"]:
                raise ValueError("Approved archive changed during failed-pair audit")
            continue
        validation_job = validation_by_id[asset_id]
        pair = produced[asset_id]
        pins = validation_job["packs"]
        checks = verified[asset_id]["packs"]
        pin = pins["shared"]
        eligible = all(checks[kind]["ok"] for kind in pins)
        transfer_win = eligible and pin["asset"]["size_bytes"] < job["asset"]["size_bytes"]
        installation_win = eligible and checks["shared"]["installed_bytes"] < job["source_installed_bytes"]
        selected = transfer_win and installation_win
        record = {"asset_id": asset_id, "runtime_identity": job["models"][0]["identity"],
                  "source_archive_sha256": job["asset"]["sha256"],
                  "source_download_bytes": job["asset"]["size_bytes"],
                  "source_installed_bytes": job["source_installed_bytes"],
                  "codec_control_pck_bytes": pins["codec_control"]["asset"]["size_bytes"],
                  "serializer_control_pck_bytes": pins["serializer_control"]["asset"]["size_bytes"],
                  "shared_pck_bytes": pin["asset"]["size_bytes"],
                  "shared_installed_bytes": checks["shared"].get("installed_bytes", 0),
                  "shared_pack_sha256": pin["asset"]["sha256"],
                  "eligible": eligible, "selected": selected,
                  "texture_summary": pair["texture_summary"], "texture_files": pair["texture_files"],
                  "replacements": pair["replacements"], "physical_checks": checks,
                  "models": [{**source, "semantic_sha256": row["semantic_sha256"],
                              "candidate_sha256": pin["asset"]["appearances"][i]["runtime_sha256"]}
                             for i, (source, row) in enumerate(zip(job["models"], pair["models"], strict=True))]}
        for row in record["models"]:
            row.pop("path")
        candidate_directory = output / "candidate-assets" / str(job["position"])
        candidate_directory.mkdir(parents=True, exist_ok=True)
        write_json(candidate_directory / "asset.json", pin["asset"])
        if eligible:
            packs = output / "packs"
            packs.mkdir(exist_ok=True)
            target = packs / Path(pin["asset"]["object_key"]).name
            if target.exists() and file_sha(target) != pin["asset"]["sha256"]:
                raise ValueError("Immutable retained pack collision")
            if not target.exists():
                Path(pin["path"]).rename(target)
        if file_sha(job["source_archive"]) != job["asset"]["sha256"]:
            raise ValueError("Approved archive changed during audit")
        archive_pins.append(record)
    # Logs and small receipts remain; only this run's temporary derived
    # model payloads are removed, after the verifier process has exited.
    for path in list(batch.iterdir()):
        if path.is_dir() and (path.name in ("sources", "members") or path.name.startswith(("produced-", "validated-"))):
            if path.name.startswith(("produced-", "validated-")) and (path / "receipts.jsonl").exists():
                (path / "receipts.jsonl").rename(batch / (path.name + ".receipts.jsonl"))
            shutil.rmtree(path)
    return archive_pins

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-report", type=Path, required=True, help="Retained v11 preparation archive locations")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=20)
    parser.add_argument("--compression-workers", type=int, default=2)
    parser.add_argument("--batch-workers", type=int, default=2)
    parser.add_argument("--limit", type=int, help="Explicit smoke-test subset, not full catalog qualification")
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Use assigned slot-env")
    if not 1 <= args.batch_size <= 50 or not 1 <= args.compression_workers <= 4 or not 1 <= args.batch_workers <= 4 or args.limit is not None and args.limit < 1:
        parser.error("Bounded batch size and positive subset required")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    if output.exists() != args.resume:
        parser.error("Fresh output required, or explicitly resume existing output")
    output.mkdir(parents=True, exist_ok=True)
    codec = Zstd()
    hashes = {name: file_sha(ROOT / name) for name in PROOF_INPUTS}
    index = json.loads((ROOT / PROOF_INPUTS[0]).read_bytes())
    bindings = json.loads((ROOT / PROOF_INPUTS[1]).read_bytes())["models"]
    pilot = json.loads((ROOT / "data/model_pair_pilot.json").read_bytes())
    versions = {a["asset_id"]: a["version"] for a in pilot["assets"]}
    assets = index["assets"][:args.limit] if args.limit else index["assets"]
    origins = {Path(a["candidate_archive"]).name: Path(a["candidate_archive"]) for a in json.loads(args.source_report.read_bytes())["assets"]}
    for asset in assets:
        if not origins.get(Path(asset["object_key"]).name, Path("/nonexistent")).is_file():
            raise ValueError("Missing approved source: " + asset["asset_id"])
    contract = {"schema": 1, "prototype_only": True, "production_approved": False,
                "full_catalog": args.limit is None, "pairs": len(assets), "source_sha256": hashes,
                "libzstd": codec.version, "godot": subprocess.check_output(["godot", "--version"], text=True).strip(),
                "block_size": 262144, "level": 9,
                "source_report_sha256": file_sha(args.source_report), "batch_size": args.batch_size,
                "compression_workers": args.compression_workers, "batch_workers": args.batch_workers}
    configuration = output / "configuration.json"
    if args.resume:
        if json.loads(configuration.read_bytes()) != contract:
            raise ValueError("Resume inputs/tools/codec differ from recorded run")
    else:
        write_json(configuration, contract)
    lock = (ROOT / ".tmp/diagnostic-project.lock").open("a+")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    receipts = output / "receipts.jsonl"
    done = checkpoints(read_rows(receipts), assets, output, origins)
    pending = [(position, asset) for position, asset in enumerate(assets) if asset["asset_id"] not in done]
    started = time.monotonic()
    def interrupted(_signal, _frame):
        cancel_children()
        raise KeyboardInterrupt("Catalog audit interrupted; owned receipts retained")
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    try:
        with ThreadPoolExecutor(max_workers=args.batch_workers) as executor:
            futures = [executor.submit(audit_batch, pending[offset:offset + args.batch_size], output,
                                       origins, bindings, versions, hashes, args.compression_workers)
                       for offset in range(0, len(pending), args.batch_size)]
            try:
                for future in as_completed(futures):
                    archive_pins = future.result()
                    with receipts.open("a") as stream:
                        for record in archive_pins:
                            stream.write(json.dumps(record, separators=(",", ":")) + "\n")
                            done[record["asset_id"]] = record
                        stream.flush()
                    report = {**contract, "complete": len(done) == len(assets), "completed_pairs": len(done),
                              "elapsed_this_invocation_seconds": round(time.monotonic() - started, 2)}
                    write_json(output / "progress.json", report)
                    print("CATALOG_AUDIT_PROGRESS", len(done), "/", len(assets),
                          "download_saving_bytes", sum(r["source_download_bytes"] - r["shared_pck_bytes"] for r in done.values() if r["selected"]), flush=True)
            except BaseException:
                cancel_children()
                for future in futures:
                    future.cancel()
                raise
    finally:
        lock.close()
    if (len(done) != len(assets) or file_sha(args.source_report) != contract["source_report_sha256"]
            or any(file_sha(ROOT / name) != digest for name, digest in hashes.items())):
        raise ValueError("Catalog audit is incomplete or frozen proof inputs changed")
    rows = [done[a["asset_id"]] for a in assets]
    totals = {key: sum(row.get(key, 0) for row in rows) for key in ("source_download_bytes", "source_installed_bytes",
              "codec_control_pck_bytes", "serializer_control_pck_bytes", "shared_pck_bytes", "shared_installed_bytes")}
    totals["selected_download_bytes"] = sum(r["shared_pck_bytes"] if r["selected"] else r["source_download_bytes"] for r in rows)
    totals["selected_installed_bytes"] = sum(r["shared_installed_bytes"] if r["selected"] else r["source_installed_bytes"] for r in rows)
    result = {**contract, "complete": True, "source_assets_byte_verified": len(rows),
              "physically_qualified_pairs": sum(r["eligible"] for r in rows), "selected_pairs": sum(r["selected"] for r in rows),
              "measured_candidate_pairs": sum("shared_pck_bytes" in r for r in rows),
              "native_graph_checks": sum(check.get("scenes_exact", 0) for r in rows for check in r["physical_checks"].values()),
              "totals": totals, "receipts_sha256": file_sha(receipts), "pairs": rows}
    write_json(output / "report.json", result)
    selected = copy.deepcopy(index)
    selected.update(catalog_revision="shared-model-full-catalog-audit-draft", prototype_only=True,
                    production_approved=False, runtime_contract={"pokemon_3d": 2, "godot": "4.6"})
    for position, row in enumerate(rows):
        if row["selected"]:
            selected["assets"][position] = json.loads((output / "candidate-assets" / str(position) / "asset.json").read_bytes())
    write_json(output / "draft-index.json", selected)
    print("CATALOG_AUDIT_COMPLETE", json.dumps({"pairs": len(rows), "selected": result["selected_pairs"], "totals": totals}), flush=True)


if __name__ == "__main__":
    main()
