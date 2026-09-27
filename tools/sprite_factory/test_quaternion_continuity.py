import math
import unittest

from quaternion_continuity import hemisphere_signs


class QuaternionContinuityTest(unittest.TestCase):
    def test_equivalent_rotations_do_not_cross_zero(self):
        keys = [(0, 0, -1, 0), (0, 0, 1, 0), (0, 0, -1, 0)]
        signs = hemisphere_signs(keys)
        self.assertEqual(signs, [1, -1, 1])
        repaired = [[v * s for v in q] for q, s in zip(keys, signs)]
        self.assertTrue(all(q == repaired[0] for q in repaired))

    def test_rotation_motion_is_preserved(self):
        keys = [(1, 0, 0, 0), (-math.cos(.2), 0, -math.sin(.2), 0)]
        signs = hemisphere_signs(keys)
        self.assertEqual(signs, [1, -1])
        self.assertAlmostEqual(sum(a * b * signs[1] for a, b in zip(*keys)), math.cos(.2))

    def test_invalid_source_is_held(self):
        for value in [(0, 0, 0, 0), (float('nan'), 0, 0, 1), (1, 0, 0)]:
            with self.assertRaises(ValueError):
                hemisphere_signs([value])
