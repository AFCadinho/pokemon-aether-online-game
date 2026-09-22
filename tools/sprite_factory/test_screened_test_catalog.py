import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import build_screened_test_catalog as catalog


class ScreenedCatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "frontend"
        self.root.mkdir()
        (self.root / "tools/sprite_factory").mkdir(parents=True)
        (self.root / "scripts/battle/battle_ui").mkdir(parents=True)
        self.scene = self.root.parent / ".tmp/sample.scn"
        self.scene.parent.mkdir()
        self.scene.write_bytes(b"screened fixture")
        self.sha = hashlib.sha256(self.scene.read_bytes()).hexdigest()
        self.review = self.root / "tools/sprite_factory/review.json"
        self.review.write_text(json.dumps({"entries": [
            {"species": "candidate", "classification": "visual_pass", "runtime_path": ".tmp/sample.scn", "runtime_sha256": self.sha},
            {"species": "held", "classification": "material_issue", "runtime_path": ".tmp/held.scn", "runtime_sha256": "x" * 64},
        ]}))
        self.registry = self.root / "scripts/battle/battle_ui/screened.json"
        self.registry.write_text(json.dumps({"schema": 1,
            "source_visual_review_sha256": hashlib.sha256(self.review.read_bytes()).hexdigest(),
            "models": {"candidate": {"sha256": self.sha}}, "profiles": {"candidate": {}}}))

    def build(self, name="catalog.json"):
        with patch.object(catalog, "ROOT", self.root), patch.object(catalog, "SCREENED", self.registry), patch.object(catalog, "REVIEW", self.review):
            return catalog.build(self.root / name, self.root)

    def test_emits_only_hash_bound_visual_passes(self):
        output = self.build()
        data = json.loads(output.read_text())
        self.assertEqual(data, [{"species": "candidate", "variant": "normal", "runtime_schema": 1,
                                 "runtime_path": str(self.scene.resolve()), "runtime_sha256": self.sha}])

    def test_rejects_stale_hash_missing_scene_and_overwrite(self):
        self.build()
        with self.assertRaisesRegex(ValueError, "already exists"):
            self.build()
        self.registry.write_text(json.dumps({"schema": 1, "source_visual_review_sha256": hashlib.sha256(self.review.read_bytes()).hexdigest(),
                                              "models": {"candidate": {"sha256": "a" * 64}}, "profiles": {}}))
        with self.assertRaisesRegex(ValueError, "identity/hash"):
            self.build("stale.json")
        self.registry.write_text(json.dumps({"schema": 1, "source_visual_review_sha256": hashlib.sha256(self.review.read_bytes()).hexdigest(),
                                              "models": {"candidate": {"sha256": self.sha}}, "profiles": {}}))
        self.scene.unlink()
        with self.assertRaisesRegex(ValueError, "missing or changed"):
            self.build("missing.json")


if __name__ == "__main__":
    unittest.main()
