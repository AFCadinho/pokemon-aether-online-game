import unittest
from types import SimpleNamespace
from source_clip_timing import constant_pose_endpoint


class SourceClipTimingTests(unittest.TestCase):
    def test_fixed_pose_uses_native_duration(self):
        self.assertEqual(constant_pose_endpoint(SimpleNamespace(keyFrames=81, frameRate=60), 0, 0, 60), 80)

    def test_moving_clip_is_unchanged(self):
        self.assertIsNone(constant_pose_endpoint(SimpleNamespace(keyFrames=81, frameRate=60), 0, 80, 60))

    def test_invalid_or_mismatching_sources_fail(self):
        for frames, rate, first, last in [(1,60,0,0),(0,60,0,0),(81,30,0,0),(81,60,1,1),(81,60,0,float('nan'))]:
            with self.assertRaises(ValueError):
                constant_pose_endpoint(SimpleNamespace(keyFrames=frames, frameRate=rate), first, last, 60)
