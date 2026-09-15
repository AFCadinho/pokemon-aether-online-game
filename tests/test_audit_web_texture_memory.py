import io
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from audit_web_texture_memory import audit, entries, texture_dimensions


def fixture(version=3, base=0, flags=0):
    data = bytearray(256)
    struct.pack_into('<II', data, 0, 0x43504447, version)
    struct.pack_into('<IQQ', data, 20, flags, base, 96)
    struct.pack_into('<II', data, 96, 1, 8)
    data[104:112] = b'a.ctex\0\0'
    struct.pack_into('<QQ', data, 112, 192 - base, 16)
    data[192:208] = b'GST2' + struct.pack('<III', 1, 2048, 1805)
    return data


class TextureAuditTests(unittest.TestCase):
    def test_pck_versions_and_base(self):
        for version in (2, 3):
            for base in (0, 64):
                self.assertEqual(entries(io.BytesIO(fixture(version, base))), [('a.ctex', 192, 16)])

    def test_imported_not_source_dimensions(self):
        self.assertEqual(texture_dimensions(fixture()[192:208]), (2048, 1805))

    def test_reject_encryption(self):
        with self.assertRaises(ValueError):
            entries(io.BytesIO(fixture(flags=1)))

    def test_reject_out_of_bounds_payload(self):
        data = fixture()
        struct.pack_into('<Q', data, 112, 256)
        with self.assertRaises(ValueError):
            entries(io.BytesIO(data))

    def test_reject_truncated_directory_and_header(self):
        for size in (0, 39, 99, 107, 130):
            with self.assertRaises(ValueError):
                entries(io.BytesIO(fixture()[:size]))

    def test_reject_bad_texture(self):
        for header in (b'', b'BAD!' + bytes(12), b'GST2' + struct.pack('<III', 2, 64, 32),
                       b'GST2' + struct.pack('<III', 1, 0, 32)):
            with self.assertRaises(ValueError):
                texture_dimensions(header)

    def test_duplicate_effect_payloads_are_reported_not_changed(self):
        data = fixture()
        struct.pack_into('<I', data, 96, 2)
        struct.pack_into('<Q', data, 112, 224)
        struct.pack_into('<I', data, 148, 8)
        data[152:160] = b'b.ctex\0\0'
        struct.pack_into('<QQ', data, 160, 240, 16)
        data[224:240] = data[240:256] = b'GST2' + struct.pack('<III', 1, 64, 32)
        # The tail ends at 196; clear the leftover old payload/flags bytes.
        data[176:196] = bytes(20)
        sources = {'a.ctex': 'assets/battles/animations/a/sheet.png',
                   'b.ctex': 'assets/battles/animations/b/sheet.png'}
        with tempfile.TemporaryDirectory() as directory:
            pack = Path(directory) / 'test.pck'
            pack.write_bytes(data)
            with patch('audit_web_texture_memory.source_paths', return_value=sources):
                report = audit(pack)
            self.assertEqual(report['textureCount'], 2)
            duplicate, = report['identicalBattleEffectPayloads']
            self.assertEqual(len(duplicate['sources']), 2)
            self.assertEqual(duplicate['estimatedRGBABytesPerTexture'], 64 * 32 * 4)
            self.assertEqual(pack.read_bytes(), data)


if __name__ == '__main__':
    unittest.main()
