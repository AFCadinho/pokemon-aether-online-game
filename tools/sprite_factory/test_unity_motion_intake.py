import math
import struct
import unittest
import tempfile
from pathlib import Path
from unity_motion_intake import decode_bundle, decode_clip, scalar_value, streamed_curves


def stream(frames, count=1):
    data = b''.join(struct.pack('<fi', time, len(keys)) + b''.join(
        struct.pack('<i4f', index, *coefficients) for index, coefficients in keys)
        for time, keys in frames)
    return {'curveCount': count, 'data': list(struct.unpack('<' + 'I' * (len(data)//4), data))}


class UnityMotionIntakeTests(unittest.TestCase):
    def test_sparse_cubic_and_negative_infinity_baseline(self):
        curves = streamed_curves(stream([(-math.inf, [(0, [0, 0, 0, 7])]),
                                         (1., [(0, [1, 2, 3, 4])])]))
        dense = {'m_CurveCount': 0}
        self.assertEqual(scalar_value(0, 0, curves, dense, []), 7)
        self.assertEqual(scalar_value(0, 2, curves, dense, []), 10)

    def test_dense_interpolation_and_constant_bank_offset(self):
        dense = {'m_CurveCount': 2, 'm_BeginTime': 0, 'm_SampleRate': 2,
                 'm_FrameCount': 2, 'm_SampleArray': [0, 4, 2, 8]}
        self.assertEqual(scalar_value(0, .25, [], dense, [12]), 1)
        self.assertEqual(scalar_value(1, .25, [], dense, [12]), 6)
        self.assertEqual(scalar_value(2, .25, [], dense, [12]), 12)

    def test_non_transform_scalar_does_not_shift_later_transform(self):
        clip = {'m_Name': 'fixture', 'm_SampleRate': 2,
                'm_MuscleClip': {'m_StartTime': 0, 'm_StopTime': .75, 'm_Clip': {'data': {
                    'm_StreamedClip': stream([], 0), 'm_DenseClip': {'m_CurveCount': 0},
                    'm_ConstantClip': {'data': [99, 1, 2, 3]}}}},
                'm_ClipBindingConstant': {'genericBindings': [
                    {'typeID': 95, 'attribute': 7, 'path': 0},
                    {'typeID': 4, 'attribute': 1, 'path': 42}]}}
        result = decode_clip(clip, {42: 'waist'})
        self.assertEqual(result['frames'][-1], {'time': .75, 'tracks': {'waist': {'1': [1, 2, 3]}}})
        self.assertEqual(len(result['ignored_non_transform_bindings']), 1)
        with self.assertRaisesRegex(ValueError, 'path hash'):
            decode_clip(clip, {})
        clip['m_MuscleClip']['m_StopTime'] = 1.00000001
        self.assertEqual(len(decode_clip(clip, {42: 'waist'})['frames']), 3)
        clip['m_MuscleClip']['m_Clip']['data']['m_ConstantClip']['data'].append(5)
        with self.assertRaisesRegex(ValueError, 'lengths differ'):
            decode_clip(clip, {42: 'waist'})

    def test_changed_download_is_rejected_before_parsing(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'changed.unity3d'
            path.write_bytes(b'UnityFS\0changed')
            with self.assertRaisesRegex(ValueError, 'hash changed'):
                decode_bundle(path, '0' * 64)

    def test_corrupt_stream_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'outside bank'):
            streamed_curves(stream([(0, [(2, [0, 0, 0, 1])])]))
        broken = stream([(0, [(0, [0, 0, 0, 1])])])
        broken['data'].pop()
        with self.assertRaisesRegex(ValueError, 'frame length'):
            streamed_curves(broken)


if __name__ == '__main__':
    unittest.main()
