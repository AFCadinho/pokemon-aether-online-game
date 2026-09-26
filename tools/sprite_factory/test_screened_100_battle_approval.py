import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
FACTORY = ROOT / "tools/sprite_factory"


class Screened100BattleApprovalTests(unittest.TestCase):
    def test_exact_pairs_and_holds_are_separated(self):
        approval_path = FACTORY / "screened_100_battle_approval.json"
        qualification_path = FACTORY / "screened_100_battle_qualification.json"
        production = json.loads((FACTORY / "screened_100_shiny_production_results.json").read_text())
        approval = json.loads(approval_path.read_text())
        qualification = json.loads(qualification_path.read_text())
        reviewed_path = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
        screened_path = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
        reviewed = json.loads(reviewed_path.read_text())
        screened = json.loads(screened_path.read_text())
        self.assertEqual(reviewed_path.read_bytes(), (ROOT / "launcher/data/reviewed_model_catalog.json").read_bytes())
        self.assertEqual(screened_path.read_bytes(), (ROOT / "launcher/data/screened_model_catalog.json").read_bytes())
        digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
        self.assertEqual(approval["qualification_sha256"], digest(qualification_path))
        self.assertEqual(reviewed["screened_100_battle_approval_sha256"], digest(approval_path))
        self.assertEqual((qualification["qualified"], qualification["held"]), (55, 6))
        self.assertEqual((len(reviewed["models"]), len(reviewed["profiles"])), (152, 76))
        self.assertEqual((len(screened["models"]), len(screened["profiles"])), (20, 20))
        candidates = {row["species"]: row for row in production["entries"] if row["status"] == "technical_candidate"}
        accepted = {row["species"] for row in qualification["entries"] if row["status"] == "battle_qualified"}
        self.assertEqual(set(approval["approved_species"]), accepted)
        for name in accepted:
            row = candidates[name]
            self.assertEqual(reviewed["models"][name]["sha256"], row["normal_scn_sha256"])
            self.assertEqual(reviewed["models"][name + "@shiny"]["sha256"], row["shiny_scn_sha256"])
            self.assertEqual(reviewed["profiles"][name]["motion"]["sha256"], row["normal_scn_sha256"])
            self.assertEqual(reviewed["profiles"][name]["grounding"]["sha256"], row["normal_scn_sha256"])
            self.assertNotIn(name, screened["models"])
        for name in set(candidates) - accepted:
            self.assertIn(name, screened["models"])
            self.assertNotIn(name + "@shiny", reviewed["models"])
        for row in production["entries"]:
            if row["status"] == "held":
                self.assertIn(row["species"], screened["models"])
                self.assertNotIn(row["species"] + "@shiny", reviewed["models"])


if __name__ == "__main__":
    unittest.main()
