"""Safety checks for explicit held-shiny recovery."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from catalog_shiny_production import replacements


class CatalogShinyProductionTest(unittest.TestCase):
    def test_colour_only_shiny_requires_explicit_supported_source_parameters(self):
        import copy
        from test_scvi_shared_material_identity import material_fixture
        from scvi_material_probe import inspect_materials
        with tempfile.TemporaryDirectory() as temp:
            table = Path(temp) / 'material.trmtr'
            rare_table = table.with_stem('material_rare')
            table.write_bytes(material_fixture((0.2, 0.4, 0.6, 1.0)))
            rare_table.write_bytes(material_fixture((0.8, 0.7, 0.2, 1.0)))
            with self.assertRaisesRegex(ValueError, 'settings differ'):
                replacements(table)
            pairs, _, floats, colors = replacements(table, review_queue=True,
                include_float_overrides=True, include_color_overrides=True)
            self.assertEqual(pairs, [])
            self.assertEqual(floats, [])
            self.assertEqual(len(colors), 1)
            self.assertEqual(colors[0]['key'], 'BaseColorLayer1')
            original, rare = inspect_materials(table), inspect_materials(rare_table)
            for change in ('alpha', 'nan', 'unknown'):
                altered = copy.deepcopy(rare)
                if change == 'alpha': altered[0]['colors']['BaseColorLayer1'][3] = 0.5
                if change == 'nan': altered[0]['colors']['BaseColorLayer1'][0] = float('nan')
                if change == 'unknown': altered[0]['colors']['UnboundColour'] = [1, 0, 0, 1]
                with patch('catalog_shiny_production.inspect_materials', side_effect=[original, altered]):
                    with self.assertRaises(ValueError):
                        replacements(table, review_queue=True, include_color_overrides=True)

    def test_emission_scalar_and_metallic_map_are_preserved_for_review(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); table = root / 'material.trmtr'
            table.touch(); table.with_stem('material_rare').touch()
            (root / 'metal.png').write_bytes(b'normal'); (root / 'rare.png').write_bytes(b'rare')
            normal = {'name': 'body', 'floats': {'EmissionIntensity': 0.2}, 'shaders': [],
                      'textures': {'MetallicMap': 'metal.bntx'}}
            rare = {**normal, 'floats': {'EmissionIntensity': 0.0}, 'textures': {'MetallicMap': 'rare.bntx'}}
            with patch('catalog_shiny_production.inspect_materials', side_effect=[[normal], [rare]]):
                with self.assertRaises(ValueError): replacements(table)
            with patch('catalog_shiny_production.inspect_materials', side_effect=[[normal], [rare]]):
                pairs, _, floats = replacements(table, review_queue=True, include_float_overrides=True)
            self.assertEqual(len(pairs), 1)
            self.assertEqual(floats[0]['key'], 'EmissionIntensity')
            self.assertEqual(floats[0]['mode'], 'apply')

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

    def test_review_queue_requires_official_layer_mask_pixels(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            table = root / "materials.trmtr"
            table.touch()
            table.with_name("materials_rare.trmtr").touch()
            for name, payload in {"base.png": b"normal", "rare.png": b"rare",
                                  "mask.png": b"opaque", "rare_mask.png": b"masked"}.items():
                (root / name).write_bytes(payload)
            normal = {"name": "body", "floats": {}, "shaders": [], "textures": {
                "BaseColorMap": "base.bntx", "LayerMaskMap": "mask.bntx"}}
            rare = {**normal, "textures": {
                "BaseColorMap": "rare.bntx", "LayerMaskMap": "rare_mask.bntx"}}
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                with self.assertRaisesRegex(ValueError, "non-albedo change"):
                    replacements(table)
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                pairs, _ = replacements(table, review_queue=True)
            self.assertEqual({Path(p["normal"]).name for p in pairs}, {"base.png", "mask.png"})
            (root / "rare_mask.png").unlink()
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                with self.assertRaisesRegex(ValueError, "PNG missing"):
                    replacements(table, review_queue=True)

    def test_official_eye_emission_float_is_explicitly_bound(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            table = root / "materials.trmtr"
            table.touch()
            table.with_name("materials_rare.trmtr").touch()
            (root / "base.png").write_bytes(b"normal")
            (root / "rare.png").write_bytes(b"rare")
            normal = {"name": "l_eye", "floats": {"EmissionIntensityLayer1": 0.2},
                      "shaders": [{"name": "Eye", "values": {}}],
                      "textures": {"BaseColorMap": "base.bntx"}}
            rare = {**normal, "floats": {"EmissionIntensityLayer1": 0.0},
                    "textures": {"BaseColorMap": "rare.bntx"}}
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                pairs, _, floats = replacements(table, review_queue=True,
                                                 include_float_overrides=True)
            self.assertEqual(len(pairs), 1)
            self.assertEqual(floats, [{"material": "l_eye", "key": "EmissionIntensityLayer1",
                                       "normal": 0.2, "rare": 0.0, "mode": "apply"}])
            changed = {**rare, "floats": {"EmissionIntensityLayer1": 0.0,
                                          "EmissionIntensityLayer5": 10.0}}
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [changed]]):
                with self.assertRaisesRegex(ValueError, "settings differ"):
                    replacements(table, review_queue=True, include_float_overrides=True)

    def test_unrepresented_eye_float_is_recorded_for_visual_review(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            table = root / "materials.trmtr"
            table.touch()
            table.with_name("materials_rare.trmtr").touch()
            (root / "base.png").write_bytes(b"normal")
            (root / "rare.png").write_bytes(b"rare")
            normal = {"name": "r_eye", "floats": {"EmissionIntensityLayer5": 1.0},
                      "shaders": [{"name": "Eye", "values": {}}],
                      "textures": {"BaseColorMap": "base.bntx"}}
            rare = {**normal, "floats": {"EmissionIntensityLayer5": 10.0},
                    "textures": {"BaseColorMap": "rare.bntx"}}
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                with self.assertRaisesRegex(ValueError, "settings differ"):
                    replacements(table, review_queue=True)
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                _, _, floats = replacements(table, review_queue=True,
                                             include_float_overrides=True)
            self.assertEqual(floats, [{"material": "r_eye", "key": "EmissionIntensityLayer5",
                                       "normal": 1.0, "rare": 10.0, "mode": "unrepresented"}])

    def test_official_eye_emission_layers_are_applied(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            table = root / "materials.trmtr"
            table.touch()
            table.with_name("materials_rare.trmtr").touch()
            (root / "base.png").write_bytes(b"normal")
            (root / "rare.png").write_bytes(b"rare")
            normal = {"name": "l_eye", "floats": {"EmissionIntensityLayer2": 0.2,
                                                     "EmissionIntensityLayer4": 0.0},
                      "shaders": [{"name": "Eye", "values": {}}],
                      "textures": {"BaseColorMap": "base.bntx"}}
            rare = {**normal, "floats": {"EmissionIntensityLayer2": 0.5,
                                         "EmissionIntensityLayer4": 0.2},
                    "textures": {"BaseColorMap": "rare.bntx"}}
            with patch("catalog_shiny_production.inspect_materials", side_effect=[[normal], [rare]]):
                _, _, floats = replacements(table, review_queue=True,
                                             include_float_overrides=True)
            self.assertEqual([x["mode"] for x in floats], ["apply", "apply"])


if __name__ == "__main__":
    unittest.main()
