"""Regression evidence, not a decoder or an approval of a guessed clock."""
import json
from pathlib import Path
import tempfile
import unittest

from scvi_tracm import inspect_visibility
from test_scvi_tracm import visibility_fixture
from visibility_export import keys


class DynamicSourceEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.audit = json.loads(Path(__file__).with_name(
            'visibility_dynamic_audit.json').read_text())

    def test_observed_payloads_survive_binary_inspection(self):
        self.assertEqual(len(self.audit['rows']), 18)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'evidence.tracm'
            for row in self.audit['rows']:
                with self.subTest(source=row['source'], target=row['track']['target']):
                    payload = row['track']['packed_bytes']
                    path.write_bytes(visibility_fixture(2, payload))
                    decoded = inspect_visibility(path)[0]
                    self.assertEqual(decoded['packed_bytes'], payload)
                    self.assertEqual(decoded['encoding'], 'dynamic_bool')
                    self.assertEqual(decoded['frames'], [])
                    self.assertIsNone(decoded['fixed_value'])
                    self.assertLess(8 * len(payload), row['frames'])

    def test_real_short_streams_remain_explicit_holds(self):
        # Neither byte-to-bool conversion, spreading bits across a clip, nor
        # repeating the last bit is a verified source playback reference.
        for row in self.audit['rows']:
            with self.subTest(source=row['source'], target=row['track']['target']):
                with self.assertRaisesRegex(ValueError, 'dynamic visibility clock'):
                    keys(row['track'], row['frames'], row['fps'])


if __name__ == '__main__':
    unittest.main()
