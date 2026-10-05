#!/usr/bin/env python3
"""Check v9 pins, preserved v8 records, packaging, and malformed descriptors."""
import json
from package_approved_3d_release_v9 import ROOT, build
from package_launcher_release import _build_asset_bundle_index
from publish_approved_3d_index_v9 import validate_local


def main():
    metadata = validate_local()
    index = json.loads(build()[0])
    old = json.loads((ROOT / 'release/approved_3d_bundles_v8_index.json').read_bytes())
    old_assets = {a['asset_id']: a for a in old['assets']}
    new_assets = {a['asset_id']: a for a in index['assets']}
    assert all(new_assets[k] == value for k, value in old_assets.items())
    assert set(new_assets) - set(old_assets) == {
        'pokemon_3d:articuno-galar:base', 'pokemon_3d:zapdos-galar:base', 'pokemon_3d:moltres-galar:base'}
    pin = metadata['index']
    entry = f"{metadata['revision']}:{pin['object_key']}:{pin['size_bytes']}:{pin['sha256']}"
    descriptor = _build_asset_bundle_index(entry, 'https://updates.pokeaether.com')
    assert set(descriptor['requiredAssetIds']) == set(new_assets)
    assert len(descriptor['requiredAssetIds']) == 1142
    try:
        _build_asset_bundle_index(entry[:-64] + '0' * 64, 'https://updates.pokeaether.com')
    except SystemExit:
        pass
    else:
        raise AssertionError('Packaging accepted a tampered v9 hash')
    path = ROOT / '.tmp/galar-birds-r2-v1/packaged-v9-descriptor.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(descriptor))
    print('PACKAGE_APPROVED_3D_V9_OK preserved_v8=1139 added=3 exact_ids=true tamper_rejected=true')


if __name__ == '__main__':
    main()
