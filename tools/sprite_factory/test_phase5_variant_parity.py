import json
from pathlib import Path
import struct
from tempfile import TemporaryDirectory
import unittest

from phase5_variant_parity import compare


def glb(path, color, geometry=b'123456789012', **extra):
    doc = {'asset': {'version': '2.0'}, 'buffers': [{'byteLength': len(geometry)}],
        'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': len(geometry)}],
        'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': 1, 'type': 'VEC3'}],
        'materials': [{'pbrMetallicRoughness': {'baseColorFactor': color}}], **extra}
    metadata = json.dumps(doc).encode()
    metadata += b' ' * (-len(metadata) % 4)
    path.write_bytes(struct.pack('<III', 0x46546C67, 2, 28 + len(metadata) + len(geometry))
        + struct.pack('<II', len(metadata), 0x4E4F534A) + metadata
        + struct.pack('<II', len(geometry), 0x004E4942) + geometry)


class VariantParityTests(unittest.TestCase):
    def test_material_difference_preserves_geometry(self):
        with TemporaryDirectory() as tmp:
            a, b = Path(tmp) / 'a.glb', Path(tmp) / 'b.glb'
            glb(a, [1, 0, 0, 1])
            glb(b, [0, 1, 0, 1])
            self.assertEqual(len(compare(a, b)), 64)

    def test_identical_variant_rejected(self):
        with TemporaryDirectory() as tmp:
            a = Path(tmp) / 'a.glb'
            glb(a, [1, 0, 0, 1])
            with self.assertRaisesRegex(ValueError, 'identical'):
                compare(a, a)

    def test_geometry_and_motion_changes_rejected(self):
        with TemporaryDirectory() as tmp:
            a, b = Path(tmp) / 'a.glb', Path(tmp) / 'b.glb'
            glb(a, [1, 0, 0, 1])
            for changes in ({'geometry': b'223456789012'}, {'animations': [{'name': 'different'}]},
                            {'nodes': [{'scale': [2, 2, 2]}]}, {'skins': [{'joints': [1]}]}):
                glb(b, [0, 1, 0, 1], **changes)
                with self.assertRaisesRegex(ValueError, 'mismatch'):
                    compare(a, b)

    def test_sparse_accessor_rejected(self):
        with TemporaryDirectory() as tmp:
            a, b = Path(tmp) / 'a.glb', Path(tmp) / 'b.glb'
            glb(a, [1, 0, 0, 1])
            glb(b, [0, 1, 0, 1], accessors=[{'sparse': {}}])
            with self.assertRaisesRegex(ValueError, 'sparse'):
                compare(a, b)
