import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from catalog_animation_review_page import build, POSES


class ReviewPageTest(unittest.TestCase):
    def capture(self, root, digest, errors=None):
        directory = root / digest
        directory.mkdir()
        rows = [{'species': 'wurmple', 'runtime_sha256': digest,
                 'errors': errors or [], 'captures': [
                     {'action': action, 'image': 'wurmple-' + action + '.png'}
                     for action, _ in POSES if action != 'physical_attack_2']}]
        (directory / 'review.json').write_text(json.dumps(
            {'capture_profile': 'quick_pair', 'entries': rows}))
        return directory

    def test_stale_images_cannot_satisfy_current_scene(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            old = self.capture(root, 'old')
            with self.assertRaisesRegex(ValueError, 'Missing exact scene captures'):
                build([{'species': 'wurmple', 'runtime_sha256': 'new'}],
                      [old], root / 'page')

    def test_matching_scene_with_render_errors_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            capture = self.capture(root, 'new', ['missing texture'])
            with self.assertRaisesRegex(ValueError, 'failed matching capture'):
                build([{'species': 'wurmple', 'runtime_sha256': 'new'}],
                      [capture], root / 'page')

    def test_missing_shiny_and_second_attack_are_shown_explicitly(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            capture = self.capture(root, 'new')
            with patch('catalog_animation_review_page.thumbnail'):
                receipt = build([{'species': 'wurmple', 'runtime_sha256': 'new'}],
                                [capture], root / 'page')
            page = (root / 'page/index.html').read_text()
            self.assertEqual(receipt['shiny_pair_count'], 0)
            self.assertFalse(receipt['runtime_approved'])
            self.assertIn('Nog in onderzoek', page)
            self.assertIn('Geen aparte tweede aanval', page)


if __name__ == '__main__':
    unittest.main()
