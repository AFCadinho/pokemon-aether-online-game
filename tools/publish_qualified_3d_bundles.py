#!/usr/bin/env python3
"""Publish hash-bound approved base-form bundles and their immutable index."""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
import re
from pathlib import Path
import shlex
import time
import urllib.error
import urllib.request
import zipfile
from upload_launcher_release import _load_config, _upload_file, _signed_request

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://updates.pokeaether.com/'
QUALIFICATION = ROOT / 'tools/sprite_factory/catalog_remaining_56_bundle_qualification.json'


def digest(stream):
    hashing = hashlib.sha256()
    size = 0
    while data := stream.read(1024 * 1024):
        hashing.update(data)
        size += len(data)
    return size, hashing.hexdigest()


def file_digest(path):
    with path.open('rb') as stream:
        return digest(stream)


def public(record, head=False):
    # A pre-upload 404 can be cached; each verification reads a fresh URL.
    request = urllib.request.Request(BASE + record['object_key'] + '?verify=' + record['sha256']
                                     + '&check=' + str(time.time_ns()),
                                     headers={'User-Agent': 'Mozilla/5.0'}, method='HEAD' if head else 'GET')
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            if head:
                if int(response.headers['Content-Length']) != record['size_bytes']:
                    raise ValueError('Public size mismatch')
            elif digest(response) != (record['size_bytes'], record['sha256']):
                raise ValueError('Public SHA-256 mismatch')
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise ValueError('Public HTTP status ' + str(error.code)) from None
    return True


def publish(config, path, record):
    if public(record):
        uploaded = False
    else:
        status, _, _ = _signed_request(config, 'HEAD', record['object_key'])
        if status not in (200, 404):
            raise ValueError('R2 HEAD status ' + str(status))
        uploaded = status == 404
        if uploaded:
            _upload_file(config, path, record['object_key'])
        for attempt in range(6):
            if public(record):
                break
            time.sleep(2)
        else:
            raise ValueError('Public object not available after upload')
    if not public(record, head=True):
        raise ValueError('Public HEAD missing')
    return {**record, 'uploaded': uploaded, 'public_get_sha256_verified': True,
            'public_head_size_verified': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--credentials', type=Path)
    parser.add_argument('--qualification', type=Path, default=QUALIFICATION)
    parser.add_argument('--expected-count', type=int, required=True)
    parser.add_argument('--receipt-prefix', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    directory = args.directory.resolve()
    qualification_path = args.qualification.resolve()
    assert re.fullmatch(r'approved_3d_[a-z0-9_]+', args.receipt_prefix)
    qualification = json.loads(qualification_path.read_text())
    registry_file = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    registry = json.loads(registry_file.read_text())
    assert file_digest(qualification_path)[1] in registry.values(), 'Qualification is not bound to approved registry'
    assert qualification['appearance_approved'] and qualification['battle_approved'] and qualification['runtime_approved']
    index_path = directory / 'asset-index.json'
    index = json.loads(index_path.read_text())
    assert index == qualification['bundle_index'] and len(index['assets']) == args.expected_count and args.expected_count > 0
    rows = []
    for asset in index['assets']:
        assert asset['asset_id'] == 'pokemon_3d:' + asset['species_id'] + ':base'
        assert asset['object_key'].startswith('optional-assets/pokemon_3d/' + asset['species_id'] + '/base/')
        path = directory / Path(asset['object_key']).name
        assert path.is_file() and not path.is_symlink()
        assert file_digest(path) == (asset['size_bytes'], asset['sha256'])
        assert len(asset['appearances']) == 2
        assert {a['variant'] for a in asset['appearances']} == {'normal', 'shiny'}
        with zipfile.ZipFile(path) as archive:
            assert set(archive.namelist()) == {'bundle.json', 'models/normal.scn', 'models/shiny.scn'}
            manifest = json.loads(archive.read('bundle.json'))
            assert manifest['asset_id'] == asset['asset_id']
            assert [{k: a[k] for k in ('variant', 'runtime_identity', 'runtime_sha256')}
                    for a in manifest['appearances']] == asset['appearances']
            for appearance in manifest['appearances']:
                assert appearance['runtime_path'] == 'models/' + appearance['variant'] + '.scn'
                assert registry['models'][appearance['runtime_identity']]['sha256'] == appearance['runtime_sha256']
                with archive.open(appearance['runtime_path']) as stream:
                    assert digest(stream) == (appearance['bytes'], appearance['runtime_sha256'])
        rows.append((path, {k: asset[k] for k in ('asset_id', 'object_key', 'sha256', 'size_bytes')}))
    print('Verified', args.expected_count, 'qualified bundles,', args.expected_count*2, 'scenes,', sum(r[1]['size_bytes'] for r in rows), 'bytes', flush=True)
    if not args.apply:
        print('Local verification only; no R2 access.')
        return
    if args.credentials:
        for line in args.credentials.read_text().splitlines():
            parts = shlex.split(line, comments=True)
            if parts and parts[0] == 'export':
                parts = parts[1:]
            if len(parts) == 1 and '=' in parts[0]:
                key, value = parts[0].split('=', 1)
                if key in ('R2_ACCOUNT_ID', 'R2_BUCKET', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_ENDPOINT'):
                    os.environ[key] = value
    config = _load_config()
    assert config.bucket == 'pokemon-aether-updates'
    status, _, _ = _signed_request(config, 'HEAD', 'manifest.json')
    assert status == 200, 'R2 access check failed'
    manifest_request = urllib.request.Request(BASE + 'manifest.json', headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(manifest_request, timeout=60) as response:
        active_manifest_before = digest(response)
    completed = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(publish, config, path, record) for path, record in rows]
        for future in concurrent.futures.as_completed(futures):
            completed.append(future.result())
            print('Publicly verified', len(completed), '/', args.expected_count, flush=True)
    published_index = ROOT / ('release/' + args.receipt_prefix + '_index.json')
    published_index.write_bytes(index_path.read_bytes())
    size, sha = file_digest(published_index)
    content_index = {'object_key': f"optional-assets/pokemon_3d/index/{index['catalog_revision']}-{sha}.json",
                     'sha256': sha, 'size_bytes': size}
    index_verification = publish(config, published_index, content_index)
    with urllib.request.urlopen(manifest_request, timeout=60) as response:
        assert digest(response) == active_manifest_before, 'Active manifest changed concurrently'
    receipt = {'schema': 1, 'scope': 'Qualified base-form pairs only; immutable content publication',
               'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat(),
               'catalog_revision': index['catalog_revision'], 'public_base_url': BASE.rstrip('/'),
               'bundle_qualification_sha256': file_digest(qualification_path)[1],
               'reviewed_catalog_sha256': file_digest(registry_file)[1],
               'profile_count': args.expected_count, 'appearance_count': args.expected_count*2,
               'bundle_bytes': sum(r['size_bytes'] for r in completed),
               'new_bundle_objects_uploaded': sum(r['uploaded'] for r in completed),
               'public_get_sha256_verified_objects': len(completed)+1, 'public_head_size_verified_objects': len(completed)+1,
               'desktop_manifest_activated': False, 'active_manifest_sha256_unchanged': active_manifest_before[1],
               'content_index': content_index, 'index_verification': index_verification,
               'bundles': sorted(completed, key=lambda r: r['asset_id'])}
    (ROOT / ('release/' + args.receipt_prefix + '_r2_upload.json')).write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print('COMPLETE:', args.expected_count, 'bundles and immutable index publicly verified; active manifest unchanged.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Credential values and authenticated response bodies must never enter logs.
        raise SystemExit('Publication failed (' + type(error).__name__ + '); no activation performed.') from None
