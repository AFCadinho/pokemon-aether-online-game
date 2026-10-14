import io
import struct
import unittest
from PIL import Image
from portable_texture_buffer import replace_buffer


def text(value):
    value = value.encode()+b'\0'
    return struct.pack('<I', len(value))+value


def fixture():
    shape = {'format': 5, 'mipmaps': 0, 'width': 1, 'height': 1}
    png = struct.pack('<HH4I', 0, 2, 5, 1, 1, 1)+struct.pack('<I', 3)+b'old'
    head = struct.pack('<5I', 0, 0, 4, 6, 6)+text('PortableCompressedTexture2D')
    head += struct.pack('<QIQ', 0, 3, 2**64-1)+bytes(44)+struct.pack('<I', 3)
    head += text('_data')+text('resource_name')+text('keep_compressed_buffer')
    head += struct.pack('<II', 0, 1)+text('local://PortableCompressedTexture2D_test')
    head += struct.pack('<Q', len(head)+8)
    body = text('PortableCompressedTexture2D')+struct.pack('<I', 3)
    body += struct.pack('<II', 1, 5)+text('preserved name')
    body += struct.pack('<III', 0, 31, len(png))+png+bytes(-len(png)%4)
    body += struct.pack('<III', 2, 2, 1)+b'RSRC'
    stream = io.BytesIO()
    Image.new('RGBA', (1, 1), (19, 37, 71, 254)).save(stream, format='WEBP', lossless=True, exact=True)
    webp = stream.getvalue()
    buffer = struct.pack('<HH4I', 0, 3, 5, 1, 1, 1)+struct.pack('<I', len(webp))+webp
    return head+body, shape, buffer, len(head)


class NativeBufferTest(unittest.TestCase):
    def test_only_array_changes_and_padding_is_correct(self):
        raw, row, buffer, body = fixture()
        result, evidence = replace_buffer(raw, row, buffer)
        self.assertEqual(result[:body], raw[:body])
        self.assertIn(text('preserved name'), result)
        self.assertTrue(result.endswith(struct.pack('<III', 2, 2, 1)+b'RSRC'))
        self.assertIn(struct.pack('<I', len(buffer))+buffer+bytes(-len(buffer)%4), result)
        self.assertEqual(len(evidence), 64)

    def test_changed_shape_is_rejected(self):
        raw, row, buffer, _ = fixture()
        with self.assertRaisesRegex(ValueError, 'shape'):
            replace_buffer(raw, row, buffer[:12]+struct.pack('<I', 2)+buffer[16:])

    def test_changed_main_resource_offset_is_rejected(self):
        raw, row, buffer, body = fixture()
        bad = raw[:body-8]+struct.pack('<Q', body+1)+raw[body:]
        with self.assertRaisesRegex(ValueError, 'offset'):
            replace_buffer(bad, row, buffer)

    def test_truncated_mip_is_rejected(self):
        raw, row, buffer, _ = fixture()
        with self.assertRaisesRegex(ValueError, 'Malformed'):
            replace_buffer(raw, row, buffer[:-1])


if __name__ == '__main__': unittest.main()
