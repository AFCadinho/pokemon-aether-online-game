#!/usr/bin/env python3
"""Prepare v15 from frozen v14 and the 111 verified complete geometry packs."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

from audit_cross_form_resources import catalog
from check_new_pair_geometry_pixels import check
from probe_v13_compression import checked_bytes, unpack_pck

ROOT = Path(__file__).resolve().parents[1]
REVISION = 'approved-pokemon-3d-v15'
BINDING = ROOT / 'release/approved_3d_v15_binding.json'
FIELDS = ('asset_id', 'object_key', 'sha256', 'size_bytes')


def read(path):
    return json.loads(Path(path).read_bytes())


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False) + '\n').encode()


def write(path, value):
    Path(path).write_bytes(encoded(value))


def replacement_contract(previous, record):
    """Preserve identities and budgets; require a fresh resource namespace."""
    asset = copy.deepcopy(record['asset'])
    assert record['smaller'] and record['verification']['ok']
    assert record['baseline_sha256'] == previous['sha256']
    assert record['baseline_bytes'] == previous['size_bytes'] > asset['size_bytes']
    assert asset['version'] == previous['version'] + 1
    for field in ('asset_id', 'species_id', 'form_id', 'national_dex', 'dependencies'):
        assert asset[field] == previous[field], field
    assert asset['format'] == previous['format'] == 'model-pair-pck-v1'
    assert asset['pair_manifest']['schema'] == 2
    assert asset['pair_manifest']['version'] == asset['version']
    assert asset['pair_manifest']['resource_root'] != previous['pair_manifest']['resource_root']
    assert asset['pair_manifest']['appearances'] == asset['appearances']
    assert len(asset['appearances']) == 2
    for old, new in zip(previous['appearances'], asset['appearances'], strict=True):
        for field in ('runtime_identity', 'variant', 'runtime_path', 'source_sha256', 'cache_source_bytes'):
            assert old[field] == new[field], field
    assert asset['object_key'] == previous['object_key'].rsplit('/', 1)[0] + f"/v{asset['version']}-{asset['sha256']}.pck"
    assert Path(record['path']).is_absolute()
    asset['asset_type'] = 'pokemon_3d'
    return asset


def replacement(previous, record):
    asset = replacement_contract(previous, record)
    members, _ = unpack_pck(checked_bytes(record['path'], asset), asset)
    assert json.loads(members['bundle.json']) == asset['pair_manifest']
    assert record['decoded_members_byte_exact'] == len(members) - 1
    return asset


def build(study_root, old_sources, output):
    study_root, output = Path(study_root).resolve(), Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    meta, assets = catalog()
    receipt_path = ROOT / 'release/new_pair_geometry_study_v14.json'
    receipt = read(receipt_path)
    assert receipt['complete'] and receipt['eligible_pairs'] == receipt['pairs_built'] == receipt['pairs_smaller'] == 111
    for path, pin in receipt['inputs'].items():
        assert sha(ROOT / path) == pin, path
    for path, pin in receipt['artifacts'].items():
        file = study_root / path
        assert file.stat().st_size == pin['size_bytes'] and sha(file) == pin['sha256'], path
    build_report = read(study_root / '.tmp/new-pair-geometry-v1/build/report.json')
    assert build_report['complete'] and len(build_report['records']) == 111
    gpu = check(study_root / '.tmp/new-pair-geometry-v1/render-final', study_root / '.tmp/new-pair-geometry-v1/render-v2/input.json')
    assert gpu == read(study_root / '.tmp/new-pair-geometry-v1/gpu-receipt.json')
    assert gpu['pixels_exact'] and gpu['candidate_frames'] == 80
    source_map = read(old_sources)
    assert source_map['revision'] == meta['revision'] and source_map['metadata_sha256'] == sha(ROOT / 'release/approved_3d_bundles_v14.json')
    sources = source_map['sources'].copy()
    assert set(sources) == {a['asset_id'] for a in assets}
    by_id = {a['asset_id']: a for a in assets}
    changes = {}
    for record in build_report['records']:
        key = record['asset']['asset_id']
        assert key not in changes
        previous = by_id[key]
        asset = replacement(previous, record)
        changes[key] = {'previous': {k: previous[k] for k in FIELDS},
                        'approved': {k: asset[k] for k in FIELDS},
                        'measurement_sha256': hashlib.sha256(encoded(record)).hexdigest(),
                        'decoded_members_byte_exact': record['decoded_members_byte_exact'],
                        'motion_samples': record['verification']['motion_samples']}
        by_id[key], sources[key] = asset, record['path']
    assets = sorted(by_id.values(), key=lambda a: a['asset_id'])
    total = sum(a['size_bytes'] for a in assets)
    saved = meta['total_bundle_bytes'] - total
    assert len(changes) == 111 and saved == receipt['saved_download_bytes'] == 198171932
    assert total == receipt['selected_collection_bytes'] == 8795326138
    assert sum(r['decoded_members_byte_exact'] for r in changes.values()) == 2537
    trusted = {'schema': 1, 'kind': 'pokeaether-model-pair-catalog', 'catalog_revision': REVISION,
               'assets': [a for a in assets if a.get('format') == 'model-pair-pck-v1']}
    wire = {'schema': 1, 'kind': 'pokeaether-optional-asset-index', 'catalog_revision': REVISION,
            'runtime_contract': {'pokemon_3d': 2, 'godot': '4.6'}, 'production_approved': True,
            'prototype_only': False, 'assets': [
                {'asset_id': a['asset_id'], 'format': 'model-pair-ref-v1', 'sha256': a['sha256']}
                if a.get('format') == 'model-pair-pck-v1' else a for a in assets]}
    data = encoded(wire)
    digest = hashlib.sha256(data).hexdigest()
    pin = {'object_key': 'optional-assets/pokemon_3d/index/v15-' + digest + '.json',
           'sha256': digest, 'size_bytes': len(data)}
    client = {'schema': 1, 'revision': REVISION, 'index': pin, 'requiredAssetIds': [a['asset_id'] for a in assets]}
    for side in ('data', 'launcher/data'):
        write(ROOT / side / 'model_pair_release_v15_catalog.json', trusted)
        write(ROOT / side / 'approved_3d_release_v15.json', client)
        (ROOT / side / 'approved_3d_bundles_v15_index.json').write_bytes(data)
    (ROOT / 'release/approved_3d_bundles_v15_index.json').write_bytes(data)
    new_meta = {'schema': 1, 'kind': meta['kind'], 'revision': REVISION, 'index': pin,
                'bundles': [{k: a[k] for k in FIELDS} for a in assets], 'total_bundle_bytes': total,
                'replaced_pairs': 111, 'unchanged_pairs': 1309, 'saved_download_bytes': saved,
                'previous_index_sha256': meta['index']['sha256'], 'geometry_study_sha256': sha(receipt_path)}
    write(ROOT / 'release/approved_3d_bundles_v15.json', new_meta)
    binding = {'schema': 1, 'revision': REVISION, 'runtime_approved': False, 'publication_approved': False,
               'pairs': 1420, 'appearances': 2840, 'profiles_unchanged': True,
               'reviewed_registry_sha256': sha(ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'),
               'previous_binding_sha256': sha(ROOT / 'release/approved_3d_v14_binding.json'),
               'geometry_study_sha256': sha(receipt_path), 'bundle_index_sha256': digest,
               'trusted_catalog_sha256': sha(ROOT / 'data/model_pair_release_v15_catalog.json'),
               'replacements': changes}
    write(BINDING, binding)
    write(output / 'sources.json', {'revision': REVISION, 'metadata_sha256': sha(ROOT / 'release/approved_3d_bundles_v15.json'), 'sources': sources})
    info = read(ROOT / 'data/battle_visual_download_info.json')
    info['3d_v15'] = {'index_sha256': digest, 'bundle_count': 1420, 'download_bytes': total,
                      'installed_bytes': total - (info['3d_v14']['download_bytes'] - info['3d_v14']['installed_bytes'])}
    (ROOT / 'data/battle_visual_download_info.json').write_text(json.dumps(info, indent=2) + '\n')
    print(f'V15_PREPARED pairs=1420 replaced=111 bytes={total} saved={saved}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--study-root', type=Path, required=True)
    parser.add_argument('--previous-sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.study_root, args.previous_sources, args.output)
