#!/usr/bin/env python3
"""Export the full game as a separate debug Android colour-review app.

Never publishes, installs, accesses accounts, or changes the ordinary game.
Reuse explicit existing published asset/client identities; do not upload assets.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
from zipfile import ZipFile

from android_release import BUILD_ID, replace_setting
from check_android_demand_export import verify
from prepare_android_assets import prepare

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.pokeaether.androidcolourcandidate"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--java", type=Path, required=True)
    parser.add_argument("--architecture", choices=["arm64-v8a", "x86_64"], required=True)
    parser.add_argument("--asset-build-id", required=True)
    parser.add_argument("--compatible-build-id", required=True)
    parser.add_argument("--templates", type=Path, default=Path.home()/".local/share/godot/export_templates/4.6.2.stable")
    args = parser.parse_args()
    if ROOT.parent.name not in {"slot-a", "slot-b", "slot-c"} or os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run in an assigned task slot through slot-env")
    if not all(BUILD_ID.fullmatch(value) for value in [args.asset_build_id,args.compatible_build_id]):
        parser.error("Expected explicit existing immutable asset and compatible client identities")
    output = args.output.resolve()
    output.relative_to(ROOT/".tmp")
    output.mkdir(parents=True,exist_ok=True)
    lock = (ROOT/".tmp/diagnostic-project.lock").open("a+")
    fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
    project = ROOT/"project.godot"
    presets = ROOT/"export_presets.cfg"
    audio = ROOT/"generated/browser_audio_catalog.json"
    editor = Path(os.environ["XDG_CONFIG_HOME"])/"godot/editor_settings-4.6.tres"
    originals = {p:p.read_bytes() if p.exists() else None for p in [project,presets,audio,editor]}
    generated = ROOT/"scripts/android_colour_candidate_generated"
    if generated.exists():
        raise RuntimeError("Separate candidate adapter directory already exists")
    generated.mkdir()
    try:
        prepare(ROOT)
        # Keep the full login, world and battle scenes. Disable only this private
        # app's APK updater: a production update must never replace the preview.
        wrapper = generated/"updater_off.gd"
        wrapper.write_text('extends "res://scripts/services/android_apk_update_service.gd"\nfunc _ready() -> void:\n\tpass\n')
        config = originals[project].decode().replace('res://scripts/services/android_apk_update_service.gd','res://scripts/android_colour_candidate_generated/updater_off.gd')
        config = re.sub(r'^run/main_scene=.*$', 'run/main_scene="res://scenes/interface/login_screen.tscn"',config,flags=re.M)
        project.write_text(config)
        source_commit = subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip()
        build_id = "android-colour-review-"+source_commit[:12]
        for key,value in [("config/name","PokeAether Android Colour Test"),("config/build_id",build_id),("config/android_asset_build_id",args.asset_build_id),("config/android_test_compatible_build_id",args.compatible_build_id)]:
            replace_setting(project,"application",key,json.dumps(value))
        replace_setting(project,"application","config/android_version_code","1")
        # Clone the normal Android preset; its full world/external-asset rules
        # remain unchanged. Use the slot's debug certificate and a separate ID.
        content = originals[presets].decode()
        start,end = content.index("[preset.7]"),content.index("[preset.8]")
        index = max(map(int,re.findall(r"\[preset\.(\d+)\]",content)))+1
        selected = content[start:end].replace("[preset.7",f"[preset.{index}")
        selected = re.sub(r'^name=.*$', 'name="Android Colour Candidate"',selected,flags=re.M)
        selected = re.sub(r'^custom_features=.*$', 'custom_features="android_v1,android_3d_experimental"',selected,flags=re.M)
        selected = selected.replace('package/unique_name="com.pokeaether.game"','package/unique_name="'+PACKAGE+'"')
        selected = selected.replace('package/name="PokeAether"','package/name="PokeAether Android Colour Test"')
        selected = re.sub(r'^version/code=.*$','version/code=1',selected,flags=re.M)
        version = re.search(r'^config/version="([^"]+)"$', originals[project].decode(), re.M).group(1)
        selected = re.sub(r'^version/name=.*$','version/name="'+version+'-colour-review.1"',selected,flags=re.M)
        for arch in ["armeabi-v7a","arm64-v8a","x86","x86_64"]:
            selected = re.sub(r'^architectures/'+re.escape(arch)+r'=.*$', 'architectures/'+arch+'='+str(arch==args.architecture).lower(),selected,flags=re.M)
        presets.write_text(content+"\n"+selected)
        editor.parent.mkdir(parents=True,exist_ok=True)
        editor.write_text('[gd_resource type="EditorSettings" format=3]\n[resource]\nexport/android/android_sdk_path = "'+str(args.sdk.resolve())+'"\nexport/android/java_sdk_path = "'+str(args.java.resolve())+'"\n')
        apk = output/("PokeAether-colour-review-"+args.architecture+".apk")
        # The full app needs the real native bridge (including exit reasons).
        # Built-in diagnostic templates omit it and cannot stand in for a game APK.
        subprocess.run(["python3", str(ROOT/"android_updater/setup_build_template.py"), str(args.templates.resolve()/"android_source.zip")],check=True)
        environment = os.environ.copy()
        environment["JAVA_HOME"] = str(args.java.resolve())
        environment["ANDROID_HOME"] = str(args.sdk.resolve())
        environment["GRADLE_USER_HOME"] = str(ROOT.parent/".runtime/gradle")
        with (output/"export.log").open("w") as log:
            subprocess.run(["godot","--headless","--path",str(ROOT),"--export-debug","Android Colour Candidate",str(apk)],env=environment,stdout=log,stderr=subprocess.STDOUT,check=True)
        if re.search(r'^(?:SCRIPT ERROR:|ERROR:)',(output/"export.log").read_text(errors="replace"),re.M):
            raise RuntimeError("Candidate export contains errors; inspect export.log")
        with ZipFile(apk) as archive:
            verify(ROOT,[n.removeprefix("assets/") for n in archive.namelist() if n.startswith("assets/")])
            dex = [n for n in archive.namelist() if re.fullmatch(r"classes(?:[0-9]+)?\.dex",n)]
            if not any(b"Lcom/pokeaether/game/ApkInstallBridge;" in archive.read(n) for n in dex):
                raise ValueError("Full-game candidate must include the native exit/update bridge")
            libs=[n for n in archive.namelist() if n.startswith("lib/") and n.endswith(".so")]
            if not libs or any(n.split("/")[1]!=args.architecture for n in libs):
                raise ValueError("Candidate ABI differs from requested architecture")
        aapt=args.sdk/"build-tools/35.0.1/aapt2"
        badging=subprocess.check_output([str(aapt),"dump","badging",str(apk)],text=True,stderr=subprocess.PIPE)
        if "package: name='"+PACKAGE+"'" not in badging or "application-debuggable" not in badging:
            raise ValueError("Expected separate, debuggable candidate package")
        with apk.open("rb") as stream:
            digest=hashlib.file_digest(stream,"sha256").hexdigest()
        record={"schema":1,"test_only":True,"full_game":True,"published":False,"installed":False,"package":PACKAGE,"architecture":args.architecture,"apk":apk.name,"bytes":apk.stat().st_size,"sha256":digest,"source_commit":source_commit,"build_id":build_id,"asset_build_id":args.asset_build_id,"compatible_build_id":args.compatible_build_id,"normal_app_data_reused":False,"apk_updater_enabled":False,"native_exit_bridge":True}
        (output/"candidate.json").write_text(json.dumps(record,indent=2)+"\n")
        print("Full game Android colour candidate prepared:",apk)
    finally:
        for path,value in originals.items():
            if value is None:path.unlink(missing_ok=True)
            else:path.write_bytes(value)
        shutil.rmtree(generated)
        lock.close()


if __name__=="__main__":
    main()
