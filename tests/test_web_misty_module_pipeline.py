import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from build_web_asset_modules import build_module, import_project


class MistyModulePipelineTests(unittest.TestCase):
    def test_lavender_town_is_registered_in_extended_browser_maps(self):
        map_id = "kanto_lavender_town"
        scope = json.loads((ROOT / "docs/browser-full-world-scope.json").read_text())
        catalog = json.loads((ROOT / "generated/world_access_catalog.json").read_text())
        path = catalog["areas"][map_id]["scenePath"]
        self.assertIn(map_id, scope["extendedMapIds"])
        self.assertTrue((ROOT / path.removeprefix("res://")).is_file())
        presets = (ROOT / "export_presets.cfg").read_text()
        module = presets.split("[preset.8]\n")[1].split("[preset.8.options]")[0]
        core = presets.split("[preset.3]\n")[1].split("[preset.3.options]")[0]
        self.assertIn(path, module)
        self.assertIn(path.removeprefix("res://"), core)
        self.assertIn(path, (ROOT / "scripts/services/web_asset_module_service.gd").read_text())

    def test_asset_import_finishes_before_module_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "modules"
            output.mkdir()
            with patch("build_web_asset_modules.run_export", return_value=0) as run_export:
                import_project("godot", output)
            command, console_log = run_export.call_args.args
            self.assertIn("--import", command)
            self.assertEqual(command[command.index("--path") + 1], str(ROOT))
            self.assertEqual(console_log.name, "asset-module-import-console.log")

    def build(self, files, forbidden=()):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            def export(command, log):
                Path(command[-1]).write_bytes(b"fixture pack with script references to other maps")
                return 0
            with patch("build_web_asset_modules.run_export", side_effect=export), patch(
                "build_web_asset_modules.subprocess.run", return_value=subprocess.CompletedProcess(
                    [], 0, "MODULE_FILES " + json.dumps(files), "")):
                return build_module("godot", output, "misty", "Web Misty Maps Trial",
                                    ["res://map.tscn"], (b"map.tscn",), forbidden)

    def test_actual_remapped_files_and_hash(self):
        result = self.build(["res://map.tscn.remap"], (b"outside.tscn",))
        self.assertEqual(result["sha256"], hashlib.sha256(
            b"fixture pack with script references to other maps").hexdigest())
        self.assertEqual(result["file"], "misty.pck")

    def test_outside_module_file_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "outside-module"):
            self.build(["res://map.tscn.remap", "res://outside.tscn.remap"], (b"outside.tscn",))

    def test_missing_map_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "misses required"):
            self.build([])

    def test_full_world_scope_covers_every_current_kanto_scene(self):
        scope = json.loads((ROOT / "docs/browser-full-world-scope.json").read_text())
        misty = json.loads((ROOT / "docs/browser-misty-scope.json").read_text())
        catalog = json.loads((ROOT / "generated/world_access_catalog.json").read_text())
        covered = set(scope["coreMapIds"]) | set(misty["additionalMapIds"]) | set(scope["extendedMapIds"])
        for map_id, area in catalog["areas"].items():
            if map_id.startswith("kanto_") and area["scenePath"]:
                self.assertIn(map_id, covered, map_id)
        self.assertFalse(set(scope["extendedMapIds"]) & set(misty["additionalMapIds"]))
        presets = (ROOT / "export_presets.cfg").read_text()
        module = presets.split("[preset.8]\n")[1].split("[preset.8.options]")[0]
        core = presets.split("[preset.3]\n")[1].split("[preset.3.options]")[0]
        loader = (ROOT / "scripts/services/web_asset_module_service.gd").read_text()
        for map_id in scope["extendedMapIds"]:
            path = catalog["areas"][map_id]["scenePath"]
            self.assertTrue((ROOT / path.removeprefix("res://")).is_file(), map_id)
            self.assertIn(path, module, map_id)
            self.assertIn(path, loader, map_id)
            self.assertIn(path.removeprefix("res://"), core, map_id)

    def test_scope_matches_module_selection_and_browser_loader(self):
        scope = json.loads((ROOT / "docs/browser-misty-scope.json").read_text())
        catalog = json.loads((ROOT / "generated/world_access_catalog.json").read_text())
        presets = (ROOT / "export_presets.cfg").read_text()
        core = presets.split("[preset.3]\n")[1].split("[preset.3.options]")[0]
        misty = presets.split("[preset.5]\n")[1].split("[preset.5.options]")[0]
        loader = (ROOT / "scripts/services/web_asset_module_service.gd").read_text()
        self.assertEqual(len(scope["additionalMapIds"]), 16)
        for map_id in scope["additionalMapIds"]:
            path = catalog["areas"][map_id]["scenePath"]
            self.assertIn(path, misty)
            self.assertIn(path, loader)
        for directory in scope["additionalVisualDirectories"]:
            self.assertIn("generated/tiled_visuals/" + directory + "/**", core)
