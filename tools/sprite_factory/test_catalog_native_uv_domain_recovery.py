import struct
import unittest

from catalog_native_uv_domain_recovery import used_domains


class NativeUVRecoveryTests(unittest.TestCase):
    def domain(self, uv, texture=None):
        document = {
            'meshes': [{'primitives': [{'material': 0, 'attributes': {'TEXCOORD_0': 0}}]}],
            'materials': [{'name': 'Eye', 'pbrMetallicRoughness': {
                'baseColorTexture': texture or {'index': 0}}}],
            'accessors': [{'type': 'VEC2', 'componentType': 5126,
                           'bufferView': 0, 'count': len(uv)}],
            'bufferViews': [{'byteOffset': 4, 'byteStride': 12}],
        }
        binary = b'HEAD' + b''.join(struct.pack('<fff', u, v, 123) for u, v in uv)
        return used_domains(document, binary)

    def test_negative_eye_tile_maps_to_baked_pixels(self):
        points = [(0.025, -0.992), (0.475, -0.758)]
        result = self.domain(points)[0]
        self.assertEqual(result['glb_uv_domain'], [0, -1, 1, 0])
        self.assertEqual(result['source_uv_domain'], [0, 1, 1, 2])
        self.assertEqual(result['offset'], [0, 1])
        for u, v in points:
            baked_v = v * result['scale'][1] + result['offset'][1]
            native_v = 2 - baked_v
            self.assertAlmostEqual(native_v, 1 - v)

    def test_eye_crossing_tile_boundary_keeps_both_sides(self):
        result = self.domain([(0.76, -0.94), (1.24, -0.8)])[0]
        self.assertEqual(result['glb_uv_domain'], [0, -1, 2, 0])
        self.assertEqual(result['scale'], [0.5, 1])

    def test_first_tile_is_unchanged(self):
        self.assertEqual(self.domain([(0, 0), (1, 1)]), [])

    def test_nonfinite_uv_and_existing_transform_fail_closed(self):
        with self.assertRaisesRegex(ValueError, 'Non-finite'):
            self.domain([(float('nan'), 0)])
        with self.assertRaisesRegex(ValueError, 'composition'):
            self.domain([(0, -1)], {'index': 0, 'extensions': {
                'KHR_texture_transform': {'scale': [0.5, 1]}}})


if __name__ == '__main__':
    unittest.main()
