"""Convert normal-form diagnostic GLBs to standalone Godot scenes, without approval."""

import argparse
import json
import os
import re
import subprocess
from pathlib import Path


def convert_one(source, frontend, slot_env, output):
    species = source["species"]
    directory = output / species
    runtime = directory / "runtime"
    report = runtime / "report.json"
    if report.exists():
        return {"species": species, "status": "converted", "report": str(report)}
    directory.mkdir(parents=True, exist_ok=True)
    if runtime.exists():
        attempt = 1
        while (directory / f"runtime-failed-{attempt}").exists():
            attempt += 1
        runtime.rename(directory / f"runtime-failed-{attempt}")
    exported = json.loads(Path(source["report"]).read_text())
    job = json.loads(Path(source["report"]).with_name("job.json").read_text())
    stage = [{"species": species, "path": exported["path"],
              "source_sha256": job["source_sha256"],
              "placement": {"scale": 1.0, "yaw_degrees": 0.0},
              "runtime_approved": False,
              "action_timing": {name: {"frames": round(clip["duration"] * 60, 6),
                                        "speed": 1.0, "loop": clip["loop"]}
                                for name, clip in exported["animations"].items()}}]
    stage_path = directory / "stage.json"
    stage_path.write_text(json.dumps(stage, indent=2) + "\n")
    command = [str(slot_env), "slot-a", "--", "godot", "--headless", "--path",
               str(frontend), "--script", "tools/sprite_factory/prepare_battle_3d_runtime.gd"]
    env = os.environ.copy()
    env.update(POKEAETHER_3D_STAGE_REPORT=str(stage_path), POKEAETHER_3D_RUNTIME_OUTPUT=str(runtime))
    try:
        with (directory / "conversion.log").open("w") as log:
            subprocess.run(command, cwd=frontend, env=env, stdout=log, stderr=subprocess.STDOUT,
                           timeout=300, check=True)
        result = json.loads(report.read_text())
        if len(result) != 1 or result[0]["species"] != species:
            raise ValueError("Unexpected standalone scene report")
        return {"species": species, "status": "converted", "report": str(report)}
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        log = directory / "conversion.log"
        failures = re.findall(r"(?:CONVERSION_FAILED|PREFLIGHT_FAILED|OUTPUT_ERROR): ([^\n]+)",
                              log.read_text(errors="replace") if log.exists() else "")
        return {"species": species, "status": "blocked",
                "reason": failures[-1] if failures else type(error).__name__ + ": " + str(error)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--export-status", type=Path, required=True)
    parser.add_argument("--frontend", type=Path, required=True)
    parser.add_argument("--slot-env", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    frontend, output = args.frontend.resolve(), args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    sources = [entry for entry in json.loads(args.export_status.read_text())["entries"]
               if entry["status"] == "exported"]
    if args.limit is not None:
        sources = sources[:args.limit]
    results = []
    for source in sources:
        result = convert_one(source, frontend, args.slot_env.resolve(), output)
        results.append(result)
        (output / "status.json").write_text(json.dumps({"schema": 1, "total": len(sources),
            "processed": len(results), "converted": sum(x["status"] == "converted" for x in results),
            "blocked": sum(x["status"] == "blocked" for x in results),
            "entries": results}, indent=2) + "\n")
        print(result["species"], result["status"], flush=True)


if __name__ == "__main__":
    main()
