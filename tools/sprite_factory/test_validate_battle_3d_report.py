import json
import tempfile
import unittest
from pathlib import Path

from validate_battle_3d_report import REQUIRED_ACTIONS, validate_report


class ReportPreflightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.model = self.root / "model.glb"
        # Header-only fixture exercises file preflight, not GLTF import.
        self.model.write_bytes(b"glTF" + (2).to_bytes(4, "little") + (12).to_bytes(4, "little"))
        self.entry = {"species": "bulbasaur", "path": str(self.model), "action_timing": {
            action: {"frames": 60, "speed": 1.0, "loop": action == "idle"}
            for action in REQUIRED_ACTIONS}}

    def check_entries(self, entries):
        report = self.root / "report.json"
        report.write_text(json.dumps(entries))
        return validate_report(report)

    def test_species_agnostic(self):
        self.assertEqual(self.check_entries([self.entry]), [])

    def test_duplicate_and_missing_action(self):
        del self.entry["action_timing"]["damage"]
        errors = self.check_entries([self.entry, self.entry])
        self.assertTrue(any("duplicate" in e for e in errors))
        self.assertTrue(any("required action damage" in e for e in errors))

    def test_invalid_timing(self):
        self.entry["action_timing"]["idle"] = {"frames": True, "speed": float("nan"), "loop": 1}
        self.assertEqual(len(self.check_entries([self.entry])), 3)

    def test_missing_and_corrupt_file(self):
        self.model.unlink()
        self.assertTrue(self.check_entries([self.entry]))
        self.model.write_bytes(b"broken")
        self.assertTrue(any("header" in e for e in self.check_entries([self.entry])))

    def test_hash_format(self):
        self.entry["source_sha256"] = "invalid"
        self.assertTrue(any("source_sha256" in e for e in self.check_entries([self.entry])))
        self.entry["source_sha256"] = "0" * 64
        self.assertEqual(self.check_entries([self.entry]), [])

    def test_malformed_entries(self):
        for data in ([], {}, [None], [{"species": "../escape"}]):
            self.assertTrue(self.check_entries(data))


if __name__ == "__main__":
    unittest.main()
