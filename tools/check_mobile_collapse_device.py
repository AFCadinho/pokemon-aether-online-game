#!/usr/bin/env python3
"""Check the isolated QA app's Android density and real edge-tap input.

Run only while the QA app is foreground and its automatic checks have finished.
Reads this diagnostic package's report; never reads the installed game's data.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time

PACKAGE = "com.pokeaether.mobilecollapseqa"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", type=Path, required=True)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    prefix = [str(args.adb), "-s", args.serial]

    def adb(*arguments):
        return subprocess.check_output(prefix + list(arguments), text=True, timeout=15)

    def report():
        # The diagnostic rewrites its report after each press. ADB can read
        # between truncation and the completed write; retry that transient read.
        deadline = time.monotonic() + 2
        while True:
            try:
                return json.loads(adb("exec-out", "run-as", PACKAGE, "cat", "files/mobile-collapse-details.json"))
            except json.JSONDecodeError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(0.1)

    def foreground():
        activities = adb("shell", "dumpsys", "activity", "activities")
        if not any("ResumedActivity" in line and PACKAGE + "/" in line for line in activities.splitlines()):
            raise RuntimeError("The diagnostic app must be foreground before sending input")

    foreground()
    density_values = re.findall(r"(?:Physical|Override) density: (\d+)", adb("shell", "wm", "density"))
    if not density_values:
        raise RuntimeError("Android did not report its logical display density")
    density_dpi = int(density_values[-1])
    pixels_per_dp = density_dpi / 160
    initial = report()
    if initial["failures"]:
        raise RuntimeError("Automatic device checks failed: " + repr(initial["failures"]))
    sizes = [min(button["width"], button["height"]) / pixels_per_dp
             for sample in initial["samples"] for button in sample["buttons"].values()]
    if not sizes or min(sizes) < 47.99:
        raise RuntimeError("Targets are below 48 Android dp using the independent ADB density")
    cases = []
    for panel_id in initial["liveButtons"]:
        for direction in ["toggle", "restore"]:
            before = report()
            button = before["liveButtons"][panel_id]
            foreground()
            x = round(button["x"] + button["width"] * 0.1)
            y = round(button["y"] + button["height"] * 0.9)
            adb("shell", "input", "tap", str(x), str(y))
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                after = report()
                if len(after["presses"]) > len(before["presses"]):
                    break
                time.sleep(0.1)
            else:
                raise RuntimeError("Android edge tap did not reach " + panel_id)
            last = after["presses"][-1]
            if last["panel"] != panel_id or not last["manual"]:
                raise RuntimeError("Android tap reached a different control: " + repr(last))
            if after["liveButtons"][panel_id]["collapsed"] == button["collapsed"]:
                raise RuntimeError("Android tap did not toggle " + panel_id)
            cases.append({"panel": panel_id, "action": direction, "x": x, "y": y})
    final = report()
    evidence = {"densityDpiFromAdb": density_dpi, "minimumTargetDp": min(sizes),
                "uiScale": initial["currentScale"], "androidEdgeTaps": cases, "report": final}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2) + "\n")
    print(f"PASS: {len(cases)} Android edge taps; minimum target {min(sizes):.3f} dp; density {density_dpi} dpi")


if __name__ == "__main__":
    main()
