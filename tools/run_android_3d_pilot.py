#!/usr/bin/env python3
"""Run the separate 3D debug pilot on the fixed local emulator, retaining models.
Collect only this diagnostic's reports/images/logs, never game userdata or caches.
"""
import argparse
import json
import re
import subprocess
import time
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.pokeaether.android3dpilot"
SERIAL = "emulator-5580"

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, default=Path.home() / "Android/Sdk")
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, choices=[1, 2], default=2)
    parser.add_argument("--timeout", type=int, default=1800, help="Observer deadline per run in seconds (software GPU may be slow)")
    parser.add_argument("--attach", action="store_true", help="Collect the currently running pilot as the first run")
    parser.add_argument("--fresh", action="store_true", help="Reset only this isolated test app before the first run")
    parser.add_argument("--cache-only", action="store_true", help="Verify all persisted cohort files in a new process, without rendering")
    args = parser.parse_args()
    if args.timeout < 60 or args.timeout > 3600:
        parser.error("--timeout must be between 60 and 3600 seconds")
    if args.cache_only and (args.fresh or args.attach or args.runs != 1):
        parser.error("--cache-only requires --runs 1, existing app files, and a new process")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=True)
    adb = str(args.sdk / "platform-tools/adb")
    apk = args.apk.resolve()
    apk.relative_to(ROOT / ".tmp")
    aapt = sorted((args.sdk / "build-tools").glob("*/aapt"))[-1]
    metadata = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True)
    if not re.search(r"package: name='" + re.escape(PACKAGE) + r"'", metadata) or "application-debuggable" not in metadata:
        raise ValueError("Only the separately packaged debug pilot may be installed/reset")
    with ZipFile(apk) as archive:
        libraries = [n for n in archive.namelist() if n.startswith("lib/")]
        if not libraries or any(not n.startswith("lib/x86_64/") for n in libraries):
            raise ValueError("The local emulator pilot requires an x86_64 APK")

    def device(*command, check=True, binary=False):
        try:
            return subprocess.run([adb, "-s", SERIAL, *command], capture_output=True,
                                  text=not binary, timeout=30, check=check)
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as error:
            (output / "device-failure.json").write_text(json.dumps({
                "serial": SERIAL, "command": list(command), "error": type(error).__name__,
                "note": "Device communication failed; this does not establish a game crash.",
            }, indent=2) + "\n")
            raise RuntimeError("Emulator communication failed; inspect device-failure.json and emulator logs") from error

    name = device("emu", "avd", "name").stdout.splitlines()
    if not name or name[0].strip() != "PokeAether_Android13":
        raise RuntimeError("Refusing a different emulator/device")
    if not args.attach:
        device("install", "--no-incremental", "-r", str(apk))
    if args.fresh:
        if args.attach:
            parser.error("--fresh cannot attach to a running test")
        device("shell", "pm", "clear", PACKAGE)
    reports = []
    for number in range(1, args.runs + 1):
        folder = output / f"run-{number}"
        folder.mkdir(exist_ok=True)
        if not args.attach or number > 1:
            device("shell", "am", "force-stop", PACKAGE)
            marker = "files/android-3d-pilot-cache-only"
            device("shell", "run-as", PACKAGE, "touch" if args.cache_only else "rm", *([] if args.cache_only else ["-f"]), marker)
            # Reset only disposable diagnostic reports, never model files.
            device("shell", "run-as", PACKAGE, "rm", "-f", "files/android-3d-pilot-details.json",
                   "files/android-3d-pilot-results.json")
            device("shell", "am", "start", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher")
        deadline = time.monotonic() + args.timeout
        memory = []
        if args.attach and number == 1 and (folder / "memory.json").exists():
            # Resume this diagnostic's sampler after a collector interruption.
            memory = json.loads((folder / "memory.json").read_text())
        missing_process = 0
        while time.monotonic() < deadline:
            result = device("shell", "run-as", PACKAGE, "cat", "files/android-3d-pilot-results.json", check=False)
            if result.returncode == 0:
                break
            pid = device("shell", "pidof", PACKAGE, check=False).stdout.strip()
            if not pid:
                missing_process += 1
                if missing_process >= 3:
                    raise RuntimeError("Pilot stopped before writing its result")
                time.sleep(3)
                continue
            missing_process = 0
            status = device("shell", "dumpsys", "meminfo", PACKAGE).stdout
            pss = re.search(r"TOTAL PSS:\s*(\d+)", status)
            rss = re.search(r"TOTAL RSS:\s*(\d+)", status)
            memory.append({"time": time.time(), "pss_kib": int(pss[1]) if pss else None,
                           "rss_kib": int(rss[1]) if rss else None})
            (folder / "memory.json").write_text(json.dumps(memory, indent=2) + "\n")
            time.sleep(3)
        else:
            raise TimeoutError(f"Pilot did not finish within {args.timeout} seconds")
        details = json.loads(device("shell", "run-as", PACKAGE, "cat", "files/android-3d-pilot-details.json").stdout)
        (folder / "details.json").write_text(json.dumps(details, indent=2) + "\n")
        (folder / "memory.json").write_text(json.dumps(memory, indent=2) + "\n")
        (folder / "result.json").write_text(result.stdout)
        pid = device("shell", "pidof", PACKAGE).stdout.strip()
        log = device("logcat", "--pid=" + pid, "-d", "-v", "brief", "godot:V", "*:S").stdout
        (folder / "native.log").write_text(log)
        names = [] if args.cache_only else device("shell", "run-as", PACKAGE, "ls", "files").stdout.splitlines()
        for name in names:
            if re.fullmatch(r"android-3d-pilot-[a-z0-9-]+\.png", name):
                image = device("exec-out", "run-as", PACKAGE, "cat", "files/" + name, binary=True)
                (folder / name).write_bytes(image.stdout)
        errors = [line for line in log.splitlines() if "SCRIPT ERROR:" in line or "): ERROR:" in line]
        downloads = details.get("completed_downloads", [])
        checks = json.loads(result.stdout)
        warm_cache_reused = (number == 1 and not args.cache_only) or not downloads
        success = (len(details["cases"]) == 21 and not details["failures"]
                   and not details["engine_errors"] and not errors
                   and bool(checks) and all(code == 0 for code in checks.values())
                   and bool(details.get("cache_only", False)) == args.cache_only
                   and warm_cache_reused)
        reports.append({"run": number, "success": success, "cases": len(details["cases"]),
                        "cache_only": args.cache_only,
                        "elapsed_ms": details["elapsed_ms"], "script_or_engine_errors": len(errors),
                        "network_downloads": len(downloads),
                        "network_bytes": sum(item["bytes"] for item in downloads),
                        "warm_cache_reused": warm_cache_reused,
                        "peak_pss_kib": max((s["pss_kib"] or 0 for s in memory), default=0),
                        "peak_rss_kib": max((s["rss_kib"] or 0 for s in memory), default=0)})
        (output / "summary.json").write_text(json.dumps(reports, indent=2) + "\n")
        print(json.dumps(reports[-1]), flush=True)
        if not success:
            raise RuntimeError("Diagnostic failed; inspect " + str(folder))
    if args.cache_only:
        device("shell", "run-as", PACKAGE, "rm", "-f", "files/android-3d-pilot-cache-only")
        print("Android restart cache verification complete; this run did not render models.")
    else:
        print("Android pilot complete. The app remains open for manual model review.")

if __name__ == "__main__":
    main()
