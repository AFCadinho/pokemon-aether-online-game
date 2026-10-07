#!/usr/bin/env python3
"""Owned offline model audit/render proof; no cache transfer or publication."""
import argparse
import os
from pathlib import Path
import re
import signal
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=["audit", "render"], required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not ROOT.parent.name.startswith("slot-") or os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run in an assigned slot through slot-env")
    source, output = args.input.resolve(), args.output.resolve()
    for path in (source, output):
        path.relative_to(ROOT / ".tmp")
    if output.exists() or not source.is_file():
        parser.error("Require existing input and fresh output")
    output.parent.mkdir(parents=True, exist_ok=True)
    log_path = output.with_suffix(".log")
    if log_path.exists():
        parser.error("Fresh log required")
    project = ROOT / "project.godot"
    original = project.read_bytes()
    config = re.sub(r"\[autoload\].*?(?=\n\[)", "", original.decode(), flags=re.S)
    config = re.sub(r"\[editor_plugins\].*?(?=\n\[)", "", config, flags=re.S)

    def interrupt(_signal, _frame):
        raise KeyboardInterrupt("Probe interrupted; restoring slot project")

    signal.signal(signal.SIGTERM, interrupt)
    try:
        project.write_text(config)
        command = ["godot", "--path", str(ROOT)]
        if args.mode == "audit":
            command.append("--headless")
        else:
            command += ["--rendering-method", "mobile", "--resolution", "512x512"]
        script = "model_texture_sharing_probe" if args.mode == "audit" else "model_texture_render_probe"
        command += ["--script", f"res://tools/sprite_factory/{script}.gd", "--", str(source), str(output)]
        with log_path.open("w") as log:
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                code = child.wait(timeout=240)
                if code:
                    raise RuntimeError(f"Godot exited {code}; inspect {log_path}")
            except BaseException:
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
                raise
    finally:
        project.write_bytes(original)
    text = log_path.read_text()
    if re.search(r"(?:SCRIPT ERROR|^ERROR:)", text, re.M) or not (output / "report.json").is_file():
        raise RuntimeError(f"Probe failed; inspect {log_path}")
    print("Model texture proof complete:", output)


if __name__ == "__main__":
    main()
