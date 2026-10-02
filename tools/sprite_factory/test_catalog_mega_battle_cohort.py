"""A smaller Mega cohort must not bypass complete, matching pair approval."""
import json
from pathlib import Path
import tempfile
import unittest

from catalog_mega_battle_stage import stage
from catalog_mega_battle_calibrate import calibrate
from catalog_mega_battle_page import page
from catalog_mega_battle_qualification import qualify
from catalog_mega_3d_production import sha


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


if __name__ == "__main__":
    unittest.main()
