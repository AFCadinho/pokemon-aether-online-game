import json
import tempfile
import unittest
from pathlib import Path

from physical_attack_review import build, build_gallery, classify_report, infer_family, motion_group


class PhysicalAttackReviewTests(unittest.TestCase):
    def test_conservative_region_classification(self):
        result = infer_family({"jaw": 9, "body": 1}, 0.9)
        self.assertEqual(result["family"], "bite")
        self.assertFalse(result["review_required"])
        result = infer_family({"arm": 9, "body": 1}, 0.9)
        self.assertEqual(result["family"], "unclear")
        self.assertIn("claw_from_punch", result["reason"])
        self.assertTrue(result["review_required"])

    def test_mixed_or_poorly_named_motion_is_queued(self):
        self.assertTrue(infer_family({"tail": 4, "body": 3.5}, 0.9)["review_required"])
        self.assertTrue(infer_family({"tail": 9, "unknown": 1}, 0.2)["review_required"])

    def test_motion_groups_are_broader_than_semantic_labels(self):
        self.assertEqual(motion_group({"arm": 7, "leg": 1, "body": 1}, 0.8),
                         "forelimb-led")
        self.assertEqual(motion_group({"arm": 4, "leg": 3.8, "body": 1}, 0.8), "mixed")
        self.assertEqual(motion_group({"tail": 9}, 0.2), "unknown")

    def test_equal_clear_families_are_still_reviewed(self):
        report = {"motion_analysis": {
            "physical_attack": {"region_scores": {"jaw": 9, "body": 1}, "named_coverage": 0.9},
            "physical_attack_2": {"region_scores": {"jaw": 8, "body": 1}, "named_coverage": 0.9},
        }}
        result = classify_report(report)
        self.assertEqual(result["queue"], "needs_human_review")
        self.assertIn("same_family_suggestion", result["queue_reasons"])

    def test_gallery_defaults_to_human_queue_and_exports_unapproved_template(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            classification = {"queue": "needs_human_review", "queue_reasons": ["alternate_uncertain"],
                              "clips": {name: {"family": "unclear", "confidence": 0,
                                                "reason": "mixed_motion_regions", "review_required": True}
                                        for name in ("physical_attack", "physical_attack_2")}}
            catalog = {"entries": [{"species": "garchomp", "status": "review_ready",
                                     "classification": classification,
                                     "loops": {"physical_attack": "one.webp",
                                               "physical_attack_2": "two.webp"}}]}
            build_gallery(root, catalog)
            page = (root / "index.html").read_text()
            self.assertIn("idle → attack → idle", page)
            self.assertIn("onlyQueue", page)
            self.assertIn("Bewegingsgroep", page)
            self.assertIn("review-decisions.json", page)
            self.assertNotIn("fetch(template)", page)
            self.assertIn("structuredClone(seed)", page)
            template = json.loads((root / "review-decisions.template.json").read_text())
            self.assertFalse(template["runtime_approved"])
            self.assertEqual(template["entries"]["garchomp"]["status"],
                             "pending_human_confirmation")

    def test_existing_output_requires_explicit_resume(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            inventory = root / "inventory.json"
            inventory.write_text(json.dumps({"entries": [{"species": "fixture",
                                                            "review_route": "identity_blocked",
                                                            "identity_error": "held"}]}))
            output = root / "review"
            output.mkdir()
            with self.assertRaisesRegex(ValueError, "must not already exist"):
                build(inventory, root / "prepared", output, None)
            catalog = build(inventory, root / "prepared", output, None, resume=True)
            self.assertEqual(catalog["entries"][0]["status"], "blocked")


if __name__ == "__main__":
    unittest.main()
