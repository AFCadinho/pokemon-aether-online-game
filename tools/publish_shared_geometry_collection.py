#!/usr/bin/env python3
"""Stage the verified geometry collection as immutable R2 objects, without activation.

Offline validation is the default. The retained physical sources are read in
place; failed or interrupted uploads can be retried with a fresh receipt path.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess

from publish_qualified_3d_bundles import file_digest
from publish_shared_model_collection import load_credentials, publish_immutable, snapshot_manifests
from verify_shared_model_publication import check as check_previous_receipt

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(Path(path).read_bytes())


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def prepare(collection, source_map):
    from sys import path as python_path
    python_path.insert(0, str(ROOT / 'tests'))
    from shared_geometry_metadata_check import check as check_metadata

    wire_path = ROOT / 'data/model_pair_geometry.json'
    catalog_path = ROOT / 'data/model_pair_geometry_catalog.json'
    wire = read(wire_path)
    catalog = read(catalog_path)
    baseline = read(ROOT / 'data/model_pair_qualified.json')
    proof = read(ROOT / 'release/shared_model_geometry_collection.json')
    check_metadata(wire, catalog, baseline, proof)
    assert proof['build_report_sha256'] == sha(collection / 'report.json')
    assert proof['compiled_files']['data/model_pair_geometry.json'] == sha(wire_path)
    assert proof['compiled_files']['data/model_pair_geometry_catalog.json'] == sha(catalog_path)
    assert (ROOT / 'launcher/data/model_pair_geometry.json').read_bytes() == wire_path.read_bytes()
    assert (ROOT / 'launcher/data/model_pair_geometry_catalog.json').read_bytes() == catalog_path.read_bytes()
    report = read(collection / 'report.json')
    assert report['complete'] and report['pairs_built'] == 1031 and report['pairs_smaller'] == 1031
    selected = {r['asset']['asset_id']: r for r in report['records']}
    catalog_assets = {a['asset_id']: a for a in catalog['assets']}
    assert set(selected) == set(catalog_assets)
    old_receipt = read(ROOT / 'release/shared_model_collection_r2_receipt.json')
    check_previous_receipt(old_receipt)
    former = {a['asset_id']: a for a in old_receipt['bundles']}
    retained = read(source_map)
    assert retained['index_sha256'] == sha(ROOT / 'data/model_pair_qualified.json')
    rows = []
    for entry in wire['assets']:
        key = entry['asset_id']
        if key in selected:
            asset = selected[key]['asset']
            assert asset == catalog_assets[key]
            source = Path(selected[key]['path'])
        else:
            previous = former[key]
            if entry.get('format') == 'model-pair-ref-v1':
                assert entry == {k: previous[k] for k in ('asset_id', 'sha256')} | {'format': 'model-pair-ref-v1'}
            else:
                assert all(entry[name] == previous[name] for name in
                           ('asset_id', 'object_key', 'sha256', 'size_bytes'))
            asset = previous
            source = Path(retained['sources'][key])
        assert entry['sha256'] == asset['sha256']
        assert re.fullmatch(r'optional-assets/pokemon_3d/[a-z0-9-]+/[a-z0-9-]+/v[0-9]+-'
                            + asset['sha256'] + r'\.(pck|zip)', asset['object_key'])
        assert source.is_absolute() and source.is_file() and not source.is_symlink()
        assert file_digest(source) == (asset['size_bytes'], asset['sha256']), key
        rows.append((source, {name: asset[name] for name in ('asset_id', 'object_key', 'sha256', 'size_bytes')}))
    assert len(rows) == 1200 and len({row['object_key'] for _, row in rows}) == 1200
    assert sum(row['size_bytes'] for _, row in rows) == proof['candidate_download_bytes']
    index = {'object_key': 'optional-assets/pokemon_3d/index/pilot-' + sha(wire_path) + '.json',
             'sha256': sha(wire_path), 'size_bytes': wire_path.stat().st_size}
    return rows, index, old_receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--collection', type=Path, required=True)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--credentials', type=Path, help='Existing credentials, read in place')
    parser.add_argument('--output', type=Path, default=ROOT / 'release/shared_model_geometry_r2_receipt.json')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    rows, index, old_receipt = prepare(args.collection, args.sources)
    old = {a['asset_id']: a for a in old_receipt['bundles']}
    replaced = [a for _, a in rows if a['object_key'] != old[a['asset_id']]['object_key']]
    print('GEOMETRY_PUBLICATION_LOCAL_OK pairs=1200 changed=' + str(len(replaced))
          + ' bytes=' + str(sum(a['size_bytes'] for _, a in rows)), flush=True)
    if not args.apply:
        return
    output = args.output.resolve()
    output.relative_to(ROOT / 'release')
    preflight = output.with_suffix('.preflight.json')
    if output.exists() or preflight.exists():
        raise ValueError('Use a fresh receipt path; retain prior evidence')
    config = load_credentials(args.credentials)
    before = snapshot_manifests()
    source_commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    preflight.write_text(json.dumps({'source_commit': source_commit, 'content_index': index,
                                     'build_report_sha256': sha(args.collection / 'report.json'),
                                     'active_manifests': before,
                                     'bundles': [record for _, record in rows]}, indent=2, sort_keys=True) + '\n')
    completed = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(publish_immutable, config, source, record) for source, record in rows]
        for future in concurrent.futures.as_completed(futures):
            completed.append(future.result())
            if len(completed) % 25 == 0:
                print('GEOMETRY_PUBLIC_VERIFIED', len(completed), '/', len(rows), flush=True)
    index_result = publish_immutable(config, ROOT / 'data/model_pair_geometry.json', index)
    if snapshot_manifests() != before:
        raise ValueError('Live manifests changed during staging')
    receipt = {'schema': 1, 'revision': 'shared-geometry-test-v1',
               'scope': 'Immutable staging only; no client activation',
               'build_report_sha256': sha(args.collection / 'report.json'),
               'source_commit': source_commit, 'preflight_sha256': sha(preflight),
               'content_index': index, 'index_verification': index_result,
               'bundles': sorted(completed, key=lambda a: a['asset_id']),
               'active_manifests_unchanged': before, 'active_manifest_activated': False,
               'production_approved': False,
               'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat()}
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print('GEOMETRY_PUBLICATION_OK pairs=1200 full_get_sha256=true head_size=true manifests_unchanged=true', flush=True)


if __name__ == '__main__':
    main()
