"""Safety checks for explicit held-shiny recovery."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from catalog_shiny_production import replacements


class CatalogShinyProductionTest(unittest.TestCase):
    def test_review_queue_matches_names_and_recovers_distinct_eye_texture(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            normal_table = root / "materials.trmtr"
            rare_table = root / "materials_rare.trmtr"
            normal_table.touch()
            rare_table.touch()
            for name, data in {"base.png": b"same", "base_rare.png": b"same",
                               "eye.png": b"normal", "eye_rare.png": b"rare"}.items():
                (root / name).write_bytes(data)
            first = {"name": "body", "floats": {}, "shaders": [], "textures": {
                "BaseColorMap": "base.dds", "UpperEyelidColorMap": "eye.dds"}}
            first_rare = {**first, "textures": {
                "BaseColorMap": "base_rare.dds", "UpperEyelidColorMap": "eye_rare.dds"}}
            second = {"name": "shadow", "floats": {}, "shaders": [], "textures": {
                "BaseColorMap": "base.dds"}}
            with patch("catalog_shiny_production.inspect_materials",
                       side_effect=[[first, second], [second, first_rare]]):
                with self.assertRaises(ValueError):
                    replacements(normal_table)
            with patch("catalog_shiny_production.inspect_materials",
                       side_effect=[[first, second], [second, first_rare]]):
                pairs, digest = replacements(normal_table, review_queue=True)
            self.assertEqual([(Path(p["normal"]).name, Path(p["rare"]).name) for p in pairs],
                             [("eye.png", "eye_rare.png")])
            self.assertEqual(len(digest), 64)

    def test_review_queue_still_holds_shader_float_changes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            normal_table = root / "materials.trmtr"
            normal_table.touch()
            normal_table.with_name("materials_rare.trmtr").touch()
            normal = {"name": "body", "floats": {"RoughnessHighlight": 1.0},
                      "shaders": [], "textures": {"BaseColorMap": "base.dds"}}
            rare = {**normal, "floats": {"RoughnessHighlight": 2.0},
                    "textures": {"BaseColorMap": "rare.dds"}}
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                with self.assertRaisesRegex(ValueError, "settings differ"):
                    replacements(normal_table, review_queue=True)


if __name__ == "__main__":
    unittest.main()
