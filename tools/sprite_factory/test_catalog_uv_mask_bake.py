import copy
import struct
import unittest
from PIL import Image
from catalog_uv_mask_bake import raster


def scene(shift=0, conflict=False):
    doc = {'accessors': [], 'bufferViews': [], 'meshes': []}
    binary = bytearray()

    def add(values, kind, fmt, component):
        offset = len(binary)
        binary.extend(struct.pack('<' + fmt * len(values), *values))
        view = len(doc['bufferViews'])
        doc['bufferViews'].append({'byteOffset': offset, 'byteLength': len(binary)-offset})
        index = len(doc['accessors'])
        doc['accessors'].append({'bufferView': view, 'type': kind, 'componentType': component,
                                 'count': len(values)//(2 if kind == 'VEC2' else 1)})
        return index

    uv0 = add([0, shift, 1, shift, 0, 1+shift], 'VEC2', 'f', 5126)
    uv1 = add([.1, .1, .2, .1, .1, .2], 'VEC2', 'f', 5126)
    indices = add([0, 1, 2], 'SCALAR', 'H', 5123)
    prim = {'material': 0, 'attributes': {'TEXCOORD_0': uv0, 'TEXCOORD_1': uv1}, 'indices': indices}
    doc['meshes'].append({'primitives': [prim]})
    if conflict:
        uv2 = add([.8, .8, .9, .8, .8, .9], 'VEC2', 'f', 5126)
        doc['meshes'].append({'primitives': [{**prim, 'attributes': {'TEXCOORD_0': uv0, 'TEXCOORD_1': uv2}}]})
    image = Image.new('RGBA', (8, 8), (255, 0, 0, 0))
    for y in range(4, 8):
        for x in range(4, 8):
            image.putpixel((x, y), (0, 255, 0, 0))
    return doc, binary, image


class MaskBakeTests(unittest.TestCase):
    def test_data_under_zero_alpha_and_geometry_preserved(self):
        d, b, im = scene()
        before = copy.deepcopy(d), bytes(b)
        result, audit = raster(d, b, 0, im, [1, 1, 0, 0], 8)
        self.assertEqual(result.getpixel((1, 1)), (255, 0, 0, 0))
        self.assertGreater(audit['covered_pixels'], 0)
        self.assertEqual((d, bytes(b)), before)

    def test_negative_base_tile_repeats(self):
        d, b, im = scene()
        expected, _ = raster(d, b, 0, im, [1, 1, 0, 0], 8)
        d, b, im = scene(-1)
        actual, _ = raster(d, b, 0, im, [1, 1, 0, 0], 8)
        self.assertEqual(expected.tobytes(), actual.tobytes())

    def test_ambiguous_overlaps_fail(self):
        d, b, im = scene(conflict=True)
        with self.assertRaisesRegex(ValueError, 'conflicting'):
            raster(d, b, 0, im, [1, 1, 0, 0], 8)

    def test_empty_and_nonfinite_inputs_fail(self):
        d, b, im = scene()
        with self.assertRaisesRegex(ValueError, 'no pixels'):
            raster(d, b, 1, im, [1, 1, 0, 0], 8)
        with self.assertRaisesRegex(ValueError, 'Invalid'):
            raster(d, b, 0, im, [1, 1, float('nan'), 0], 8)


if __name__ == '__main__':
    unittest.main()
