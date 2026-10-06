import struct
import contextlib
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile
from native_resource_compression_probe import Zstd, decode, encode, main


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

    def test_measure_only_retains_verified_uncompressed_files(self):
        # Opaque native-shaped fixture; this audit does not qualify RSRC loading.
        raw_file = b"RSRC" + b"unchanged-fixture" * 100 + b"RSRC"
        digest = lambda data: hashlib.sha256(data).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            archive = root / "original.zip"
            with zipfile.ZipFile(archive, "w") as target:
                target.writestr("models/normal.scn", raw_file)
            before = archive.read_bytes()
            asset = {"asset_id": "fixture", "object_key": "original.zip",
                "size_bytes": len(before), "sha256": digest(before),
                "appearances": [{"variant": "normal", "runtime_identity": "fixture",
                                 "runtime_sha256": digest(raw_file)}]}
            (root / "index.json").write_text(json.dumps({"assets": [asset]}))
            (root / "archives.json").write_text(json.dumps({"original.zip": str(archive)}))
            arguments = ["probe", "--index", str(root / "index.json"), "--archives",
                str(root / "archives.json"), "--identities", "fixture", "--output",
                str(root / "result"), "--measure-only"]
            with patch.object(sys, "argv", arguments), contextlib.redirect_stdout(io.StringIO()):
                main()
            report = json.loads((root / "result/report.json").read_text())
            self.assertTrue(report["complete"])
            self.assertEqual(report["entries"], [])
            self.assertEqual(report["unmodified"][0]["source_bytes"], len(raw_file))
            self.assertEqual(report["unmodified"][0]["source_sha256"], digest(raw_file))
            self.assertEqual(archive.read_bytes(), before)
            self.assertEqual(list((root / "result").iterdir()), [root / "result/report.json"])


if __name__ == "__main__":
    unittest.main()
