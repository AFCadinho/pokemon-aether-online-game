import hashlib
import json
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
FACTORY = ROOT / "tools/sprite_factory"


class Batch03HoldRecoveryApprovalTests(unittest.TestCase):
    def test_all_previous_holds_have_pinned_normal_and_shiny_models(self):
        previous = json.loads((FACTORY / "catalog_production_batch_03_approval.json").read_text())
        approval_path = FACTORY / "catalog_production_batch_03_hold_recovery_approval.json"
        approval = json.loads(approval_path.read_text())
        game_path = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
        launcher_path = ROOT / "launcher/data/reviewed_model_catalog.json"
        self.assertEqual(game_path.read_bytes(), launcher_path.read_bytes())
        registry = json.loads(game_path.read_text())
        expected = set(previous["held_source_species"]) | set(previous["held_shiny_species"])
        self.assertEqual(set(approval["approved_species"]), expected)
        self.assertEqual(len(expected), 25)
        self.assertFalse(approval["published"])
        self.assertEqual(
            registry["catalog_batch_03_hold_recovery_approval_sha256"],
            hashlib.sha256(approval_path.read_bytes()).hexdigest(),
        )
        for name in expected:
            normal = registry["models"][name]
            shiny = registry["models"][name + "@shiny"]
            self.assertEqual(normal["profile"], name)
            self.assertEqual(shiny["profile"], name)
            profile = registry["profiles"][name]
            self.assertEqual(profile["grounding"]["sha256"], normal["sha256"])
            self.assertEqual(profile["motion"]["sha256"], normal["sha256"])
            self.assertTrue(profile["action_timing"])


if __name__ == "__main__":
    unittest.main()
