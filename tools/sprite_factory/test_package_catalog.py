import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

from package_catalog import package_catalog, sha256


class PackageCatalogTests(unittest.TestCase):
    def test_packages_without_mutating_source_and_preserves_alpha(self):
        with tempfile.TemporaryDirectory() as scratch_text:
            scratch = Path(scratch_text)
            runtime = scratch / "source" / "runtime"
            runtime.mkdir(parents=True)
            page = runtime / "front" / "idle-000.png"
            page.parent.mkdir()
            image = Image.new("RGBA", (1024, 512), (240, 10, 120, 0))
            draw = ImageDraw.Draw(image)
            draw.ellipse((180, 120, 300, 360), fill=(230, 120, 20, 255))
            draw.ellipse((512 + 200, 130, 512 + 320, 370), fill=(30, 150, 240, 180))
            image.save(page)
            preview = runtime / "front" / "idle-preview.png"
            image.crop((0, 0, 512, 512)).save(preview)
            manifest = {
                "schema": 1, "species": "fixture", "variant": "normal", "cell_size": 512, "fps": 60,
                "views": {"front": {"idle": {"count": 2, "visual_bounds": [175, 115, 150, 260],
                    "pages": [{"file": "front/idle-000.png", "count": 2, "columns": 2, "sha256": sha256(page)}],
                    "preview_frame": {"file": "front/idle-preview.png", "sha256": sha256(preview)}}}},
            }
            manifest_path = runtime / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            original = manifest_path.read_bytes()
            catalog = scratch / "preview.json"
            catalog.write_text(json.dumps({"schema": 1, "mode": "preview", "entries": {
                "fixture:normal": {"path": str(manifest_path), "sha256": sha256(manifest_path)}}}))
            output = scratch / "packaged"
            result_path = package_catalog(catalog, output, workers=2)
            self.assertEqual(manifest_path.read_bytes(), original)
            result = json.loads(result_path.read_text())
            packaged_manifest = Path(result["entries"]["fixture:normal"]["path"])
            packaged = json.loads(packaged_manifest.read_text())
            idle = packaged["views"]["front"]["idle"]
            self.assertEqual(idle["stored_cell_rect"], [171, 111, 158, 268])
            self.assertTrue(idle["pages"][0]["file"].endswith(".webp"))
            self.assertEqual(packaged["fps"], 60)
            report = json.loads((output / "quality-report.json").read_text())
            self.assertGreater(report["entries"]["fixture:normal"]["minimum_rgb_psnr_db"], 40)


if __name__ == "__main__":
    unittest.main()
