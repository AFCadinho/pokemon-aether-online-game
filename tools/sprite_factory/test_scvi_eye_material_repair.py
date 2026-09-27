import math
import unittest
from scvi_eye_material_repair import eyelid_transform

class EyelidTransformTests(unittest.TestCase):
    def test_source_top_origin_offset_is_converted_to_blender_bottom_origin(self):
        row = {'colors': {'UVScaleOffset3': [1, 1, 0, 0.6]}, 'floats': {'UVRotation3': 0}}
        scale, offset = eyelid_transform(row, 3)
        self.assertEqual(scale, (1, 1, 1))
        self.assertEqual(offset, (0, -0.6, 0))
        # Verify both ends against the coordinate definition, including nonunit scale.
        row['colors']['UVScaleOffset3'] = [2, 0.5, 0.1, -0.2]
        scale, offset = eyelid_transform(row, 3)
        for u, v in ((0, 0), (0.5, 0.5), (1, 1)):
            self.assertAlmostEqual(u * scale[0] + offset[0], u * 2 + 0.1)
            self.assertAlmostEqual(v * scale[1] + offset[1], 1 - ((1-v)*0.5 - 0.2))

    def test_unknown_rotation_missing_and_nonfinite_offsets_stay_held(self):
        cases = [{}, {'colors': {'UVScaleOffset3': [1, 1, 0, 0.6]}},
                 {'colors': {'UVScaleOffset3': [1, 1, 0, math.nan]}, 'floats': {'UVRotation3': 0}},
                 {'colors': {'UVScaleOffset3': [1, 1, 0, 0]}, 'floats': {'UVRotation3': 1}},
                 {'colors': {'UVScaleOffset3': [0, 1, 0, 0]}, 'floats': {'UVRotation3': 0}}]
        for row in cases:
            with self.assertRaises(ValueError): eyelid_transform(row, 3)

if __name__ == '__main__': unittest.main()
