import json
import struct
import tempfile
import unittest
from pathlib import Path

from physical_attack_runtime_upgrade import verify_append_only


def glb(path: Path, animations: list, suffix: bytes = b"") -> None:
    document = {
        "asset": {"version": "2.0"}, "scene": 0,
        "accessors": [{"count": 1}],
        "bufferViews": [{"buffer": 0, "byteLength": 4}],
        "buffers": [{"byteLength": 4 + len(suffix)}],
        "animations": [{"name": name} for name in animations],
    }
    raw = json.dumps(document, separators=(",", ":")).encode()
    raw += b" " * (-len(raw) % 4)
    binary = b"BASE" + suffix
    binary += b"\x00" * (-len(binary) % 4)
    payload = (b"glTF" + struct.pack("<II", 2, 12 + 8 + len(raw) + 8 + len(binary)) +
               struct.pack("<I4s", len(raw), b"JSON") + raw +
               struct.pack("<I4s", len(binary), b"BIN\x00") + binary)
    path.write_bytes(payload)


class RuntimeUpgradeTest(unittest.TestCase):
    def test_accepts_one_appended_animation_and_binary_suffix(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            glb(root / "old.glb", ["idle"])
            glb(root / "new.glb", ["idle", "physical_attack_2"], b"NEXT")
            result = verify_append_only(root / "old.glb", root / "new.glb",
                                        "physical_attack_2")
            self.assertTrue(result["existing_glb_prefix_identical"])

    def test_rejects_existing_animation_change(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            glb(root / "old.glb", ["idle"])
            glb(root / "new.glb", ["damage", "physical_attack_2"], b"NEXT")
            with self.assertRaisesRegex(ValueError, "sequence"):
                verify_append_only(root / "old.glb", root / "new.glb",
                                   "physical_attack_2")


if __name__ == "__main__":
    unittest.main()
