#!/usr/bin/env python3
"""Verify the staged shared-geometry collection and publish its immutable production index."""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path

from publish_shared_model_collection import load_credentials, publish_immutable, snapshot_manifests
from publish_approved_3d_index_v8 import public_head

ROOT = Path(__file__).resolve().parents[1]
META = ROOT / 'release/approved_3d_bundles_v13.json'
INDEX = ROOT / 'release/approved_3d_bundles_v13_index.json'
RECEIPT = ROOT / 'release/approved_3d_bundles_v13_r2_receipt.json'
FIELDS = ('asset_id', 'object_key', 'sha256', 'size_bytes')


def read(path):
    return json.loads(path.read_bytes())


def digest(data):
    return hashlib.sha256(data).hexdigest()


def validate_local():
    metadata = read(META)
    index_bytes = INDEX.read_bytes()
    index = json.loads(index_bytes)
    pin = metadata['index']
    assert metadata['schema'] == 1 and metadata['kind'] == 'pokeaether-approved-3d-release'
    assert metadata['revision'] == index['catalog_revision'] == 'approved-pokemon-3d-v13'
    assert index['production_approved'] is True and index['prototype_only'] is False
    diagnostic = read(ROOT / 'data/model_pair_geometry.json')
    assert index == {**diagnostic, 'catalog_revision': metadata['revision'],
                     'production_approved': True, 'prototype_only': False}
    assert pin == {'object_key': 'optional-assets/pokemon_3d/index/v13-' + digest(index_bytes) + '.json',
                   'sha256': digest(index_bytes), 'size_bytes': len(index_bytes)}
    assert INDEX.read_bytes() == (ROOT / 'data/approved_3d_bundles_v13_index.json').read_bytes()
    assert INDEX.read_bytes() == (ROOT / 'launcher/data/approved_3d_bundles_v13_index.json').read_bytes()
    for side in ('data', 'launcher/data'):
        release = read(ROOT / side / 'approved_3d_release_v13.json')
        assert release == {'schema': 1, 'revision': metadata['revision'], 'index': pin,
                           'requiredAssetIds': [a['asset_id'] for a in metadata['bundles']]}
    stage = read(ROOT / 'release/shared_model_geometry_r2_receipt.json')
    repair = read(ROOT / 'release/approved_3d_bundles_v12_r2_receipt.json')
    assert stage['production_approved'] is False and stage['active_manifest_activated'] is False
    assert repair['active_manifest_activated'] is False
    assert all(a['public_get_sha256_verified'] and a['public_head_size_verified'] for a in stage['bundles'])
    assert all(a['public_get_sha256_verified'] and a['public_head_size_verified'] for a in repair['replacement_shared_packs'])
    old = {a['asset_id']: a for a in stage['bundles']}
    replacement = [a for a in repair['replacement_shared_packs'] if a['object_key'].endswith('.pck') and '/v5-' in a['object_key']]
    assert len(replacement) == 1 and replacement[0]['asset_id'] == 'pokemon_3d:hawlucha:mega'
    old[replacement[0]['asset_id']] = replacement[0]
    assert len(index['assets']) == len(metadata['bundles']) == len(old) == 1200
    assert len({a['asset_id'] for a in metadata['bundles']}) == 1200
    trusted = {a['asset_id']: a for a in read(ROOT / 'data/model_pair_catalog.json')['assets']}
    trusted.update({a['asset_id']: a for a in read(ROOT / 'data/model_pair_geometry_catalog.json')['assets']})
    for compact, row in zip(index['assets'], metadata['bundles']):
        assert compact['asset_id'] == row['asset_id']
        asset = trusted[row['asset_id']] if compact.get('format') == 'model-pair-ref-v1' else compact
        assert all(asset[field] == row[field] for field in FIELDS)
        if compact.get('format') == 'model-pair-ref-v1':
            assert set(compact) == {'asset_id', 'format', 'sha256'}
            assert compact['sha256'] == asset['sha256']
        proof = old[row['asset_id']]
        assert all(row[field] == proof[field] for field in FIELDS)
    if RECEIPT.exists():
        receipt = read(RECEIPT)
        assert receipt['revision'] == metadata['revision'] and receipt['content_index'] == pin
        assert len(receipt['bundles']) == 1200
        assert all(all(row[field] == proof[field] for field in FIELDS)
                   and proof['public_get_sha256_verified'] and proof['public_head_size_verified']
                   for row, proof in zip(metadata['bundles'], receipt['bundles']))
        assert receipt['index_verification']['public_get_sha256_verified']
        assert receipt['index_verification']['public_head_size_verified']
    return metadata, old


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--credentials', type=Path, help='Read existing local credentials in place')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    metadata, proof = validate_local()
    print('V13_LOCAL_OK bundles=1200 index_sha256=' + metadata['index']['sha256'], flush=True)
    if not args.apply:
        return
    config = load_credentials(args.credentials)
    before = snapshot_manifests()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        if not all(pool.map(public_head, metadata['bundles'])):
            raise ValueError('A previously verified model payload is no longer publicly available')
    index_proof = publish_immutable(config, INDEX, metadata['index'])
    if snapshot_manifests() != before:
        raise ValueError('Active manifests changed during index publication')
    if RECEIPT.exists():
        assert read(RECEIPT)['index_verification']['sha256'] == metadata['index']['sha256']
    else:
        rows = [{**row, 'public_get_sha256_verified': True, 'public_head_size_verified': True,
                 'proof_source': 'v12-repair' if row['asset_id'] == 'pokemon_3d:hawlucha:mega' else 'geometry-stage'}
                for row in metadata['bundles']]
        receipt = {'schema': 1, 'revision': metadata['revision'], 'content_index': metadata['index'],
                   'bundles': rows, 'index_verification': index_proof, 'active_manifest_activated': False,
                   'manifest_snapshots': before, 'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat()}
        RECEIPT.write_text(json.dumps(receipt, sort_keys=True, indent=2) + '\n')
    print('V13_PUBLICATION_OK bundles=1200 index_verified=true manifest_activated=false', flush=True)


if __name__ == '__main__':
    main()
