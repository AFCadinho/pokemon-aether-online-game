#!/usr/bin/env python3
"""Write compiled v16 pins for local qualification, with publication unapproved."""
import argparse
from pathlib import Path

from probe_v13_compression import read, write, encoded, require
from study_lossless_texture_storage import ROOT, sha
from study_shared_form_textures import digest


def prepare(configuration):
    config = read(configuration)
    require(config['complete'] and not config['production_approved'], 'Unexpected assembly')
    require(config['builder_sha256'] == sha(ROOT / 'tools/package_approved_3d_release_v16.py'), 'Builder changed after assembly')
    assets = sorted((j['asset'] for j in config['jobs']), key=lambda a: a['asset_id'])
    require(len(assets) == len({a['asset_id'] for a in assets}) == 1421, 'Incomplete collection')
    require(sum(len(a['appearances']) for a in assets) == 2840, 'Incomplete appearances')
    total = sum(a['size_bytes'] for a in assets)
    require(total == config['total_bundle_bytes'] < 7_000_000_000, 'Wrong collection size')
    revision = config['revision']
    packs = [a for a in assets if a.get('format') in ['model-pair-pck-v1', 'model-texture-pck-v1']]
    trusted = {'schema': 1, 'kind': 'pokeaether-model-pair-catalog', 'catalog_revision': revision, 'assets': packs}
    wire = {'schema': 1, 'kind': 'pokeaether-optional-asset-index', 'catalog_revision': revision,
        'runtime_contract': {'pokemon_3d': 3, 'godot': '4.6'}, 'production_approved': True,
        'prototype_only': False, 'assets': [
            {'asset_id': a['asset_id'], 'format': 'model-pair-ref-v1', 'sha256': a['sha256']}
            if a in packs else a for a in assets]}
    data = encoded(wire)
    pin = {'object_key': 'optional-assets/pokemon_3d/index/v16-' + digest(data) + '.json',
           'sha256': digest(data), 'size_bytes': len(data)}
    client = {'schema': 1, 'revision': revision, 'index': pin, 'requiredAssetIds': [a['asset_id'] for a in assets]}
    for side in ['data', 'launcher/data']:
        write(ROOT / side / 'model_pair_release_v16_catalog.json', trusted)
        write(ROOT / side / 'approved_3d_release_v16.json', client)
        (ROOT / side / 'approved_3d_bundles_v16_index.json').write_bytes(data)
    (ROOT / 'release/approved_3d_bundles_v16_index.json').write_bytes(data)
    fields = ['asset_id', 'object_key', 'sha256', 'size_bytes']
    meta = {'schema': 1, 'kind': 'pokeaether-approved-3d-release', 'revision': revision,
        'index': pin, 'bundles': [{k: a[k] for k in fields} for a in assets],
        'total_bundle_bytes': total, 'model_pairs': 1420, 'texture_pools': 1,
        'saved_download_bytes': config['saved_bytes'], 'previous_revision': 'approved-pokemon-3d-v15'}
    write(ROOT / 'release/approved_3d_bundles_v16.json', meta)
    write(configuration.parent / 'sources.json', {'revision': revision,
        'metadata_sha256': sha(ROOT / 'release/approved_3d_bundles_v16.json'),
        'sources': {j['asset']['asset_id']: j['path'] for j in config['jobs']}})
    binding = {'schema': 1, 'revision': revision, 'runtime_approved': False, 'publication_approved': False,
        'pairs': 1420, 'appearances': 2840, 'texture_pools': 1, 'profiles_unchanged': True,
        'bundle_index_sha256': pin['sha256'], 'trusted_catalog_sha256': sha(ROOT / 'data/model_pair_release_v16_catalog.json'),
        'assembly_path': str(configuration), 'assembly_sha256': sha(configuration),
        'reviewed_registry_sha256': sha(ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'),
        'previous_binding_sha256': sha(ROOT / 'release/approved_3d_v15_binding.json'),
        'full_texture_audit_sha256': sha(ROOT / 'release/full_texture_storage_audit_v15.json'),
        'shared_texture_runtime_sha256': sha(ROOT / 'release/shared_texture_runtime_qualification.json')}
    write(ROOT / 'release/approved_3d_v16_binding.json', binding)
    print(f'V16_COMPILED_PINS_PREPARED archives=1421 bytes={total}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--configuration', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.configuration.resolve())
