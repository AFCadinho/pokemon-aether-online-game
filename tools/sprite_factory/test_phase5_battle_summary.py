import copy
import unittest
from phase5_battle_summary import summarize


class BattleSummaryTests(unittest.TestCase):
    def fixture(self):
        return {'runtime_approved': False, 'complete': True, 'sample_hz': 60, 'entries': [{
            'species': 'sample', 'scale': 1, 'candidate_lift': 0.025, 'runtime_approved': False,
            'clips': {'idle': {'duration': 1, 'samples': 61, 'minimum_y': 0, 'clearance_with_idle_lift': 0.025},
                      'sleep': {'duration': 1, 'samples': 61, 'minimum_y': -0.2, 'clearance_with_idle_lift': -0.175}},
            'shots': [{'image': 'idle.png', 'action': 'idle', 'in_view': False,
                       'model_overlaps_hud_proxy': True, 'hud_gap_pixels': -20}]}]}

    def test_penetration_framing_and_hud_remain_review_findings(self):
        result = summarize(self.fixture())
        self.assertFalse(result['runtime_approved'])
        entry = result['entries'][0]
        self.assertEqual(entry['floor_penetrating_clips'], ['sleep'])
        self.assertEqual(entry['out_of_frame_shots'], ['idle.png'])
        self.assertEqual(entry['hud_proxy_overlap_shots'], ['idle.png'])

    def test_incomplete_or_inconsistent_samples_rejected(self):
        for key, value in [('samples', 60), ('minimum_y', float('nan')), ('clearance_with_idle_lift', 5)]:
            data = self.fixture()
            data['entries'][0]['clips']['idle'][key] = value
            with self.assertRaises(ValueError):
                summarize(data)

    def test_no_approval_and_no_duplicate_entries(self):
        data = self.fixture()
        data['runtime_approved'] = True
        with self.assertRaises(ValueError):
            summarize(data)
        data = self.fixture()
        data['entries'].append(copy.deepcopy(data['entries'][0]))
        with self.assertRaises(ValueError):
            summarize(data)

    def test_partial_run_is_not_reported_as_complete(self):
        data = self.fixture()
        data['complete'] = False
        with self.assertRaises(ValueError):
            summarize(data)

    def test_floating_idle_is_not_forced_down(self):
        data = self.fixture()
        entry = data['entries'][0]
        entry['candidate_lift'] = 0
        entry['clips'] = {'idle': {'duration': 1, 'samples': 61, 'minimum_y': 0.4, 'clearance_with_idle_lift': 0.4}}
        self.assertEqual(summarize(data)['entries'][0]['idle_clearance'], 0.4)

    def test_corrected_summary_retains_raw_baseline_findings(self):
        data = self.fixture()
        data['entries'][0]['bounds_hud_proxy'] = True
        data['entries'][0]['corrected_clearance_120hz'] = {
            'idle': {'minimum_y': .025}, 'sleep': {'minimum_y': .03}}
        entry = summarize(data)['entries'][0]
        self.assertEqual(entry['floor_penetrating_clips'], ['sleep'])
        self.assertEqual(entry['corrected_floor_penetrating_clips'], [])
        self.assertEqual(entry['corrected_minimum_clearance'], .025)
        self.assertEqual(entry['hud_proxy'], 'posed_model_bounds')


if __name__ == '__main__':
    unittest.main()
