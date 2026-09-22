import struct
import tempfile
import unittest
from pathlib import Path

from scvi_tracm import inspect_tracm, inspect_visibility, unapplied_channel_warnings


def visibility_fixture(kind, values, frames=()):
    """Minimal nested FlatBuffers fixture, independent of the source decoder."""
    data = bytearray(4)

    def table(count):
        vt = len(data)
        data.extend(struct.pack('<HH', 4 + 2 * count, 4 + 4 * count))
        data.extend(struct.pack('<' + 'H' * count, *[4 + 4*i for i in range(count)]))
        pos = len(data)
        data.extend(struct.pack('<i', pos-vt) + bytes(4*count))
        return pos

    def link(location, target):
        struct.pack_into('<I', data, location, target-location)

    def vector(values, fmt='B'):
        pos = len(data)
        data.extend(struct.pack('<I', len(values)))
        data.extend(struct.pack('<'+fmt*len(values), *values))
        return pos

    root = table(2)
    struct.pack_into('<I', data, 0, root)
    tracks = vector([0], 'I'); link(root+8, tracks)
    track = table(6); link(tracks+4, track)
    name = len(data); data.extend(struct.pack('<I', 4)+b'mesh\0'); link(track+4, name)
    timeline = table(3); link(track+24, timeline)
    info = table(2); link(timeline+12, info)
    data[info+4] = kind
    payload = table(2 if kind in (3,4) else 1); link(info+8, payload)
    if kind == 1:
        data[payload+4] = values[0]
    elif kind == 2:
        link(payload+4, vector(values))
    else:
        link(payload+4, vector(frames, 'H' if kind == 3 else 'B'))
        link(payload+8, vector(values))
    return data


class TracmTests(unittest.TestCase):
    def decode(self, kind, values, frames=()):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'fixture.tracm'
            path.write_bytes(visibility_fixture(kind, values, frames))
            return inspect_visibility(path)[0]

    def test_fixed_values(self):
        for value in (0, 1):
            row = self.decode(1, [value])
            self.assertIs(row['fixed_value'], bool(value))
            self.assertEqual(row['packed_bytes'], [])

    def test_dynamic_payload_is_not_converted_to_booleans(self):
        row = self.decode(2, [255, 0, 192])
        self.assertIsNone(row['fixed_value'])
        self.assertEqual(row['packed_bytes'], [255, 0, 192])

    def test_framed_payload_preserves_compressed_bytes(self):
        for kind, frames in [(4, [0, 83, 91]), (3, [0, 300, 600])]:
            row = self.decode(kind, [5], frames)
            self.assertEqual(row['frames'], frames)
            self.assertEqual(row['packed_bytes'], [5])
            self.assertIsNone(row['fixed_value'])

    def test_rejects_unknown_union(self):
        with self.assertRaisesRegex(ValueError, 'Unsupported visibility'):
            self.decode(9, [1])

    def test_rejects_non_boolean_fixed_value(self):
        with self.assertRaisesRegex(ValueError, 'Boolean'):
            self.decode(1, [2])

    def test_rejects_unsorted_frames(self):
        with self.assertRaisesRegex(ValueError, 'frame keys'):
            self.decode(4, [5], [0, 91, 83])

    def test_reports_all_unapplied_channels(self):
        self.assertEqual(unapplied_channel_warnings('sleep', {
            'material_tracks': 2, 'visibility_tracks': 3, 'blendshape_tracks': 1}),
            ['unapplied_tracm_material:sleep:2', 'unapplied_tracm_visibility:sleep:3',
             'unapplied_tracm_blendshape:sleep:1'])
        self.assertEqual(unapplied_channel_warnings('idle', None), [])

    def test_rejects_missing_config(self):
        # Root table with no fields. This is structurally valid FlatBuffers data
        # but not a valid SCVI channel animation.
        data = struct.pack("<IHHHHI", 12, 4, 4, 0, 0, 4)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "empty.tracm"
            path.write_bytes(data)
            with self.assertRaisesRegex(ValueError, "TrackConfig"):
                inspect_tracm(path)


if __name__ == "__main__":
    unittest.main()
