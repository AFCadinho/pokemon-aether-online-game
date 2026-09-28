import tempfile
import unittest
import zipfile
from pathlib import Path

from catalog_remaining_intake import source_members
from catalog_remaining_normal_export import REQUIRED, choose_actions
from phase5_review_actions import candidates


class SourceMembersTest(unittest.TestCase):
    def test_default_form_wins_over_alternate_form_and_unsuffixed_file(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "Gen1.zip"
            with zipfile.ZipFile(archive, "w") as zipped:
                for name in ("pm0003_81.blend", "pm0003.blend", "pm0003_00.blend"):
                    zipped.writestr(name, b"blend")
            self.assertEqual(source_members(archive, 1)[3].filename, "pm0003_00.blend")

    def test_later_generations_use_developer_number_table(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "Gen8.zip"
            with zipfile.ZipFile(archive, "w") as zipped:
                zipped.writestr("_pokemon_dev_numbers.csv", "#,Dev #,Name\n810,948,Grookey\n")
                zipped.writestr("pm0948.blend", b"blend")
            self.assertEqual(source_members(archive, 8)[810].filename, "pm0948.blend")

    def test_export_chooses_one_complete_bank_and_matching_second_attack(self):
        report = {"unambiguous_actions": {}, "action_candidates_by_bank": {
            "0": {key: [f"pm0007_00_00_0_{key}.gfbanm"] for key in REQUIRED},
            "1": {key: [] for key in REQUIRED}},
            "second_physical_candidates": ["pm0007_00_00_00410_attack02.gfbanm",
                                           "pm0007_00_00_10410_attack02.gfbanm"]}
        mapping, bank = choose_actions(report)
        self.assertEqual(bank, "0")
        self.assertEqual(mapping["physical_attack_2"], "pm0007_00_00_00410_attack02.gfbanm")

    def test_export_holds_two_complete_banks(self):
        report = {"unambiguous_actions": {}, "action_candidates_by_bank": {
            str(bank): {key: [f"bank{bank}_{key}"] for key in REQUIRED} for bank in (0, 1)}}
        self.assertEqual(choose_actions(report), (None, "missing_or_ambiguous_native_actions"))

    def test_export_rejects_direct_cross_bank_mix(self):
        direct = {key: f"pm0007_00_00_0{index:04d}_{key}.gfbanm"
                  for index, key in enumerate(sorted(REQUIRED))}
        direct["sleep"] = "pm0007_00_00_20281_sleep01_loop.gfbanm"
        self.assertEqual(choose_actions({"unambiguous_actions": direct,
                                         "action_candidates_by_bank": {}}),
                         (None, "missing_or_ambiguous_native_actions"))

    def test_missing_faint_loop_uses_runtime_final_pose_hold(self):
        direct = {key: f"pm0001_00_00_0{index:04d}_{key}.gfbanm"
                  for index, key in enumerate(sorted(REQUIRED))}
        mapping, bank = choose_actions({"unambiguous_actions": direct,
                                        "action_candidates": {"faint_loop": []}})
        self.assertEqual(bank, "direct")
        self.assertNotIn("faint_loop", mapping)

    def test_extensionless_native_actions_keep_exact_token_boundaries(self):
        names = ["pm0711_00_00_00001_battlewait01_loop",
                 "pm0711_00_00_00400_attack01",
                 "pm0711_00_00_00450_rangeattack01",
                 "pm0711_00_00_00500_damage01",
                 "pm0711_00_00_00281_sleep01_loop",
                 "pm0711_00_00_00520_down01_start",
                 "pm0711_00_00_00521_down01_loop",
                 "pm0711_00_00_00401_attack010"]
        found = candidates(names)
        self.assertTrue(all(len(found[key]) == 1 for key in REQUIRED))
        self.assertEqual(found["physical_attack"], ["pm0711_00_00_00400_attack01"])

    def test_extensionless_drowse_requires_entry_and_exit(self):
        trio = ["pm0001_kw20_drowseA01", "pm0001_kw20_drowseB01",
                "pm0001_kw20_drowseC01"]
        self.assertEqual(candidates(trio)["sleep"], [trio[1]])
        self.assertEqual(candidates(trio[1:2])["sleep"], [])


if __name__ == "__main__":
    unittest.main()
