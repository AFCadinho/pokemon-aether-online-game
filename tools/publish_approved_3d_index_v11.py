#!/usr/bin/env python3
"""Publish verified immutable v11 bundles/index on explicit --apply; never activate."""
import argparse
import concurrent.futures
import datetime
import json
import os
from pathlib import Path
import shlex

from package_approved_3d_release_v11 import ROOT, validate_local, file_sha
from publish_approved_3d_index_v8 import public_head, active_manifest_hash
from publish_qualified_3d_bundles import publish
from upload_launcher_release import _load_config

RECEIPT = ROOT / 'release/approved_3d_bundles_v11_r2_receipt.json'


def publish_bundles(config, archive_paths, bundles):
    """Bound upload concurrency; every object must pass GET and HEAD verification."""
    rows = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        pending = [pool.submit(publish, config, archive_paths[a['asset_id']], a)
                   for a in bundles]
        for future in concurrent.futures.as_completed(pending):
            rows.append(future.result())
            if len(rows) % 25 == 0:
                print('V11_PUBLIC_BUNDLES_VERIFIED', len(rows), '/', len(bundles), flush=True)
    return sorted(rows, key=lambda row: row['asset_id'])


def validate_receipt(metadata):
    receipt = json.loads(RECEIPT.read_bytes())
    assert receipt['revision'] == metadata['revision']
    assert receipt['lossless_binding_sha256'] == metadata['lossless_binding_sha256']
    assert receipt['content_index'] == metadata['index']
    verification = receipt['index_verification']
    assert all(verification[k] == metadata['index'][k] for k in ('object_key','sha256','size_bytes'))
    assert verification['public_get_sha256_verified'] and verification['public_head_size_verified']
    assert len(receipt['bundles']) == len(metadata['bundles']) == 1200
    rows = {a['asset_id']:a for a in receipt['bundles']}
    for asset in metadata['bundles']:
        row = rows[asset['asset_id']]
        assert all(row[k] == asset[k] for k in ('object_key','sha256','size_bytes'))
        assert row['public_get_sha256_verified'] and row['public_head_size_verified']
    return receipt


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--apply',action='store_true')
    p.add_argument('--archives-report',type=Path,help='Retained preparation report; reads archives in place to upload bundles first.')
    p.add_argument('--credentials',type=Path)
    args=p.parse_args()
    metadata=validate_local()
    archive_paths={}
    if args.archives_report:
        report=json.loads(args.archives_report.read_bytes())
        archive_paths={r['candidate_asset']['asset_id']:Path(r['candidate_archive']) for r in report['assets']}
        for asset in metadata['bundles']:
            path=archive_paths[asset['asset_id']]
            assert path.is_file() and not path.is_symlink()
            assert path.stat().st_size == asset['size_bytes'] and file_sha(path) == asset['sha256']
    if not args.apply:
        print('V11_LOCAL_OK bundles=1200 appearances=2400 no_network=true')
        return
    if not archive_paths and not RECEIPT.is_file():
        raise SystemExit('Publish the v11 bundles with --archives-report before running the release workflow.')
    existing = validate_receipt(metadata) if not archive_paths else None
    if args.credentials:
        for line in args.credentials.read_text().splitlines():
            parts=shlex.split(line,comments=True)
            if parts and parts[0]=='export': parts=parts[1:]
            if len(parts)==1 and '=' in parts[0]:
                key,value=parts[0].split('=',1)
                if key in ('R2_ACCOUNT_ID','R2_BUCKET','R2_ACCESS_KEY_ID','R2_SECRET_ACCESS_KEY','R2_ENDPOINT'):
                    os.environ[key]=value
    config=_load_config()
    assert config.account_id=='64ea7ddcb5e97df8500c33b8cb48f921'
    assert config.bucket=='pokemon-aether-updates'
    before=active_manifest_hash()
    if archive_paths:
        rows=publish_bundles(config,archive_paths,metadata['bundles'])
    else:
        # CI has no archive/cache copies. It requires the explicit immutable
        # publication receipt produced by the local upload before this build.
        rows=existing['bundles']
        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            assert all(pool.map(public_head,metadata['bundles']))
    index=publish(config,ROOT/'release/approved_3d_bundles_v11_index.json',metadata['index'])
    assert active_manifest_hash()==before,'Active manifest changed concurrently'
    receipt={'schema':1,'revision':metadata['revision'],'content_index':metadata['index'],
             'lossless_binding_sha256':metadata['lossless_binding_sha256'],'bundles':rows,
             'index_verification':index,'active_manifest_activated':False,
             'active_manifest_sha256_unchanged':before,
             'verified_at_utc':datetime.datetime.now(datetime.UTC).isoformat()}
    RECEIPT.write_text(json.dumps(receipt,indent=2,sort_keys=True)+'\n')
    print('V11_PUBLICATION_OK bundles=1200 index_sha256_verified=true manifest_activated=false')


if __name__=='__main__':
    main()
