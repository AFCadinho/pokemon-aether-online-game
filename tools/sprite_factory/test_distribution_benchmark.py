import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from distribution_benchmark import _encode_record, _restore_trimmed, _trim_page


class DistributionBenchmarkTests(unittest.TestCase):
    def test_union_crop_round_trips_visible_pixels_and_keeps_timing_cells(self):
        image = Image.new("RGBA", (1024, 512), (231, 17, 99, 0))
        draw = ImageDraw.Draw(image)
        draw.rectangle((100, 120, 190, 300), fill=(255, 90, 12, 255))
        draw.rectangle((512 + 140, 100, 512 + 220, 280), fill=(10, 170, 240, 190))
        record = {"crop": [90, 90, 240, 310], "columns": 2, "count": 2}
        trimmed = _trim_page(image, record)
        self.assertEqual(trimmed.size, (300, 220))
        restored = _restore_trimmed(trimmed, record, image.size)
        self.assertEqual(restored.getchannel("A").tobytes(), image.getchannel("A").tobytes())
        self.assertEqual(restored.getpixel((120, 150)), image.getpixel((120, 150)))
        self.assertEqual(restored.getpixel((512 + 160, 140)), image.getpixel((512 + 160, 140)))

    def test_generated_lossless_candidates_preserve_composited_pixels(self):
        with tempfile.TemporaryDirectory() as scratch_text:
            scratch = Path(scratch_text)
            source = scratch / "source.png"
            image = Image.new("RGBA", (1024, 512), (44, 88, 122, 0))
            draw = ImageDraw.Draw(image)
            draw.ellipse((80, 70, 260, 320), fill=(220, 80, 120, 255))
            draw.ellipse((512 + 100, 90, 512 + 280, 340), fill=(60, 190, 230, 210))
            image.save(source)
            record = {
                "species": "fixture",
                "view": "front",
                "action": "idle",
                "page_index": 0,
                "source": str(source),
                "count": 2,
                "columns": 2,
                "crop": [64, 54, 300, 360],
            }
            result = _encode_record((record, str(scratch / "output")))
            for label in ("webp_lossless", "trimmed_png", "trimmed_webp_lossless"):
                self.assertEqual(result["quality"][label]["alpha_max_delta"], 0)
                for background in result["quality"][label]["backgrounds"].values():
                    self.assertEqual(background["max_delta"], 0)


if __name__ == "__main__":
    unittest.main()
