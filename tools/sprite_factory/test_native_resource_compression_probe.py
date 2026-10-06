import struct
import unittest
from native_resource_compression_probe import Zstd, decode, encode


class NativeCompressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.codec = Zstd()

    def test_native_stream_preserved_including_exact_block_multiple(self):
        for length in [1, 4095, 4096, 4097, 65536, 65537]:
            data = bytes(range(256)) * (length // 256) + bytes(range(length % 256))
            for size in [4096, 65536]:
                packed = encode(data, size, 9, self.codec)
                self.assertEqual(decode(packed, self.codec), data)

    def test_malformed_container_rejected(self):
        valid = encode(b"scene-data" * 600, 4096, 3, self.codec)
        invalid = [valid[:-1], valid + b"x", b"RSCC" + valid[4:15],
                   valid[:8] + struct.pack("<I", 0) + valid[12:],
                   valid[:12] + struct.pack("<I", 0xffffffff) + valid[16:],
                   valid[:16] + struct.pack("<I", 0xffffffff) + valid[20:]]
        for data in invalid:
            with self.assertRaises(ValueError):
                decode(data, self.codec)

    def test_changed_compressed_payload_rejected(self):
        data = bytearray(encode(bytes(range(256)) * 64, 4096, 9, self.codec))
        data[36] ^= 255
        with self.assertRaises(ValueError):
            decode(bytes(data), self.codec)


if __name__ == "__main__":
    unittest.main()
