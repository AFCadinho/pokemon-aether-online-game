import copy
from io import BytesIO
from pathlib import Path
import tempfile
import unittest

from PIL import Image

from catalog_shiny_151_material_probe import za_colour


class ZaColourTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.row = {
            'shaders': [{'name': 'IkCharacter', 'values': {}}],
            'textures': {'BaseColorMap': 'body_alb.bntx', 'LayerMaskMap': 'body_lym.bntx'},
            'colors': {'UVScaleOffset': [2, 1, 0, 0],
                       'BaseColorLayer1': [1, 0, 0, 1],
                       'BaseColorLayer2': [0, 1, 0, 1],
                       'BaseColorLayer3': [0, 0, 1, 1],
                       'BaseColorLayer4': [1, 1, 1, 1]},
        }

    def test_rectangular_mask_is_mirrored_without_squashing_square_albedo(self):
        Image.new('RGBA', (4, 4), 'white').save(self.root / 'body_alb.png')
        mask = Image.new('RGBA', (2, 4), (255, 0, 0, 0))
        for y in range(4):
            mask.putpixel((1, y), (0, 255, 0, 0))
        mask.save(self.root / 'body_lym.png')
        baked = Image.open(BytesIO(za_colour(self.row, self.root)))
        self.assertEqual(baked.size, (4, 4))
        self.assertEqual([baked.getpixel((x, 1)) for x in range(4)],
                         [(255, 0, 0, 255), (0, 255, 0, 255),
                          (0, 255, 0, 255), (255, 0, 0, 255)])

    def test_small_constant_mask_preserves_body_detail_resolution(self):
        Image.new('RGBA', (4, 8), 'white').save(self.root / 'body_alb.png')
        Image.new('RGBA', (1, 1), (255, 0, 0, 0)).save(self.root / 'body_lym.png')
        baked = Image.open(BytesIO(za_colour(self.row, self.root)))
        self.assertEqual(baked.size, (8, 8))
        self.assertEqual(baked.getpixel((3, 4)), (255, 0, 0, 255))

    def test_eye_options_use_absolute_iris_colours_and_opaque_alpha(self):
        self.row['shaders'][0]['values']['EnableEyeOptions'] = 'True'
        Image.new('RGBA', (4, 4), (0, 0, 0, 0)).save(self.root / 'body_alb.png')
        Image.new('RGBA', (4, 4), (255, 0, 0, 0)).save(self.root / 'body_lym.png')
        before = copy.deepcopy(self.row)
        baked = Image.open(BytesIO(za_colour(self.row, self.root)))
        self.assertEqual(baked.getpixel((0, 0)), (255, 0, 0, 255))
        self.assertEqual(self.row, before)

    def test_unimplemented_uv_transform_is_held(self):
        self.row['colors']['UVScaleOffset'] = [4, 2, 0, 0]
        with self.assertRaisesRegex(ValueError, 'UV transform'):
            za_colour(self.row, self.root)


if __name__ == '__main__':
    unittest.main()
