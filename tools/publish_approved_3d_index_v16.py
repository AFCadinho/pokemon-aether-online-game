#!/usr/bin/env python3
"""Publish qualified immutable v16 objects; active player manifests stay untouched."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import datetime
import hashlib
from pathlib import Path
import subprocess

from probe_v13_compression import read, write, require, encoded
from publish_shared_model_collection import load_credentials, publish_immutable, snapshot_manifests, file_digest
from publish_approved_3d_index_v8 import public_head
from study_lossless_texture_storage import ROOT, sha

FIELDS = ['asset_id', 'object_key', 'sha256', 'size_bytes']


def validate_local():
    meta = read(ROOT / 'release/approved_3d_bundles_v16.json')
    binding = read(ROOT / 'release/approved_3d_v16_binding.json')
    index = ROOT / 'release/approved_3d_bundles_v16_index.json'
    wire = read(index)
    require(meta['revision'] == binding['revision'] == wire['catalog_revision'] == 'approved-pokemon-3d-v16', 'Wrong release')
    require(binding['runtime_approved'] and binding['publication_approved'], 'Unqualified release')
    require(wire['production_approved'] and not wire['prototype_only'], 'Diagnostic index')
    require(sha(index) == meta['index']['sha256'] == binding['bundle_index_sha256'], 'Wrong index pin')
    require(index.stat().st_size == meta['index']['size_bytes'], 'Wrong index size')
    require(len(meta['bundles']) == len(wire['assets']) == 1421, 'Incomplete release')
    require(len({r['asset_id'] for r in meta['bundles']}) == 1421, 'Duplicate asset IDs')
    require(sum(r['size_bytes'] for r in meta['bundles']) == meta['total_bundle_bytes'] < 7_000_000_000, 'Wrong collection size')
    require(sha(ROOT / 'release/approved_3d_v15_binding.json') == binding['previous_binding_sha256'], 'Historical binding changed')
    require(sha(ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json') == binding['reviewed_registry_sha256'], 'Reviewed profiles changed')
    for name, expected in binding['code_bindings'].items():
        require(sha(ROOT / name) == expected, 'Qualified code changed: ' + name)
    trusted_path = ROOT / 'data/model_pair_release_v16_catalog.json'
    require(sha(trusted_path) == binding['trusted_catalog_sha256'], 'Compiled catalog changed')
    trusted = read(trusted_path)
    assets = {a['asset_id']: a for a in trusted['assets']}
    require(len(assets) == 1366 and sum(len(a['appearances']) for a in assets.values()) == 2730, 'Wrong PCK appearance count')
    for filename, key in [('approved_3d_v16_native_qualification.json', 'native_qualification_sha256'),
                          ('approved_3d_v16_runtime_qualification.json', 'runtime_qualification_sha256')]:
        require(sha(ROOT / 'release' / filename) == binding[key], 'Qualification receipt changed')
    native = read(ROOT / 'release/approved_3d_v16_native_qualification.json')
    previous = {a['asset_id']: a for a in read(ROOT / 'data/model_pair_release_v15_catalog.json')['assets']}
    retained = {a['asset_id']: a for a in read(ROOT / 'release/approved_3d_bundles_v15_index.json')['assets']
                if a.get('format') != 'model-pair-ref-v1'}
    require(len(retained) == 55, 'Wrong historical ZIP cohort')
    pools = [a for a in assets.values() if a.get('format') == 'model-texture-pck-v1']
    require(len(pools) == 1 and not pools[0]['appearances'] and not pools[0]['dependencies'], 'Wrong texture pool cohort')
    consumers = [a for a in assets.values() if a.get('pair_manifest', {}).get('texture_pools')]
    require(len(consumers) == 8 and all(a['pair_manifest']['texture_pools'] == pools for a in consumers), 'Wrong inline pool bindings')
    require(len(native['records']) == len({r['asset_id'] for r in native['records']}) == 1365, 'Incomplete native proof')
    for row in native['records']:
        asset = assets[row['asset_id']]
        require(row['candidate_sha256'] == asset['sha256'] and row['source_sha256'] == previous[row['asset_id']]['sha256'], 'Native archive proof differs')
        require([r['identity'] for r in row['looks']] == [a['runtime_identity'] for a in asset['appearances']], 'Native appearance proof differs')
    for side in ['data', 'launcher/data']:
        require((ROOT / side / 'approved_3d_bundles_v16_index.json').read_bytes() == index.read_bytes(), 'Game/launcher index differs')
        require((ROOT / side / 'model_pair_release_v16_catalog.json').read_bytes() == trusted_path.read_bytes(), 'Game/launcher bindings differ')
        client = read(ROOT / side / 'approved_3d_release_v16.json')
        require(client['index'] == meta['index'] and client['revision'] == meta['revision'] and
                client['requiredAssetIds'] == [a['asset_id'] for a in meta['bundles']], 'Game/launcher descriptor differs')
    for compact, pin in zip(wire['assets'], meta['bundles'], strict=True):
        asset = assets[compact['asset_id']] if compact.get('format') == 'model-pair-ref-v1' else compact
        require(all(asset[k] == pin[k] for k in FIELDS), 'Archive binding differs')
        if compact.get('format') == 'model-pair-ref-v1':
            require(compact == {'asset_id': asset['asset_id'], 'format': 'model-pair-ref-v1', 'sha256': asset['sha256']}, 'Invalid compact reference')
        else:
            require(asset == retained.get(asset['asset_id']), 'Retained ZIP changed')
    return meta


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path)
    parser.add_argument('--credentials', type=Path)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--requalify-receipt', action='store_true', help='Rebind unchanged published payloads after a qualified consumer-only release fix')
    parser.add_argument('--workers', type=int, choices=range(1, 9), default=6)
    args = parser.parse_args()
    meta = validate_local()
    print('V16_LOCAL_OK archives=1421 bytes=' + str(meta['total_bundle_bytes']), flush=True)
    if not args.apply:
        return
    source = None
    if args.sources:
        source = read(args.sources)
        require(source['revision'] == meta['revision'] and source['metadata_sha256'] == sha(ROOT / 'release/approved_3d_bundles_v16.json'), 'Wrong source mapping')
        require(set(source['sources']) == {a['asset_id'] for a in meta['bundles']}, 'Incomplete sources')

        def precheck(row):
            path = Path(source['sources'][row['asset_id']])
            require(path.is_absolute() and path.is_file(), 'Missing retained archive')
            require(file_digest(path) == (row['size_bytes'], row['sha256']), 'Retained archive changed: ' + row['asset_id'])
            return True

        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            require(all(executor.map(precheck, meta['bundles'])), 'Archive preflight failed')
    config = load_credentials(args.credentials)
    before = snapshot_manifests()
    receipt = ROOT / 'release/approved_3d_bundles_v16_r2_receipt.json'
    if args.sources:
        checkpoint = ROOT / '.tmp/model-v16-publication'
        checkpoint.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.datetime.now(datetime.UTC).strftime('%Y%m%dT%H%M%S%fZ')
        write(checkpoint / ('preflight-' + timestamp + '.json'), {
            'source_commit': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
            'revision': meta['revision'], 'binding_sha256': sha(ROOT / 'release/approved_3d_v16_binding.json'),
            'manifest_snapshots': before, 'objects': meta['bundles'], 'index': meta['index'],
            'sources_sha256': sha(args.sources), 'active_manifest_activation': False})

        def publish(row):
            path = Path(source['sources'][row['asset_id']])
            require(path.is_absolute() and path.is_file(), 'Missing retained archive')
            proof = publish_immutable(config, path, row)
            write(checkpoint / (row['sha256'] + '.json'), proof)
            print('V16_OBJECT_OK ' + row['asset_id'], flush=True)
            return proof

        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            rows = list(executor.map(publish, meta['bundles']))
    else:
        require(receipt.exists(), 'Upload retained archives locally before CI publication')
        historical = read(receipt)
        require(historical['content_index'] == meta['index'], 'Wrong published index')
        if args.requalify_receipt:
            previous_bytes = subprocess.check_output(['git', '-C', str(ROOT), 'show', 'HEAD:release/approved_3d_v16_binding.json'])
            require(hashlib.sha256(previous_bytes).hexdigest() == historical['binding_sha256'], 'Original publication binding is not the retained commit')
            import json
            previous_binding = json.loads(previous_bytes)
            current_binding = read(ROOT / 'release/approved_3d_v16_binding.json')
            for field in ['revision', 'bundle_index_sha256', 'trusted_catalog_sha256', 'native_qualification_sha256', 'assembly_sha256']:
                require(previous_binding[field] == current_binding[field], 'Payload qualification changed: ' + field)
        else:
            require(historical['binding_sha256'] == sha(ROOT / 'release/approved_3d_v16_binding.json'), 'Wrong publication binding')
        rows = historical['bundles']
        require(len(rows) == 1421, 'Incomplete publication receipt')
        for row, proof in zip(meta['bundles'], rows, strict=True):
            require(all(row[k] == proof[k] for k in FIELDS) and proof['public_get_sha256_verified'] and proof['public_head_size_verified'], 'Unverified publication row')
        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            require(all(executor.map(public_head, meta['bundles'])), 'Public archive missing')
    proof = publish_immutable(config, ROOT / 'release/approved_3d_bundles_v16_index.json', meta['index'])
    require(snapshot_manifests() == before, 'Active manifests changed during immutable publication')
    write(receipt, {'schema': 1, 'revision': meta['revision'], 'content_index': meta['index'],
        'binding_sha256': sha(ROOT / 'release/approved_3d_v16_binding.json'), 'bundles': rows,
        'index_verification': proof, 'active_manifest_activated': False, 'manifest_snapshots': before,
        'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat(),
        'previous_runtime_binding_sha256': historical['binding_sha256'] if args.requalify_receipt and not args.sources else None})
    print('V16_PUBLICATION_COMPLETE archives=1421 manifest_activated=false', flush=True)


if __name__ == '__main__':
    main()
