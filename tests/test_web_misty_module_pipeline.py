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
from build_web_asset_modules import build_module


class MistyModulePipelineTests(unittest.TestCase):
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
