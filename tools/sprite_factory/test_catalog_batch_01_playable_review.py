import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class PlayableReviewRegistrationTests(unittest.TestCase):
    def test_all_paired_candidates_are_pinned_without_release_approval(self):
        qualification_path = ROOT / "tools/sprite_factory/catalog_production_batch_01_shiny_qualification.json"
        qualification = json.loads(qualification_path.read_text())
        game = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
        launcher = ROOT / "launcher/data/screened_model_catalog.json"
        self.assertEqual(game.read_bytes(), launcher.read_bytes())
        registry = json.loads(game.read_text())
        species = {row["species"] for row in qualification["entries"]}
        self.assertEqual(set(registry["catalog_batch_01_pairs"]), species)
        self.assertEqual(registry["catalog_batch_01_qualification_sha256"],
                         hashlib.sha256(qualification_path.read_bytes()).hexdigest())
        self.assertFalse(qualification["release_approved"])
        self.assertEqual(len(registry["models"]), 75 + 28)
        self.assertEqual(len(registry["profiles"]), 75 + 14)
        for row in qualification["entries"]:
            name = row["species"]
            normal = registry["models"][name]
            shiny = registry["models"][name + "@shiny"]
            self.assertEqual(normal["sha256"], row["normal_scn_sha256"])
            self.assertEqual(shiny["sha256"], row["shiny_scn_sha256"])
            self.assertEqual(shiny["glb_sha256"], row["shiny_glb_sha256"])
            self.assertEqual(normal["profile"], name)
            self.assertEqual(shiny["profile"], name)
            self.assertIn("motion", registry["profiles"][name])
            self.assertIn("grounding", registry["profiles"][name])
        for row in qualification["material_holds"]:
            self.assertNotIn(row["species"] + "@shiny", registry["models"])


if __name__ == "__main__":
    unittest.main()
