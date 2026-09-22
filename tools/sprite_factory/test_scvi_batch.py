"""Focused safety checks for review-batch source selection."""

import argparse
import json
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

from PIL import Image, ImageDraw

from scvi_batch import (automatic_probe_warnings, compact_action_report,
                        evaluate_gates, load_batch, probe_image_metrics, record_probe_review,
                        preview_catalog, requested_import_categories, selected_entries, source_entry)


class ScviBatchTest(unittest.TestCase):
    def test_pilot_batch_contains_25_unique_candidates(self):
        entries = load_batch(Path(__file__).with_name("pilot_batch_25.json"))
        self.assertEqual(len(entries), 25)
        self.assertEqual(len({item["species"] for item in entries}), 25)

    def test_batch_composition_is_explicit_and_duplicate_safe(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "base.json").write_text(json.dumps({
                "entries": [{"species": "eevee", "pm": 133}]}))
            composed = root / "pilot.json"
            composed.write_text(json.dumps({
                "include": ["base.json"],
                "entries": [{"species": "dragonite", "pm": 149}]}))
            self.assertEqual([item["species"] for item in load_batch(composed)],
                             ["eevee", "dragonite"])
            composed.write_text(json.dumps({
                "include": ["base.json"],
                "entries": [{"species": "eevee", "pm": 133}]}))
            with self.assertRaisesRegex(ValueError, "Duplicate species"):
                load_batch(composed)

    def test_explicit_subset_rejects_unknown_species(self):
        entries = [{"species": "eevee"}, {"species": "dragonite"}]
        self.assertEqual(selected_entries(entries, "dragonite"), [entries[1]])
        with self.assertRaisesRegex(ValueError, "outside the explicit batch"):
            selected_entries(entries, "missingno")

    def test_action_scoped_diagnostic_import_is_explicit_and_bounded(self):
        args = argparse.Namespace(categories=("idle", "physical_attack", "physical_attack_2"))
        self.assertEqual(requested_import_categories(args), args.categories)
        with self.assertRaisesRegex(ValueError, "Unknown requested"):
            requested_import_categories(argparse.Namespace(categories=("idle", "bite")))
        with self.assertRaisesRegex(ValueError, "Duplicate requested"):
            requested_import_categories(argparse.Namespace(categories=("idle", "idle")))

    def test_probe_metrics_warn_without_claiming_artistic_approval(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "dark.png"
            image = Image.new("RGBA", (512, 512))
            ImageDraw.Draw(image).rectangle((0, 100, 20, 120), fill=(5, 5, 5, 255))
            image.save(path)
            metrics = probe_image_metrics(path)
            warnings = automatic_probe_warnings({"front": metrics})
            self.assertIn("front:clipping_risk", warnings)
            self.assertIn("front:suspiciously_dark", warnings)
            self.assertIn("front:very_small_silhouette", warnings)

    def test_full_render_gate_requires_explicit_human_probe_decision(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            batch = root / "batch.json"
            batch.write_text(json.dumps({"entries": [{"species": "eevee"}]}))
            (root / "intake.json").write_text(batch.read_text())
            (root / "intake-status-normal.json").write_text(json.dumps({
                "entries": {"eevee": {"status": "configured_needs_review",
                                        "facial_warnings": ["inherited_eyelid_pose:idle:left"]}}}))
            probe = root / "probes" / "normal"
            probe.mkdir(parents=True)
            (probe / "status.json").write_text(json.dumps({"entries": {
                "eevee": {"status": "needs_review", "qc_errors": [],
                          "automatic_warnings": ["front:suspiciously_dark"]}}}))
            args = argparse.Namespace(output=root, variant="normal", only=None,
                                      species="eevee", reviewer="Ada", note="visual probe checked",
                                      decision="approved_for_full_render")
            report = evaluate_gates(args)
            self.assertEqual(report["entries"]["eevee"]["status"],
                             "awaiting_human_probe_review")
            record_probe_review(args)
            report = evaluate_gates(args)
            self.assertEqual(report["entries"]["eevee"]["status"],
                             "eligible_for_full_render")
            self.assertEqual(report["entries"]["eevee"]["automatic_warnings"],
                             ["front:suspiciously_dark", "inherited_eyelid_pose:idle:left"])

    def test_compact_action_report_preserves_review_metadata(self):
        result = compact_action_report({
            "idle": {
                "action": "pm0001_00_00_20001_battlewait01_loop",
                "frames": list(range(91)),
                "source_fps": 60,
                "loop": True,
                "speed": 1.0,
                "review": "needs_review",
            },
            "sleep": None,
        })
        self.assertEqual(result["idle"], {
            "source_action": "pm0001_00_00_20001_battlewait01_loop",
            "frame_count": 91,
            "source_fps": 60,
            "loop": True,
            "speed": 1.0,
            "review": "needs_review",
        })
        self.assertNotIn("sleep", result)

    def test_preview_catalog_ignores_incomplete_stale_build(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            batch = root / "batch.json"
            batch.write_text(json.dumps({"entries": [{"species": "eevee"}]}))
            complete = root / "complete"
            complete.mkdir()
            manifest = {"actions": {}, "cameras": {}, "presentation": {}}
            (complete / "provenance.json").write_text(json.dumps({
                "identity": {"manifest": manifest}}))
            (complete / "qc.json").write_text(json.dumps({
                "errors": [], "warnings": []}))
            incomplete = root / "incomplete"
            incomplete.mkdir()
            (root / "build-status-normal-full.json").write_text(json.dumps({
                "entries": {"eevee": {"status": "needs_review", "qc_errors": [],
                                        "build": str(complete)}}}))
            (root / "build-status-shiny-full.json").write_text(json.dumps({
                "entries": {"eevee": {"status": "needs_review", "qc_errors": [],
                                        "build": str(incomplete)}}}))
            args = argparse.Namespace(output=root, batch=batch)
            with patch("scvi_batch.subprocess.run") as run:
                preview_catalog(args)
            catalog_args = run.call_args_list[0].args[0]
            self.assertIn(str(complete), catalog_args)
            self.assertNotIn(str(incomplete), catalog_args)

    def test_explicit_identity_and_review_candidates(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            identity = "pm0149_00_00"
            model = root / "models" / "pm0149" / identity
            motion = root / "motions" / "pm0149" / identity
            model.mkdir(parents=True)
            motion.mkdir(parents=True)
            (model / (identity + ".trmdl")).touch()
            (model / (identity + "_00_big.png")).touch()
            (model / (identity + "_rare.trmtr")).touch()
            (model / (identity + "_body_rare_alb.png")).touch()
            for suffix in ("00001_battlewait01_loop", "20001_battlewait01_loop",
                           "20000_defaultwait01_loop", "20400_attack01",
                           "00400_attack01", "20500_damage01", "20010_defaultidle01",
                           "28000_eye01"):
                (motion / (identity + "_" + suffix + ".tranm")).touch()
            (motion / (identity + "_20001_battlewait01_loop.tracm")).touch()
            result = source_entry({"species": "dragonite", "pm": 149,
                                   "target_game_height_px": 180,
                                   "facial_baseline_motion": "20010_defaultidle01"},
                                  root / "models", root / "motions")
            self.assertEqual(result["identity"], identity)
            self.assertTrue(result["motions"]["idle"].endswith("20001_battlewait01_loop.tranm"))
            self.assertTrue(result["motions"]["physical_attack"].endswith("20400_attack01.tranm"))
            self.assertTrue(result["motion_channels"]["idle"].endswith(
                "20001_battlewait01_loop.tracm"))
            self.assertTrue(result["facial_baseline"].endswith("20010_defaultidle01.tranm"))
            self.assertIsNone(result["motions"]["sleep"])
            self.assertIn("missing_action:sleep", result["warnings"])
            self.assertNotIn("missing_official_rare_albedo", result["warnings"])
            result = source_entry({"species": "dragonite", "pm": 149,
                                   "target_game_height_px": 180,
                                   "motion_overrides": {"idle": "28000_eye01"}},
                                  root / "models", root / "motions")
            self.assertTrue(result["motions"]["idle"].endswith("28000_eye01.tranm"))
            (motion / (identity + "_20001_battlewait01_loop.tranm")).unlink()
            result = source_entry({"species": "dragonite", "pm": 149,
                                   "target_game_height_px": 180},
                                  root / "models", root / "motions")
            self.assertTrue(result["motions"]["idle"].endswith("00001_battlewait01_loop.tranm"))
            with self.assertRaisesRegex(ValueError, "motion override missing"):
                source_entry({"species": "dragonite", "pm": 149,
                              "motion_overrides": {"idle": "99999_nonexistent"}},
                             root / "models", root / "motions")
            with self.assertRaisesRegex(ValueError, "facial baseline motion missing"):
                source_entry({"species": "dragonite", "pm": 149,
                              "facial_baseline_motion": "99999_nonexistent"},
                             root / "models", root / "motions")

    def test_shiny_requires_material_and_texture(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            model = root / "models" / "pm0025" / "pm0025_00_00"
            model.mkdir(parents=True)
            (model / "pm0025_00_00.trmdl").touch()
            (model / "pm0025_00_00_body_rare_alb.png").touch()
            result = source_entry({"species": "pikachu", "pm": 25,
                                   "target_game_height_px": 75},
                                  root / "models", root / "motions")
            self.assertIn("missing_official_rare_albedo", result["warnings"])
            self.assertIn("missing_all_motions", result["warnings"])


if __name__ == "__main__":
    unittest.main()
