import unittest
from PIL import Image
from catalog_animation_palette_variants import recolour


class PaletteTests(unittest.TestCase):
    def test_preserves_alpha_and_unmatched_colours(self):
        image = Image.new('RGBA', (3, 1))
        image.putdata([(160, 50, 60, 0), (160, 50, 60, 127), (255, 255, 255, 255)])
        result = recolour(image, [{'from': [160, 50, 60], 'to': [100, 60, 150], 'tolerance': 20}])
        self.assertEqual(list(result.get_flattened_data()), [(100, 60, 150, 0), (100, 60, 150, 127), (255, 255, 255, 255)])

    def test_rejects_unbounded_or_zero_anchors(self):
        image = Image.new('RGBA', (1, 1))
        for rule in [{'from': [0, 0, 0], 'to': [10, 10, 10], 'tolerance': 10},
                     {'from': [10, 10, 10], 'to': [300, 10, 10], 'tolerance': 10},
                     {'from': [10, 10, 10], 'to': [10, 20, 10], 'tolerance': 200}]:
            with self.assertRaises(ValueError):
                recolour(image, [rule])


if __name__ == '__main__':
    unittest.main()
