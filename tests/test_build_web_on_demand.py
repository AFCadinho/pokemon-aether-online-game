from pathlib import Path
import hashlib
import json
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from build_web_on_demand import prepare_home_icons


class HomeAssetTests(unittest.TestCase):
    def test_catalog_keeps_exact_names_and_content_hashed_individual_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sprites = root / 'assets/sprites/pokemon'
            normal = sprites / 'pokemon_home'
            shiny = sprites / 'pokemon_home_shiny'
            normal.mkdir(parents=True)
            shiny.mkdir()
            (normal / 'Flabe-be.png').write_bytes(b'normal-image')
            (normal / 'Flabébé.png').write_bytes(b'normal-image')
            (normal / 'Flabe-be.png.import').write_text('not runtime content')
            (shiny / 'flabebe.png').write_bytes(b'shiny-image')
            output = root / 'output'
            size = prepare_home_icons(root, output)
            catalog = json.loads((output / 'home-icons/catalog.json').read_text())
            expected = 'home-icons/' + hashlib.sha256(b'normal-image').hexdigest() + '.png'
            self.assertEqual(catalog['normal']['Flabe-be'], expected)
            self.assertEqual(catalog['normal']['Flabébé'], expected)
            self.assertNotEqual(catalog['shiny']['flabebe'], expected)
            self.assertEqual(len(list((output / 'home-icons').glob('*.png'))), 2)
            self.assertEqual((output / expected).read_bytes(), b'normal-image')
            self.assertEqual(size, sum(p.stat().st_size for p in (output / 'home-icons').iterdir()))


if __name__ == '__main__':
    unittest.main()
