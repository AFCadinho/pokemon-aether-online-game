#!/usr/bin/env python3
"""Physical, separate-package quality smoke with USB-only asset/metric transport.

No game account, production gateway or telemetry service is used. Missing
immutable art fixtures are fetched as public, hash-pinned content downloads.
"""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import math
import os
from pathlib import Path
import re
import shlex
import signal
import subprocess
import threading
import time
from urllib.parse import urlsplit
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.pokeaether.androidquality." + ROOT.parent.name.replace("-", "_")
ORDERS = {"descending": ["ultra", "high", "medium", "low", "ultra"],
          "ascending": ["ultra", "low", "medium", "high", "ultra"]}
COUNTS = ("frame_ms", "main_gpu_ms", "response_gpu_ms")
MOVES = ["Flamethrower", "Thunderbolt", "Rock Slide", "Draco Meteor"]


def save_progress(output, report, details, uploads):
    # Preserve bounded local evidence even if the terminal/host is interrupted.
    for name, value in (("report.json", report), ("details.json", details),
                        ("telemetry.json", {"reports": uploads})):
        partial = output / (name + ".partial")
        partial.write_text(json.dumps(value, indent=2) + "\n")
        partial.replace(output / name)


def interrupt_run(signum, _frame):
    raise RuntimeError("Host runner interrupted by signal " + str(signum))


def expected_presets(fixture):
    if fixture.get("mode") == "gameplay":
        return ["medium"] * 3
    if fixture.get("mode") == "warm-compare":
        return ["high", "medium", "medium", "high"]
    if fixture.get("mode", "smoke") == "soak":
        return [fixture["preset"]] * 40
    return ORDERS[fixture["order"]]


def require_debug_manifest(raw):
    package = re.search(r'^    A: package="([^"]+)"', raw, re.M)
    application = re.search(r'^    E: application[^\n]*\n((?:      A:[^\n]*\n)+)', raw, re.M)
    debug = application and re.search(r'android:debuggable\(0x0101000f\)=\(type 0x12\)0xffffffff', application[1])
    if not package or package[1] != PACKAGE or not debug:
        raise ValueError("Require this slot's exact separate debuggable quality package")


