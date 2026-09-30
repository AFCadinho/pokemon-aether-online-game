import tempfile
import unittest
from pathlib import Path
from PIL import Image
from catalog_remaining_eye_highlight import repair_mask


class AuthoredHighlightTest(unittest.TestCase):
    def test_rejects_rgb_layer_mask_before_reading_model(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mask = Image.new('RGB', (2, 2), 'black')
            mask.putpixel((1, 1), (255, 0, 0))
            mask.save(root / 'mask.png')
            with self.assertRaisesRegex(ValueError, 'achromatic highlight'):
                repair_mask(root / 'absent.glb', root / 'mask.png', root / 'out.glb')
            self.assertFalse((root / 'out.glb').exists())

    def test_rejects_full_white_mask_that_would_hide_the_pupil(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            Image.new('RGB', (2, 2), 'white').save(root / 'mask.png')
            with self.assertRaisesRegex(ValueError, 'achromatic highlight'):
                repair_mask(root / 'absent.glb', root / 'mask.png', root / 'out.glb')


if __name__ == '__main__':
    unittest.main()
