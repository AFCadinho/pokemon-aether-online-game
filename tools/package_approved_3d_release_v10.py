#!/usr/bin/env python3
"""Extend immutable v9 with the 58 approved, published regional form bundles."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'approved-pokemon-3d-v10'
NAMES = {a['species_id'] for a in json.loads((ROOT / 'tools/sprite_factory/regional_model_bundle_qualification.json').read_text())['bundle_index']['assets']}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode()


def build():
    release = ROOT / 'release'
    old_bytes = (release / 'approved_3d_bundles_v9_index.json').read_bytes()
    old = json.loads(old_bytes)
    old_metadata = json.loads((release / 'approved_3d_bundles_v9.json').read_bytes())
    assert sha(old_bytes) == old_metadata['index']['sha256']
    assert len(old_bytes) == old_metadata['index']['size_bytes']
    assert old['catalog_revision'] == 'approved-pokemon-3d-v9' and len(old['assets']) == 1142
    new_bytes = (release / 'approved_3d_regional_58_index.json').read_bytes()
    new = json.loads(new_bytes)
    receipt_bytes = (release / 'approved_3d_regional_58_r2_upload.json').read_bytes()
    receipt = json.loads(receipt_bytes)
    qualification = (ROOT / 'tools/sprite_factory/regional_model_bundle_qualification.json').read_bytes()
    assert receipt['bundle_qualification_sha256'] == sha(qualification)
    qualified = json.loads(qualification)
    assert all(qualified[key] for key in ('appearance_approved', 'battle_approved', 'runtime_approved'))
    assert new == qualified['bundle_index']
    assert receipt['content_index']['sha256'] == sha(new_bytes)
    assert receipt['content_index']['size_bytes'] == len(new_bytes)
    assert receipt['public_get_sha256_verified_objects'] == receipt['public_head_size_verified_objects'] == 59
    assert {a['species_id'] for a in new['assets']} == NAMES and len(new['assets']) == 58
    published = {a['asset_id']: a for a in receipt['bundles']}
    for asset in new['assets']:
        assert published[asset['asset_id']]['public_get_sha256_verified']
        assert published[asset['asset_id']]['public_head_size_verified']
        assert all(published[asset['asset_id']][key] == asset[key] for key in ('object_key', 'sha256', 'size_bytes'))
    assets = sorted(old['assets'] + new['assets'], key=lambda a: a['asset_id'])
    assert len({a['asset_id'] for a in assets}) == 1200
    registry = json.loads((ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json').read_bytes())
    assert sha(qualification) == registry['regional_58_bundle_qualification_sha256']
    covered = {}
    for asset in assets:
        assert asset['asset_id'] == f"pokemon_3d:{asset['species_id']}:{asset['form_id']}"
        assert len(asset['appearances']) == 2
        assert {a['variant'] for a in asset['appearances']} == {'normal', 'shiny'}
        for appearance in asset['appearances']:
            identity = appearance['runtime_identity']
            assert identity not in covered
            assert registry['models'][identity]['sha256'] == appearance['runtime_sha256']
            covered[identity] = True
    assert set(covered) == set(registry['models']) and len(covered) == 2400
    index = {**old, 'catalog_revision': REVISION, 'assets': assets}
    data = encoded(index)
    assert len(data) <= 1024 * 1024
    pin = {'object_key': f'optional-assets/pokemon_3d/index/{REVISION}-{sha(data)}.json',
           'sha256': sha(data), 'size_bytes': len(data)}
    metadata = {'schema': 1, 'kind': 'pokeaether-approved-3d-release', 'revision': REVISION,
                'index': pin, 'bundles': [{k: a[k] for k in ('asset_id', 'object_key', 'sha256', 'size_bytes')} for a in assets],
                'new_bundle_count': 58, 'total_bundle_bytes': sum(a['size_bytes'] for a in assets),
                'source_receipts_sha256': {'approved_3d_regional_58_r2_upload.json': sha(receipt_bytes)},
                'previous_index_sha256': sha(old_bytes)}
    client = {'schema': 1, 'revision': REVISION, 'index': pin, 'requiredAssetIds': [a['asset_id'] for a in assets]}
    return data, encoded(metadata), encoded(client)


def main():
    index, metadata, client = build()
    for path, data in [('release/approved_3d_bundles_v10_index.json', index),
                       ('release/approved_3d_bundles_v10.json', metadata),
                       ('data/approved_3d_release_v10.json', client),
                       ('launcher/data/approved_3d_release_v10.json', client)]:
        (ROOT / path).write_bytes(data)
    print(f'V10_PREPARED bundles=1200 appearances=2400 index_bytes={len(index)}')


if __name__ == '__main__':
    main()
