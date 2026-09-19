import struct
import tempfile
import unittest
from pathlib import Path

from scvi_tracm import inspect_tracm


class TracmTests(unittest.TestCase):
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
