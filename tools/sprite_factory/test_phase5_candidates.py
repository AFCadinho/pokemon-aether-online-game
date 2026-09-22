import copy
import unittest

from phase5_candidates import COHORT, REQUIRED_ACTIONS, bake_candidates, close, prepare


def fixture():
    entries = []
    for name in sorted(COHORT):
        if name == 'gastly':
            entries.append({'species': name, 'status': 'held'})
            continue
        entries.append({'species': name, 'runtime_approved': False, 'scale': 1,
            'yaw_degrees': 0, 'glb_sha256': 'model', 'candidate_lift': .025,
            'clips': {action: {'duration': 1, 'samples': 61, 'minimum_y': 0,
                              'minimum_y_samples': [0] * 61, 'clearance_with_idle_lift': .025} for action in REQUIRED_ACTIONS},
            'shots': [{'action': 'idle', 'image': str(i), 'in_view': True,
                       'arena_camera': 'classic' if i < 2 else 'stadium', 'side': i % 2,
                       'model_overlaps_hud_proxy': False, 'hud_gap_pixels': 12,
                       'screen_rect': [0, 100, 50, 70]} for i in range(4)],
            'bounds_hud_proxy': True,
            'corrected_clearance_120hz': {action: {'samples': 121, 'minimum_y': .025} for action in REQUIRED_ACTIONS}})
    return {'entries': entries, 'complete': True, 'sample_hz': 60,
            'runtime_approved': False, 'catalog_sha256': 'catalog', 'candidates_sha256': 'candidate'}


class CandidateTests(unittest.TestCase):
    def test_one_readability_rule_preserves_large_models_and_caps_growth(self):
        report = fixture()
        for shot in report['entries'][0]['shots']:
            shot['screen_rect'][3] = 22
        candidates = prepare(report)
        self.assertEqual(candidates['readability'][report['entries'][0]['species']], 3)
        self.assertEqual(candidates['readability']['dragonite'], 1)
        self.assertFalse(candidates['runtime_approved'])

    def test_incomplete_duplicate_and_nonfinite_reviews_rejected(self):
        for mode in ('partial', 'missing', 'duplicate', 'nan'):
            report = fixture()
            if mode == 'partial':
                report['complete'] = False
            elif mode == 'missing':
                report['entries'].pop()
            elif mode == 'duplicate':
                report['entries'].append(copy.deepcopy(report['entries'][0]))
            else:
                report['entries'][0]['shots'][0]['screen_rect'][3] = float('nan')
            with self.assertRaises(ValueError):
                prepare(report)

    def test_closure_does_not_approve_blocked_sources_or_runtime(self):
        report = fixture()
        candidates = bake_candidates(report, prepare(report))
        result = close(report, candidates, 'candidate')
        self.assertTrue(result['review_complete'])
        self.assertFalse(result['runtime_approved'])
        self.assertEqual({e['species'] for e in result['entries'] if e['status'] == 'held'},
                         {'gastly', 'abra', 'onix'})
        self.assertTrue(all(not e['runtime_approved'] for e in result['entries']))

    def test_bad_clearance_hud_or_readability_blocks_model(self):
        for mode in ('floor', 'hud', 'small', 'missing_samples'):
            report = fixture()
            entry = next(e for e in report['entries'] if e['species'] == 'pikachu')
            if mode == 'floor':
                entry['corrected_clearance_120hz']['idle']['minimum_y'] = -.01
            elif mode == 'missing_samples':
                entry.pop('corrected_clearance_120hz')
            elif mode == 'hud':
                entry['shots'][0]['model_overlaps_hud_proxy'] = True
            else:
                entry['shots'][0]['screen_rect'][3] = 30
            result = close(report, prepare(report), 'candidate')
            self.assertEqual(next(e for e in result['entries'] if e['species'] == 'pikachu')['status'], 'held')

    def test_provenance_and_half_frame_counts_checked(self):
        report = fixture()
        with self.assertRaises(ValueError):
            close(report, prepare(report), 'stale')
        report['entries'][0]['corrected_clearance_120hz']['idle']['samples'] = 61
        with self.assertRaises(ValueError):
            close(report, prepare(report), 'candidate')

    def test_missing_camera_view_cannot_close(self):
        report = fixture()
        candidates = prepare(report)
        report['entries'][0]['shots'].pop()
        with self.assertRaises(ValueError):
            close(report, candidates, 'candidate')

    def test_missing_action_blocks_even_when_remaining_geometry_passes(self):
        report = fixture()
        entry = next(e for e in report['entries'] if e['species'] == 'pikachu')
        del entry['clips']['faint_loop']
        del entry['corrected_clearance_120hz']['faint_loop']
        result = close(report, prepare(report), 'candidate')
        pikachu = next(e for e in result['entries'] if e['species'] == 'pikachu')
        self.assertEqual(pikachu['status'], 'held')
        self.assertIn('Missing canonical actions: faint_loop', pikachu['reasons'])

    def test_faint_seam_failure_is_an_explicit_per_model_hold(self):
        report = fixture()
        entry = next(e for e in report['entries'] if e['species'] == 'pikachu')
        for action, minimum in [('faint_start', 0), ('faint_loop', -.1)]:
            entry['clips'][action] = {'duration': 1, 'samples': 61, 'minimum_y': minimum,
                'minimum_y_samples': [minimum] * 61, 'clearance_with_idle_lift': minimum + .025}
        result = bake_candidates(report, prepare(report))
        self.assertIn('pikachu', result['motion_holds'])
        self.assertNotIn('pikachu', result['motion'])
        self.assertIn('dragonite', result['motion'])


if __name__ == '__main__':
    unittest.main()
