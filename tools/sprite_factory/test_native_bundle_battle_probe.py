from pathlib import Path
import tempfile
import unittest

from run_native_bundle_battle_validation import restore_registry


class RegistryRestorationTests(unittest.TestCase):
    def test_exact_source_bytes_restored_after_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "registry.json"
            original = b'{ "models": {} }\n'
            fixture = b'{"models":{"fixture":{"sha256":"test"}}}\n'
            path.write_bytes(fixture)
            restore_registry(path, fixture, original)
            self.assertEqual(path.read_bytes(), original)

    def test_unexpected_concurrent_edit_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "registry.json"
            unexpected = b'{"unrelated-edit":true}\n'
            path.write_bytes(unexpected)
            with self.assertRaisesRegex(ValueError, "changed concurrently"):
                restore_registry(path, b'fixture', b'original')
            self.assertEqual(path.read_bytes(), unexpected)


if __name__ == "__main__":
    unittest.main()
