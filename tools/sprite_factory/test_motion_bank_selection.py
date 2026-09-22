import tempfile
import json
import unittest
from pathlib import Path
from scvi_batch import source_entry


class MotionBankSelectionTests(unittest.TestCase):
    def select(self, names, overrides=None):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            directory = root / 'pm0445' / 'pm0445_00_00'
            directory.mkdir(parents=True)
            for name in names:
                (directory / ('pm0445_00_00_' + name + '.tranm')).touch()
                (directory / ('pm0445_00_00_' + name + '.tracm')).touch()
            return source_entry(dict(species='fixture', pm=445, motion_overrides=overrides or {}), root, root)

    def test_idle_bank_not_global_zero(self):
        for bank in ('0', '1', '2'):
            r = self.select([bank+'0001_battlewait01_loop', bank+'0500_damage01', '30500_damage01'])
            self.assertEqual(r['motion_bank'], bank)
            self.assertTrue(r['motions']['damage'].endswith(bank+'0500_damage01.tranm'))
            self.assertTrue(r['motion_channels']['damage'].endswith(bank+'0500_damage01.tracm'))

    def test_missing_never_borrows_other_bank(self):
        r = self.select(['00001_battlewait01_loop', '20500_damage01'])
        self.assertIsNone(r['motions']['damage'])
        self.assertIsNone(r['motion_channels']['damage'])
        self.assertIn('motion_bank_hold:damage:missing', r['warnings'])

    def test_ambiguous_requires_explicit_same_bank_override(self):
        names = ['00001_battlewait01_loop', '00500_damage01', '00501_damage01']
        r = self.select(names)
        self.assertIsNone(r['motions']['damage'])
        self.assertIn('motion_bank_hold:damage:ambiguous', r['warnings'])
        r = self.select(names, {'damage': '00501_damage01'})
        self.assertTrue(r['motions']['damage'].endswith('00501_damage01.tranm'))

    def test_override_cannot_cross_bank(self):
        with self.assertRaisesRegex(ValueError, 'crosses idle bank'):
            self.select(['00001_battlewait01_loop', '20500_damage01'], {'damage': '20500_damage01'})

    def test_missing_idle_holds_actions(self):
        r = self.select(['00500_damage01'])
        self.assertIsNone(r['motions']['damage'])
        self.assertIsNone(r['motion_bank'])

    def test_second_physical_attack_is_optional_and_stays_in_idle_bank(self):
        r = self.select(['00001_battlewait01_loop', '00400_attack01',
                         '00410_attack02', '20410_attack02'])
        self.assertTrue(r['motions']['physical_attack_2'].endswith(
            '00410_attack02.tranm'))
        self.assertFalse(any(w.startswith('motion_bank_hold:physical_attack_2:')
                             for w in r['warnings']))
        missing = self.select(['00001_battlewait01_loop', '00400_attack01'])
        self.assertIsNone(missing['motions']['physical_attack_2'])
        self.assertNotIn('missing_action:physical_attack_2', missing['warnings'])

    def test_measured_six_model_advisory_sets(self):
        evidence = json.loads(Path(__file__).with_name('posture_family_results.json').read_text())
        for entry in evidence['entries']:
            with self.subTest(species=entry['species']):
                names = [clip['clip'].split('_', 3)[3] for clip in entry['clips']]
                result = self.select(names)
                for category, expected in entry['advisory_candidate'].items():
                    self.assertTrue(result['motions'][category].endswith(expected.split('_', 3)[3] + '.tranm'))
                self.assertFalse(any(w.startswith('motion_bank_hold:') for w in result['warnings']))
