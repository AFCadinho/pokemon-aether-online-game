#!/usr/bin/env python3
"""Reuse the immutable, already qualified model release without republishing it.

Consumer releases have their own game certification. Historical publication code
hashes remain historical; this check binds the delivered bytes to that receipt.
"""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
BASE_URL = 'https://updates.pokeaether.com/'
FIELDS = ('object_key', 'sha256', 'size_bytes')


def require(value, message):
    if not value:
        raise ValueError(message)


def load(path):
    return json.loads(path.read_bytes())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verified_metadata(root=ROOT):
    release = root / 'release'
    meta = load(release / 'approved_3d_bundles_v16.json')
    receipt = load(release / 'approved_3d_bundles_v16_r2_receipt.json')
    binding = load(release / 'approved_3d_v16_binding.json')
    index_path = release / 'approved_3d_bundles_v16_index.json'
    index = load(index_path)
    revision = 'approved-pokemon-3d-v16'
    require(meta['revision'] == receipt['revision'] == binding['revision'] == index['catalog_revision'] == revision, 'Wrong revision')
    require(binding['runtime_approved'] and binding['publication_approved'], 'Unqualified historical publication')
    require(receipt['binding_sha256'] == digest(release / 'approved_3d_v16_binding.json'), 'Historical publication binding changed')
    require(index['production_approved'] and not index['prototype_only'], 'Diagnostic index')
    require(meta['index'] == receipt['content_index'], 'Published index changed')
    require(meta['index']['sha256'] == binding['bundle_index_sha256'] == digest(index_path), 'Index hash changed')
    require(index_path.stat().st_size == meta['index']['size_bytes'], 'Index size changed')
    require(digest(release / 'approved_3d_v16_native_qualification.json') == binding['native_qualification_sha256'], 'Native proof changed')
    require(digest(release / 'approved_3d_v16_runtime_qualification.json') == binding['runtime_qualification_sha256'], 'Runtime proof changed')
    require(len(meta['bundles']) == len(receipt['bundles']) == len(index['assets']) == 1421, 'Incomplete collection')
    require(len({r['asset_id'] for r in meta['bundles']}) == 1421, 'Duplicate model')
    require(sum(r['size_bytes'] for r in meta['bundles']) == meta['total_bundle_bytes'], 'Collection size changed')
    for row, proof in [(meta['index'], receipt['index_verification']), *zip(meta['bundles'], receipt['bundles'], strict=True)]:
        require(all(row[k] == proof[k] for k in FIELDS), 'Published object changed')
        if 'asset_id' in row:
            require(row['asset_id'] == proof['asset_id'], 'Published model identity changed')
        require(proof['public_get_sha256_verified'] and proof['public_head_size_verified'], 'Missing public verification')
    for side in ('data', 'launcher/data'):
        descriptor = load(root / side / 'approved_3d_release_v16.json')
        require(descriptor['revision'] == revision and descriptor['index'] == meta['index'], 'Client index differs')
        require(descriptor['requiredAssetIds'] == [r['asset_id'] for r in meta['bundles']], 'Client collection differs')
        require((root / side / 'approved_3d_bundles_v16_index.json').read_bytes() == index_path.read_bytes(), 'Client index bytes differ')
        require(digest(root / side / 'model_pair_release_v16_catalog.json') == binding['trusted_catalog_sha256'], 'Compiled catalog changed')
    return meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--remote', action='store_true')
    args = parser.parse_args()
    meta = verified_metadata()
    if args.remote:
        row = meta['index']
        request = Request(BASE_URL + row['object_key'], headers={'User-Agent': 'PokeAether-ModelVerifier/1.0'})
        with urlopen(request, timeout=60) as response:
            raw = response.read(row['size_bytes'] + 1)
        require(len(raw) == row['size_bytes'] and hashlib.sha256(raw).hexdigest() == row['sha256'], 'Public index differs')
    print('V16_PUBLISHED_COLLECTION_OK archives=1421; no uploads or manifest changes')


if __name__ == '__main__':
    main()
