#!/usr/bin/env python3
"""Export focused battle-entry checks as an offline Web or Android diagnostic.
Run through slot-env. Project/preset edits and generated adapters are temporary.
"""
import argparse
import os
import struct
import zlib
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECKS = ["trainer_vision_physics_flush_check", "fullscreen_battle_fade_check", "battle_entry_slow_sprite_check", "wild_entry_before_response_check", "trainer_entry_before_response_check"]
FIXTURES = ["trainer_vision_probe", "wild_entry_request_probe", "trainer_entry_request_probe", "trainer_entry_lead_probe"]

def rewrite_fixture_paths(source):
    for name in FIXTURES:
        source = source.replace(f"res://tests/fixtures/{name}.gd", f"res://scripts/battle_entry_qa_generated/{name}.gd")
    return source

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    global CHECKS, FIXTURES
    parser.add_argument("--suite", choices=["battle-entry", "mobile-collapse", "coop-sprites", "android-3d", "android-arenas"], default="battle-entry")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--platform", choices=["web", "android"], default="web")
    parser.add_argument("--sdk", type=Path)
    parser.add_argument("--templates", type=Path, default=Path.home() / ".local/share/godot/export_templates/4.6.2.stable")
    parser.add_argument("--java", type=Path, default=Path("/usr/lib/jvm/java-26-openjdk"))
    parser.add_argument("--emulator-frame-pacing-off", action="store_true", help="Arena-only x86_64 workaround for Godot emulator issue 121035")
    parser.add_argument("--android-renderer", choices=["gl_compatibility", "mobile"], default="gl_compatibility")
    parser.add_argument("--architecture", choices=["arm64-v8a", "x86_64"], default="arm64-v8a")
    args = parser.parse_args()
    mobile_collapse = args.suite == "mobile-collapse"
    coop_sprites = args.suite == "coop-sprites"
    android_arenas = args.suite == "android-arenas"
    if args.android_renderer != "gl_compatibility" and not android_arenas:
        parser.error("--android-renderer is limited to the separate Android arena diagnostic")
    if args.emulator_frame_pacing_off and (not android_arenas or args.architecture != "x86_64"):
        parser.error("Frame-pacing workaround is limited to the x86_64 arena emulator diagnostic")
    android_3d = args.suite in {"android-3d", "android-arenas"}
    if android_3d:
        if args.platform != "android":
            parser.error("3D pilot requires the native Android debug runtime")
        CHECKS = ["android_arena_asset_check" if android_arenas else "android_3d_pilot_check"]
        FIXTURES = []
    if mobile_collapse:
        if args.platform != "android":
            parser.error("Mobile collapse QA uses the native Android runtime")
        CHECKS = ["mobile_collapse_phone_check"]
        FIXTURES = []
    if coop_sprites:
        CHECKS = ["coop_sprite_platform_check"]
        FIXTURES = []
    title = "Mobile Collapse QA" if mobile_collapse else "Battle Entry QA"
    app_name = "PokeAether Mobile Collapse QA" if mobile_collapse else "PokeAether Entry QA"
    package = "com.pokeaether.mobilecollapseqa" if mobile_collapse else "com.pokeaether.battleentryqa"
    report_name = "mobile-collapse-qa-results.json" if mobile_collapse else "battle-entry-qa-results.json"
    if coop_sprites:
        title = "Co-op Sprite QA"
        app_name = "PokeAether Co-op Sprite QA"
        package = "com.pokeaether.coopspriteqa"
        report_name = "coop-sprite-qa-results.json"
    if android_3d:
        title = "Android 3D Pilot"
        app_name = "PokeAether Android 3D Pilot"
        package = "com.pokeaether.android3dpilot"
        report_name = "android-3d-pilot-results.json"
    if android_arenas:
        title = "Android Arena Pilot"
        app_name = "PokeAether Android Arena Pilot"
        package = "com.pokeaether.androidarenapilot"
        report_name = "android-arena-results.json"
    if ROOT.parent.name.startswith("slot-") and os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Run slot exports through ops/worktrees/slot-env SLOT -- COMMAND")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 4, 4, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress((b"\0" + bytes([40, 80, 230, 255]) * 4) * 4)) + chunk(b"IEND", b"")
    (output / "qa-sheet.png").write_bytes(png)
    generated = ROOT / "scripts/battle_entry_qa_generated"
    if generated.exists():
        raise RuntimeError("Diagnostic adapter directory already exists")
    project = ROOT / "project.godot"
    presets = ROOT / "export_presets.cfg"
    originals = {project: project.read_bytes(), presets: presets.read_bytes()}
    original_editor = None
    editor_settings = None
    generated.mkdir()
    try:
        for name in FIXTURES:
            source = (ROOT / f"tests/fixtures/{name}.gd").read_text()
            (generated / f"{name}.gd").write_text(rewrite_fixture_paths(source))
        for name in CHECKS:
            source = (ROOT / f"tests/{name}.gd").read_text()
            source = source.replace("extends SceneTree", "extends Node\nsignal completed(code: int)\n@onready var root: Window = get_tree().root\nfunc quit(code := 0) -> void:\n\tcompleted.emit.call_deferred(code)")
            source = source.replace("func _init()", "func _ready()")
            source = re.sub(r"(?<![\w.])(process_frame|physics_frame)\b", r"get_tree().\1", source)
            source = re.sub(r"(?<![\w.])create_timer\(", "get_tree().create_timer(", source)
            source = rewrite_fixture_paths(source)
            (generated / f"{name}.gd").write_text(source)
        paths = [f"res://scripts/battle_entry_qa_generated/{name}.gd" for name in CHECKS]
        runner = "extends Node\nfunc _ready() -> void:\n\tvar origin := str(JavaScriptBridge.eval(\"window.location.origin\", true)) if OS.has_feature(\"web\") else \"http://127.0.0.1:8091\"\n\tWebPokemonSpriteService._release_config_cache = {\"spriteStyles\": {\"animated\": {\"front\": origin + \"/qa-sprites/front\", \"back\": origin + \"/qa-sprites/back\"}}}\n\tWebHomeIconService._catalog = {\"normal\": {}, \"shiny\": {}}\n\t_run.call_deferred()\nfunc _run() -> void:\n\tvar results := {}\n"
        if coop_sprites:
            runner = runner.replace('"front": origin + "/qa-sprites/front", "back": origin + "/qa-sprites/back"',
                                    ', '.join(f'"{side}": origin + "/qa-sprites/{side}-0123456789ab"'
                                              for side in ["front", "back", "shiny_front", "shiny_back"]))
        runner += "\tfor path: String in " + repr(paths).replace("'", '"') + ":\n"
        runner += "\t\tvar check: Node = load(path).new()\n\t\tadd_child(check)\n\t\tvar code: int = await check.completed\n\t\tresults[path.get_file()] = code\n"
        if not mobile_collapse and not android_3d:
            runner += "\t\tcheck.queue_free()\n"
        runner += "\t\tawait get_tree().process_frame\n"
        runner += "\tvar report_file := FileAccess.open(\"user://battle-entry-qa-results.json\", FileAccess.WRITE)\n\treport_file.store_string(JSON.stringify(results))\n\tif OS.has_feature(\"web\"):\n\t\tJavaScriptBridge.eval(\"window.battleEntryQA = \" + JSON.stringify(results), true)\n\tprint(\"BATTLE_ENTRY_WEB_QA_COMPLETE \", JSON.stringify(results))\n"
        runner = runner.replace("battle-entry-qa-results.json", report_name)
        if mobile_collapse:
            runner = runner.replace("BATTLE_ENTRY_WEB_QA_COMPLETE", "MOBILE_COLLAPSE_QA_COMPLETE")
        if coop_sprites:
            runner = runner.replace("BATTLE_ENTRY_WEB_QA_COMPLETE", "COOP_SPRITE_QA_COMPLETE")
        if android_3d:
            runner = runner.replace("BATTLE_ENTRY_WEB_QA_COMPLETE", "ANDROID_3D_QA_COMPLETE")
        (generated / "runner.gd").write_text(runner)
        (generated / "runner.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/battle_entry_qa_generated/runner.gd" id="1"]\n[node name="BattleEntryQA" type="Node"]\nscript = ExtResource("1")\n')
        config = originals[project].decode()
        config = re.sub(r'^run/main_scene=.*$', 'run/main_scene="res://scripts/battle_entry_qa_generated/runner.tscn"', config, flags=re.M)
        if args.platform == "android":
            for service in ["android_music_pack_service", "android_apk_update_service"] + (["client_crash_report_service"] if mobile_collapse or coop_sprites or android_3d else []):
                wrapper = generated / (service + "_offline.gd")
                wrapper.write_text('extends "res://scripts/services/' + service + '.gd"\nfunc _ready() -> void:\n\tpass\n')
                if service == 'client_crash_report_service':
                    wrapper.write_text(wrapper.read_text() + 'func _enter_tree() -> void:\n\tpass\n')
                config = config.replace('res://scripts/services/' + service + '.gd', 'res://scripts/battle_entry_qa_generated/' + wrapper.name)
            if android_3d and not android_arenas:
                wrapper = generated / "pilot_model_service.gd"
                wrapper.write_text('extends "res://scripts/services/on_demand_3d_bundle_service.gd"\nvar completed_downloads: Array[Dictionary] = []\nfunc _selected_release() -> Dictionary:\n\treturn RELEASE_V11.data\nfunc _publish_verified_download(absolute: String, expected: int, digest: String) -> String:\n\tvar error := super._publish_verified_download(absolute, expected, digest)\n\tif error.is_empty():\n\t\tcompleted_downloads.append({"file": absolute.get_file(), "bytes": expected, "sha256": digest})\n\treturn error\n')
                config = config.replace('res://scripts/services/on_demand_3d_bundle_service.gd', 'res://scripts/battle_entry_qa_generated/' + wrapper.name)
                config = re.sub(r'^config/name=.*$', 'config/name="' + app_name + '"', config, flags=re.M)
            if coop_sprites:
                wrapper = generated / "mobile_asset_service_offline.gd"
                wrapper.write_text('extends "res://scripts/services/mobile_asset_service.gd"\nfunc release_prefix() -> String:\n\treturn "http://127.0.0.1:8091/"\n')
                config = config.replace('res://scripts/services/mobile_asset_service.gd', 'res://scripts/battle_entry_qa_generated/' + wrapper.name)
        if android_arenas:
            config = re.sub(r'^config/name=.*$', 'config/name="' + app_name + '"', config, flags=re.M)
            config = re.sub(r'^renderer/rendering_method.mobile=.*$', 'renderer/rendering_method.mobile="' + args.android_renderer + '"', config, flags=re.M)
        if args.emulator_frame_pacing_off:
            setting = "window/frame_pacing/android/enable_frame_pacing"
            if re.search(r"^" + re.escape(setting) + r"=.*$", config, re.M):
                config = re.sub(r"^" + re.escape(setting) + r"=.*$", setting + "=false", config, flags=re.M)
            else:
                config = config.replace("[display]", "[display]\n" + setting + "=false")
        project.write_text(config)
        preset = originals[presets].decode()
        source_index = 3 if args.platform == 'web' else 7
        start = preset.index(f'[preset.{source_index}]')
        end = preset.index(f'[preset.{source_index + 1}]', start)
        next_index = max(int(value) for value in re.findall(r'\[preset\.(\d+)\]', preset)) + 1
        selected = preset[start:end].replace(f'[preset.{source_index}', f'[preset.{next_index}')
        selected = re.sub(r'^name=.*$', 'name="' + title + '"', selected, flags=re.M)
        selected = re.sub(r'^html/custom_html_shell=.*$', 'html/custom_html_shell=""', selected, flags=re.M)
        if args.platform == "android":
            if args.sdk is None:
                raise ValueError("Android diagnostic requires --sdk")
            selected = selected.replace(f'[preset.{next_index}.options]', f'[preset.{next_index}.options]\ncustom_template/debug="{args.templates / 'android_debug.apk'}"\ncustom_template/release="{args.templates / 'android_release.apk'}"')
            selected = selected.replace('gradle_build/use_gradle_build=true', 'gradle_build/use_gradle_build=false')
            for architecture in ["armeabi-v7a", "arm64-v8a", "x86", "x86_64"]:
                selected = re.sub(r'^architectures/' + re.escape(architecture) + r'=.*$',
                                  'architectures/' + architecture + '=' + ('true' if architecture == args.architecture else 'false'),
                                  selected, flags=re.M)
            selected = selected.replace('package/unique_name="com.pokeaether.game"', 'package/unique_name="' + package + '"')
            selected = selected.replace('package/name="PokeAether"', 'package/name="' + app_name + '"')
            if android_3d:
                selected = re.sub(r'^custom_features=.*$', 'custom_features="android_v1,android_3d_pilot' + (',android_arena_pilot' if android_arenas else '') + '"', selected, flags=re.M)
                release_version = re.search(r'^config/version="([^"]+)"$', originals[project].decode(), re.M).group(1)
                selected = re.sub(r'^version/name=.*$', 'version/name="' + release_version + '-3d-pilot.1"', selected, flags=re.M)
            if mobile_collapse:
                selected = selected.replace('permissions/internet=true', 'permissions/internet=false')
                selected = selected.replace('permissions/access_network_state=true', 'permissions/access_network_state=false')
            editor_settings = Path(os.environ["XDG_CONFIG_HOME"]) / "godot/editor_settings-4.6.tres"
            editor_settings.parent.mkdir(parents=True, exist_ok=True)
            original_editor = editor_settings.read_bytes() if editor_settings.exists() else None
            editor_settings.write_text('[gd_resource type="EditorSettings" format=3]\n[resource]\nexport/android/android_sdk_path = "' + str(args.sdk.resolve()) + '"\nexport/android/java_sdk_path = "' + str(args.java.resolve()) + '"\n')
        presets.write_text(preset + "\n" + selected)
        with (output / "export.log").open("w") as log:
            if android_3d:
                subprocess.run(["godot", "--headless", "--path", str(ROOT),
                                "--script", paths[0], "--check-only"],
                               stdout=log, stderr=subprocess.STDOUT, check=True)
            command = ["godot", "--headless", "--log-file", str(output / "engine-export.log"), "--path", str(ROOT)]
            android_file = "coop-sprite-qa.apk" if coop_sprites else ("mobile-collapse-qa.apk" if mobile_collapse else "battle-entry-qa.apk")
            if android_3d:
                android_file = "android-arena-pilot.apk" if android_arenas else "android-3d-pilot.apk"
            command += ["--export-debug", title, str(output / ("index.html" if args.platform == "web" else android_file))]
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
        print(f"{title} {args.platform} diagnostic exported:", output)
    finally:
        for file, content in originals.items():
            file.write_bytes(content)
        shutil.rmtree(generated)
        if editor_settings is not None:
            if original_editor is None:
                editor_settings.unlink(missing_ok=True)
            else:
                editor_settings.write_bytes(original_editor)

if __name__ == "__main__":
    main()
