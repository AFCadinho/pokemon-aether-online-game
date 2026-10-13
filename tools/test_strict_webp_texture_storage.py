"""Exact-channel tests independent of Godot's alpha-detection heuristic."""
import hashlib
import io
import struct
import tempfile
import unittest
from pathlib import Path

from PIL import Image
from probe_v13_compression import encode, Zstd
from study_strict_webp_texture_storage import exact_webp_buffer, native_pixels


class StrictWebPTests(unittest.TestCase):
    def fixture(self, directory):
        levels = []
        mips = []
        for index, size in enumerate([4, 2, 1]):
            # Authored lower mips are intentionally different from resampling.
            pixels = bytes(v for i in range(size*size) for v in
                           ((i*37+index*23)%256, (i*19+index*71)%256, (i*11+index*13)%256,
                            254 if i%2 == 0 else 0))
            image = Image.frombytes('RGBA', (size, size), pixels)
            png = io.BytesIO()
            image.save(png, format='PNG')
            payload = b'PNG ' + png.getvalue()
            levels.append(struct.pack('<I', len(payload)) + payload)
            mips.append({'width': size, 'height': size, 'source_sha256': hashlib.sha256(pixels).hexdigest()})
        buffer = struct.pack('<HH4I', 0, 2, 5, 3, 4, 4) + b''.join(levels)
        # Exercise the buffer extraction separately from the complete PCK path.
        raw = b'RSRC' + struct.pack('<I', len(buffer)) + buffer + b'RSRC'
        path = Path(directory) / 'texture.res'
        path.write_bytes(encode(raw, 262144, 19, Zstd()))
        return {'format': 5, 'width': 4, 'height': 4, 'mipmaps': 2, 'codecs': {'png': {'mips': mips}}}, path

    def test_preserves_alpha_254_hidden_rgb_and_each_authored_mip(self):
        with tempfile.TemporaryDirectory() as directory:
            row, path = self.fixture(directory)
            buffer, evidence = exact_webp_buffer(row, path)
            self.assertEqual(struct.unpack_from('<HH4I', buffer), (0, 3, 5, 3, 4, 4))
            self.assertEqual(len(evidence), 3)
            offset = 20
            for mip in row['codecs']['png']['mips']:
                length, = struct.unpack_from('<I', buffer, offset)
                offset += 4
                with Image.open(io.BytesIO(buffer[offset:offset+length])) as image:
                    self.assertEqual(hashlib.sha256(native_pixels(image, 5)).hexdigest(), mip['source_sha256'])
                offset += length
            self.assertEqual(offset, len(buffer))

    def test_rejects_changed_source_mip_hash(self):
        with tempfile.TemporaryDirectory() as directory:
            row, path = self.fixture(directory)
            row['codecs']['png']['mips'][1]['source_sha256'] = '0' * 64
            with self.assertRaisesRegex(ValueError, 'differs from source'):
                exact_webp_buffer(row, path)

    def test_rejects_changed_mip_dimensions(self):
        with tempfile.TemporaryDirectory() as directory:
            row, path = self.fixture(directory)
            row['codecs']['png']['mips'][2]['width'] = 2
            with self.assertRaisesRegex(ValueError, 'Changed mip dimensions'):
                exact_webp_buffer(row, path)


if __name__ == '__main__': unittest.main()
