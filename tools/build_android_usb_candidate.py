#!/usr/bin/env python3
"""Build a signed local Android update; never publish or install it.

Run in the assigned slot with the release-key environment variables configured.
Reuse an existing asset build ID so a USB test does not require publishing assets.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess

from android_release import prepare, replace_setting, inspect
from prepare_android_assets import prepare as prepare_assets
from check_android_demand_export import verify
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--java", type=Path, required=True)
    parser.add_argument("--templates", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--code", type=int, required=True)
    parser.add_argument("--build-id", required=True)
    parser.add_argument("--compatible-build-id", required=True)
    parser.add_argument("--asset-build-id", required=True)
    parser.add_argument("--certificate", required=True)
    parser.add_argument("--architecture", choices=["arm64-v8a", "x86_64"], default="arm64-v8a",
                        help="Use x86_64 for an accelerated desktop Android emulator")
    args = parser.parse_args()
    if ROOT.parent.name.startswith("slot-") and os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run through ops/worktrees/slot-env SLOT -- COMMAND")
    for name in ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"]:
        if not os.environ.get(name):
            parser.error("Missing signing environment variable: " + name)
    os.umask(0o077)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    project = ROOT / "project.godot"
    presets = ROOT / "export_presets.cfg"
    editor = Path(os.environ["XDG_CONFIG_HOME"]) / "godot/editor_settings-4.6.tres"
    originals = {p: p.read_bytes() if p.exists() else None for p in [project, presets, editor, ROOT / "generated/browser_audio_catalog.json"]}
    try:
        prepare_assets(ROOT)
        subprocess.run(["python3", str(ROOT / "android_updater/setup_build_template.py"), str(args.templates / "android_source.zip")], check=True)
        prepare(project, presets, args.version, args.code, args.build_id, args.compatible_build_id)
        for architecture in ["armeabi-v7a", "arm64-v8a", "x86", "x86_64"]:
            replace_setting(presets, "preset.7.options", "architectures/" + architecture,
                            "true" if architecture == args.architecture else "false")
        replace_setting(project, "application", "config/android_asset_build_id", json.dumps(args.asset_build_id))
        editor.parent.mkdir(parents=True, exist_ok=True)
        editor.write_text('[gd_resource type="EditorSettings" format=3]\n[resource]\nexport/android/android_sdk_path = "' + str(args.sdk.resolve()) + '"\nexport/android/java_sdk_path = "' + str(args.java.resolve()) + '"\n')
        apk = output / ("game-" + args.build_id + "-android.apk")
        environment = os.environ.copy()
        environment["JAVA_HOME"] = str(args.java.resolve())
        environment["ANDROID_HOME"] = str(args.sdk.resolve())
        environment["GRADLE_USER_HOME"] = str(ROOT.parent / ".runtime/gradle")
        with (output / "export.log").open("w") as log:
            subprocess.run(["godot", "--headless", "--path", str(ROOT), "--export-release", "Android Internal Alpha", str(apk)], env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
        with zipfile.ZipFile(apk) as archive:
            verify(ROOT, [name.removeprefix("assets/") for name in archive.namelist() if name.startswith("assets/")])
            libraries = [name for name in archive.namelist() if name.startswith("lib/") and name.endswith(".so")]
            if not libraries or any(name.split("/")[1] != args.architecture for name in libraries):
                raise ValueError("APK native libraries differ from the requested architecture")
        record = inspect(apk, args.sdk / "build-tools/35.0.1/aapt", args.sdk / "build-tools/35.0.1/apksigner", args.version, args.code, args.build_id, args.certificate, output / "local-usb-build-record.json", args.compatible_build_id)
        record["localUsbTestOnly"] = True
        record["sourceCommit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        record["assetBuildId"] = args.asset_build_id
        record["architecture"] = args.architecture
        (output / "local-usb-build-record.json").write_text(json.dumps(record, indent=2) + "\n")
        print("Verified local USB candidate:", apk)
    finally:
        for file, content in originals.items():
            if content is None:
                file.unlink(missing_ok=True)
            else:
                file.write_bytes(content)


if __name__ == "__main__":
    main()
