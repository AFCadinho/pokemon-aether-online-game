import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import prepare_cave_review


class CavePreparationTests(unittest.TestCase):
    def test_prepare_and_refresh_only_review_files(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory) / 'review'
            with patch('sys.argv', ['prepare', str(project)]):
                prepare_cave_review.main()
                prepare_cave_review.main()
            self.assertTrue((project / '.pokeaether-cave-review').is_file())
            self.assertTrue((project / 'tools/sprite_factory/cave_battle_review.gd').is_file())
            self.assertFalse((project / 'scenes/world/test_world.res').exists())
            self.assertNotIn('autoload', (project / 'project.godot').read_text())

    def test_reject_non_review_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'keep.txt'
            marker.write_text('preserve')
            with patch('sys.argv', ['prepare', directory]):
                with self.assertRaises(ValueError):
                    prepare_cave_review.main()
            self.assertEqual(marker.read_text(), 'preserve')

    def test_reject_frontend_checkout(self):
        source = Path(prepare_cave_review.__file__).resolve().parents[2]
        with patch('sys.argv', ['prepare', str(source)]):
            with self.assertRaises(ValueError):
                prepare_cave_review.main()


if __name__ == '__main__':
    unittest.main()
