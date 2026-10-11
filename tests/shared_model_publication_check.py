#!/usr/bin/env python3
"""Immutable staging must fail closed before writes and never overwrite a key."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import publish_shared_model_collection as tool
import verify_shared_model_publication as verifier
from shared_model_publication_helpers import validate_selection


class PublicationCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'payload.pck'
        self.path.write_bytes(b'payload')
        size, sha = tool.file_digest(self.path)
        self.row = {'object_key': 'optional-assets/pokemon_3d/example/base/v3-' + sha + '.pck',
                    'size_bytes': size, 'sha256': sha, 'asset_id': 'pokemon_3d:example:base'}

    def test_exact_selection(self):
        wire, assets = validate_selection(ROOT)
        self.assertEqual(len(assets), 1200)
        self.assertEqual(sum(a.get('format') == 'model-pair-pck-v1' for a in assets), 1082)
        self.assertEqual(len(wire), 236908)
        self.assertEqual(next(a for a in assets if a['asset_id'] == 'pokemon_3d:greninja:base').get('format'), None)
        self.assertEqual(next(a for a in assets if a['asset_id'] == 'pokemon_3d:inkay:base').get('format'), None)

    def test_verified_existing_object_is_reused(self):
        with patch.object(tool, 'public', return_value=True), patch.object(tool, '_upload_file') as upload:
            self.assertFalse(tool.publish_immutable(None, self.path, self.row)['uploaded'])
            upload.assert_not_called()

    def test_existing_bad_or_hidden_object_is_never_overwritten(self):
        for status in (200, 403, 500):
            with self.subTest(status=status), patch.object(tool, 'public', return_value=False), patch.object(tool, '_signed_request', return_value=(status, '', b'')), patch.object(tool, '_upload_file') as upload:
                with self.assertRaises(ValueError):
                    tool.publish_immutable(None, self.path, self.row)
                upload.assert_not_called()

    def test_changed_local_payload_is_not_uploaded(self):
        self.path.write_bytes(b'changed')
        with patch.object(tool, 'public', return_value=False), patch.object(tool, '_signed_request', return_value=(404, '', b'')), patch.object(tool, '_upload_file') as upload:
            with self.assertRaises(ValueError):
                tool.publish_immutable(None, self.path, self.row)
            upload.assert_not_called()

    def test_new_object_requires_get_and_head(self):
        with patch.object(tool, 'public', side_effect=[False, True, True]), patch.object(tool, '_signed_request', return_value=(404, '', b'')), patch.object(tool, '_upload_file') as upload:
            result = tool.publish_immutable(None, self.path, self.row)
            self.assertTrue(result['uploaded'])
            upload.assert_called_once_with(None, self.path, self.row['object_key'])

    def test_bad_public_head_is_rejected(self):
        with patch.object(tool, 'public', side_effect=[True, False]):
            with self.assertRaises(ValueError):
                tool.publish_immutable(None, self.path, self.row)

    def test_receipt_row_requires_exact_hash_and_both_public_checks(self):
        valid = {**self.row, 'uploaded': False, 'public_get_sha256_verified': True,
                 'public_head_size_verified': True}
        verifier.verify_row(valid, self.row)
        for key, value in [('sha256', '0' * 64), ('size_bytes', 0),
                           ('public_get_sha256_verified', False),
                           ('public_head_size_verified', False), ('uploaded', None)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                verifier.verify_row({**valid, key: value}, self.row)


if __name__ == '__main__':
    unittest.main()
