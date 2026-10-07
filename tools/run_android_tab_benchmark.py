#!/usr/bin/env python3
"""Collect the separate ARM64 debug workload on the explicitly selected Tab A7."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import threading
import time
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.pokeaether.androidtabbenchmark"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--arena", type=Path, required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sdk", type=Path, default=Path.home() / "Android/Sdk")
    parser.add_argument("--phase-seconds", type=float, default=20)
    parser.add_argument("--timeout", type=int, default=2400)
    parser.add_argument("--smoke", action="store_true", help="Short, explicitly labeled compatibility run; not sustained qualification")
    parser.add_argument("--disable-msaa", action="store_true", help="Smoke-only GPU crash isolation; not the original 4x quality workload")
    parser.add_argument("--disable-grass", action="store_true", help="Smoke-only arena isolation; not a complete arena qualification")
    parser.add_argument("--models-only", action="store_true", help="Qualify all pinned models without the failing arena; no render benchmark")
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through assigned slot-env")
    if args.serial.startswith("emulator-") or not re.fullmatch(r"[A-Za-z0-9]+", args.serial):
        parser.error("Explicit physical USB device serial required")
    if not 10 <= args.phase_seconds <= 30 or not 120 <= args.timeout <= 3600:
        parser.error("Require bounded phase duration/deadline")
    if not args.smoke and args.phase_seconds < 20:
        parser.error("Sustained qualification requires at least 20 seconds per phase")
    if (args.disable_msaa or args.disable_grass) and not args.smoke:
        parser.error("An isolation experiment cannot qualify the sustained original workload")
    if args.models_only and (args.smoke or args.disable_msaa or args.disable_grass):
        parser.error("Models-only requires the whole cohort and no isolation settings")
    assets, arena, apk, output = [path.resolve() for path in (args.assets, args.arena, args.apk, args.output)]
    for path in (assets, arena, apk, output):
        path.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    fixture = json.loads((assets / "fixture.json").read_bytes())
    qualification = json.loads((ROOT / "tools/sprite_factory/model_pair_cohort_results.json").read_bytes())
    qualified = {row["species"]: row for row in qualification["pairs"]}
    if args.smoke:
        fixture["pairs"] = [row for row in fixture["pairs"] if row["species"] in {"garchomp", "charizard", "dragonite-mega"}]
    assert fixture["prototype_only"] and fixture["pairs"]
    files = {}
    for pair in fixture["pairs"]:
        for kind in ("baseline", "shared"):
            pin = pair[kind]
            proof = qualified[pair["species"]]["packs"][kind]
            path = assets / pin["pack"]
            assert path.stat().st_size == pin["pack_bytes"] == proof["bytes"]
            assert sha(path) == pin["pack_sha256"] == proof["sha256"]
            files["/" + pin["pack"]] = path
    arena_report = json.loads((arena.parent.parent / "report.json").read_text())
    arena_pin = arena_report["candidates"]["android-etc2-art"]
    assert arena.stat().st_size == arena_pin["bytes"] and sha(arena) == arena_pin["sha256"]
    fixture.update(run_id=uuid.uuid4().hex, phase_seconds=args.phase_seconds,
                   arena={"bytes": arena_pin["bytes"], "sha256": arena_pin["sha256"]}, smoke=args.smoke,
                   disable_msaa=args.disable_msaa, disable_grass=args.disable_grass, models_only=args.models_only)
    files["/forest.pck"] = arena
    fixture_bytes = json.dumps(fixture).encode()
    aapt = sorted((args.sdk / "build-tools").glob("*/aapt2"))[-1]
    metadata = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True)
    if "package: name='" + PACKAGE + "'" not in metadata or "application-debuggable" not in metadata:
        raise ValueError("Only the dedicated tablet debug app is allowed")
    with zipfile.ZipFile(apk) as archive:
        libraries = [name for name in archive.namelist() if name.startswith("lib/")]
        if not libraries or any(not name.startswith("lib/arm64-v8a/") for name in libraries):
            raise ValueError("Require only ARM64 libraries")
    adb = str(args.sdk / "platform-tools/adb")

    def device(*command, check=True, binary=False):
        return subprocess.run([adb, "-s", args.serial, *command], timeout=45, check=check,
                              capture_output=True, text=not binary)

    def prop(key):
        return device("shell", "getprop", key).stdout.strip()

    if prop("ro.product.model") not in {"SM-T500", "SM-T505"} or "arm64-v8a" not in prop("ro.product.cpu.abilist").split(","):
        raise ValueError("Refusing a different device or ABI")
    hardware = {key: prop(key) for key in ("ro.product.model", "ro.build.version.release", "ro.build.version.sdk", "ro.product.cpu.abilist", "ro.board.platform")}
    hardware["memory"] = [line for line in device("shell", "cat", "/proc/meminfo").stdout.splitlines() if line.startswith(("MemTotal:", "MemAvailable:"))]
    hardware["screen_size"] = device("shell", "wm", "size").stdout.strip()
    (output / "device.json").write_text(json.dumps(hardware, indent=2) + "\n")
    (output / "fixture.json").write_bytes(fixture_bytes)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            path = files.get(self.path)
            if self.path == "/fixture.json":
                data = fixture_bytes
            elif path:
                data = path.read_bytes()
            else:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    server = ThreadingHTTPServer(("127.0.0.1", 8799), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()

    def interrupted(_signal, _frame):
        raise KeyboardInterrupt("Tablet diagnostic interrupted; cleaning only its own process/reverse")

    signal.signal(signal.SIGTERM, interrupted)
    memory = []
    seen_pids = set()
    logs = {}
    try:
        device("reverse", "tcp:8799", "tcp:8799")
        device("install", "--no-incremental", "-r", str(apk))
        device("shell", "am", "force-stop", PACKAGE)
        device("shell", "am", "start", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher")
        deadline = time.monotonic() + args.timeout
        missing = 0
        last_phase = ""
        last_notice = time.monotonic()
        while time.monotonic() < deadline:
            pids = device("shell", "pidof", PACKAGE, check=False).stdout.split()
            if pids:
                seen_pids.update(pids)
                missing = 0
                # Samsung Java/engine tags differ in capitalization. Scope all
                # tags to this app's PID instead of missing startup failures.
                for pid in seen_pids:
                    collected = device("logcat", "--pid=" + pid, "-d", "-v", "brief", check=False)
                    if collected.returncode == 0 and collected.stdout:
                        logs[pid] = collected.stdout
                log = "\n".join(logs.values())
                (output / "native.log").write_text(log)
                if "SCRIPT ERROR:" in log or "): ERROR:" in log or "FATAL EXCEPTION:" in log:
                    raise RuntimeError("Native script/engine error; inspect native.log")
            else:
                missing += 1
                if missing >= 3:
                    raise RuntimeError("Tablet test process stopped without completing")
            status = device("shell", "dumpsys", "meminfo", PACKAGE, check=False).stdout
            pss = re.search(r"TOTAL PSS:\s*(\d+)", status)
            rss = re.search(r"TOTAL RSS:\s*(\d+)", status)
            battery = device("shell", "dumpsys", "battery", check=False).stdout
            temperature = re.search(r"^\s*temperature:\s*(\d+)", battery, re.M)
            charging = re.search(r"^\s*status:\s*(\d+)", battery, re.M)
            thermal = device("shell", "dumpsys", "thermalservice", check=False).stdout
            thermal_status = re.search(r"Thermal Status:\s*(\d+)", thermal)
            raw_phase = device("shell", "run-as", PACKAGE, "cat", "files/android-tab-benchmark-phase.json", check=False)
            phase_data = json.loads(raw_phase.stdout) if raw_phase.returncode == 0 else {}
            phase = phase_data.get("label", "") if phase_data.get("run_id") == fixture["run_id"] else "model-qualification"
            power = device("shell", "dumpsys", "power", check=False).stdout
            awake = "mWakefulness=Awake" in power
            activities = device("shell", "dumpsys", "activity", "activities", check=False).stdout
            foreground = any(PACKAGE + "/" in line for line in activities.splitlines()
                             if "mResumedActivity:" in line or "topResumedActivity=" in line)
            memory.append({"time": time.time(), "phase": phase, "pss_kib": int(pss[1]) if pss else 0,
                           "rss_kib": int(rss[1]) if rss else 0, "battery_c": int(temperature[1]) / 10 if temperature else None,
                           "battery_status": int(charging[1]) if charging else None,
                           "thermal_status": int(thermal_status[1]) if thermal_status else None, "screen_awake": awake,
                           "app_processes": len(pids), "app_foreground": foreground})
            (output / "memory.json").write_text(json.dumps(memory, indent=2) + "\n")
            if thermal_status and int(thermal_status[1]) >= 4:
                raise RuntimeError("Android reports critical thermal status; stopping the workload")
            if phase != "model-qualification" and not awake:
                raise RuntimeError("Screen slept during rendering; this run cannot qualify sustained performance")
            if phase != "model-qualification" and len(pids) != 1:
                raise RuntimeError("Require one dedicated app process during the render measurement")
            if phase != "model-qualification" and not foreground:
                raise RuntimeError("The dedicated app left the foreground during rendering")
            if phase != last_phase or time.monotonic() - last_notice >= 30:
                print("TABLET_PHASE", phase, "pss_kib", memory[-1]["pss_kib"], "battery_c", memory[-1]["battery_c"], flush=True)
                last_phase, last_notice = phase, time.monotonic()
            for name in ("android-model-pairs-details.json", "android-tab-benchmark-details.json"):
                raw = device("shell", "run-as", PACKAGE, "cat", "files/" + name, check=False)
                if raw.returncode == 0:
                    value = json.loads(raw.stdout)
                    if value.get("run_id") == fixture["run_id"]:
                        (output / name).write_text(raw.stdout)
                        if value.get("failures") or value.get("engine_errors"):
                            raise RuntimeError("Tablet check failed; inspect details")
            done = device("shell", "run-as", PACKAGE, "cat", "files/android-tab-benchmark-results.json", check=False)
            details_path = output / "android-tab-benchmark-details.json"
            if done.returncode == 0 and details_path.exists():
                details = json.loads(details_path.read_text())
                codes = json.loads(done.stdout)
                if details.get("run_id") == fixture["run_id"] and details.get("success") is True:
                    assert details["success"] and details["renderer"] == "mobile"
                    assert details["shader_cache"] and details["frame_pacing"]
                    assert details["msaa"] == ("disabled-diagnostic" if args.disable_msaa else "4x")
                    assert details["grass"] == (not args.disable_grass) and details["models_only"] == args.models_only
                    assert set(codes) == {"model_pair_bundle_check.gd", "android_tab_benchmark_check.gd"} and all(v == 0 for v in codes.values())
                    assert len(details["phases"]) == (0 if args.models_only else len(fixture["pairs"]) * 4 + 1)
                    expected_labels = set() if args.models_only else {
                        f"{index}-{pair['species']}-{kind}-{variant}"
                        for index, pair in enumerate(fixture["pairs"])
                        for kind in ("baseline", "shared") for variant in ("normal", "shiny")
                    } | {"mega-prepared-shared"}
                    assert {row["label"] for row in details["phases"]} == expected_labels
                    assert details["render_size"] == [960, 540]
                    assert all(row["frames"] > 0 and row["seconds"] >= args.phase_seconds
                               for row in details["phases"])
                    pairs = json.loads((output / "android-model-pairs-details.json").read_text())
                    expected_cases = {(row["species"], kind) for row in fixture["pairs"] for kind in ("baseline", "shared")}
                    assert pairs["success"] and len(pairs["cases"]) == len(expected_cases)
                    assert {(row["species"], row["variant"]) for row in pairs["cases"]} == expected_cases
                    assert all(row["remaining_texture_refs"] == 0 for row in pairs["cases"])
                    assert args.models_only or args.smoke or details["observed_seconds"] >= 1200
                    (output / "results.json").write_text(done.stdout)
                    names = device("shell", "run-as", PACKAGE, "ls", "files").stdout.splitlines()
                    current_captures = {"tab-" + row["label"] + ".png" for index, row in enumerate(details["phases"])
                                        if index < 4 or any(token in row["label"] for token in ("mega", "palkia", "dondozo"))}
                    for name in names:
                        if name in current_captures and re.fullmatch(r"tab-[a-zA-Z0-9-]+\.png", name):
                            data = device("exec-out", "run-as", PACKAGE, "cat", "files/" + name, binary=True).stdout
                            assert data.startswith(b"\x89PNG")
                            (output / name).write_bytes(data)
                    summary = {"success": True, "smoke": args.smoke, "msaa": details["msaa"], "grass": details["grass"], "models_only": args.models_only,
                               "model": hardware["ro.product.model"], "android": hardware["ro.build.version.release"],
                               "adapter": details["adapter"], "phases": len(details["phases"]), "observed_seconds": details.get("observed_seconds", 0),
                               "peak_pss_kib": max(m["pss_kib"] for m in memory), "maximum_battery_c": max(m["battery_c"] or 0 for m in memory),
                               "maximum_thermal_status": max(m["thermal_status"] or 0 for m in memory),
                               "apk_sha256": sha(apk), "fresh_run_id": fixture["run_id"]}
                    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
                    print("ANDROID_TAB_BENCHMARK_OK", json.dumps(summary), flush=True)
                    break
            time.sleep(3)
        else:
            raise TimeoutError("Tablet workload exceeded its deadline")
    finally:
        # Preserve partial, fresh evidence before stopping a failed/crashed run.
        for name in ("android-model-pairs-details.json", "android-tab-benchmark-details.json"):
            try:
                raw = device("shell", "run-as", PACKAGE, "cat", "files/" + name, check=False)
                if raw.returncode == 0 and json.loads(raw.stdout).get("run_id") == fixture["run_id"]:
                    (output / name).write_text(raw.stdout)
            except (subprocess.TimeoutExpired, json.JSONDecodeError):
                pass
        if seen_pids:
            try:
                for pid in seen_pids:
                    collected = device("logcat", "--pid=" + pid, "-d", "-v", "brief", check=False)
                    if collected.returncode == 0 and collected.stdout:
                        logs[pid] = collected.stdout
                (output / "native.log").write_text("\n".join(logs.values()))
            except subprocess.TimeoutExpired:
                pass
        try:
            for command in (("shell", "am", "force-stop", PACKAGE), ("reverse", "--remove", "tcp:8799")):
                try:
                    device(*command, check=False)
                except subprocess.TimeoutExpired:
                    pass
        finally:
            server.shutdown()
            server.server_close()


if __name__ == "__main__":
    main()
