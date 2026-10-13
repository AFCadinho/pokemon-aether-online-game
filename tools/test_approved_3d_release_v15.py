"""Ensure a v15 update preserves historical pins and exact source contracts."""
import copy
import unittest

from audit_cross_form_resources import catalog
from package_approved_3d_release_v15 import BINDING, ROOT, read, replacement_contract, sha
from publish_approved_3d_index_v15 import validate_local


class V15Release(unittest.TestCase):
    def test_manifest_packager_accepts_only_complete_v15_pin(self):
        from package_launcher_release import _build_asset_bundle_index
        meta = read(ROOT / 'release/approved_3d_bundles_v15.json')
        pin = meta['index']
        entry = f"{meta['revision']}:{pin['object_key']}:{pin['size_bytes']}:{pin['sha256']}"
        descriptor = _build_asset_bundle_index(entry, 'https://updates.pokeaether.com')
        self.assertEqual(descriptor['requiredAssetIds'], [a['asset_id'] for a in meta['bundles']])
        self.assertEqual(len(descriptor['requiredAssetIds']), 1420)
        for bad in [entry.replace(pin['sha256'], '0' * 64), entry.replace(meta['revision'], 'approved-pokemon-3d-v14')]:
            with self.assertRaises(SystemExit):
                _build_asset_bundle_index(bad, 'https://updates.pokeaether.com')

    def test_complete_qualified_catalog_and_unchanged_bundles(self):
        meta = validate_local()
        previous, assets = catalog()
        old = {a['asset_id']: a for a in previous['bundles']}
        changes = read(BINDING)['replacements']
        current = {a['asset_id']: a for a in read(ROOT / 'data/model_pair_release_v15_catalog.json')['assets']}
        self.assertEqual((meta['total_bundle_bytes'], meta['saved_download_bytes']), (8795326138, 198171932))
        self.assertEqual(len(changes), 111)
        unchanged = 0
        for asset in assets:
            key = asset['asset_id']
            row = next(r for r in meta['bundles'] if r['asset_id'] == key)
            if key in changes:
                self.assertEqual(changes[key]['previous'], old[key])
                self.assertEqual(changes[key]['approved'], row)
                self.assertEqual(current[key]['version'], asset['version'] + 1)
                self.assertNotEqual(current[key]['pair_manifest']['resource_root'], asset['pair_manifest']['resource_root'])
            else:
                self.assertEqual(row, old[key])
                if key in current:
                    self.assertEqual(current[key], asset)
                unchanged += 1
        self.assertEqual(unchanged, 1309)

    def test_reviewed_profiles_and_previous_admission_untouched(self):
        binding = read(BINDING)
        self.assertEqual(binding['reviewed_registry_sha256'], sha(ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'))
        self.assertEqual(binding['previous_binding_sha256'], sha(ROOT / 'release/approved_3d_v14_binding.json'))
        self.assertTrue(binding['profiles_unchanged'])
        self.assertEqual((binding['actual_presenter_pairs'], binding['actual_battles'], binding['actual_previews']), (111, 222, 888))

    def test_reject_source_budget_version_and_identity_changes(self):
        # Actual checked-in release assets, also available to CI without packs.
        key = sorted(read(BINDING)['replacements'])[0]
        asset = next(a for a in read(ROOT / 'data/model_pair_release_v15_catalog.json')['assets'] if a['asset_id'] == key)
        _, previous = catalog()
        old = next(a for a in previous if a['asset_id'] == key)
        record = {'asset': asset, 'baseline_sha256': old['sha256'], 'baseline_bytes': old['size_bytes'],
                  'verification': {'ok': True}, 'smaller': True, 'path': '/not-read-by-contract-check.pck'}
        self.assertEqual(replacement_contract(old, record)['sha256'], asset['sha256'])
        mutations = [lambda a: a.update(version=old['version']),
                     lambda a: a.update(species_id='wrong-species'),
                     lambda a: a['appearances'][0].update(source_sha256='0' * 64),
                     lambda a: a['appearances'][0].update(cache_source_bytes=1),
                     lambda a: a['pair_manifest'].update(resource_root=old['pair_manifest']['resource_root'])]
        for mutation in mutations:
            bad = copy.deepcopy(record)
            mutation(bad['asset'])
            with self.assertRaises(AssertionError):
                replacement_contract(old, bad)


if __name__ == '__main__':
    unittest.main()
