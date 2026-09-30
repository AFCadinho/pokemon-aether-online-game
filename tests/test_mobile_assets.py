from pathlib import Path
import hashlib
import json
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from build_web_on_demand import prepare_mobile_assets
from prepare_android_assets import prepare
from check_android_demand_export import verify


class MobileAssetsTests(unittest.TestCase):
    def test_manifest_reuses_home_and_cries_with_source_quality_theora(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'assets/video/login_background.ogv'
            source.parent.mkdir(parents=True)
            source.write_bytes(b'original-theora')
            output = root / 'output'
            files = {'home-icons/catalog.json': b'{}', 'home-icons/icon.png': b'png',
                     'browser-audio/assets/audio/sfx/pokemon_cries/PIKACHU.ogg': b'cry',
                     'browser-audio/assets/audio/sfx/pokemon_anime_cries/PIKACHU.ogg': b'unused'}
            for name, content in files.items():
                path = output / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
            prepare_mobile_assets(root, output)
            catalog = json.loads((output / 'mobile-assets/catalog.json').read_text())
            self.assertEqual((output / 'login-media/world.ogv').read_bytes(), source.read_bytes())
            self.assertNotIn(next(k for k in files if 'anime' in k), catalog)
            for name in ['home-icons/icon.png', 'login-media/world.ogv']:
                self.assertEqual(catalog[name]['sha256'], hashlib.sha256((output / name).read_bytes()).hexdigest())
                self.assertEqual(catalog[name]['size'], (output / name).stat().st_size)

    def test_android_cry_availability_is_independent_of_imported_resources(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            cry = root / 'assets/audio/sfx/pokemon_cries/PIKACHU.ogg'
            cry.parent.mkdir(parents=True)
            cry.write_bytes(b'cry')
            self.assertEqual(prepare(root), ['res://assets/audio/sfx/pokemon_cries/PIKACHU.ogg'])
            self.assertEqual(json.loads((root / 'generated/browser_audio_catalog.json').read_text()), prepare(root))

    def test_export_check_detects_native_import_leaks(self):
        required = ['generated/browser_audio_catalog.json', 'assets/ui/home_unknown.png.import',
                    'scenes/overworld/kanto/routes/kanto_route_5.tscn.remap']
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'assets/sprites/pokemon/pokemon_home/Pikachu.png.import'
            source.parent.mkdir(parents=True)
            source.write_text('path="res://.godot/imported/Pikachu.png-digest.ctex"')
            verify(root, required)
            with self.assertRaisesRegex(RuntimeError, 'leaked'):
                verify(root, required + ['.godot/imported/Pikachu.png-digest.ctex'])
            with self.assertRaisesRegex(RuntimeError, 'missing'):
                verify(root, required[1:])


if __name__ == '__main__':
    unittest.main()
