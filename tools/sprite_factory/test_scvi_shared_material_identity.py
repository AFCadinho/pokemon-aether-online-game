import struct
import tempfile
import unittest
from pathlib import Path

from test_scvi_identity import Fixture
from scvi_shared_material_identity import verify_default_materials


def material_fixture(colour):
    f = Fixture(); root = f.table(2, [1])
    pointer = f.vector(f.field(root, 1), 1)[0]; material = f.table(8, [0, 7]); f.pointer(pointer, material)
    f.string(f.field(material, 0), 'body')
    pointer = f.vector(f.field(material, 7), 1)[0]; parameter = f.table(5, [0, 1]); f.pointer(pointer, parameter)
    for i, value in enumerate(colour): f.put(f.field(parameter, 1) + i * 4, value, 'f')
    f.string(f.field(parameter, 0), 'BaseColorLayer1')
    return f.finish(root)


def selector_fixture(colour, time=0, switch=1, replacement=False):
    f = Fixture(); root = f.table(2); config = f.table(3); f.pointer(f.field(root, 0), config)
    f.put(f.field(config, 1), 2); f.put(f.field(config, 2), 60)
    p = f.vector(f.field(root, 1), 1)[0]; timeline = f.table(7, [4]); f.pointer(p, timeline)
    track = f.table(3, [2]); f.pointer(f.field(timeline, 4), track)
    p = f.vector(f.field(track, 2), 1)[0]; material = f.table(3, [0, 2]); f.pointer(p, material)
    f.string(f.field(material, 0), 'body')
    p = f.vector(f.field(material, 2), 1)[0]; parameter = f.table(2); f.pointer(p, parameter)
    f.string(f.field(parameter, 0), 'BaseColorLayer1')
    channels = f.table(4); f.pointer(f.field(parameter, 1), channels)
    for i, value in enumerate(colour):
        sequence = f.table(1); f.pointer(f.field(channels, i), sequence)
        p = f.vector(f.field(sequence, 0), 1)[0]; key = f.table(2); f.pointer(p, key)
        f.put(f.field(key, 0), time, 'f'); f.put(f.field(key, 1), value, 'f')
    clip = f.finish(root)
    f = Fixture(); root = f.table(3, [2]); p = f.vector(f.field(root, 2), 1)[0]
    normal = f.table(4); f.pointer(p, normal); f.string(f.field(normal, 0), 'normal')
    references = f.vector(f.field(normal, 1), 1 if replacement else 0)
    if replacement: f.string(references[0], 'another.trmtr')
    p = f.vector(f.field(normal, 2), 1)[0]; row = f.table(2); f.pointer(p, row)
    f.string(f.field(row, 0), 'body_shape'); f.put(f.field(row, 1), switch, 'B')
    p = f.vector(f.field(normal, 3), 1)[0]; prop = f.table(5, [0, 1, 4]); f.pointer(p, prop)
    f.string(f.field(prop, 0), 'color')
    p = f.vector(f.field(prop, 1), 1)[0]; mapper = f.table(3); f.pointer(p, mapper)
    for i, name in enumerate(('body_shape', 'body', 'BaseColorLayer1')): f.string(f.field(mapper, i), name)
    embedded = f.table(1); f.pointer(f.field(prop, 4), embedded)
    f.align(); vector = len(f.data); f.data += struct.pack('<I', len(clip)) + clip
    f.pointer(f.field(embedded, 0), vector)
    return f.finish(root)


class SharedMaterialTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.table = Path(self.temp.name) / 'model.trmmt'; self.material = Path(self.temp.name) / 'model.trmtr'
        self.colour = (0.2, 0.4, 0.6, 1.0)
        self.material.write_bytes(material_fixture(self.colour))

    def test_frame_zero_matches_default_and_records_rounding(self):
        self.table.write_bytes(selector_fixture((0.2003, 0.4, 0.6, 1)))
        result = verify_default_materials(self.table, self.material)
        self.assertEqual(1, result['verified_colours'])
        self.assertGreater(result['maximum_colour_delta'], 0)

    def test_wrong_colour_missing_frame_and_replacement_are_rejected(self):
        cases = [((0.3, 0.4, 0.6, 1), {}), (self.colour, {'time': 1}),
                 (self.colour, {'switch': 0}), (self.colour, {'replacement': True}),
                 ((float('nan'), 0.4, 0.6, 1), {})]
        for colour, options in cases:
            with self.subTest(options=options, colour=colour):
                self.table.write_bytes(selector_fixture(colour, **options))
                with self.assertRaises(ValueError): verify_default_materials(self.table, self.material)


if __name__ == '__main__':
    unittest.main()
