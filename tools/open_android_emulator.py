#!/usr/bin/env python3
"""Open the dedicated PokeAether virtual Android device and an installed app.

Only each profile's fixed emulator serial is addressed. Phones are never selected.
AVD userdata persists outside task slots; closing the window stops the emulator.
"""
import argparse
import os
from pathlib import Path
import subprocess
import time

PROFILES = {
    "native": ("PokeAether_Android13", "5580"),
    "phone": ("PokeAether_Pixel6_Android15", "5582"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, default=Path.home() / "Android/Sdk")
    parser.add_argument("--avd-home", type=Path,
                        default=Path.home() / ".local/share/pokeaether/android-emulator/avd")
    parser.add_argument("--profile", choices=PROFILES, default="native",
                        help="phone runs ordinary ARM64 releases; native retains the Android 13 QA device")
    parser.add_argument("--name", help="Override the selected profile's AVD name")
    parser.add_argument("--boot-only", action="store_true",
                        help="Start Android without launching or requiring an installed app")
    parser.add_argument("--gpu", choices=["auto", "host", "software", "swiftshader", "swangle"], default="host")
    parser.add_argument("--window-scale", type=float, default=0.7,
                        help="Desktop viewing zoom for a newly opened emulator (default: 0.7)")
    parser.add_argument("--package", choices=["com.pokeaether.game", "com.pokeaether.mobilecollapseqa"],
                        default="com.pokeaether.game")
    args = parser.parse_args()
    if not 0.1 <= args.window_scale <= 1.0:
        parser.error("Window scale must be between 0.1 and 1.0")
    default_name, port = PROFILES[args.profile]
    args.name = args.name or default_name
    serial = "emulator-" + port
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
            parser.error(f"Emulator port {port} is already used by a different virtual device")
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
            subprocess.Popen([str(emulator), "-avd", args.name, "-port", port,
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
    if args.profile == "phone":
        abis = device("shell", "getprop", "ro.product.cpu.abilist").stdout.strip().split(",")
        if "arm64-v8a" not in abis:
            raise RuntimeError("The phone profile cannot run ARM64 releases; see docs/android-emulator.md")
    if args.boot_only:
        print("Ready:", args.name)
        return
    if started:
        # Android's fixed landscape and the host's clockwise rotation use
        # opposite directions. Three clockwise turns keep the game upright.
        # Retain the portrait framebuffer for its normal cutout layout.
        for _ in range(3):
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
