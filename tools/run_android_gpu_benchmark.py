#!/usr/bin/env python3
"""Run the separate GPU diagnostic on an explicitly selected physical phone.

Engine frame intervals are collected on-device; they are not presentation FPS.
Only the diagnostic package's public fixture/results are accessed.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.pokeaether.androidgpuqa"
MATRIX = ["baseline", "no_grass", "baseline", "no_shadows", "baseline", "msaa_2", "baseline", "msaa_off", "baseline"]


def validate(details, fixture):
    errors = []
    if details.get("run_id") != fixture["run_id"]:
        errors.append("Stale or foreign report")
    if not details.get("complete") or details.get("failures") or details.get("engine_errors"):
        errors.append("Incomplete workload or engine/check errors")
    expected = []
    for index in range(fixture["rounds"]):
        expected.extend(reversed(MATRIX) if index % 2 else MATRIX)
    expected += ["moves_first", "moves_repeat"]
    phases = details.get("phases", [])
    if [row.get("variant") for row in phases] != expected:
        errors.append("Unexpected phase sequence")
    labels = [row.get("label") for row in phases]
    if len(set(labels)) != len(labels):
        errors.append("Duplicate phase labels")
    for row in phases:
        if not re.fullmatch(r"\d+:\d+:(baseline|no_grass|no_shadows|msaa_2|msaa_off|moves_first|moves_repeat)", str(row.get("label"))):
            errors.append("Invalid artifact label")
        if not fixture["phase_seconds"] <= row.get("seconds", 0) < fixture["phase_seconds"] + 5:
            errors.append("Incomplete or stalled phase")
        for key in ["engine_frame_ms", "main_gpu_ms", "response_gpu_ms"]:
            metric = row.get("timings", {}).get(key, {})
            if metric.get("count", 0) < 50 or not all(isinstance(metric.get(k), (float, int)) and math.isfinite(metric[k]) for k in ["p50", "p95", "p99", "max"]):
                errors.append("Missing finite timing samples")
        if row.get("timings", {}).get("main_gpu_ms", {}).get("p50", 0) <= 0:
            errors.append("GPU timestamps unavailable")
        if not all(isinstance(row.get(key), list) and len(row[key]) == 4 for key in ["pipeline_start", "pipeline_end"]):
            errors.append("Missing pipeline counters")
        elif row.get("variant") in MATRIX and row["pipeline_start"] != row["pipeline_end"]:
            errors.append("Idle timing includes pipeline compilation")
        for view in ["main", "response"]:
            item = row.get("viewports", {}).get(view, {})
            expected_msaa = {"msaa_off": 0, "msaa_2": 1}.get(row.get("variant"), 2)
            if item.get("size") != details.get("render_size") or item.get("msaa") != expected_msaa:
                errors.append("Raster/MSAA controls did not restore")
    return sorted(set(errors))


def comparisons(details):
    rows = details["phases"]
    output = []
    for index, row in enumerate(rows):
        if row["variant"] not in ["no_grass", "no_shadows", "msaa_2", "msaa_off"]:
            continue
        before, after = rows[index - 1], rows[index + 1]
        baseline = (before["timings"]["main_gpu_ms"]["p50"] + after["timings"]["main_gpu_ms"]["p50"]) / 2
        measured = row["timings"]["main_gpu_ms"]["p50"]
        output.append({"label": row["label"], "variant": row["variant"],
                       "main_gpu_ms": measured, "adjacent_baseline_gpu_ms": baseline,
                       "gpu_reduction_percent": 100 * (1 - measured / baseline),
                       "baseline_drift_percent": 100 * (after["timings"]["main_gpu_ms"]["p50"] / before["timings"]["main_gpu_ms"]["p50"] - 1)})
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--phase-seconds", type=int, choices=[10, 15, 20], default=15)
    parser.add_argument("--rounds", type=int, choices=[1, 2], default=2)
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through the assigned slot-env")
    if not re.fullmatch(r"[A-Za-z0-9]+", args.serial) or args.serial.startswith("emulator-"):
        parser.error("Explicit physical device required")
    apk, output = args.apk.resolve(), args.output.resolve()
    apk.relative_to(ROOT / ".tmp")
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    aapt = sorted((Path.home() / "Android/Sdk/build-tools").glob("*/aapt"))[-1]
    badging = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True)
    if not re.search(r"^package: name='" + re.escape(PACKAGE) + "'", badging, re.M) or "application-debuggable" not in badging:
        raise ValueError("Require the exact separate debuggable diagnostic package")
    with zipfile.ZipFile(apk) as archive:
        architectures = {name.split("/")[1] for name in archive.namelist() if name.startswith("lib/")}
    if architectures != {"arm64-v8a"}:
        raise ValueError("Require ARM64-only diagnostic")

    def device(*command, check=True, data=None, timeout=20):
        return subprocess.run(["adb", "-s", args.serial, *command], input=data,
                              timeout=timeout, capture_output=True, check=check).stdout

    def shell(command, check=True):
        return device("shell", command, check=check).decode().strip()

    def private_file(name):
        raw = device("shell", "run-as " + PACKAGE + " cat files/" + shlex.quote(name), check=False)
        try:
            return json.loads(raw)
        except (ValueError, UnicodeError):
            return None

    if shell("getprop ro.kernel.qemu") == "1":
        raise ValueError("Emulator is not a physical performance result")
    fixture = {"schema": 1, "run_id": uuid.uuid4().hex, "phase_seconds": args.phase_seconds, "rounds": args.rounds}
    report = {"schema": 1, "package": PACKAGE, "fixture": fixture, "health": [], "errors": [], "usable": False,
              "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)),
              "apk_sha256": hashlib.sha256(apk.read_bytes()).hexdigest(),
              "device": {key: shell("getprop " + key) for key in ["ro.product.model", "ro.build.version.sdk", "ro.board.platform"]}}
    print(device("install", "--no-incremental", "-r", str(apk), timeout=120).decode(), flush=True)
    shell("am force-stop " + PACKAGE)
    shell("run-as " + PACKAGE + " rm -f files/android-gpu-details.json files/android-gpu-results.json files/android-gpu-phase.json")
    device("shell", "run-as " + PACKAGE + " sh -c " + shlex.quote("cat > files/android-gpu-fixture.json"), data=json.dumps(fixture).encode())
    shell("am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p " + PACKAGE)
    started = time.monotonic()
    pid = None
    last_phase = None
    deadline = 900 + (len(MATRIX) * args.rounds + 2) * (args.phase_seconds + 4)
    details = None
    try:
        while time.monotonic() - started < deadline:
            marker = private_file("android-gpu-phase.json") or {}
            phase = marker.get("phase") if marker.get("run_id") == fixture["run_id"] else "startup"
            if phase != last_phase:
                print("Phase", phase, flush=True)
                last_phase = phase
            details = private_file("android-gpu-details.json")
            result = private_file("android-gpu-results.json")
            if result is not None:
                if result != {"android_gpu_isolation_check.gd": 0}:
                    report["errors"].append("Diagnostic runner failed")
                break
            current_pid = shell("pidof " + PACKAGE)
            if pid is None and current_pid.isdigit(): pid = current_pid
            if pid is not None and current_pid != pid:
                raise RuntimeError("Diagnostic process exited or restarted")
            def number(raw, pattern, scale=1):
                match = re.search(pattern, raw, re.M)
                return int(match[1]) / scale if match else None
            memory = shell("dumpsys meminfo " + PACKAGE)
            battery = shell("dumpsys battery")
            thermal = shell("dumpsys thermalservice")
            activities = shell("dumpsys activity activities")
            sample = {"elapsed_seconds": time.monotonic() - started, "phase": phase,
                      "pss_kib": number(memory, r"TOTAL PSS:\s*(\d+)"), "rss_kib": number(memory, r"TOTAL RSS:\s*(\d+)"),
                      "battery_c": number(battery, r"^\s*temperature:\s*(\d+)", 10),
                      "thermal_status": number(thermal, r"Thermal Status:\s*(\d+)"),
                      "foreground": any(PACKAGE + "/" in line for line in activities.splitlines() if "mResumedActivity:" in line or "topResumedActivity=" in line)}
            report["health"].append(sample)
            if not sample["foreground"]:
                raise RuntimeError("Diagnostic left foreground")
            if sample["thermal_status"] is None:
                raise RuntimeError("Thermal monitoring unavailable")
            if sample["thermal_status"] >= 4:
                raise RuntimeError("Critical thermal status")
            time.sleep(3)
        else:
            raise RuntimeError("Bounded diagnostic timed out")
        report["errors"] += validate(details or {}, fixture)
        if not report["errors"]:
            report["comparisons"] = comparisons(details)
            for row in details["phases"]:
                name = "android-gpu-" + row["label"].replace(":", "-") + ".png"
                raw = device("exec-out", "run-as", PACKAGE, "cat", "files/" + name)
                if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
                    raise RuntimeError("Diagnostic image missing")
                (output / name).write_bytes(raw)
            report["usable"] = True
    except Exception as error:
        report["errors"].append(str(error))
        if pid:
            (output / "diagnostic.log").write_bytes(device("logcat", "--pid", pid, "-d", "-v", "brief", check=False))
    finally:
        shell("am force-stop " + PACKAGE, check=False)
        (output / "details.json").write_text(json.dumps(details, indent=2) + "\n")
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"usable": report["usable"], "errors": report["errors"], "comparisons": report.get("comparisons", [])}), flush=True)
    return 0 if report["usable"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
