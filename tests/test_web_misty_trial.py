from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from build_web_misty_trial import validate_pack_files


class MistyTrialTests(unittest.TestCase):
    def setUp(self):
        self.scope = {"additionalMapIds": ["cerulean"], "newBlockedTransitionIds": ["route5"]}
        self.catalog = {"areas": {"cerulean": {"scenePath": "res://cerulean.tscn"},
                                  "route5": {"scenePath": "res://route5.tscn"}},
                        "transitions": {"route5": {"destination": {"mapId": "route5"}}}}

    def test_exported_remaps_are_accepted(self):
        validate_pack_files(["res://cerulean.tscn.remap"], self.scope, self.catalog)

    def test_missing_map_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Missing planned map"):
            validate_pack_files([], self.scope, self.catalog)

    def test_boundary_map_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Outside-demo"):
            validate_pack_files(["res://cerulean.tscn.remap", "res://route5.tscn.remap"], self.scope, self.catalog)

    def test_aether_clash_stays_separate(self):
        with self.assertRaisesRegex(ValueError, "Aether Clash"):
            validate_pack_files(["res://cerulean.tscn.remap", "res://scenes/overworld/aether_clash/aether_clash_duel.tscn.remap"], self.scope, self.catalog)

    def test_other_unplanned_area_is_rejected(self):
        self.catalog["areas"]["outside"] = {"scenePath": "res://outside.tscn"}
        with self.assertRaisesRegex(ValueError, "Unplanned map"):
            validate_pack_files(["res://cerulean.tscn.remap", "res://outside.tscn.remap"], self.scope, self.catalog)


if __name__ == "__main__":
    unittest.main()
