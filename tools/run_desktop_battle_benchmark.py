#!/usr/bin/env python3
"""Slot-only visible desktop benchmark. Public pinned art; no account/server access."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import subprocess
import time
import uuid
import zipfile

from tools.run_android_quality_benchmark import ROOT, MOVES, prepare_assets, validate_entry

ORDERS = [["low", "medium", "high", "ultra"], ["ultra", "high", "medium", "low"], ["medium", "low", "ultra", "high"]]


def validate(details, fixture):
    errors = []
    if not isinstance(details, dict) or details.get("run_id") != fixture["run_id"] or not details.get("complete"):
        return ["Missing, stale or incomplete desktop result"]
    if details.get("failures") or details.get("engine_errors"):
        errors.append("Engine/workload errors")
    if details.get("renderer") != "forward_plus" or details.get("adapter") != fixture.get("expected_adapter"):
        errors.append("Unexpected native renderer/GPU")
    phases = details.get("phases", [])
    if [r.get("preset") for r in phases] != fixture["order"]:
        errors.append("Wrong/incomplete profile sequence")
    for row in phases:
        if not fixture["seconds"] <= row.get("seconds", 0) < fixture["seconds"] + 90:
            errors.append("Incomplete/stalled observation")
        entry = row.get("entry", {})
        case_index = row.get("index", 0) if fixture["mode"] == "entry" else 0
        errors.extend(validate_entry(dict(row, index=case_index), {"entry_warmup": fixture["warmup"]}))
        native = entry.get("arena_native_size", [])
        if len(native) != 2 or any(not isinstance(n, int) or n < 2 or n > 1922 for n in native):
            errors.append("Missing actual desktop arena size")
        else:
            scale = {"low": .5, "medium": .75, "high": 1, "ultra": 1}[row["preset"]]
            expected = [max(2, math.floor(n * scale + .5)) for n in native]
            if row.get("render_size") != expected or row.get("response_size") != expected:
                errors.append("Desktop passes do not match relative profile scale")
        if row.get("msaa") != {"low": 0, "medium": 1, "high": 1, "ultra": 2}[row["preset"]]:
            errors.append("Incorrect profile MSAA")
        for metric in ("frame_ms", "main_gpu_ms", "response_gpu_ms"):
            stat = row.get("timings", {}).get(metric, {})
            if stat.get("count", 0) < 10 or any(not isinstance(stat.get(k), (float, int)) or not math.isfinite(stat[k]) for k in ("p50", "p95", "p99", "max")):
                errors.append("Missing finite frame/GPU timings")
        gameplay = row.get("gameplay", {})
        if not gameplay.get("menu_in_host") or not all(tab.get("visible") for tab in gameplay.get("tabs", [])):
            errors.append("Menu was not rendered in the ordinary host overlay")
        if not gameplay.get("complete") or [m.get("move") for m in gameplay.get("moves", [])] != MOVES or len(gameplay.get("tabs", [])) != 8:
            errors.append("Incomplete real move/menu workload")
        for move in gameplay.get("moves", []):
            if not move.get("cleaned") or not move.get("hit_seen") or move.get("render_visible_frames", 0) <= 0:
                errors.append("Missing real effect impact/visibility/cleanup")
            for metric in ("frame_ms", "main_gpu_ms", "response_gpu_ms"):
                stat = move.get("timings", {}).get(metric, {})
                if stat.get("count", 0) < 2 or any(not isinstance(stat.get(k), (float, int)) or not math.isfinite(stat[k]) for k in ("p50", "p95", "p99", "max")):
                    errors.append("Missing finite real move timings")
    if fixture["mode"] == "soak" and len({r.get("stage_instance") for r in phases}) != 1:
        errors.append("Soak recreated its battle")
    if fixture["mode"] != "soak" and len({r.get("stage_instance") for r in phases}) != len(phases):
        errors.append("Each observation must reconstruct its battle")
    captures = details.get("move_captures", [])
    if len(captures) != 4 or any(r.get("visible_pieces", 0) <= 0 or r.get("elapsed", 0) < r.get("impact", 0) + .025 for r in captures):
        errors.append("Missing separate visible impact evidence")
    return sorted(set(errors))


def prepare_fixture(output, mode, repeat, warmup):
    files, pins = prepare_assets(ROOT / ".tmp/android-quality-phone/fixtures")
    catalog = json.loads((ROOT / "data/model_pair_release_v16_catalog.json").read_text())
    models = [{"asset": asset, "path": str(files["/" + asset["object_key"]])}
              for asset in catalog["assets"] if "/" + asset["object_key"] in files]
    descriptor = json.loads((ROOT / "data/android_3d_experiment.json").read_text())["arena"]
    forest = output.parent / "fixtures/forest-runtime"
    forest.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(files["/" + descriptor["object_key"]]) as archive:
        if set(archive.namelist()) != {"forest-runtime/forest.pck", "forest-runtime/forest.json"}:
            raise ValueError("Unexpected arena archive members")
        for name in ("forest.pck", "forest.json"):
            path = forest / name
            payload = archive.read("forest-runtime/" + name)
            if name == "forest.pck" and (len(payload) != descriptor["pack_bytes"] or hashlib.sha256(payload).hexdigest() != descriptor["pack_sha256"]):
                raise ValueError("Invalid pinned forest pack")
            if not path.exists() or path.read_bytes() != payload:
                path.write_bytes(payload)
    order = ORDERS[repeat] if mode == "profiles" else ["ultra"] * 20 if mode == "soak" else ["medium"] * (3 if mode == "entry" else 1)
    return {"schema": 1, "run_id": uuid.uuid4().hex, "mode": mode, "repeat": repeat, "warmup": warmup,
            "seconds": 15 if mode == "smoke" else 30, "order": order, "output": str(output),
            "forest_manifest": str(forest / "forest.json"), "models": models, "pins": pins}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mode", choices=["smoke", "profiles", "entry", "soak"], required=True)
    parser.add_argument("--repeat", type=int, choices=[0, 1, 2], default=0)
    parser.add_argument("--warmup", action="store_true")
    args = parser.parse_args()
    if ROOT.parent.name not in {"slot-a", "slot-b", "slot-c"} or os.getenv("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Use the assigned slot-env")
    if args.warmup and args.mode not in {"entry", "smoke"}:
        parser.error("Warmup control requires entry/smoke mode")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    fixture = prepare_fixture(output, args.mode, args.repeat, args.warmup)
    fixture["expected_adapter"] = subprocess.check_output(["nvidia-smi", "--query-gpu=name", "--format=csv,noheader"], text=True).strip().splitlines()[0]
    fixture_path = output / "fixture.json"
    fixture_path.write_text(json.dumps(fixture, indent=2) + "\n")
    report = {"schema": 1, "usable": False, "running": True, "errors": [], "health": [],
              "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)),
              "godot": subprocess.check_output(["godot", "--version"], text=True).strip(),
              "no_account_or_server_access": True, "mode": args.mode}
    def save():
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    command = ["godot", "--path", str(ROOT), "--rendering-method", "forward_plus", "--windowed",
               "--resolution", "1600x900", "--log-file", str(output / "engine.log"),
               "--script", "res://tests/desktop_battle_benchmark.gd", "--", str(fixture_path)]
    report["hardware"] = {"cpu": next((line.split(":",1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")), "unknown"),
                          "kernel": os.uname().release,
                          "gpu_driver_memory": subprocess.check_output(["nvidia-smi", "--query-gpu=name,driver_version,memory.total", "--format=csv,noheader"], text=True).strip()}
    report["command"] = command
    save()
    started = time.monotonic()
    last_phase = ""
    with (output / "stdout.log").open("w") as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        report["pid"] = process.pid
        def interrupted(signum, _frame):
            raise RuntimeError("Host interrupted by signal " + str(signum))
        previous_term = signal.signal(signal.SIGTERM, interrupted)
        try:
            while process.poll() is None:
                if time.monotonic() - started > (1000 if args.mode == "soak" else 550):
                    raise RuntimeError("Bounded desktop benchmark timed out")
                try:
                    phase = json.loads((output / "phase.json").read_text())["phase"] if (output / "phase.json").exists() else "startup"
                except ValueError:
                    phase = last_phase or "startup"
                if phase != last_phase:
                    print("Phase", phase, flush=True)
                    last_phase = phase
                memory = Path(f"/proc/{process.pid}/smaps_rollup")
                pss = next((int(line.split()[1]) for line in memory.read_text().splitlines() if line.startswith("Pss:")), 0) if memory.exists() else 0
                gpu = subprocess.check_output(["nvidia-smi", "--query-gpu=name,temperature.gpu,utilization.gpu,memory.used,power.draw,clocks.sm,clocks.mem", "--format=csv,noheader,nounits"], text=True).strip()
                report["health"].append({"elapsed_seconds": time.monotonic()-started, "phase": phase, "pss_kib": pss, "gpu": gpu})
                save()
                time.sleep(5)
            report["exit_code"] = process.returncode
            details = json.loads((output / "details.json").read_text())
            report["errors"].extend(validate(details, fixture))
            if process.returncode != 0: report["errors"].append("Desktop diagnostic exited unsuccessfully")
            required = ["move-%d.png" % i for i in range(4)] + ["entry-0.png", "battle-0.png"]
            if args.mode != "soak": required.append("graphics.png")
            for name in required:
                path = output / name
                if not path.is_file() or not path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"):
                    report["errors"].append("Missing PNG: " + name)
            report["usable"] = not report["errors"]
        except (OSError, ValueError, KeyError, RuntimeError, KeyboardInterrupt) as error:
            report["errors"].append(str(error))
        finally:
            signal.signal(signal.SIGTERM, previous_term)
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            report["running"] = False
            save()
    print(json.dumps({"usable": report["usable"], "errors": report["errors"], "output": str(output)}), flush=True)
    return 0 if report["usable"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
