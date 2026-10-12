#!/usr/bin/env python3
"""Back up v11 and retire its exact v13-exclusive ZIPs; never change manifests.

Backup is offline. Plan and verify are read-only online operations. Apply requires
the reviewed plan digest, rehashes the complete backup, protects the live v13
pins and journals every deletion so an interrupted operation is auditable.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from prune_r2_release_objects import _list_release_objects
from publish_approved_3d_index_v13 import validate_local as validate_v13
from publish_shared_model_collection import BASE, MANIFESTS, load_credentials
from upload_launcher_release import _signed_request

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ('asset_id', 'object_key', 'sha256', 'size_bytes')
EXPECTED_COUNT = 1145
EXPECTED_BYTES = 12_716_839_877
REQUIRED_MANIFESTS = ('manifest.json', 'manifest-windows.json',
                      'manifest-linux.json', 'manifest-macos.json')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def read(path):
    return json.loads(Path(path).read_bytes())


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path, value):
    path = regular_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = regular_path(path.with_name(path.name + '.partial'))
    with temporary.open('w') as stream:
        json.dump(value, stream, sort_keys=True, indent=2)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def regular_path(path):
    path = Path(path).absolute()
    require(not any(p.is_symlink() for p in (path, *path.parents)),
            'Linked backup/source paths are refused: ' + str(path))
    return path


def matches(path, row):
    path = regular_path(path)
    return path.is_file() and path.stat().st_size == row['size_bytes'] and sha(path) == row['sha256']


def selection(old, current):
    protected = {row['object_key'] for row in current['bundles']}
    require(len(protected) == len(current['bundles']), 'Duplicate current object keys')
    old_keys = set()
    result = []
    for row in old['bundles']:
        key = row['object_key']
        require(key not in old_keys, 'Duplicate legacy object key')
        old_keys.add(key)
        require(re.fullmatch(r'optional-assets/pokemon_3d/[a-z0-9-]+/[a-z0-9-]+/v[0-9]+-'
                             + re.escape(row['sha256']) + r'\.zip', key) is not None,
                'Unexpected legacy object key')
        if key not in protected:
            result.append({field: row[field] for field in FIELDS})
    return sorted(result, key=lambda row: row['object_key'])


def releases():
    require(__debug__, 'Optimized Python cannot perform qualification validation')
    current, _ = validate_v13()
    old = read(ROOT / 'release/approved_3d_bundles_v11.json')
    require(old['revision'] == 'approved-pokemon-3d-v11', 'Unexpected legacy revision')
    index_path = ROOT / 'release/approved_3d_bundles_v11_index.json'
    require(matches(index_path, old['index']), 'Legacy index pin mismatch')
    index = read(index_path)
    require(index['catalog_revision'] == old['revision'], 'Legacy index revision mismatch')
    require(len(index['assets']) == len(old['bundles']) == 1200, 'Incomplete legacy release')
    require([{field: row[field] for field in FIELDS} for row in index['assets']]
            == [{field: row[field] for field in FIELDS} for row in old['bundles']],
            'Legacy release metadata/index mismatch')
    doomed = selection(old, current)
    require(len(doomed) == EXPECTED_COUNT and sum(r['size_bytes'] for r in doomed) == EXPECTED_BYTES,
            'Unexpected retirement selection; review a separate operation')
    return old, current, doomed


def backup_rows(old):
    return [{**{k: row[k] for k in FIELDS}, 'backup_path': 'objects/' + row['object_key']}
            for row in old['bundles']] + [
                {**old['index'], 'backup_path': 'objects/' + old['index']['object_key']}]


def verify_backup(directory, old):
    directory = regular_path(directory)
    manifest = read(directory / 'backup-manifest.json')
    require(manifest['revision'] == old['revision'] and manifest['objects'] == backup_rows(old),
            'Incomplete or different backup inventory')
    require(read(directory / 'legacy-release.json') == old, 'Backup release metadata differs')
    expected_restore = {'assets': [
        {'candidate_asset': row, 'candidate_archive': str(directory / 'objects' / row['object_key'])}
        for row in old['bundles']]}
    require(read(directory / 'restore-archives-report.json') == expected_restore,
            'Backup restoration report differs')
    with ThreadPoolExecutor(max_workers=4) as pool:
        valid = list(pool.map(lambda row: matches(directory / row['backup_path'], row), manifest['objects']))
    require(all(valid), 'Backup checksum/size verification failed; no retirement allowed')
    return sha(directory / 'backup-manifest.json')


def make_backup(directory, source_report, old):
    directory = regular_path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    report = read(source_report)
    require(report.get('complete') is True, 'Source archive report is incomplete')
    sources = {row['candidate_asset']['asset_id']: row for row in report['assets']}
    require(len(sources) == len(report['assets']) == 1200, 'Incomplete/duplicate source inventory')
    jobs = []
    for row in old['bundles']:
        source = sources[row['asset_id']]
        require(all(source['candidate_asset'][key] == row[key] for key in FIELDS),
                'Source archive differs from approved v11 metadata')
        jobs.append((regular_path(source['candidate_archive']), row))
    jobs.append((ROOT / 'release/approved_3d_bundles_v11_index.json', old['index']))
    remaining = sum(row['size_bytes'] for _, row in jobs
                    if not (directory / 'objects' / row['object_key']).exists())
    require(shutil.disk_usage(directory).free > remaining + 1024**3, 'Insufficient backup disk space')

    def copy_one(job):
        source, row = job
        target = regular_path(directory / 'objects' / row['object_key'])
        if target.exists():
            require(matches(target, row), 'Existing backup differs; refusing overwrite')
            return
        require(source.is_file(), 'Missing archive source: ' + str(source))
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + '.partial')
        regular_path(temporary)
        digest = hashlib.sha256()
        size = 0
        with source.open('rb') as inp, temporary.open('wb') as out:
            while chunk := inp.read(1024 * 1024):
                out.write(chunk)
                digest.update(chunk)
                size += len(chunk)
            out.flush()
            os.fsync(out.fileno())
        require((size, digest.hexdigest()) == (row['size_bytes'], row['sha256']),
                'Source bytes changed or differ from v11')
        temporary.replace(target)

    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(copy_one, job) for job in jobs]
        for completed, future in enumerate(as_completed(futures), 1):
            future.result()
            if completed % 100 == 0:
                print('V11_BACKED_UP', completed, '/', len(jobs), flush=True)
    write_json(directory / 'legacy-release.json', old)
    write_json(directory / 'backup-manifest.json', {'schema': 1, 'revision': old['revision'],
               'objects': backup_rows(old), 'payload_bytes': sum(r['size_bytes'] for r in old['bundles'])})
    write_json(directory / 'restore-archives-report.json', {'assets': [
        {'candidate_asset': row, 'candidate_archive': str(directory / 'objects' / row['object_key'])}
        for row in old['bundles']]})
    return verify_backup(directory, old)


def fetch(key):
    request = Request(BASE + key + '?retirement=' + str(time.time_ns()),
                      headers={'User-Agent': 'PokeAetherRetirementVerifier/1.0', 'Cache-Control': 'no-cache'})
    try:
        with urlopen(request, timeout=60) as response:
            return response.read(2 * 1024 * 1024 + 1)
    except HTTPError as error:
        if error.code == 404:
            return None
        raise


def live_snapshot(current):
    result = {}
    pin = current['index']
    index = fetch(pin['object_key'])
    require(index is not None and len(index) == pin['size_bytes']
            and hashlib.sha256(index).hexdigest() == pin['sha256'], 'Active v13 index failed verification')
    ids = [row['asset_id'] for row in current['bundles']]
    for name in MANIFESTS:
        payload = fetch(name)
        require(payload is not None or name not in REQUIRED_MANIFESTS, 'Required live manifest missing')
        result[name] = None if payload is None else {
            'sha256': hashlib.sha256(payload).hexdigest(), 'size_bytes': len(payload)}
        if payload is None:
            continue
        descriptor = json.loads(payload).get('assetBundleIndex')
        require(isinstance(descriptor, dict) or name not in REQUIRED_MANIFESTS,
                'Desktop manifest lacks model descriptor')
        if descriptor is not None:
            require(descriptor.get('revision') == current['revision']
                    and descriptor.get('sha256') == pin['sha256']
                    and descriptor.get('sizeBytes') == pin['size_bytes']
                    and descriptor.get('url') == BASE + pin['object_key']
                    and descriptor.get('objectBaseUrl', '').rstrip('/') == BASE.rstrip('/')
                    and descriptor.get('requiredAssetIds') == ids,
                    'Live manifest changed model selection; retirement refused')
    return result


def inventory(config, current):
    objects = {row.key: row for row in _list_release_objects(config, 'desktop')}
    for row in [*current['bundles'], current['index']]:
        item = objects.get(row['object_key'])
        require(item is not None and item.size == row['size_bytes'], 'Protected current object missing/changed')
    return objects


def make_plan(config, directory, old, current, doomed):
    backup_sha = verify_backup(directory, old)
    before = live_snapshot(current)
    objects = inventory(config, current)
    require(all(row['object_key'] not in objects or objects[row['object_key']].size == row['size_bytes']
                for row in doomed), 'Legacy R2 object size differs')
    require(live_snapshot(current) == before, 'Manifest changed during plan')
    return {'schema': 1, 'legacy_revision': old['revision'], 'current_revision': current['revision'],
            'legacy_metadata_sha256': sha(ROOT / 'release/approved_3d_bundles_v11.json'),
            'current_metadata_sha256': sha(ROOT / 'release/approved_3d_bundles_v13.json'),
            'retirement_tool_sha256': sha(Path(__file__)),
            'current_index': current['index'], 'active_manifests': before,
            'backup_directory': str(regular_path(directory)), 'backup_manifest_sha256': backup_sha,
            'candidates': doomed, 'candidate_bytes': EXPECTED_BYTES,
            'present_objects': sum(row['object_key'] in objects for row in doomed),
            'retained_shared_objects': len(old['bundles']) - len(doomed)}


def retire_one(config, row):
    key = row['object_key']
    status, _, _ = _signed_request(config, 'HEAD', key)
    if status == 404:
        return {'object_key': key, 'outcome': 'already_absent'}
    require(status == 200, 'R2 HEAD failed: ' + key)
    status, _, _ = _signed_request(config, 'DELETE', key)
    require(200 <= status < 300, 'R2 DELETE failed: ' + key)
    status, _, _ = _signed_request(config, 'HEAD', key)
    require(status == 404, 'Retired key still exists on R2: ' + key)
    return {'object_key': key, 'outcome': 'deleted'}


def apply_plan(config, plan_path, receipt_path, expected_digest, old, current, doomed):
    require(sha(plan_path) == expected_digest, 'Reviewed plan digest changed')
    saved = read(plan_path)
    fresh = make_plan(config, Path(saved['backup_directory']), old, current, doomed)
    require(all(saved.get(key) == value for key, value in fresh.items() if key != 'present_objects'),
            'Reviewed plan, backup or manifests changed')
    receipt_path = regular_path(receipt_path)
    journal = regular_path(Path(saved['backup_directory']) / 'retirement-journal.jsonl')
    if receipt_path.exists():
        require(read(receipt_path)['plan_sha256'] == expected_digest, 'Receipt belongs to another plan')
    journal.parent.mkdir(parents=True, exist_ok=True)
    completed = {}
    if journal.exists():
        regular_path(journal)
        for line in journal.read_text().splitlines():
            row = json.loads(line)
            require(row['plan_sha256'] == expected_digest, 'Journal belongs to another plan')
            completed[row['object_key']] = row
        require(set(completed).issubset(row['object_key'] for row in doomed), 'Unknown journal objects')
    with journal.open('a') as stream, ThreadPoolExecutor(max_workers=4) as pool:
        for offset in range(0, len(doomed), 25):
            require(live_snapshot(current) == saved['active_manifests'], 'Manifest changed; retirement paused')
            futures = [pool.submit(retire_one, config, row) for row in doomed[offset:offset + 25]]
            errors = []
            for future in as_completed(futures):
                try:
                    row = future.result()
                except Exception as error:
                    errors.append(error)
                    continue
                if row['object_key'] not in completed:
                    entry = {**row, 'plan_sha256': expected_digest}
                    stream.write(json.dumps(entry, sort_keys=True) + '\n')
                    stream.flush()
                    os.fsync(stream.fileno())
                    completed[row['object_key']] = entry
            if errors:
                raise errors[0]
            print('V11_RETIRED', min(offset + 25, len(doomed)), '/', len(doomed), flush=True)
    objects = inventory(config, current)
    require(not any(row['object_key'] in objects for row in doomed), 'Retired objects remain in inventory')
    require(live_snapshot(current) == saved['active_manifests'], 'Manifest changed during retirement')
    deleted_keys = {key for key, row in completed.items() if row['outcome'] == 'deleted'}
    receipt = {'schema': 1, 'plan_sha256': expected_digest, 'backup_manifest_sha256': fresh['backup_manifest_sha256'],
               'deleted': len(deleted_keys), 'already_absent': len(doomed) - len(deleted_keys),
               'deleted_bytes': sum(row['size_bytes'] for row in doomed if row['object_key'] in deleted_keys),
               'retained_shared_objects': saved['retained_shared_objects'], 'active_manifests_unchanged': saved['active_manifests'],
               'all_1200_current_payloads_present': True, 'old_candidates_absent_from_origin': True,
               'objects': [completed[row['object_key']] for row in doomed],
               'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat()}
    write_json(receipt_path, receipt)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('backup', 'plan', 'apply', 'verify'))
    parser.add_argument('--backup-directory', type=Path, required=True)
    parser.add_argument('--archives-report', type=Path)
    parser.add_argument('--credentials', type=Path)
    parser.add_argument('--plan', type=Path)
    parser.add_argument('--receipt', type=Path)
    parser.add_argument('--confirm-plan-sha256')
    args = parser.parse_args()
    old, current, doomed = releases()
    if args.mode == 'backup':
        require(args.archives_report is not None, 'Backup requires retained archive report')
        digest = make_backup(args.backup_directory, args.archives_report, old)
        print('V11_BACKUP_OK objects=1201 payload_bytes=12857317549 backup_manifest_sha256=' + digest)
        return
    config = load_credentials(args.credentials)
    if args.mode == 'plan':
        require(args.plan is not None and not args.plan.exists(), 'Use a fresh plan path')
        plan = make_plan(config, args.backup_directory, old, current, doomed)
        write_json(args.plan, plan)
        print('V11_RETIREMENT_PLAN_OK candidates=1145 bytes=12716839877 present=' + str(plan['present_objects'])
              + ' plan_sha256=' + sha(args.plan))
    elif args.mode == 'apply':
        require(args.plan is not None and args.receipt is not None and args.confirm_plan_sha256,
                'Apply requires reviewed plan, receipt and exact plan digest')
        require(str(regular_path(args.backup_directory)) == read(args.plan)['backup_directory'],
                'Backup directory differs from plan')
        receipt = apply_plan(config, args.plan, args.receipt, args.confirm_plan_sha256, old, current, doomed)
        print('V11_RETIREMENT_OK deleted=' + str(receipt['deleted']) + ' bytes=' + str(receipt['deleted_bytes']))
    else:
        verify_backup(args.backup_directory, old)
        before = live_snapshot(current)
        objects = inventory(config, current)
        require(not any(row['object_key'] in objects for row in doomed), 'Retired candidates remain')
        require(live_snapshot(current) == before, 'Manifest changed during verification')
        print('V11_RETIREMENT_VERIFIED backup_objects=1201 active_models=1200 retained_shared=55 retired_absent=1145')


if __name__ == '__main__':
    main()
