import tempfile
import unittest
import zipfile
import hashlib
import json
from pathlib import Path

from catalog_remaining_intake import source_members
from catalog_remaining_normal_export import REQUIRED, WISHIWASHI_SOLO_SOURCE_SHA256, choose_actions, export_one
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

    def test_form_only_source_requires_matching_developer_number(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "Gen8.zip"
            with zipfile.ZipFile(archive, "w") as zipped:
                zipped.writestr("_pokemon_dev_numbers.csv", "#,Dev #,Name\n862,928,Obstagoon\n")
                zipped.writestr("pm0928_00_31.blend", b"blend")
            self.assertEqual(source_members(archive, 8)[862].filename, "pm0928_00_31.blend")
            with zipfile.ZipFile(archive, "w") as zipped:
                zipped.writestr("_pokemon_dev_numbers.csv", "#,Dev #,Name\n863,928,Perrserker\n")
                zipped.writestr("pm0928_00_31.blend", b"blend")
            with self.assertRaisesRegex(ValueError, "Invalid form-only source"):
                source_members(archive, 8)

    def test_legends_arceus_native_actions(self):
        names = [f"pm0201_11_00_{code}_{action}.gfbanm" for code, action in (
            ("20000", "defaultwait01_loop"), ("20400", "attack01"),
            ("20450", "rangeattack01_start"), ("20500", "damage01_start"),
            ("20281", "sleep01_loop"), ("20520", "down01_start"))]
        found = candidates(names)
        self.assertTrue(all(len(found[key]) == 1 for key in REQUIRED))

    def test_wishiwashi_uses_pinned_field_wait_for_sleep_review(self):
        direct = {key: key for key in REQUIRED - {"sleep"}}
        report = {"species": "wishiwashi", "source_member": "pm0820_11.blend",
                  "source_sha256": WISHIWASHI_SOLO_SOURCE_SHA256,
                  "unambiguous_actions": direct,
                  "action_names": ["pm0820_11_kw01_wait01"],
                  "action_candidates": {"faint_loop": []}}
        self.assertEqual(choose_actions(report)[0]["sleep"], "pm0820_11_kw01_wait01")
        report["source_sha256"] = "changed"
        self.assertIsNone(choose_actions(report)[0])

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

    def test_export_selects_actions_from_proven_default_rig(self):
        own = "pm0044_00_00"
        other = "pm0044_01_00"
        report = {"unambiguous_actions": {},
                  "rig_selection": {"rig": own, "policy": "exclusive_texture_variant_v1"},
                  "action_candidates": {key: [f"{own}_0{index:04d}_{key}",
                                              f"{other}_0{index:04d}_{key}"]
                                        for index, key in enumerate(sorted(REQUIRED))},
                  "action_candidates_by_bank": {},
                  "second_physical_candidates": [f"{own}_00410_attack02",
                                                 f"{other}_00410_attack02"]}
        mapping, bank = choose_actions(report)
        self.assertEqual(bank, "0")
        self.assertEqual(set(mapping), REQUIRED | {"physical_attack_2"})
        self.assertTrue(all(name.startswith(own + "_") for name in mapping.values()))

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

    def test_battle_idle_resolves_same_rig_same_bank_default_idle(self):
        names = [f"pm0428_00_00_{code}_{action}" for code, action in (
            ("00000", "defaultwait01_loop"), ("00001", "battlewait01_loop"),
            ("00400", "attack01"), ("00450", "rangeattack01"),
            ("00500", "damage01"), ("00281", "sleep01_loop"),
            ("00520", "down01_start"))]
        found = candidates(names)
        report = {"rig_selection": {"rig": "pm0428_00_00"},
                  "unambiguous_actions": {}, "action_candidates": found,
                  "action_candidates_by_bank": {"0": found}}
        mapping, bank = choose_actions(report)
        self.assertEqual(mapping["idle"], names[1])
        self.assertTrue(REQUIRED <= mapping.keys())

    def test_proven_rig_isolated_before_complete_bank_selection(self):
        own, other = "pm0272_00_00", "pm0272_01_00"
        names = [f"{rig}_{code}_{action}.gfbanm" for rig in (own, other)
                 for code, action in (("00000", "defaultwait01_loop"),
                 ("00001", "battlewait01_loop"), ("00400", "attack01"),
                 ("00450", "rangeattack01"), ("00500", "damage01"),
                 ("00281", "sleep01_loop"), ("00520", "down01_start"))]
        found = candidates(names)
        mapping, bank = choose_actions({"rig_selection": {"rig": own + ".trmdl"},
            "unambiguous_actions": {}, "action_candidates": found,
            "action_candidates_by_bank": {"0": found}})
        self.assertTrue(REQUIRED <= mapping.keys())
        self.assertTrue(all(name.startswith(own + "_") for name in mapping.values()))

    def test_battle_idle_preference_keeps_competing_complete_banks_held(self):
        names = [f"pm0742_00_00_{bank}{code}_{action}" for bank in (0, 2)
                 for code, action in (("0000", "defaultwait01_loop"),
                 ("0001", "battlewait01_loop"), ("0400", "attack01"),
                 ("0450", "rangeattack01"), ("0500", "damage01"),
                 ("0281", "sleep01_loop"), ("0520", "down01_start"))]
        self.assertEqual(choose_actions({"rig_selection": {"rig": "pm0742_00_00"},
            "unambiguous_actions": {}, "action_candidates": candidates(names),
            "action_candidates_by_bank": {str(b): candidates(names, bank=b) for b in (0, 2)}}),
            (None, "missing_or_ambiguous_native_actions"))

    def test_resume_rejects_changed_mapping_and_artifact_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "0387-turtwig"
            directory.mkdir()
            actions = {k: k for k in REQUIRED}
            probe = root / "probe.json"
            probe.write_text(json.dumps({'unambiguous_actions': actions,
                                         'source_sha256': 'pinned-source'}))
            model = directory / 'model.glb'
            model.write_bytes(b'original model')
            (directory / 'export.json').write_text(json.dumps({'path': str(model),
                'glb_sha256': hashlib.sha256(model.read_bytes()).hexdigest(),
                'animations': actions}))
            job = directory / 'job.json'
            job.write_text(json.dumps({'actions': actions | {'idle': 'old idle'},
                                       'source_sha256': 'pinned-source'}))
            entry = {'species': 'turtwig', 'national_dex': 387}
            probes = {'turtwig': {'status': 'probed', 'report': str(probe)}}
            self.assertEqual(export_one(entry, probes, root, root / 'unused')['reason'],
                             'existing_diagnostic_has_different_source_or_action_mapping')
            job.write_text(json.dumps({'actions': actions, 'source_sha256': 'pinned-source'}))
            model.write_bytes(b'changed model')
            self.assertEqual(export_one(entry, probes, root, root / 'unused')['reason'],
                             'existing_diagnostic_bytes_changed')

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
