#!/usr/bin/env python3
"""Read presentation intervals and process memory from the installed USB game.

No APK changes, game input, logcat, screenshots or private userdata access.
SurfaceFlinger measures submitted/presented frames, not separate CPU/GPU costs.
"""
import argparse
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.pokeaether.game"
PENDING = 2**63 - 1


def surface_name(lines):
    candidates = []
    for line in lines.splitlines():
        if f"SurfaceView[{PACKAGE}/" not in line or "Background for" in line:
            continue
        name = line.removeprefix("RequestedLayerState{").split(" parentId=")[0]
        candidates.append(name)
    blast = [name for name in candidates if "(BLAST)" in name]
    chosen = blast or candidates
    if len(chosen) != 1:
        raise ValueError("Require one unambiguous game SurfaceView")
    return chosen[0]


def presentations(raw):
    lines = raw.splitlines()
    period = int(lines[0]) if lines and lines[0].isdigit() else 0
    actual = set()
    for line in lines[1:]:
        fields = line.split()
        if len(fields) == 3 and all(field.isdigit() for field in fields):
            # AOSP: desired present, actual present, frame ready (nanoseconds).
            stamp = int(fields[1])
            if 0 < stamp < PENDING:
                actual.add(stamp)
    return period, sorted(actual)


class FrameSeries:
    def __init__(self, seed):
        self.last = seed
        self.intervals_ns = []
        self.coverage_gaps = 0
        self.empty_polls = 0

    def add(self, stamps):
        if not stamps:
            self.empty_polls += 1
            return
        fresh = [stamp for stamp in stamps if stamp > self.last]
        if not fresh:
            return
        if self.last not in stamps:
            # The finite history was overwritten, or the surface was reset.
            # Do not turn unobserved frames into one fabricated slow frame.
            self.coverage_gaps += 1
            self.last = fresh.pop(0)
        for stamp in fresh:
            self.intervals_ns.append(stamp - self.last)
            self.last = stamp

    def summary(self):
        ordered = sorted(value / 1e6 for value in self.intervals_ns)
        if not ordered:
            return {"intervals": 0}
        def percentile(fraction):
            return ordered[max(0, math.ceil(len(ordered) * fraction) - 1)]
        return {"intervals": len(ordered), "observed_seconds": sum(ordered) / 1000,
                "observed_fps": 1000 * len(ordered) / sum(ordered),
                "p50_ms": percentile(.5), "p95_ms": percentile(.95),
                "p99_ms": percentile(.99), "max_ms": ordered[-1],
                "over_16_667_ms": sum(x > 1000 / 60 + .1 for x in ordered),
                "over_33_333_ms": sum(x > 1000 / 30 + .1 for x in ordered),
                "over_100_ms": sum(x > 100 for x in ordered)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--seconds", type=int, default=60)
    parser.add_argument("--label", choices=["idle", "moves", "repeat", "menu"], required=True)
    parser.add_argument("--variant", choices=["baseline", "optimized"], default="baseline")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through the assigned slot-env")
    if args.serial.startswith("emulator-") or not re.fullmatch(r"[A-Za-z0-9]+", args.serial):
        parser.error("Explicit physical device serial required")
    if not 10 <= args.seconds <= 1800:
        parser.error("Duration must be 10–1800 seconds")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)

    def device(*command, check=True):
        return subprocess.run(["adb", "-s", args.serial, *command], timeout=15,
                              capture_output=True, text=True, check=check).stdout

    def shell(command):
        return device("shell", command)

    pid = shell("pidof " + PACKAGE).strip()
    if not pid.isdigit():
        raise ValueError("Require one running game process")
    name = surface_name(shell("dumpsys SurfaceFlinger --list"))
    latency_command = "dumpsys SurfaceFlinger --latency " + shlex.quote(name)
    period, seed = presentations(shell(latency_command))
    if not seed:
        raise ValueError("No actual presentation timestamps for this game surface")
    frames = FrameSeries(seed[-1])
    report = {"schema": 1, "label": args.label, "variant": args.variant,
              "requested_seconds": args.seconds, "pid": int(pid),
              "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "device": {key: shell("getprop " + key).strip() for key in
                         ["ro.product.model", "ro.build.version.sdk", "ro.board.platform"]},
              "installed_version": [line.strip() for line in shell("dumpsys package " + PACKAGE).splitlines()
                                    if line.strip().startswith(("versionCode=", "versionName="))],
              "refresh_periods_ns": [period], "health": [], "errors": [],
              "poll_ms": [], "complete": False}
    stop = threading.Event()

    def health_sampler():
        while not stop.is_set():
            try:
                memory = shell("dumpsys meminfo " + PACKAGE)
                battery = shell("dumpsys battery")
                thermal = shell("dumpsys thermalservice")
                activities = shell("dumpsys activity activities")
                def number(raw, pattern, scale=1):
                    match = re.search(pattern, raw, re.M)
                    return int(match[1]) / scale if match else None
                sample = {"elapsed_seconds": time.monotonic() - started,
                          "pss_kib": number(memory, r"TOTAL PSS:\s*(\d+)"),
                          "rss_kib": number(memory, r"TOTAL RSS:\s*(\d+)"),
                          "battery_c": number(battery, r"^\s*temperature:\s*(\d+)", 10),
                          "battery_status": number(battery, r"^\s*status:\s*(\d+)"),
                          "thermal_status": number(thermal, r"Thermal Status:\s*(\d+)"),
                          "same_process": shell("pidof " + PACKAGE).strip() == pid,
                          "foreground": any(PACKAGE + "/" in line for line in activities.splitlines()
                                             if "mResumedActivity:" in line or "topResumedActivity=" in line)}
                report["health"].append(sample)
                if not sample["same_process"] or not sample["foreground"]:
                    report["errors"].append("Game process changed or left foreground")
                    stop.set()
                if sample["thermal_status"] is not None and sample["thermal_status"] >= 4:
                    report["errors"].append("Critical thermal status")
                    stop.set()
            except Exception as error:
                report["errors"].append(type(error).__name__ + " during health sampling")
                stop.set()
            stop.wait(5)

    started = time.monotonic()
    health = threading.Thread(target=health_sampler, daemon=True)
    health.start()
    print("Measuring", args.label, "for", args.seconds, "seconds", flush=True)
    try:
        while time.monotonic() - started < args.seconds and not stop.is_set():
            tick = time.monotonic()
            period, stamps = presentations(shell(latency_command))
            report["poll_ms"].append((time.monotonic() - tick) * 1000)
            if period not in report["refresh_periods_ns"]:
                report["refresh_periods_ns"].append(period)
            frames.add(stamps)
            stop.wait(max(0, .25 - (time.monotonic() - tick)))
        report["complete"] = not stop.is_set()
    except BaseException as error:
        report["errors"].append(type(error).__name__ + " during frame sampling")
        raise
    finally:
        stop.set()
        health.join(timeout=60)
        report["wall_seconds"] = time.monotonic() - started
        report["summary"] = frames.summary()
        report["coverage_gaps"] = frames.coverage_gaps
        report["empty_polls"] = frames.empty_polls
        report["usable"] = (report["complete"] and not report["errors"] and
                            not frames.coverage_gaps and not frames.empty_polls and
                            len(frames.intervals_ns) >= 100 and not health.is_alive())
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        (output / "presentation-intervals-ns.json").write_text(json.dumps(frames.intervals_ns) + "\n")
    print(json.dumps({"usable": report["usable"], **report["summary"]}), flush=True)
    return 0 if report["usable"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
