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
    canonical = CANONICAL
    moves = MOVES
    effect = 'solar_beam_charge'
    source_directory = 'charge'
    filename = 'PRAS- Electric.png'

    def test_catalogues_share_preloaded_terrain(self):
        moves = json.loads((ROOT / 'data/battle_move_animations.json').read_text())['moves']
        effects = json.loads((ROOT / 'data/battle_effect_animations.json').read_text())['effects']
        for move in self.moves:
            self.assertEqual(moves[move]['sheet_path'], self.canonical, move)
        self.assertEqual(effects[self.effect]['sheet_path'], self.canonical)
        self.assertIn('path="' + self.canonical + '"', (ROOT / 'scenes/battle/battle.tscn').read_text())
        self.assertIn('preload(BATTLE_SCENE_PATH)', (ROOT / 'scripts/world/world.gd').read_text())

    def test_source_bytes_are_identical(self):
        source = ROOT / 'assets/battles/animations' / self.source_directory / self.filename
        canonical = ROOT / self.canonical.removeprefix('res://')
        self.assertEqual(hashlib.sha256(source.read_bytes()).digest(),
                         hashlib.sha256(canonical.read_bytes()).digest())

    def test_import_parameters_are_identical(self):
        source = ROOT / 'assets/battles/animations' / self.source_directory / self.filename
        canonical = ROOT / self.canonical.removeprefix('res://')
        paths = [Path(str(source) + '.import'), Path(str(canonical) + '.import')]
        self.assertEqual(paths[0].read_text().split('[params]', 1)[1],
                         paths[1].read_text().split('[params]', 1)[1])

class SharedGrassTextureTests(SharedElectricTextureTests):
    canonical = 'res://assets/battles/animations/grassyterrain/PRAS- Grass.png'
    moves = ('grassyterrain', 'vinewhip', 'leafage', 'razorleaf', 'growth')
    effect = 'grassy_terrain_start'
    source_directory = 'common/grassyterrain'
    filename = 'PRAS- Grass.png'


if __name__ == '__main__':
    unittest.main()
