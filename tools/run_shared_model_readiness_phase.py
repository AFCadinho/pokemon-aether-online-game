#!/usr/bin/env python3
"""Run one local readiness phase with frozen inputs and retained output."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from shared_model_qualification_evidence_check import frozen_commit_check


def frozen_inputs():
    paths = {ROOT / "project.godot", Path(__file__).resolve()}
    for pattern in ("scripts/**/*.gd", "launcher/scripts/*.gd", "data/model_pair*.json",
                    "launcher/data/model_pair*.json", "tests/shared_model*.gd",
                    "release/approved_3d*.json", "resources/battle/model_animations/**/*",
                    "resources/battle/model_visibility/**/*"):
        paths.update(p for p in ROOT.glob(pattern) if p.is_file() and p.suffix != ".uid")
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


def write_new(path, value):
    with path.open("x") as stream:
        stream.write(json.dumps(value, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--phase", choices=("installation", "consumers", "session"), required=True)
    parser.add_argument("--attempt", help="Fresh session output name; retains any earlier failed session")
    args = parser.parse_args()
    assert os.environ.get("POKEAETHER_SLOT") == ROOT.parent.name, "Use assigned slot-env"
    run = args.run.resolve()
    run.relative_to(ROOT / ".tmp")
    config = json.loads((run / "input.json").read_bytes())
    assert Path(config["root"]).resolve() == run
    phase = args.phase
    assert args.attempt is None or (phase == "session" and re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9_-]*", args.attempt))
    name = args.attempt or phase
    assert all(not (run / (name + suffix)).exists()
               for suffix in (".log", ".engine.log", ".json", ".execution.json")), "Keep previous evidence"
    if phase == "installation":
        assert not (run / "fresh").exists() and not (run / "upgrade").exists()
        script, script_args = "install", [str(run / "input.json")]
    elif phase == "consumers":
        assert json.loads((run / "installation.json").read_bytes())["ok"]
        script, script_args = "consumer", [str(run)]
    else:
        assert json.loads((run / "consumers.json").read_bytes())["ok"]
        script, script_args = "stress", [str(run / "fresh/store"), str(run / (name + ".json"))]
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    inputs = frozen_inputs()
    frozen_commit_check({"qualified_source_commit": revision, "inputs": inputs})
    write_new(run / ("inputs.sha256.json" if phase == "installation" else name + ".inputs.json"), inputs)
    if phase == "installation":
        with (run / "implementation-commit.txt").open("x") as stream:
            stream.write(revision + "\n")
    environment = os.environ.copy()
    for kind in ("data", "config", "cache"):
        directory = run / "runtime" / name / kind
        directory.mkdir(parents=True, exist_ok=False)
        environment["XDG_" + kind.upper() + "_HOME"] = str(directory)
    renderer = ["--rendering-method", "mobile"] if phase == "session" else ["--headless"]
    command = ["godot", *renderer,
               "--log-file", str(run / (name + ".engine.log")), "--path", str(ROOT),
               "--script", "res://tests/shared_model_collection_" + script + "_check.gd", "--", *script_args]
    started = time.monotonic()
    reason = ""
    with (run / (name + ".log")).open("x") as output:
        process = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=output,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        print(phase, "pid", process.pid, "log", output.name, flush=True)
        try:
            while process.poll() is None:
                log = Path(output.name).read_text()
                if "SCRIPT ERROR:" in log or "\nERROR:" in log:
                    reason = "Godot error in retained log"
                    break
                if time.monotonic() - started > 4 * 3600:
                    reason = "Phase exceeded four hours"
                    break
                time.sleep(2)
        except KeyboardInterrupt:
            reason = "Interrupted by operator"
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    process.kill()
            code = process.wait()
    unchanged = inputs == frozen_inputs()
    receipt = run / (name + ".json")
    passed = not reason and code == 0 and unchanged and receipt.exists() and json.loads(receipt.read_bytes())["ok"]
    write_new(run / (name + ".execution.json"), {
        "ok": passed, "returncode": code, "reason": reason, "inputs_unchanged": unchanged,
        "implementation_commit": revision, "elapsed_seconds": time.monotonic() - started,
    })
    print("SHARED_MODEL_READINESS_PHASE", phase, "OK" if passed else "FAILED", flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    def interrupted(_signal, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    raise SystemExit(main())
