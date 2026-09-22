import json
import tempfile
import unittest
from pathlib import Path

from storage_components_report import summarize


class ComponentAccountingTest(unittest.TestCase):
    def test_shared_data_counted_once_and_no_runtime_claim(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            components = {}
            for name, size in [("shared", 100), ("normal", 20), ("shiny", 30)]:
                (root / (name + ".res")).write_bytes(bytes(size))
                components[name] = {"bytes": size, "kind": "Resource"}
            entries = [
                {"identity": "fixture", "species": "fixture", "components": ["shared", "normal"],
                 "old_bytes": 200, "source_sha256": "n"},
                {"identity": "fixture@shiny", "species": "fixture", "components": ["shared", "shiny"],
                 "old_bytes": 220, "source_sha256": "s"},
            ]
            (root / "prototype.json").write_text(json.dumps({"components": components, "entries": entries}))
            result = summarize(root)
            self.assertEqual(result["normal_only_bytes"], 120)
            self.assertEqual(result["both_appearances_bytes"], 150)
            self.assertEqual(result["pairs"][0]["incremental_shiny_bytes"], 30)
            self.assertEqual(result["pairs"][0]["shared_bytes"], 100)
            self.assertFalse(result["production_approved"])
            self.assertIn("Not run", result["runtime_measurements"])
            self.assertEqual(result["new_package_bytes"], 150 + result["manifest_bytes"])
            (root / "orphan.res").write_bytes(b"x")
            with self.assertRaisesRegex(AssertionError, "Unreferenced"):
                summarize(root)


if __name__ == "__main__":
    unittest.main()
