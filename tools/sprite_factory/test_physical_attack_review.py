import json
import tempfile
import unittest
import hashlib
from pathlib import Path

from physical_attack_review import build, build_gallery, classify_report, infer_family, motion_group
from physical_attack_semantic_review import compile_human_review, compile_review


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

    def test_semantic_review_binds_labels_to_exact_non_runtime_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            review = root / "review" / "garchomp"
            review.mkdir(parents=True)
            (review / "review.json").write_text("{}")
            (review / "physical_attack_2.webp").write_bytes(b"lossless-loop")
            (review / "job.json").write_text(json.dumps({
                "prepared_sha256": "a" * 64,
                "actions": {"physical_attack_2": "pm0445_attack02"},
            }))
            catalog = root / "catalog.json"
            catalog.write_text(json.dumps({
                "scope": "review_only_not_runtime_mapping",
                "entries": [{
                    "species": "garchomp",
                    "status": "review_ready",
                    "report": "review/garchomp/review.json",
                    "loops": {"physical_attack_2": "physical_attack_2.webp"},
                }],
            }))
            decisions = root / "decisions.json"
            decisions.write_text(json.dumps({
                "scope": "visual_review_candidates_not_runtime_mapping",
                "runtime_approved": False,
                "entries": {"garchomp": {
                    "family": "bite", "status": "reviewed_candidate", "note": "Jaw-led."
                }},
            }))
            result = compile_review(decisions, catalog)
            entry = result["entries"]["garchomp"]
            self.assertFalse(result["runtime_approved"])
            self.assertEqual(entry["source_action"], "pm0445_attack02")
            self.assertEqual(entry["review_loop_sha256"],
                             hashlib.sha256(b"lossless-loop").hexdigest())

    def test_semantic_review_rejects_unclear_candidate_status(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            review = root / "review" / "fixture"
            review.mkdir(parents=True)
            (review / "review.json").write_text("{}")
            (review / "physical_attack_2.webp").write_bytes(b"loop")
            (review / "job.json").write_text(json.dumps({
                "actions": {"physical_attack_2": "fixture_attack02"}
            }))
            catalog = root / "catalog.json"
            catalog.write_text(json.dumps({"entries": [{
                "species": "fixture", "status": "review_ready",
                "report": "review/fixture/review.json",
                "loops": {"physical_attack_2": "physical_attack_2.webp"},
            }]}))
            decisions = root / "decisions.json"
            decisions.write_text(json.dumps({
                "scope": "review_only", "runtime_approved": False,
                "entries": {"fixture": {
                    "family": "unclear", "status": "reviewed_candidate", "note": "bad"
                }},
            }))
            with self.assertRaisesRegex(ValueError, "invariant"):
                compile_review(decisions, catalog)

    def test_confirmed_human_review_binds_both_clips(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            review = root / "review" / "fixture"
            review.mkdir(parents=True)
            (review / "review.json").write_text("{}")
            (review / "physical_attack.webp").write_bytes(b"primary")
            (review / "physical_attack_2.webp").write_bytes(b"alternate")
            (review / "job.json").write_text(json.dumps({
                "prepared_sha256": "b" * 64,
                "actions": {"physical_attack": "attack01",
                            "physical_attack_2": "attack02"},
            }))
            catalog = root / "catalog.json"
            catalog.write_text(json.dumps({
                "scope": "review_only_not_runtime_mapping",
                "entries": [{
                    "species": "fixture", "status": "review_ready",
                    "report": "review/fixture/review.json",
                    "loops": {"physical_attack": "physical_attack.webp",
                              "physical_attack_2": "physical_attack_2.webp"},
                }],
            }))
            exported = root / "review-decisions.json"
            exported.write_text(json.dumps({
                "runtime_approved": False,
                "entries": {"fixture": {
                    "status": "confirmed", "note": "reviewed",
                    "clips": {
                        "physical_attack": {"family": "claw_slash", "confirmed": True},
                        "physical_attack_2": {"family": "body_charge", "confirmed": True},
                    },
                }},
            }))
            result = compile_human_review(exported, catalog, {"fixture"})
            entry = result["entries"]["fixture"]
            self.assertFalse(result["runtime_approved"])
            self.assertEqual(entry["clips"]["physical_attack"]["source_action"], "attack01")
            self.assertEqual(entry["clips"]["physical_attack_2"]["family"], "body_charge")

    def test_human_review_rejects_unconfirmed_selection(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            exported = root / "review-decisions.json"
            exported.write_text(json.dumps({
                "runtime_approved": False,
                "entries": {"fixture": {"status": "pending_human_confirmation"}},
            }))
            catalog = root / "catalog.json"
            catalog.write_text(json.dumps({"entries": [{
                "species": "fixture", "status": "review_ready"
            }]}))
            with self.assertRaisesRegex(ValueError, "not confirmed"):
                compile_human_review(exported, catalog, {"fixture"})


if __name__ == "__main__":
    unittest.main()
