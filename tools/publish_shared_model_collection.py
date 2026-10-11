#!/usr/bin/env python3
"""Stage the exact Linux-qualified collection on R2; never replace live manifests.

Offline by default. Reads verified retained payloads in place, uploads missing
immutable objects only, and verifies full public GET SHA-256 and HEAD size.
Existing mismatching objects are an error, never an overwrite opportunity.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import urllib.error
import urllib.request
import time

from publish_qualified_3d_bundles import file_digest, public
from upload_launcher_release import _load_config, _signed_request, _upload_file
from shared_model_publication_helpers import validate_selection

ROOT = Path(__file__).resolve().parents[1]
BASE = 'https://updates.pokeaether.com/'
MANIFESTS = ('manifest.json', 'manifest-windows.json', 'manifest-linux.json',
             'manifest-macos.json', 'manifest-macos-arm64.json', 'manifest-android.json',
             'manifest-web.json')


def prepare(sources_file):
    wire, assets = validate_selection(ROOT)
    sources = json.loads(sources_file.read_bytes())
    if sources['index_sha256'] != hashlib.sha256(wire).hexdigest():
        raise ValueError('Retained source map belongs to another index')
    rows = []
    for asset in assets:
        path = Path(sources['sources'][asset['asset_id']])
        if not path.is_absolute() or path.is_symlink() or not path.is_file():
            raise ValueError('Expected an existing retained regular payload')
        if file_digest(path) != (asset['size_bytes'], asset['sha256']):
            raise ValueError('Retained payload differs: ' + asset['asset_id'])
        record = {k: asset[k] for k in ('asset_id', 'object_key', 'sha256', 'size_bytes')}
        if not re.fullmatch(r'optional-assets/pokemon_3d/[a-z0-9-]+/[a-z0-9-]+/v[0-9]+-' + record['sha256'] + r'\.(pck|zip)', record['object_key']):
            raise ValueError('Unexpected immutable payload key')
        rows.append((path, record))
    sha = hashlib.sha256(wire).hexdigest()
    index = {'object_key': 'optional-assets/pokemon_3d/index/pilot-' + sha + '.json',
             'sha256': sha, 'size_bytes': len(wire)}
    return rows, index


def snapshot_manifests():
    result = {}
    for key in MANIFESTS:
        request = urllib.request.Request(BASE + key + '?check=' + str(time.time_ns()),
                                        headers={'User-Agent': 'Mozilla/5.0'})
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read()
                result[key] = {'sha256': hashlib.sha256(payload).hexdigest(), 'size_bytes': len(payload)}
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise ValueError('Manifest snapshot HTTP ' + str(error.code) + ': ' + key) from None
            result[key] = None
    if result['manifest.json'] is None:
        raise ValueError('Active desktop manifest missing')
    return result


def publish_immutable(config, path, record):
    if public(record):
        uploaded = False
    else:
        status, _, _ = _signed_request(config, 'HEAD', record['object_key'])
        if status != 404:
            raise ValueError('Immutable key exists but public bytes are unavailable/mismatched, or HEAD failed: ' + record['object_key'])
        # Recheck the exact input immediately before writing.
        if file_digest(path) != (record['size_bytes'], record['sha256']):
            raise ValueError('Payload changed before upload')
        _upload_file(config, path, record['object_key'])
        uploaded = True
        for attempt in range(6):
            if public(record):
                break
            time.sleep(2)
        else:
            raise ValueError('Uploaded payload failed public GET verification')
    if not public(record, head=True):
        raise ValueError('Payload failed public HEAD verification')
    return {**record, 'uploaded': uploaded, 'public_get_sha256_verified': True,
            'public_head_size_verified': True}


def load_credentials(path):
    if path:
        for line in path.read_text().splitlines():
            parts = shlex.split(line, comments=True)
            if parts and parts[0] == 'export':
                parts = parts[1:]
            if len(parts) == 1 and '=' in parts[0]:
                key, value = parts[0].split('=', 1)
                if key in ('R2_ACCOUNT_ID', 'R2_BUCKET', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_ENDPOINT'):
                    os.environ[key] = value
    config = _load_config()
    if config.account_id != '64ea7ddcb5e97df8500c33b8cb48f921' or config.bucket != 'pokemon-aether-updates':
        raise ValueError('Unexpected R2 account/bucket')
    if config.endpoint != 'https://64ea7ddcb5e97df8500c33b8cb48f921.r2.cloudflarestorage.com':
        raise ValueError('Unexpected R2 endpoint')
    return config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True, help='Retained readiness input.json')
    parser.add_argument('--credentials', type=Path, help='Read existing credentials in place')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--output', type=Path, default=ROOT / 'release/shared_model_collection_r2_receipt.json')
    args = parser.parse_args()
    rows, index = prepare(args.sources)
    print('SHARED_PUBLICATION_LOCAL_OK bundles=1200 shared=1082 original=118 download_bytes=' + str(sum(a['size_bytes'] for _, a in rows)), flush=True)
    if not args.apply:
        print('No network access or upload performed.')
        return
    output = args.output.resolve()
    output.relative_to(ROOT)
    if output.exists():
        raise ValueError('Retain the previous receipt; use a fresh output for reverification')
    preflight = output.with_suffix('.preflight.json')
    if preflight.exists():
        raise ValueError('Retain the previous preflight; use a fresh output for retry')
    source_commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    config = load_credentials(args.credentials)
    before = snapshot_manifests()
    output.parent.mkdir(parents=True, exist_ok=True)
    with preflight.open('x') as stream:
        stream.write(json.dumps({'source_commit': source_commit, 'content_index': index,
                                 'active_manifests': before,
                                 'bundles': [record for _, record in rows]}, indent=2, sort_keys=True) + '\n')
    print('LIVE_MANIFEST_SNAPSHOT_OK count=' + str(sum(v is not None for v in before.values())), flush=True)
    completed = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(publish_immutable, config, path, record) for path, record in rows]
        for future in concurrent.futures.as_completed(futures):
            completed.append(future.result())
            if len(completed) % 25 == 0:
                print('SHARED_PUBLIC_BUNDLES_VERIFIED', len(completed), '/', len(rows), flush=True)
    index_result = publish_immutable(config, ROOT / 'data/model_pair_qualified.json', index)
    after = snapshot_manifests()
    if after != before:
        raise ValueError('Live manifests changed during staging; investigate before activation')
    receipt = {'schema': 1, 'revision': json.loads((ROOT / 'data/model_pair_qualified.json').read_bytes())['catalog_revision'],
               'scope': 'Immutable staging only; current clients remain on their existing collection',
               'content_index': index, 'index_verification': index_result,
               'readiness_sha256': file_digest(ROOT / 'data/shared_model_readiness_checks.json')[1],
               'publication_source_commit': source_commit,
               'preflight_sha256': file_digest(preflight)[1],
               'bundles': sorted(completed, key=lambda a: a['asset_id']),
               'active_manifest_activated': False, 'production_approved': False,
               'active_manifests_unchanged': before,
               'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat()}
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('x') as stream:
        stream.write(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print('SHARED_PUBLICATION_OK bundles=1200 full_get_sha256=true head_size=true manifests_unchanged=true', flush=True)


if __name__ == '__main__':
    main()
