import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch
from probe_v13_compression import write
from summarize_full_texture_audit import summarize


class WholeCollectionProofTest(unittest.TestCase):
    def test_partial_measurement_cannot_claim_whole_collection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write(root/'configuration.json', {})
            write(root/'report.json', {'complete': False, 'measured_complete': True, 'pairs': 3})
            with self.assertRaisesRegex(ValueError, 'partial audit'):
                summarize(root/'report.json')

    def test_changed_configuration_cannot_reuse_proof(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write(root/'configuration.json', {'changed': True})
            write(root/'report.json', {'complete': True, 'measured_complete': True,
                                      'pairs': 1365, 'configuration_sha256': '0'*64})
            with self.assertRaisesRegex(ValueError, 'Changed configuration'):
                summarize(root/'report.json')

    def test_duplicate_pairs_cannot_fill_the_collection_count(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write(root/'configuration.json', {'inputs': {}})
            from study_lossless_texture_storage import sha
            write(root/'report.json', {'complete': True, 'measured_complete': True, 'pairs': 1365,
                                      'configuration_sha256': sha(root/'configuration.json'),
                                      'records': [{'asset_id': 'repeated'}]*1365})
            with patch('summarize_full_texture_audit.base.catalog', return_value=({}, [{'asset_id': 'unique'}])):
                with self.assertRaisesRegex(ValueError, 'Duplicate or missing'):
                    summarize(root/'report.json')


if __name__ == '__main__': unittest.main()
