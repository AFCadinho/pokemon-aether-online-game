import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from PIL import Image
from phase5_review_gallery import build


class GalleryTests(unittest.TestCase):
    def test_material_loop_is_animated_and_explicitly_unapproved(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            model = root / 'review' / 'sample'
            model.mkdir(parents=True)
            frames = []
            for index, colour in enumerate(('red', 'blue')):
                filename = f'ambient-{index}.png'
                Image.new('RGB', (8, 8), colour).save(model / filename)
                frames.append({'image': filename})
            report = model / 'report.json'
            report.write_text(json.dumps({
                'review_bounds': [[0, 0, 0], [1, 1, 1]],
                'ambient_frames': frames,
                'ambient_material_probe': {'duration_seconds': 2},
            }))
            (root / 'catalog.json').write_text(json.dumps({
                'material_probe': True,
                'entries': [{'species': 'sample', 'report': str(report)}],
            }))
            build(root)
            with Image.open(model / 'ambient.webp') as animation:
                self.assertEqual(animation.n_frames, 2)
                self.assertEqual(animation.info['loop'], 0)
            page = (root / 'index.html').read_text()
            self.assertIn('Skeleton frozen', page)
            self.assertIn('not runtime approved', page)
            self.assertIn('review/sample/ambient.webp', page)


if __name__ == '__main__':
    unittest.main()
