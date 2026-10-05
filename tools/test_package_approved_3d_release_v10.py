#!/usr/bin/env python3
"""Check v10 pins, preserved v9 records, packaging, and malformed descriptors."""
import json
from package_approved_3d_release_v10 import ROOT, build
from package_launcher_release import _build_asset_bundle_index
from publish_approved_3d_index_v10 import validate_local


def main():
    metadata = validate_local()
    index = json.loads(build()[0])
    old = json.loads((ROOT / 'release/approved_3d_bundles_v9_index.json').read_bytes())
    old_assets = {a['asset_id']: a for a in old['assets']}
    new_assets = {a['asset_id']: a for a in index['assets']}
    assert all(new_assets[k] == value for k, value in old_assets.items())
    cohort = json.loads((ROOT / 'release/approved_3d_regional_58_index.json').read_text())
    assert set(new_assets) - set(old_assets) == {a['asset_id'] for a in cohort['assets']}
    assert len(cohort['assets']) == 58
    pin = metadata['index']
    entry = f"{metadata['revision']}:{pin['object_key']}:{pin['size_bytes']}:{pin['sha256']}"
    descriptor = _build_asset_bundle_index(entry, 'https://updates.pokeaether.com')
    assert set(descriptor['requiredAssetIds']) == set(new_assets)
    assert len(descriptor['requiredAssetIds']) == 1200
    try:
        _build_asset_bundle_index(entry[:-64] + '0' * 64, 'https://updates.pokeaether.com')
    except SystemExit:
        pass
    else:
        raise AssertionError('Packaging accepted a tampered v10 hash')
    path = ROOT / '.tmp/regional-production-v1/publication-v1/packaged-v10-descriptor.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(descriptor))
    print('PACKAGE_APPROVED_3D_V10_OK preserved_v9=1142 added=58 exact_ids=true tamper_rejected=true')


if __name__ == '__main__':
    main()
