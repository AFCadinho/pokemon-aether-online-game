import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from catalog_compaction_benchmark import animated_webp_benchmark, delta_zlib_benchmark, exact_period


class CatalogCompactionBenchmarkTests(unittest.TestCase):
    def test_exact_period_only_accepts_pixel_identical_cycles(self):
        self.assertEqual(exact_period(["a", "b", "a", "b"]), 2)
        self.assertIsNone(exact_period(["a", "b", "a", "c"]))

    def test_delta_candidate_round_trips_current_pixels(self):
        frames = []
        for offset in range(4):
            image = Image.new("RGBA", (32, 32))
            ImageDraw.Draw(image).ellipse((offset, 5, 18 + offset, 25), fill=(220, 90, 40, 210))
            frames.append(image)
        result = delta_zlib_benchmark(frames)
        self.assertTrue(result["exact_to_current_q95"])
        self.assertEqual(result["steady_vram_bytes"], 32 * 32 * 4)

    def test_lossless_animated_webp_round_trips_alpha_and_color(self):
        frames = [Image.new("RGBA", (24, 20), (10 + index, 80, 200, 100 + index)) for index in range(3)]
        with tempfile.TemporaryDirectory() as scratch:
            result = animated_webp_benchmark(frames, Path(scratch) / "test.webp", True)
        self.assertTrue(result["alpha_exact"])
        self.assertEqual(result["minimum_visible_psnr_db"], 99.0)


if __name__ == "__main__":
    unittest.main()
