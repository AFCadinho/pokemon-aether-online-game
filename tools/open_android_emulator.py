#!/usr/bin/env python3
"""Open the dedicated PokeAether virtual Android device and an installed app.

Only the fixed emulator serial is addressed. Physical phones are never selected.
AVD userdata persists outside task slots; closing the window stops the emulator.
"""
import argparse
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, default=Path.home() / "Android/Sdk")
    parser.add_argument("--avd-home", type=Path,
                        default=Path.home() / ".local/share/pokeaether/android-emulator/avd")
    parser.add_argument("--name", default="PokeAether_Android13")
    parser.add_argument("--gpu", choices=["auto", "host", "software", "swiftshader", "swangle"], default="host")
    parser.add_argument("--window-scale", type=float, default=0.7,
                        help="Desktop viewing zoom for a newly opened emulator (default: 0.7)")
    parser.add_argument("--package", choices=["com.pokeaether.game", "com.pokeaether.mobilecollapseqa"],
                        default="com.pokeaether.game")
    args = parser.parse_args()
    if not 0.1 <= args.window_scale <= 1.0:
        parser.error("Window scale must be between 0.1 and 1.0")
    serial = "emulator-5580"
    adb = str(args.sdk / "platform-tools/adb")
    emulator = args.sdk / "emulator/emulator"
    if not emulator.is_file() or not (args.avd_home / (args.name + ".ini")).is_file():
        parser.error("The emulator or PokeAether virtual device is not installed; see docs/android-emulator.md")

    def device(*command, timeout=10):
        return subprocess.run([adb, "-s", serial, *command], capture_output=True, text=True, timeout=timeout)

    name = device("emu", "avd", "name").stdout.splitlines()
    started = not name
    if name:
        if name[0].strip() != args.name:
            parser.error("Emulator port 5580 is already used by a different virtual device")
    else:
        metadata = dict(line.split("=", 1) for line in
                        (args.avd_home / (args.name + ".ini")).read_text().splitlines() if "=" in line)
        preferences = Path(metadata["path"].strip()) / "emulator-user.ini"
        lines = preferences.read_text().splitlines() if preferences.exists() else []
        lines = [line for line in lines if line.partition("=")[0].strip() != "window.scale"]
        preferences.write_text("\n".join(lines + [f"window.scale = {args.window_scale:.6f}"]) + "\n")
        environment = os.environ.copy()
        environment["ANDROID_AVD_HOME"] = str(args.avd_home.resolve())
        log_dir = args.avd_home.parent
        with (log_dir / "emulator.log").open("a") as log:
            subprocess.Popen([str(emulator), "-avd", args.name, "-port", "5580",
                              "-gpu", args.gpu, "-no-snapshot", "-no-boot-anim",
                              "-camera-back", "none", "-camera-front", "none", "-no-skin"],
                             env=environment, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)

    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if device("shell", "getprop", "sys.boot_completed").stdout.strip() == "1":
            break
        time.sleep(2)
    else:
        raise RuntimeError("Android did not finish booting; inspect " + str(args.avd_home.parent / "emulator.log"))
    name = device("emu", "avd", "name").stdout.splitlines()
    if not name or name[0].strip() != args.name:
        raise RuntimeError("Virtual device identity changed; refusing to launch an app")
    if started:
        # Rotate the desktop presentation; keep the AVD's portrait framebuffer
        # so Android retains its normal landscape resolution and cutout layout.
        result = device("emu", "rotate")
        if result.returncode or "KO:" in result.stdout:
            raise RuntimeError(result.stderr + result.stdout)
    installed = device("shell", "pm", "path", args.package)
    if not installed.stdout.startswith("package:"):
        raise RuntimeError("The requested app is not installed on the virtual device")
    result = device("shell", "am", "start", "-n", args.package + "/com.godot.game.GodotAppLauncher")
    if result.returncode or "Error:" in result.stderr or "Error:" in result.stdout:
        raise RuntimeError(result.stderr + result.stdout)
    print("Opened", args.package, "on", args.name)


if __name__ == "__main__":
    main()
