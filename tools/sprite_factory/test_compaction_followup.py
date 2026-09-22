import tempfile
import unittest
from pathlib import Path

from PIL import Image

from alpha_plane_benchmark import _zlib_delta
from dual_plane_video_benchmark import _codec_command
from variant_material_benchmark import _label_mask, _material_centers


class MaterialMaskTests(unittest.TestCase):
    def test_centers_group_adjacent_render_values(self):
        with tempfile.TemporaryDirectory() as scratch:
            paths = []
            for index in range(2):
                image = Image.new("RGBA", (8, 2), (0, 0, 0, 0))
                values = [50, 51, 50, 100, 101, 100, 150, 200]
                image.putdata([(value, value, value, 255) for value in values] * 2)
                path = Path(scratch) / f"{index}.png"
                image.save(path)
                paths.append(path)
            self.assertEqual(_material_centers(paths, 4), [50, 100, 150, 200])

    def test_label_mask_uses_zero_for_transparent_pixels(self):
        image = Image.new("RGBA", (3, 1))
        image.putdata([(50, 50, 50, 255), (149, 149, 149, 255), (200, 200, 200, 0)])
        self.assertEqual(list(_label_mask(image, [50, 100, 150, 200]).get_flattened_data()), [1, 3, 0])


class AlphaPlaneTests(unittest.TestCase):
    def test_zlib_delta_is_exact(self):
        frames = []
        for index in range(4):
            image = Image.new("RGBA", (8, 8), (20, 30, 40, 0))
            image.putalpha(Image.new("L", image.size, index * 40))
            frames.append(image)
        result = _zlib_delta(frames)
        self.assertTrue(result["exact"])
        self.assertGreater(result["bytes"], 0)

    def test_av1_quality_command_is_444(self):
        command = _codec_command("av1-444-crf4", Path("candidate.mkv"))
        self.assertIn("yuv444p", command)
        self.assertEqual(command[command.index("-crf") + 1], "4")


if __name__ == "__main__":
    unittest.main()
