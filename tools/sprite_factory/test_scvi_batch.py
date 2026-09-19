"""Focused safety checks for review-batch source selection."""

import tempfile
import unittest
from pathlib import Path

from scvi_batch import compact_action_report, source_entry


class ScviBatchTest(unittest.TestCase):
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
                           "00400_attack01", "20500_damage01", "20010_defaultidle01"):
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
