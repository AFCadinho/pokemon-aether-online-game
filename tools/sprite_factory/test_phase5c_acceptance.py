from copy import deepcopy
import unittest

from phase5c_acceptance import COHORT, qualify


class AcceptanceTests(unittest.TestCase):
    def fixture(self):
        row = dict(switch_ms=[100] * 12, duplicate_checks=7, faint_replacements=7,
            variant_checks=7, replay_duplicate_faint_replacement=True, load_spans=[],
            frame_p95_ms=17, frame_max_ms=100, retained_source_bytes=100,
            arena='classic', replay_setup_ms=20, stalls_over_50ms=[], static_bytes=100)
        return [dict(complete=True, screenshots_enabled=False, rounds=[deepcopy(row) for _ in range(3)]),
            dict(entries=[dict(species=s, poses=[{}] * 5, errors=[], missing_actions=[]) for s in COHORT]),
            [dict(species=s, normal_glb_sha256='a' * 64, shiny_glb_sha256='b' * 64,
                  geometry_motion_sha256='c' * 64) for s in COHORT], 'PHASE5_BATTLE_STRESS_OK']

    def test_qualification_does_not_publish(self):
        result = qualify(*self.fixture())
        self.assertTrue(result['phase5c_complete'])
        self.assertFalse(result['runtime_approved'])
        self.assertEqual(len(result['held_species']), 3)

    def test_marker_does_not_override_script_error(self):
        args = self.fixture()
        args[-1] += '\nSCRIPT ERROR: broken'
        with self.assertRaises(ValueError):
            qualify(*args)

    def test_missing_variant_and_lifecycle_rejected(self):
        for missing in ('review', 'lifecycle', 'parity'):
            args = self.fixture()
            if missing == 'review':
                args[1]['entries'].pop()
            elif missing == 'parity':
                args[2].pop()
            else:
                args[0]['rounds'][1]['variant_checks'] = 6
            with self.assertRaises(ValueError):
                qualify(*args)

    def test_performance_and_retention_guards(self):
        for change in ({'frame_p95_ms': 21}, {'static_bytes': 2 * 1024 * 1024},
                       {'load_spans': [{'operation': 'threaded load dispatch/collect', 'ms': 20}]},
                       {'retained_source_bytes': 65 * 1024 * 1024},
                       {'stalls_over_50ms': [{'ms': 101, 'context': 'load pikachu', 'covered': False}]}):
            args = self.fixture()
            args[0]['rounds'][2].update(change)
            with self.assertRaises(ValueError):
                qualify(*args)