def validate(details, fixture):
    errors = []
    if not isinstance(details, dict) or details.get("run_id") != fixture["run_id"]:
        return ["Missing, stale or foreign report"]
    if not details.get("complete") or details.get("failures") or details.get("engine_errors"):
        errors.append("Incomplete workload or engine/check errors")
    phases = details.get("phases", [])
    if [p.get("preset") for p in phases] != expected_presets(fixture):
        errors.append("Unexpected profile sequence")
    if fixture.get("mode") == "gameplay":
        ids = [p.get("stage_instance") for p in phases]
        if len(set(ids)) != 3 or not all(isinstance(v, int) and v > 0 for v in ids):
            errors.append("Gameplay must reconstruct three distinct arenas")
        for index, phase in enumerate(phases):
            game = phase.get("gameplay", {})
            moves = game.get("moves", [])
            if not game.get("complete") or game.get("cycle") != index or [m.get("move") for m in moves] != MOVES:
                errors.append("Incomplete real-time move sequence")
            for move in moves:
                if (not move.get("hit_seen") or not move.get("cleaned") or move.get("effect_frames", 0) <= 0
                        or not 0 < move.get("seconds", 0) < 30):
                    errors.append("Move did not hit, finish or clean up")
                for key in COUNTS:
                    stats = move.get("timings", {}).get(key, {})
                    if stats.get("count", 0) < 2 or not all(isinstance(stats.get(k), (int, float)) and math.isfinite(stats[k]) for k in ("p50", "p95", "max")):
                        errors.append("Missing finite real-time move samples")
            tabs = game.get("tabs", [])
            if [tab.get("tab") for tab in tabs] != list(range(8)) or not all(tab.get("visible") for tab in tabs):
                errors.append("Incomplete native menu navigation")
    if fixture.get("mode") == "warm-compare":
        heat = details.get("preheat", [])
        end = heat[-1] if heat else {}
        if (not details.get("preheat_ready") or not 30 <= end.get("elapsed_seconds", 0) < 606
                or end.get("native", {}).get("thermalStatus") not in (2, 3)
                or not 0 < end.get("fps", 0) <= 55):
            errors.append("Missing bounded warm High precondition")
        if len(phases) == 4:
            ids = [row.get("stage_instance") for row in phases]
            if (not all(isinstance(v, int) and v > 0 for v in ids)
                    or ids[0] != details.get("preheat_stage")
                    or ids[0] == ids[1] or ids[1] != ids[2] or ids[2] == ids[3]
                    or phases[0].get("preparation_ms") != 0 or phases[2].get("preparation_ms") != 0):
                errors.append("Warm comparison must reuse High preheat and the middle Medium stage")
            if phases[0].get("native_start", {}).get("thermalStatus") not in (2, 3):
                errors.append("First High observation did not start warm")
            if any(row.get("native_start", {}).get("thermalStatus") not in (0, 1, 2, 3)
                   or row.get("native", {}).get("thermalStatus") not in (0, 1, 2, 3) for row in phases):
                errors.append("Missing or critical comparison thermal samples")
            if not 120 <= sum(row.get("seconds", 0) for row in phases) < 124:
                errors.append("Incomplete two-minute warm comparison")
    if fixture.get("mode", "smoke") == "soak":
        instances = {row.get("stage_instance") for row in phases}
        elapsed = phases[-1].get("elapsed_seconds", 0) if phases else 0
        if len(instances) != 1 or not all(isinstance(v, int) and v > 0 for v in instances):
            errors.append("Soak must retain the same prepared stage throughout")
        if not 1200 <= sum(row.get("seconds", 0) for row in phases) < 1240 or not 1200 <= elapsed < 1500:
            errors.append("Incomplete twenty-minute soak")
        if any(row.get("preparation_ms", 0) != 0 for row in phases[1:]):
            errors.append("Soak unexpectedly re-prepared its workload")
    size = details.get("native_size", [])
    if len(size) != 2 or min(size, default=0) <= 0:
        return errors + ["Invalid native raster"]
    for index, row in enumerate(phases):
        preset = row.get("preset")
        if preset not in ORDERS["descending"] or row.get("index") != index:
            errors.append("Invalid profile/artifact identity")
            continue
        edge = {"low": 540, "medium": 720, "high": 1080, "ultra": min(size)}[preset]
        factor = min(1, edge / min(size))
        expected = [math.floor(value * factor + .5) for value in size]
        if row.get("render_size") != expected or row.get("response_size") != expected:
            errors.append("Both passes must use the selected aspect-preserving raster")
        if row.get("msaa") != {"low": 0, "medium": 1, "high": 1, "ultra": 2}[preset]:
            errors.append("MSAA does not match the profile")
        if not fixture["phase_seconds"] <= row.get("seconds", 0) < fixture["phase_seconds"] + 60:
            errors.append("Incomplete or stalled sample")
        for key in COUNTS:
            stats = row.get("timings", {}).get(key, {})
            if stats.get("count", 0) < 2 or not all(isinstance(stats.get(k), (int, float)) and math.isfinite(stats[k]) for k in ("p50", "p95", "max")):
                errors.append("Missing finite timing samples")
        native = row.get("native", {})
        if not isinstance(native.get("androidApi"), (int, float)) or native.get("processPssBytes", 0) <= 0:
            errors.append("Native Android memory bridge unavailable")
    lifecycle = details.get("lifecycle", {})
    if not lifecycle.get("pauses") or not lifecycle.get("resumes") or not lifecycle.get("opt_out_cleared"):
        errors.append("Physical pause/resume or opt-out not verified")
    return sorted(set(errors))


def fixture_pins():
    data = ROOT / "data"
    release = json.loads((data / "approved_3d_release_v16.json").read_text())
    index = release["index"]
    pins = [(index["object_key"], index["size_bytes"], index["sha256"], data / "approved_3d_bundles_v16_index.json")]
    catalog = json.loads((data / "model_pair_release_v16_catalog.json").read_text())
    # The real presenter also prepares these actors' reviewed transformation art.
    actor_ids = {"pokemon_3d:charizard:base", "pokemon_3d:charizard:mega-x",
                 "pokemon_3d:charizard:mega-y", "pokemon_3d:dragonite:base",
                 "pokemon_3d:dragonite:mega"}
    for actor_id in sorted(actor_ids):
        asset = next(row for row in catalog["assets"] if row["asset_id"] == actor_id)
        if set(asset.get("dependencies", [])) - actor_ids:
            raise ValueError("Explicitly extend the fixture allowlist for newly required dependencies")
        pins.append((asset["object_key"], asset["size_bytes"], asset["sha256"], None))
    arena = json.loads((data / "android_3d_experiment.json").read_text())["arena"]
    pins.append((arena["object_key"], arena["archive_bytes"], arena["archive_sha256"], None))
    return pins


