import tempfile
import unittest
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

from distribution_benchmark import ACTIONS, _encode_record, _restore_trimmed, _trim_page, _write_review_catalog


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

    def test_review_catalog_reuses_trimmed_q95_pages_and_keeps_logical_crop(self):
        with tempfile.TemporaryDirectory() as scratch_text:
            scratch = Path(scratch_text)
            runtime = scratch / "source" / "runtime"
            runtime.mkdir(parents=True)
            views = {}
            for view in ("front", "back"):
                actions = {}
                for action in ACTIONS:
                    source_page = runtime / view / f"{action}-000.png"
                    source_page.parent.mkdir(parents=True, exist_ok=True)
                    Image.new("RGBA", (512, 512), (120, 80, 200, 255)).save(source_page)
                    candidate = scratch / "output" / "trimmed-webp-q95" / "fixture" / view / action / "000.webp"
                    candidate.parent.mkdir(parents=True, exist_ok=True)
                    Image.new("RGBA", (108, 208), (120, 80, 200, 255)).save(candidate, "WEBP", quality=95)
                    actions[action] = {
                        "pages": [{"file": f"{view}/{action}-000.png", "count": 1, "columns": 1, "sha256": "unused"}],
                        "count": 1,
                        "status": "needs_review",
                        "visual_bounds": [200, 150, 100, 200],
                    }
                preview = runtime / view / "idle-preview.png"
                Image.new("RGBA", (512, 512), (120, 80, 200, 255)).save(preview)
                actions["idle"]["preview_frame"] = {
                    "file": f"{view}/idle-preview.png",
                    "sha256": "unused",
                    "visual_bounds": [200, 150, 100, 200],
                }
                views[view] = actions
            manifest = {
                "schema": 1,
                "species": "fixture",
                "variant": "normal",
                "status": "needs_review",
                "cell_size": 512,
                "fps": 60,
                "views": views,
            }
            manifest_path = runtime / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            catalog = scratch / "catalog.json"
            catalog.write_text(json.dumps({"entries": {"fixture:normal": {"path": str(manifest_path)}}}))
            args = argparse.Namespace(catalog=catalog, output=scratch / "output", species=["fixture"], padding=4)
            result = _write_review_catalog(args)
            review_catalog = json.loads(result.read_text())
            review_manifest_path = Path(review_catalog["entries"]["fixture:normal"]["path"])
            review_manifest = json.loads(review_manifest_path.read_text())
            idle = review_manifest["views"]["front"]["idle"]
            self.assertEqual(idle["stored_cell_rect"], [196, 146, 108, 208])
            self.assertTrue(idle["pages"][0]["file"].endswith(".webp"))
            self.assertTrue((review_manifest_path.parent / idle["pages"][0]["file"]).is_file())
            self.assertTrue(idle["preview_frame"]["file"].endswith(".webp"))
            self.assertTrue(review_manifest["runtime_packaging"]["review_only"])


if __name__ == "__main__":
    unittest.main()
