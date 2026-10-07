#!/usr/bin/env python3
"""Install only the owned debug package and serve pinned prototype bundles."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
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
PACKAGE = "com.pokeaether.androidmodelpairs"
SERIAL = "emulator-5580"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, required=True)
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sdk", type=Path, default=Path.home() / "Android/Sdk")
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through assigned slot-env")
    assets, apk, output = [p.resolve() for p in (args.assets, args.apk, args.output)]
    for path in (assets, apk, output):
        path.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    fixture = json.loads((assets / "fixture.json").read_bytes())
    assert fixture["prototype_only"] and fixture["pairs"]
    expected_cases = len(fixture["pairs"]) * 2
    fixture["run_id"] = uuid.uuid4().hex
    fixture_bytes = json.dumps(fixture).encode()
    aapt = sorted((args.sdk / "build-tools").glob("*/aapt2"))[-1]
    metadata = subprocess.check_output([str(aapt), "dump", "badging", str(apk)], text=True)
    if "package: name='" + PACKAGE + "'" not in metadata or "application-debuggable" not in metadata:
        raise ValueError("Only the separate model-pair debug APK is allowed")
    with zipfile.ZipFile(apk) as archive:
        libs = [name for name in archive.namelist() if name.startswith("lib/")]
        if not libs or any(not name.startswith("lib/x86_64/") for name in libs):
            raise ValueError("Fixed x86_64 emulator only")
    adb = str(args.sdk / "platform-tools/adb")

    def device(*command, check=True):
        return subprocess.run([adb, "-s", SERIAL, *command], check=check, timeout=45, text=True, capture_output=True)

    if device("emu", "avd", "name").stdout.splitlines()[0] != "PokeAether_Android13":
        raise ValueError("Refusing another device")

    class Handler(SimpleHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            if self.path == "/fixture.json":
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(fixture_bytes)))
                self.end_headers()
                self.wfile.write(fixture_bytes)
            else:
                super().do_GET()

    server = ThreadingHTTPServer(("127.0.0.1", 8799), partial(Handler, directory=str(assets)))
    threading.Thread(target=server.serve_forever, daemon=True).start()

    def interrupted(_signal, _frame):
        raise KeyboardInterrupt("Pair diagnostic interrupted; removing reverse fixture")

    signal.signal(signal.SIGTERM, interrupted)
    try:
        device("reverse", "tcp:8799", "tcp:8799")
        device("install", "--no-incremental", "-r", str(apk))
        device("shell", "am", "force-stop", PACKAGE)
        device("shell", "am", "start", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher")
        memory = []
        deadline = time.monotonic() + 600
        while time.monotonic() < deadline:
            pid = device("shell", "pidof", PACKAGE, check=False).stdout.strip()
            if pid:
                log = device("logcat", "--pid=" + pid, "-d", "-v", "brief", "godot:V", "*:S").stdout
                (output / "native.log").write_text(log)
                if "SCRIPT ERROR:" in log or "): ERROR:" in log:
                    raise RuntimeError("Native script/engine errors; inspect native.log")
            status = device("shell", "dumpsys", "meminfo", PACKAGE, check=False).stdout
            pss = re.search(r"TOTAL PSS:\s*(\d+)", status)
            rss = re.search(r"TOTAL RSS:\s*(\d+)", status)
            memory.append({"time": time.time(), "pss_kib": int(pss[1]) if pss else 0, "rss_kib": int(rss[1]) if rss else 0})
            (output / "memory.json").write_text(json.dumps(memory, indent=2))
            raw = device("shell", "run-as", PACKAGE, "cat", "files/android-model-pairs-details.json", check=False)
            codes = device("shell", "run-as", PACKAGE, "cat", "files/android-model-pairs-results.json", check=False)
            if raw.returncode == 0 and codes.returncode == 0:
                details = json.loads(raw.stdout)
                results = json.loads(codes.stdout)
                if details.get("run_id") == fixture["run_id"]:
                    (output / "details.json").write_text(raw.stdout)
                    (output / "results.json").write_text(codes.stdout)
                    assert details["success"] and details["renderer"] == "mobile" and len(details["cases"]) == expected_cases
                    assert {(row["species"], row["variant"]) for row in details["cases"]} == {
                        (pair["species"], kind) for pair in fixture["pairs"] for kind in ("baseline", "shared")}
                    assert results and all(value == 0 for value in results.values())
                    assert all(row["remaining_texture_refs"] == 0 and (row["shared_objects"] > 0) == (row["variant"] == "shared") for row in details["cases"])
                    print("ANDROID_MODEL_PAIRS_OK cases=" + str(expected_cases) + " peak_pss_kib=" + str(max(m["pss_kib"] for m in memory)), flush=True)
                    break
            time.sleep(2)
        else:
            raise TimeoutError("Pair diagnostic timed out")
    finally:
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
