"""A smaller Mega cohort must not bypass complete, matching pair approval."""
import json
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from catalog_mega_battle_stage import stage
from catalog_mega_battle_calibrate import calibrate
from catalog_mega_battle_page import page
from catalog_mega_battle_qualification import qualify
from catalog_mega_3d_production import sha
import catalog_mega_catalog_admission as admission


class CohortGateTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.batch = self.root / "status.json"
        self.approval = self.root / "approval.json"
        self.control = self.root / "missing-control.json"
        self.output = self.root / "output"
        self.batch.write_text(json.dumps({"entries": [{"showdown_id": "dianciemega"}]}))
        self.accepted = {"appearance_approved": True, "entries": [
            {"species": "dianciemega", "appearance_approved": True}]}

    def reject_stage(self, count=None):
        self.approval.write_text(json.dumps(self.accepted))
        with self.assertRaises(ValueError):
            if count is None:
                stage(self.batch, self.approval, self.control, self.output)
            else:
                stage(self.batch, self.approval, self.control, self.output, count)
        self.assertFalse(self.output.exists())

    def test_default_71_pair_gate_stays_strict(self):
        self.reject_stage()

    def test_declared_count_cannot_admit_partial_batch(self):
        self.reject_stage(24)

    def test_wrong_species_approval_and_duplicates_rejected(self):
        self.accepted["entries"][0]["species"] = "greninjamega"
        self.reject_stage(1)
        self.accepted["entries"][0]["species"] = "dianciemega"
        self.accepted["entries"] *= 2
        self.reject_stage(1)

    def test_unapproved_pair_cannot_enter_battle_staging(self):
        self.accepted["entries"][0]["appearance_approved"] = False
        self.batch.write_text(json.dumps({"entries": [
            {"showdown_id": "dianciemega", "status": "runtime_candidate"}]}))
        self.reject_stage(1)

    def test_measurement_count_requires_actual_normal_shiny_pairs(self):
        rows = [{"species": "dianciemega", "clips": {}},
                {"species": "greninjamega", "clips": {}}]
        with self.assertRaises(ValueError):
            calibrate({"complete": True, "entries": rows}, 1)
        with self.assertRaises(ValueError):
            calibrate({"complete": True, "entries": rows})

    def test_capture_count_cannot_replace_missing_shiny(self):
        report = self.root / "report.json"
        report.write_text(json.dumps({"complete": True, "entries": [
            {"species": "dianciemega", "shots": []},
            {"species": "greninjamega", "shots": []}]}))
        with self.assertRaises(ValueError):
            page(report, self.control, self.output, 1)
        self.assertFalse(self.output.exists())

    def test_small_cohort_keeps_native_clock_floor_and_hud_gates(self):
        catalog = self.root / "catalog.json"
        report = self.root / "native.json"
        names = ["dianciemega", "dianciemega-shiny"]
        catalog.write_text(json.dumps({"entries": [{"species": n} for n in names]}))
        rows = [{"species": n, "clips": {"idle": {"duration": 1 / 120}},
                 "corrected_clearance_120hz": {"idle": {
                     "samples": 2, "minimum_y_samples": [.025, .025], "minimum_y": .025}},
                 "shots": [{"action": "idle", "arena_camera": "classic", "side": 0,
                            "in_view": True, "model_overlaps_hud_proxy": False}]}
                for n in names]
        data = {"complete": True, "catalog_sha256": sha(catalog), "entries": rows}
        report.write_text(json.dumps(data))
        result = qualify(report, catalog, 1)
        self.assertEqual(result["technical_variant_count"], 2)
        self.assertFalse(result["runtime_approved"])
        rows[0]["corrected_clearance_120hz"]["idle"].update(
            minimum_y=.023, minimum_y_samples=[.023, .025])
        rows[1]["corrected_clearance_120hz"]["idle"]["samples"] = 1
        rows[1]["shots"][0]["model_overlaps_hud_proxy"] = True
        report.write_text(json.dumps(data))
        result = qualify(report, catalog, 1)
        self.assertEqual(result["technical_variant_count"], 0)
        self.assertIn("floor clearance", " ".join(result["held"][names[0]]))
        self.assertIn("incomplete 120 Hz", " ".join(result["held"][names[1]]))
        self.assertIn("overlaps HUD", " ".join(result["held"][names[1]]))


class ClearanceAcceptanceTests(unittest.TestCase):
    def test_actual_hud_requires_both_arenas_and_no_cross_overlap(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            catalog, report, script = [root / name for name in ('catalog.json', 'hud.json', 'check.gd')]
            catalog.write_text('[]')
            script.write_text('fixture')
            expected = {'example': {}, 'example@shiny': {}}
            rows = [{'species': 'example', 'arena': arena, 'own_overlap': False,
                     'enemy_overlap': False, 'cross_overlap': False, 'hud_overlap': False}
                    for arena in ('classic', 'stadium')]
            def approval(entries):
                report.write_text(json.dumps({'complete': True, 'catalog_sha256': sha(catalog), 'entries': entries}))
                return {'actual_hud_review': {'report': str(report), 'report_sha256': sha(report),
                                             'script': str(script), 'script_sha256': sha(script)}}
            admission.validate_actual_hud(approval(rows), expected, catalog)
            for invalid in (rows[:1], [rows[0], rows[0]],
                            [dict(rows[0], cross_overlap=True), rows[1]]):
                with self.assertRaises(AssertionError):
                    admission.validate_actual_hud(approval(invalid), expected, catalog)

    def test_art_acceptance_cannot_authorize_arbitrary_motion_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original_path, final_path = root / "original.json", root / "final.json"
            original = {"readability": {"example": 1}, "motion": {"example": {
                "scale": 1, "lift": .025, "sha256": "same-model",
                "clips": {"physical_attack": {"times": [0, 1], "offsets": [0, 0]},
                          "idle": {"times": [0, 1], "offsets": [0, 0]}}}}}
            original_path.write_text(json.dumps(original))
            approval = {"technical_placement_followup": {
                "original_profiles": str(original_path), "original_profiles_sha256": sha(original_path)},
                "battle_visual_review": {"placement_candidates_sha256": sha(original_path)},
                "floor_followups": {"example": {}}}
            final = copy.deepcopy(original)
            final["motion"]["example"]["clips"]["physical_attack"]["offsets"] = [.03, .03]
            with patch.object(admission, "PROFILES", final_path):
                final_path.write_text(json.dumps(final))
                admission.validate_clearance_followup(approval)
                for offsets in ([.06, .06], [-.01, -.01], [.01, .02]):
                    with self.subTest(offsets=offsets):
                        invalid = copy.deepcopy(final)
                        invalid["motion"]["example"]["clips"]["physical_attack"]["offsets"] = offsets
                        final_path.write_text(json.dumps(invalid))
                        with self.assertRaises(AssertionError):
                            admission.validate_clearance_followup(approval)
                for changed in ("scale", "idle"):
                    with self.subTest(changed=changed):
                        invalid = copy.deepcopy(final)
                        if changed == "scale":
                            invalid["motion"]["example"]["scale"] = 1.2
                        else:
                            invalid["motion"]["example"]["clips"]["idle"]["offsets"] = [.03, .03]
                        final_path.write_text(json.dumps(invalid))
                        with self.assertRaises(AssertionError):
                            admission.validate_clearance_followup(approval)


if __name__ == "__main__":
    unittest.main()
