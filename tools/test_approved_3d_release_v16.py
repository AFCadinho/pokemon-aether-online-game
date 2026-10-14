"""Release admission rejects forged pools, incomplete proofs and legacy ZIP edits."""
import copy
from pathlib import Path
import unittest
from unittest.mock import patch

import publish_approved_3d_index_v16 as publisher
from package_launcher_release import _build_asset_bundle_index


class V16ReleaseChecks(unittest.TestCase):
    def test_complete_pin_and_publication_admission(self):
        meta = publisher.validate_local()
        self.assertEqual(meta['total_bundle_bytes'], 6989696054)
        self.assertEqual(meta['saved_download_bytes'], 1805630084)
        pin = meta['index']
        entry = f"{meta['revision']}:{pin['object_key']}:{pin['size_bytes']}:{pin['sha256']}"
        descriptor = _build_asset_bundle_index(entry, 'https://updates.pokeaether.com')
        self.assertEqual(len(descriptor['requiredAssetIds']), 1421)
        for bad in [entry.replace(pin['sha256'], '0' * 64), entry.replace(meta['revision'], 'approved-pokemon-3d-v15')]:
            with self.assertRaises(SystemExit):
                _build_asset_bundle_index(bad, 'https://updates.pokeaether.com')

    def reject_changed_document(self, filename, mutation):
        original_read = publisher.read
        changed = copy.deepcopy(original_read(publisher.ROOT / filename))
        mutation(changed)

        def read(path):
            return changed if Path(path) == publisher.ROOT / filename else original_read(path)

        with patch.object(publisher, 'read', side_effect=read):
            with self.assertRaises(ValueError):
                publisher.validate_local()

    def test_unapproved_runtime_and_changed_code_rejected(self):
        self.reject_changed_document('release/approved_3d_v16_binding.json', lambda d: d.update(runtime_approved=False))
        self.reject_changed_document('release/approved_3d_v16_binding.json',
            lambda d: d['code_bindings'].update({'scripts/services/model_pair_pack.gd': '0' * 64}))

    def test_incomplete_and_duplicate_native_proof_rejected(self):
        self.reject_changed_document('release/approved_3d_v16_native_qualification.json', lambda d: d['records'].pop())
        self.reject_changed_document('release/approved_3d_v16_native_qualification.json',
            lambda d: d['records'].__setitem__(1, d['records'][0]))

    def test_pool_metadata_cannot_change_behind_compact_reference(self):
        def change(catalog):
            pool = next(a for a in catalog['assets'] if a['format'] == 'model-texture-pck-v1')
            pool['sha256'] = '0' * 64

        self.reject_changed_document('data/model_pair_release_v16_catalog.json', change)

    def test_retained_zip_metadata_cannot_acquire_new_dependency(self):
        def change(index):
            zip_asset = next(a for a in index['assets'] if a.get('format') != 'model-pair-ref-v1')
            zip_asset['dependencies'] = ['pokemon_3d:unapproved:base']

        self.reject_changed_document('release/approved_3d_bundles_v16_index.json', change)


if __name__ == '__main__':
    unittest.main()