def prepare_assets(directory):
    directory.mkdir(parents=True, exist_ok=True)
    files, records = {}, []
    for key, size, digest, source in fixture_pins():
        if not key.startswith("optional-assets/") or ".." in key or not re.fullmatch(r"[a-zA-Z0-9/_\.\-]+", key):
            raise ValueError("Invalid compiled fixture key")
        destination = source or directory / Path(key).name
        valid = destination.is_file() and destination.stat().st_size == size
        if valid:
            with destination.open("rb") as stream:
                valid = hashlib.file_digest(stream, "sha256").hexdigest() == digest
        if not valid:
            if source is not None:
                raise ValueError("Checked-in index does not match its compiled pin")
            partial = destination.with_suffix(destination.suffix + ".partial")
            print("Fetch pinned public fixture", Path(key).name, flush=True)
            # Use the same public endpoint through curl's standard TLS client;
            # the CDN rejects Python-urllib's TLS/user-agent profile on some hosts.
            subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error",
                            "--max-time", "180", "--max-filesize", str(size), "--output", str(partial),
                            "https://updates.pokeaether.com/" + key], check=True)
            total = partial.stat().st_size
            with partial.open("rb") as stream:
                if total != size or hashlib.file_digest(stream, "sha256").hexdigest() != digest:
                    raise ValueError("Fixture failed exact size/hash verification")
            partial.rename(destination)
        files["/" + key] = destination
        records.append({"key": key, "bytes": size, "sha256": digest})
    return files, records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--phase-seconds", type=int, choices=[10, 15, 20], default=15)
    parser.add_argument("--order", choices=ORDERS, default="descending")
    parser.add_argument("--mode", choices=["smoke", "soak", "warm-compare", "gameplay"], default="smoke")
    parser.add_argument("--soak-preset", choices=["low", "medium", "high", "ultra"], default="ultra")
    args = parser.parse_args()
    if ROOT.parent.name not in {"slot-a", "slot-b", "slot-c"} or os.getenv("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Use the assigned slot-env")
    if not re.fullmatch(r"[a-zA-Z0-9]+", args.serial) or args.serial.startswith("emulator-"):
        parser.error("Explicit physical device required")
    apk, output = args.apk.resolve(), args.output.resolve()
    apk.relative_to(ROOT / ".tmp")
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    aapt = Path.home() / "Android/Sdk/build-tools/35.0.1/aapt"
    raw_manifest = subprocess.check_output([str(aapt), "dump", "xmltree", str(apk), "AndroidManifest.xml"], text=True)
    require_debug_manifest(raw_manifest)
    with zipfile.ZipFile(apk) as archive:
        arch = {name.split("/")[1] for name in archive.namelist() if name.startswith("lib/") and name.endswith(".so")}
        dex = [archive.read(name) for name in archive.namelist() if re.fullmatch(r"classes(?:\d+)?\.dex", name)]
        if arch != {"arm64-v8a"} or not any(b"getPerformanceSnapshot" in blob and b"Lcom/pokeaether/game/ApkInstallBridge;" in blob for blob in dex):
            raise ValueError("Require ARM64 with the real native performance bridge")
    adb = str(Path.home() / "Android/Sdk/platform-tools/adb")
    def device(*command, data=None, check=True, timeout=30):
        return subprocess.run([adb, "-s", args.serial, *command], input=data, check=check,
                              capture_output=True, timeout=timeout).stdout
    def shell(command, check=True):
        return device("shell", command, check=check).decode().strip()
    def owned_json(name):
        raw = device("exec-out", "run-as", PACKAGE, "cat", "files/" + name, check=False)
        try:
            return json.loads(raw)
        except (ValueError, UnicodeError):
            return None
    if shell("getprop ro.kernel.qemu") == "1":
        raise ValueError("An emulator cannot be a physical result")
    files, pins = prepare_assets(output.parent / "fixtures")
    uploads = []
    transport_errors = []
    requests = []
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *unused):
            pass
        def do_GET(self):
            path = urlsplit(self.path).path
            file = files.get(path)
            requests.append({"method": "GET", "path": path, "allowed": file is not None})
            if file is None or urlsplit(self.path).query:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Length", str(file.stat().st_size))
            self.end_headers()
            with file.open("rb") as stream:
                while chunk := stream.read(1024 * 1024):
                    self.wfile.write(chunk)
        def do_POST(self):
            size = int(self.headers.get("Content-Length", "0"))
            if self.path != "/account/game/client-performance" or size <= 0 or size > 16384:
                self.send_error(413)
                return
            try:
                payload = json.loads(self.rfile.read(size))
                reports = payload["reports"]
                if not isinstance(reports, list) or not 1 <= len(reports) <= 8 or any(r.get("platform") != "android" or r.get("schemaVersion") != 1 for r in reports):
                    raise ValueError("Invalid local transport summary")
                uploads.extend(reports)
            except (ValueError, TypeError, KeyError):
                transport_errors.append("Invalid metric POST")
                self.send_error(422)
                return
            body = json.dumps({"success": True, "accepted": len(reports)}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    if f"tcp:{port}" in device("reverse", "--list").decode().split():
        server.server_close()
        raise ValueError("Chosen USB reverse port is already owned")
    fixture = {"schema": 1, "run_id": uuid.uuid4().hex, "phase_seconds": args.phase_seconds, "order": args.order, "port": port}
    if args.mode == "soak":
        fixture.update(mode="soak", preset=args.soak_preset, phase_seconds=30)
    elif args.mode == "warm-compare":
        fixture.update(mode="warm-compare", phase_seconds=30)
    elif args.mode == "gameplay":
        fixture.update(mode="gameplay", phase_seconds=30)
    report = {"schema": 1, "package": PACKAGE, "fixture": fixture, "pins": pins, "health": [], "errors": [],
              "usable": False, "running": True, "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "source_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT)),
              "apk_sha256": hashlib.sha256(apk.read_bytes()).hexdigest(), "transport_only_no_account_authentication": True,
              "device": {key: shell("getprop " + key) for key in ["ro.product.model", "ro.build.version.sdk", "ro.board.platform"]}}
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    pid, details, lifecycle_done = None, None, False
    started = time.monotonic()
    reverse_created = False
    old_term = signal.signal(signal.SIGTERM, interrupt_run)
    try:
        save_progress(output, report, details, uploads)
        print(device("install", "--no-incremental", "--user", "0", "-r", str(apk), timeout=120).decode(), flush=True)
        shell("am force-stop " + PACKAGE)
        shell("run-as " + PACKAGE + " mkdir -p files")
        shell("run-as " + PACKAGE + " rm -f files/android-quality-results.json files/android-quality-details.json files/android-quality-phase.json")
        device("shell", "run-as " + PACKAGE + " sh -c " + shlex.quote("cat > files/android-quality-fixture.json"), data=json.dumps(fixture).encode())
        device("reverse", f"tcp:{port}", f"tcp:{port}")
        reverse_created = True
        shell("am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p " + PACKAGE)
        last_phase = ""
        timeout_seconds = {"soak": 1800, "warm-compare": 1200, "smoke": 900, "gameplay": 600}[args.mode]
        while time.monotonic() - started < timeout_seconds:
            marker = owned_json("android-quality-phase.json") or {}
            phase = marker.get("phase", "startup") if marker.get("run_id") == fixture["run_id"] else "startup"
            if phase != last_phase:
                print("Phase", phase, flush=True)
                last_phase = phase
            details = owned_json("android-quality-details.json")
            result = owned_json("android-quality-results.json")
            if result is not None:
                if result != {"android_quality_phone_check.gd": 0}:
                    report["errors"].append("Diagnostic runner failed")
                break
            if phase == "startup" and time.monotonic() - started > 90:
                raise RuntimeError("Diagnostic did not produce a startup marker")
            current_pid = shell("pidof " + PACKAGE)
            if pid is None and current_pid.isdigit():
                pid = current_pid
                report["pid"] = pid
            if pid and current_pid != pid:
                raise RuntimeError("Diagnostic process exited or restarted")
            if phase == "lifecycle-ready" and not lifecycle_done:
                shell("input keyevent KEYCODE_HOME")
                time.sleep(2)
                shell("am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p " + PACKAGE)
                lifecycle_done = True
                continue
            def number(raw, pattern, scale=1):
                match = re.search(pattern, raw, re.M)
                return int(match[1]) / scale if match else None
            memory = shell("dumpsys meminfo " + PACKAGE)
            battery = shell("dumpsys battery")
            thermal = shell("dumpsys thermalservice")
            activities = shell("dumpsys activity activities")
            sample = {"elapsed_seconds": time.monotonic() - started, "phase": phase,
                      "pss_kib": number(memory, r"TOTAL PSS:\s*(\d+)"),
                      "battery_c": number(battery, r"^\s*temperature:\s*(\d+)", 10),
                      "battery_percent": number(battery, r"^\s*level:\s*(\d+)"),
                      "charging_status": number(battery, r"^\s*status:\s*(\d+)"),
                      "ac_powered": bool(re.search(r"^\s*AC powered: true$", battery, re.M)),
                      "usb_powered": bool(re.search(r"^\s*USB powered: true$", battery, re.M)),
                      "thermal_status": number(thermal, r"Thermal Status:\s*(\d+)"),
                      "foreground": any(PACKAGE + "/" in line for line in activities.splitlines() if "mResumedActivity:" in line or "topResumedActivity=" in line)}
            report["health"].append(sample)
            report["fixture_requests"] = list(requests)
            save_progress(output, report, details, list(uploads))
            if not sample["foreground"] and time.monotonic() - started > 15:
                raise RuntimeError("Keep the unlocked diagnostic in the foreground")
            if sample["thermal_status"] is not None and sample["thermal_status"] >= 4:
                raise RuntimeError("Critical thermal status")
            time.sleep(10 if args.mode in ("soak", "warm-compare") else 2)
        else:
            raise RuntimeError("Bounded quality diagnostic timed out")
        report["errors"] += validate(details, fixture) + transport_errors
        if len(uploads) != len(expected_presets(fixture)):
            report["errors"].append("Missing Android telemetry uploads")
        if report["errors"] and pid:
            (output / "diagnostic.log").write_bytes(device("logcat", "--pid", pid, "-d", "-v", "brief", check=False))
        if not report["errors"]:
            for index, preset in enumerate(expected_presets(fixture)):
                if args.mode == "soak" and index not in (0, 39):
                    continue
                name = f"android-quality-{index}-{preset}.png"
                raw = device("exec-out", "run-as", PACKAGE, "cat", "files/" + name)
                if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
                    raise RuntimeError("Own arena image missing")
                (output / name).write_bytes(raw)
            for name in ["android-quality-graphics.png", "android-quality-support.png"]:
                raw = device("exec-out", "run-as", PACKAGE, "cat", "files/" + name)
                if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
                    raise RuntimeError("Native settings image missing")
                (output / name).write_bytes(raw)
            if args.mode == "gameplay":
                for index in range(len(MOVES)):
                    name = f"android-quality-move-{index}.png"
                    raw = device("exec-out", "run-as", PACKAGE, "cat", "files/" + name)
                    if not raw.startswith(b"\x89PNG\r\n\x1a\n"):
                        raise RuntimeError("Move impact evidence missing")
                    (output / name).write_bytes(raw)
            report["usable"] = True
    except Exception as error:
        report["errors"].append(str(error))
        if pid:
            (output / "diagnostic.log").write_bytes(device("logcat", "--pid", pid, "-d", "-v", "brief", check=False))
    finally:
        signal.signal(signal.SIGTERM, old_term)
        report["running"] = False
        try:
            shell("am force-stop " + PACKAGE, check=False)
            if reverse_created:
                device("reverse", "--remove", f"tcp:{port}", check=False)
        except (OSError, subprocess.SubprocessError) as error:
            report["errors"].append("USB cleanup unavailable: " + type(error).__name__)
            report["usable"] = False
        server.shutdown()
        server.server_close()
        report["fixture_requests"] = requests
        save_progress(output, report, details, uploads)
    print(json.dumps({"usable": report["usable"], "errors": report["errors"], "output": str(output)}), flush=True)
    return 0 if report["usable"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
