import math
import unittest

from catalog_dlc_sleep_proposals import append, decomposition, interpolate, inverse, multiply, sample, trs


class SleepSamplingTests(unittest.TestCase):
    def fixture(self):
        doc = {'bufferViews': [], 'accessors': []}
        data = bytearray()
        tracks = []
        for node, duration in [(0, 4), (1, 2)]:
            tracks.append({'input': append(doc, data, [[0], [duration]], 'SCALAR'),
                           'output': append(doc, data, [[0, 0, 0], [duration, 0, 0]], 'VEC3')})
        clip = {'samplers': tracks, 'channels': [
            {'sampler': i, 'target': {'node': i, 'path': 'translation'}} for i in range(2)]}
        return doc, data, clip

    def test_short_track_uses_global_clip_clock(self):
        doc, data, clip = self.fixture()
        pose = sample(doc, data, clip, .75)
        self.assertEqual(pose[(0, 'translation')], [3, 0, 0])
        self.assertEqual(pose[(1, 'translation')], [2, 0, 0])

    def test_step_switches_at_exact_key_time(self):
        doc, data, clip = self.fixture()
        clip['samplers'][1]['interpolation'] = 'STEP'
        self.assertEqual(sample(doc, data, clip, .49)[(1, 'translation')], [0, 0, 0])
        self.assertEqual(sample(doc, data, clip, .5)[(1, 'translation')], [2, 0, 0])

    def test_antipodal_quaternions_do_not_collapse(self):
        result = interpolate([0, 0, 0, 1], [0, 0, 0, -1], .5, True)
        self.assertAlmostEqual(math.sqrt(sum(x*x for x in result)), 1)
        self.assertEqual(result, [0, 0, 0, 1])

    def test_flattened_eyelid_stays_relative_to_idle_head(self):
        doc = {'nodes': [{'translation': [0, 0, 0]},
                         {'translation': [5, 2, 0], 'rotation': [0, 0, math.sqrt(.5), math.sqrt(.5)]},
                         {'translation': [1, .2, 0], 'scale': [1, .3, 1]}]}
        idle_head, faint_head, relative_eye = [trs({}, i, doc) for i in range(3)]
        faint_eye = multiply(faint_head, relative_eye)
        transferred = multiply(multiply(idle_head, inverse(faint_head)), faint_eye)
        result = decomposition(transferred)
        for actual, expected in zip(result['translation'], [1, .2, 0]):
            self.assertAlmostEqual(actual, expected)
        for actual, expected in zip(result['scale'], [1, .3, 1]):
            self.assertAlmostEqual(actual, expected)


if __name__ == '__main__':
    unittest.main()
