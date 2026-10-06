import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from native_resource_compression_probe import Zstd, encode, sha
from native_transfer_restore_probe import restore


class TransferRestoreTests(unittest.TestCase):
    def setUp(self):
        self.codec = Zstd()
        self.raw = bytes(range(256)) * 300
        self.original = encode(self.raw, 4096, 3, self.codec)
        self.payload = encode(self.raw, 65536, 9, self.codec)
        self.receipt = {"codec_version": self.codec.version,
            "transfer_bytes": len(self.payload), "transfer_sha256": sha(self.payload),
            "raw_bytes": len(self.raw), "raw_sha256": sha(self.raw),
            "installed_bytes": len(self.original), "installed_sha256": sha(self.original)}

    def test_install_and_replace_with_exact_original(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "model.scn"
            for previous in [None, b"previous-approved-file"]:
                if previous is not None:
                    target.write_bytes(previous)
                restore(self.payload, target, self.receipt, self.codec)
                self.assertEqual(target.read_bytes(), self.original)
                self.assertEqual(list(Path(directory).iterdir()), [target])

    def test_failed_integrity_or_codec_preserves_installed_file(self):
        mutations = {"codec_version": "unsupported", "transfer_sha256": "0" * 64,
            "transfer_bytes": 1, "raw_sha256": "0" * 64, "raw_bytes": 1,
            "installed_sha256": "0" * 64, "installed_bytes": 1}
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "model.scn"
            target.write_bytes(b"previous-approved-file")
            for field, value in mutations.items():
                with self.subTest(field=field), self.assertRaises(ValueError):
                    restore(self.payload, target, dict(self.receipt, **{field: value}), self.codec)
                self.assertEqual(target.read_bytes(), b"previous-approved-file")
                self.assertEqual(list(Path(directory).iterdir()), [target])
            for corrupted in [self.payload[:-1], self.payload + b"x"]:
                with self.assertRaises(ValueError):
                    restore(corrupted, target, self.receipt, self.codec)
                self.assertEqual(target.read_bytes(), b"previous-approved-file")

    def test_failed_commit_preserves_installed_file_and_removes_pending(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "model.scn"
            target.write_bytes(b"previous-approved-file")
            with patch("native_transfer_restore_probe.os.replace", side_effect=OSError("fixture failure")):
                with self.assertRaises(OSError):
                    restore(self.payload, target, self.receipt, self.codec)
            self.assertEqual(target.read_bytes(), b"previous-approved-file")
            self.assertEqual(list(Path(directory).iterdir()), [target])


if __name__ == "__main__":
    unittest.main()
