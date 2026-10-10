#!/usr/bin/env python3
"""Kill isolated real installers at filesystem boundaries, then restart them.

Linux-only fault injection lives in a separate preload library, never in the
game or launcher. All mutated stores and derived fixtures belong to this task.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packs", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if sys.platform != "linux" or os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run on Linux in the assigned slot through slot-env")
    output = args.output.resolve()
    output.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    library = output / "crash-faults.so"
    subprocess.run(["gcc", "-Wall", "-Wextra", "-Werror", "-shared", "-fPIC", "-o", str(library),
                    str(ROOT / "tests/shared_model_crash_faults.c"), "-ldl"], check=True)
    fixtures = output / "fixtures"
    records = []

    def run(action, directory, implementation="game", point=None):
        env = os.environ.copy()
        env.pop("LD_PRELOAD", None)
        if point:
            env.update(LD_PRELOAD=str(library), POKEAETHER_CRASH_POINT=point,
                       POKEAETHER_CRASH_ROOT=str(directory))
        log = output / f"{directory.name}-{implementation}-{action}-{point or 'normal'}.log"
        runtime = output / "runtime" / f"{directory.name}-{implementation}-{action}-{point or 'normal'}"
        for kind in ("data", "config", "cache"):
            path = runtime / kind
            path.mkdir(parents=True)
            env[f"XDG_{kind.upper()}_HOME"] = str(path)
        with log.open("w") as stream:
            result = subprocess.run(["godot", "--log-file", str(log.with_suffix(".engine.log")), "--headless", "--path", str(ROOT), "--script",
                                     "res://tests/shared_model_crash_worker.gd", "--", action,
                                     str(fixtures), str(directory), implementation],
                                    env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=90)
        text = log.read_text()
        expected = -signal.SIGKILL if point else 0
        ok = result.returncode == expected and (f"INJECTED_SIGKILL {point}" in text if point else
                                               "SHARED_CRASH_WORKER" in text and "FAILED" not in text and
                                               "SCRIPT ERROR:" not in text and "ERROR:" not in text)
        records.append({"action": action, "implementation": implementation, "point": point,
                        "returncode": result.returncode, "ok": ok,
                        "log_sha256": hashlib.sha256(log.read_bytes()).hexdigest()})
        print("CRASH_CHECK", directory.name, implementation, action, point or "restart",
              "OK" if ok else "FAILED", flush=True)
        if not ok:
            print(text[-4000:], flush=True)
        return ok

    ok = run("fixture", args.packs.resolve())
    if ok:
        for implementation in ("game", "launcher"):
            for mode, points in (("install", ("copy", "staged", "published")),
                                 ("repair", ("copy", "staged", "quarantined", "published"))):
                for point in points:
                    directory = output / f"{implementation}-{mode}-{point}"
                    directory.mkdir()
                    if mode == "repair":
                        ok = run("setup", directory, implementation) and ok
                        ok = run("corrupt", directory, implementation) and ok
                    cut = run(mode, directory, implementation, point)
                    resumed = run("resume-" + mode, directory, implementation)
                    ok = cut and resumed and ok
        for point in ("copy", "staged", "published", "generation", "previous", "active"):
            directory = output / f"update-{point}"
            directory.mkdir()
            ok = run("setup", directory) and ok
            cut = run("update", directory, point=point)
            resumed = run("resume-update", directory)
            ok = cut and resumed and ok
    receipt = {"schema": 1, "ok": ok, "os": sys.platform,
               "method": "external Linux LD_PRELOAD SIGKILL at real file writes/renames",
               "records": records}
    (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
