"""The standalone launcher export cannot reach outside its project root.

Its checked-in approval snapshot must exactly match the game; web exports may
exclude launcher/**, so the game intentionally keeps its own canonical copy.
"""
from pathlib import Path
import unittest


class LauncherRegistryTests(unittest.TestCase):
    def test_approval_snapshot_matches_game(self):
        root = Path(__file__).parents[2]
        self.assertEqual((root / 'launcher/data/reviewed_model_catalog.json').read_bytes(),
                         (root / 'scripts/battle/battle_ui/reviewed_model_catalog.json').read_bytes())

    def test_manifest_validator_matches_game(self):
        root = Path(__file__).parents[2]
        launcher = (root / 'launcher/scripts/model_pack_manifest.gd').read_text()
        game = (root / 'scripts/battle/battle_ui/reviewed_model_catalog.gd').read_text()
        self.assertEqual(launcher.replace('../data/reviewed_model_catalog.json',
            'res://scripts/battle/battle_ui/reviewed_model_catalog.json'), game)
