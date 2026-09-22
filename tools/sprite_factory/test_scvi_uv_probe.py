import copy
import unittest
from scvi_uv_probe import sample_loop, validate_loop


def fixture():
    channels = [[{'time': t, 'value': (t / 120 if index >= 2 else 1), 'config': [0, 0, 1]}
                 for t in (0, 60, 120)] for index in range(4)]
    return {'frames': 121, 'fps': 60, 'multiplier': 1, 'config_flag': 1,
            'tracks': [{'material': 'any', 'parameter': 'UVScaleOffset', 'channels': channels}]}


class UVProbeTests(unittest.TestCase):
    def test_original_rate_and_loop_boundary(self):
        data = fixture()
        self.assertEqual(sample_loop(data, 0)['any']['UVScaleOffset'], [1, 1, 0, 0])
        self.assertEqual(sample_loop(data, 1)['any']['UVScaleOffset'], [1, 1, .5, .5])
        self.assertEqual(sample_loop(data, 2), sample_loop(data, 0))
        self.assertEqual(sample_loop(data, 3), sample_loop(data, 1))

    def test_non_affine_and_unknown_channels_are_not_guessed(self):
        for change in ('curve', 'config', 'nan', 'order', 'endpoint'):
            data = fixture()
            keys = data['tracks'][0]['channels'][2]
            if change == 'curve': keys[1]['value'] = .2
            if change == 'config': keys[1]['config'] = [2, 0, 0]
            if change == 'nan': keys[1]['value'] = float('nan')
            if change == 'order': keys[1]['time'] = 0
            if change == 'endpoint': keys[-1]['time'] = 119
            with self.assertRaises(ValueError): validate_loop(data)

    def test_ambiguous_and_unsupported_configs_fail(self):
        data = fixture()
        data['tracks'].append(copy.deepcopy(data['tracks'][0]))
        with self.assertRaises(ValueError): validate_loop(data)
        data = fixture()
        data['multiplier'] = 2
        with self.assertRaises(ValueError): validate_loop(data)
        with self.assertRaises(ValueError): sample_loop(fixture(), -1)


if __name__ == '__main__': unittest.main()
