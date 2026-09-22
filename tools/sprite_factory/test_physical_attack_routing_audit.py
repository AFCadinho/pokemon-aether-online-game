import json
import tempfile
import unittest
from pathlib import Path

from physical_attack_routing_audit import build_audit, family_actions, load_move_intents


class PhysicalAttackRoutingAuditTests(unittest.TestCase):
    def test_primary_wins_when_both_clips_share_family(self):
        clips = {
            "physical_attack": {"family": "body_charge"},
            "physical_attack_2": {"family": "body_charge"},
        }
        self.assertEqual(family_actions(clips), {"body_charge": "physical_attack"})

    def test_distinct_alternate_family_is_routable(self):
        clips = {
            "physical_attack": {"family": "bite"},
            "physical_attack_2": {"family": "claw_slash"},
        }
        self.assertEqual(family_actions(clips), {
            "bite": "physical_attack", "claw_slash": "physical_attack_2"
        })

    def test_duplicate_or_nonphysical_move_intent_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "intents.json"
            path.write_text(json.dumps({"schema": 1, "families": {
                "bite": ["bite"], "claw_slash": ["bite"]
            }}))
            with self.assertRaisesRegex(ValueError, "duplicate"):
                load_move_intents(path, {"bite": {"category": "physical"}})
            path.write_text(json.dumps({"schema": 1, "families": {"bite": ["ember"]}}))
            with self.assertRaisesRegex(ValueError, "not physical"):
                load_move_intents(path, {"ember": {"category": "special"}})

    def test_audit_counts_exact_and_safe_fallback_routes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            human = root / "human.json"
            intents = root / "intents.json"
            moves = root / "moves.json"
            human.write_text(json.dumps({
                "runtime_approved": False,
                "entries": {
                    "garchomp": {"status": "confirmed", "clips": {
                        "physical_attack": {"family": "bite"},
                        "physical_attack_2": {"family": "claw_slash"},
                    }},
                    "ditto": {"status": "confirmed", "clips": {
                        "physical_attack": {"family": "body_charge"},
                        "physical_attack_2": {"family": "body_charge"},
                    }},
                },
            }))
            intents.write_text(json.dumps({"schema": 1, "families": {
                "bite": ["bite"], "claw_slash": ["slash"]
            }}))
            moves.write_text(json.dumps({
                "bite": {"category": "physical"},
                "slash": {"category": "physical"},
                "earthquake": {"category": "physical"},
            }))
            result = build_audit(human, intents, moves)
            self.assertFalse(result["runtime_approved"])
            self.assertEqual(result["counts"]["exact_family_pairs"], 2)
            self.assertEqual(result["counts"]["alternate_exact_pairs"], 1)
            self.assertEqual(result["counts"]["classified_fallback_pairs"], 2)
            self.assertEqual(result["counts"]["unclassified_fallback_pairs"], 2)


if __name__ == "__main__":
    unittest.main()
