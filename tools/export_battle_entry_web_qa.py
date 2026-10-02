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
CHECKS = ["trainer_vision_physics_flush_check", "fullscreen_battle_fade_check", "battle_entry_slow_sprite_check", "wild_entry_before_response_check"]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--platform", choices=["web", "android"], default="web")
    parser.add_argument("--sdk", type=Path)
    parser.add_argument("--templates", type=Path, default=Path.home() / ".local/share/godot/export_templates/4.6.2.stable")
    parser.add_argument("--java", type=Path, default=Path("/usr/lib/jvm/java-26-openjdk"))
    args = parser.parse_args()
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
        shutil.copyfile(ROOT / "tests/fixtures/trainer_vision_probe.gd", generated / "trainer_vision_probe.gd")
        shutil.copyfile(ROOT / "tests/fixtures/wild_entry_request_probe.gd", generated / "wild_entry_request_probe.gd")
        for name in CHECKS:
            source = (ROOT / f"tests/{name}.gd").read_text()
            source = source.replace("extends SceneTree", "extends Node\nsignal completed(code: int)\n@onready var root = get_tree().root\nfunc quit(code := 0) -> void:\n\tcompleted.emit.call_deferred(code)")
            source = source.replace("func _init()", "func _ready()")
            source = re.sub(r"(?<![\w.])(process_frame|physics_frame)\b", r"get_tree().\1", source)
            source = re.sub(r"(?<![\w.])create_timer\(", "get_tree().create_timer(", source)
            source = source.replace("res://tests/fixtures/trainer_vision_probe.gd", "res://scripts/battle_entry_qa_generated/trainer_vision_probe.gd")
            source = source.replace("res://tests/fixtures/wild_entry_request_probe.gd", "res://scripts/battle_entry_qa_generated/wild_entry_request_probe.gd")
            (generated / f"{name}.gd").write_text(source)
        paths = [f"res://scripts/battle_entry_qa_generated/{name}.gd" for name in CHECKS]
        runner = "extends Node\nfunc _ready() -> void:\n\tvar origin := str(JavaScriptBridge.eval(\"window.location.origin\", true)) if OS.has_feature(\"web\") else \"http://127.0.0.1:8091\"\n\tWebPokemonSpriteService._release_config_cache = {\"spriteStyles\": {\"animated\": {\"front\": origin + \"/qa-sprites/front\", \"back\": origin + \"/qa-sprites/back\"}}}\n\tWebHomeIconService._catalog = {\"normal\": {}, \"shiny\": {}}\n\t_run.call_deferred()\nfunc _run() -> void:\n\tvar results := {}\n"
        runner += "\tfor path: String in " + repr(paths).replace("'", '"') + ":\n"
        runner += "\t\tvar check: Node = load(path).new()\n\t\tadd_child(check)\n\t\tvar code: int = await check.completed\n\t\tresults[path.get_file()] = code\n\t\tcheck.queue_free()\n\t\tawait get_tree().process_frame\n"
        runner += "\tvar report_file := FileAccess.open(\"user://battle-entry-qa-results.json\", FileAccess.WRITE)\n\treport_file.store_string(JSON.stringify(results))\n\tif OS.has_feature(\"web\"):\n\t\tJavaScriptBridge.eval(\"window.battleEntryQA = \" + JSON.stringify(results), true)\n\tprint(\"BATTLE_ENTRY_WEB_QA_COMPLETE \", JSON.stringify(results))\n"
        (generated / "runner.gd").write_text(runner)
        (generated / "runner.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://scripts/battle_entry_qa_generated/runner.gd" id="1"]\n[node name="BattleEntryQA" type="Node"]\nscript = ExtResource("1")\n')
        config = originals[project].decode()
        config = re.sub(r'^run/main_scene=.*$', 'run/main_scene="res://scripts/battle_entry_qa_generated/runner.tscn"', config, flags=re.M)
        if args.platform == "android":
            for service in ["android_music_pack_service", "android_apk_update_service"]:
                wrapper = generated / (service + "_offline.gd")
                wrapper.write_text('extends "res://scripts/services/' + service + '.gd"\nfunc _ready() -> void:\n\tpass\n')
                config = config.replace('res://scripts/services/' + service + '.gd', 'res://scripts/battle_entry_qa_generated/' + wrapper.name)
        project.write_text(config)
        preset = originals[presets].decode()
        source_index = 3 if args.platform == 'web' else 7
        start = preset.index(f'[preset.{source_index}]')
        end = preset.index(f'[preset.{source_index + 1}]', start)
        next_index = max(int(value) for value in re.findall(r'\[preset\.(\d+)\]', preset)) + 1
        selected = preset[start:end].replace(f'[preset.{source_index}', f'[preset.{next_index}')
        selected = re.sub(r'^name=.*$', 'name="Battle Entry QA"', selected, flags=re.M)
        selected = re.sub(r'^html/custom_html_shell=.*$', 'html/custom_html_shell=""', selected, flags=re.M)
        if args.platform == "android":
            if args.sdk is None:
                raise ValueError("Android diagnostic requires --sdk")
            selected = selected.replace(f'[preset.{next_index}.options]', f'[preset.{next_index}.options]\ncustom_template/debug="{args.templates / 'android_debug.apk'}"\ncustom_template/release="{args.templates / 'android_release.apk'}"')
            selected = selected.replace('gradle_build/use_gradle_build=true', 'gradle_build/use_gradle_build=false')
            selected = selected.replace('package/unique_name="com.pokeaether.game"', 'package/unique_name="com.pokeaether.battleentryqa"')
            selected = selected.replace('package/name="PokeAether"', 'package/name="PokeAether Entry QA"')
            editor_settings = Path(os.environ["XDG_CONFIG_HOME"]) / "godot/editor_settings-4.6.tres"
            editor_settings.parent.mkdir(parents=True, exist_ok=True)
            original_editor = editor_settings.read_bytes() if editor_settings.exists() else None
            editor_settings.write_text('[gd_resource type="EditorSettings" format=3]\n[resource]\nexport/android/android_sdk_path = "' + str(args.sdk.resolve()) + '"\nexport/android/java_sdk_path = "' + str(args.java.resolve()) + '"\n')
        presets.write_text(preset + "\n" + selected)
        with (output / "export.log").open("w") as log:
            command = ["godot", "--headless", "--path", str(ROOT)]
            command += ["--export-debug", "Battle Entry QA", str(output / ("index.html" if args.platform == "web" else "battle-entry-qa.apk"))]
            subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, check=True)
        print(f"Battle entry {args.platform} diagnostic exported:", output)
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
