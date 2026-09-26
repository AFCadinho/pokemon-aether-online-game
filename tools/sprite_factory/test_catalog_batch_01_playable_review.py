import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class PlayableReviewRegistrationTests(unittest.TestCase):
    def test_all_visually_approved_pairs_are_pinned(self):
        qualification_path = ROOT / "tools/sprite_factory/catalog_production_batch_01_shiny_qualification.json"
        qualification = json.loads(qualification_path.read_text())
        game = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
        launcher = ROOT / "launcher/data/reviewed_model_catalog.json"
        self.assertEqual(game.read_bytes(), launcher.read_bytes())
        registry = json.loads(game.read_text())
        species = {row["species"] for row in qualification["entries"]}
        approval_path = ROOT / "tools/sprite_factory/catalog_production_batch_01_approval.json"
        approval = json.loads(approval_path.read_text())
        self.assertEqual(set(approval["approved_species"]), species)
        self.assertEqual(approval["qualification_sha256"], hashlib.sha256(qualification_path.read_bytes()).hexdigest())
        self.assertEqual(registry["catalog_batch_01_approval_sha256"], hashlib.sha256(approval_path.read_bytes()).hexdigest())
        self.assertEqual(len(registry["models"]), 14 + 28 + 110 + 12)
        self.assertEqual(len(registry["profiles"]), 7 + 14 + 55 + 6)
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
        screened = json.loads((ROOT / "scripts/battle/battle_ui/screened_model_catalog.json").read_text())
        self.assertEqual(len(screened["models"]), 14)
        self.assertTrue(screened["normal_only"])


if __name__ == "__main__":
    unittest.main()
