"""Lossless canonical sheet contract, without changing animation preparation."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = 'res://assets/battles/animations/electricterrain/PRAS- Electric.png'
MOVES = ('thunderbolt', 'voltswitch', 'thunderwave', 'electricterrain',
         'gigavolthavoc', 'stokedsparksurfer', 'thundershock', 'charge', 'spark')


class SharedElectricTextureTests(unittest.TestCase):
    def test_catalogues_share_preloaded_terrain(self):
        moves = json.loads((ROOT / 'data/battle_move_animations.json').read_text())['moves']
        effects = json.loads((ROOT / 'data/battle_effect_animations.json').read_text())['effects']
        for move in MOVES:
            self.assertEqual(moves[move]['sheet_path'], CANONICAL, move)
        self.assertEqual(effects['solar_beam_charge']['sheet_path'], CANONICAL)
        self.assertIn('path="' + CANONICAL + '"', (ROOT / 'scenes/battle/battle.tscn').read_text())
        self.assertIn('preload(BATTLE_SCENE_PATH)', (ROOT / 'scripts/world/world.gd').read_text())

    def test_source_bytes_are_identical(self):
        source = ROOT / 'assets/battles/animations/charge/PRAS- Electric.png'
        canonical = ROOT / CANONICAL.removeprefix('res://')
        self.assertEqual(hashlib.sha256(source.read_bytes()).digest(),
                         hashlib.sha256(canonical.read_bytes()).digest())

    def test_import_parameters_are_identical(self):
        paths = [ROOT / 'assets/battles/animations' / directory / 'PRAS- Electric.png.import'
                 for directory in ('charge', 'electricterrain')]
        self.assertEqual(paths[0].read_text().split('[params]', 1)[1],
                         paths[1].read_text().split('[params]', 1)[1])


if __name__ == '__main__':
    unittest.main()
