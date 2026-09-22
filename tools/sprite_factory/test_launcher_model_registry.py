"""The standalone launcher export cannot reach outside its project root.

Its checked-in approval snapshot must exactly match the game; web exports may
exclude launcher/**, so the game intentionally keeps its own canonical copy.
"""
from pathlib import Path
import re
import fnmatch
import unittest


class LauncherRegistryTests(unittest.TestCase):
    def test_cosmetic_store_matches_game(self):
        root = Path(__file__).parents[2]
        self.assertEqual((root / 'launcher/scripts/content_pack_store.gd').read_bytes(),
                         (root / 'scripts/services/content_pack_store.gd').read_bytes())

    def test_desktop_exports_keep_battle_fallbacks(self):
        root = Path(__file__).parents[2]
        presets = (root / 'export_presets.cfg').read_text()
        for index in range(3):
            section = presets.split(f'[preset.{index}]', 1)[1].split(f'[preset.{index}.options]', 1)[0]
            exclusions = re.search(r'^exclude_filter="([^"]*)"$', section, re.M).group(1).split(',')
            for icon in ('Pikachu', 'Eevee'):
                path = f'assets/sprites/pokemon/pokemon_home/{icon}.png'
                self.assertFalse(any(fnmatch.fnmatchcase(path, x) for x in exclusions))
            for directory in ('front', 'back', 'shiny_front', 'shiny_back', 'gen5'):
                self.assertTrue(any(fnmatch.fnmatchcase(f'assets/sprites/pokemon/{directory}/probe.png', x)
                                    for x in exclusions))
        runtime = (root / 'scripts/services/content_pack_runtime.gd').read_text()
        self.assertIn('res://scripts/services/content_pack_store.gd', runtime)
        self.assertNotIn('res://launcher/', runtime)

    def test_approval_snapshot_matches_game(self):
        root = Path(__file__).parents[2]
        self.assertEqual((root / 'launcher/data/reviewed_model_catalog.json').read_bytes(),
                         (root / 'scripts/battle/battle_ui/reviewed_model_catalog.json').read_bytes())

    def test_manifest_validator_matches_game(self):
        root = Path(__file__).parents[2]
        launcher = (root / 'launcher/scripts/model_pack_manifest.gd').read_text()
        game = (root / 'scripts/battle/battle_ui/reviewed_model_catalog.gd').read_text()
        normalized = launcher.replace('../data/reviewed_model_catalog.json',
            'res://scripts/battle/battle_ui/reviewed_model_catalog.json').replace(
            '../data/screened_model_catalog.json',
            'res://scripts/battle/battle_ui/screened_model_catalog.json')
        self.assertEqual(normalized, game)

    def test_screened_snapshot_matches_game(self):
        root = Path(__file__).parents[2]
        self.assertEqual((root / 'launcher/data/screened_model_catalog.json').read_bytes(),
                         (root / 'scripts/battle/battle_ui/screened_model_catalog.json').read_bytes())
