"""Audit exact regional identities against the real Pokédex and pinned 3D release.

Read-only inputs; outputs are evidence, never model approvals. No network access.
"""
import argparse
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

REGIONS = ('alola', 'galar', 'hisui', 'paldea')
EXTRAS = {
    'pikachu-alola': 'cap variant',
    'marowak-alola-totem': 'totem variant',
    'raticate-alola-totem': 'totem variant',
    'darmanitan-galar-zen': 'battle transformation',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def revision(path):
    return subprocess.check_output(['git', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()


def audit(frontend, backend, sources):
    module_path = backend / 'account-service/pokedex_species.py'
    spec = importlib.util.spec_from_file_location('regional_dex_audit', module_path)
    dex = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dex)
    visible = dex._species_entries_for_dex('national')
    reviewed_path = frontend / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    reviewed = read(reviewed_path)['models']
    screened = read(frontend / 'scripts/battle/battle_ui/screened_model_catalog.json')['models']
    release_path = frontend / 'data/approved_3d_release_v9.json'
    release = read(release_path)
    index_path = frontend / 'release/approved_3d_bundles_v9_index.json'
    assert digest(index_path) == release['index']['sha256'], 'Index differs from the release pin'
    assert index_path.stat().st_size == release['index']['size_bytes']
    index = {row['asset_id']: row for row in read(index_path)['assets']}
    assert set(index) == set(release['requiredAssetIds']), 'Release/index asset-set mismatch'
    for relative in ['data/approved_3d_release_v9.json', 'data/reviewed_model_catalog.json']:
        client = release_path if 'release' in relative else reviewed_path
        assert read(client) == read(frontend / 'launcher' / relative), 'Launcher/client mismatch'
    rows = []
    for species, data in visible:
        region = next((r for r in REGIONS if r in species.split('-')), None)
        if region is None:
            continue
        asset_id = f'pokemon_3d:{species}:base'
        asset = index.get(asset_id, {})
        appearances = {a['runtime_identity']: a for a in asset.get('appearances', [])}
        variants = {}
        for suffix in ['', '@shiny']:
            identity = species + suffix
            approved = reviewed.get(identity, {})
            appearance = appearances.get(identity, {})
            variants['shiny' if suffix else 'normal'] = {
                'identity': identity,
                'reviewed': bool(approved),
                'screened_only': identity in screened,
                'indexed': bool(appearance),
                'digest_matches': bool(approved) and approved['sha256'] == appearance.get('runtime_sha256'),
            }
        rows.append({
            'species': species, 'name': data['name'], 'region': region,
            'kind': EXTRAS.get(species, 'regional form'),
            'species_data_sha256': digest(backend / 'pokemon-data/data/species' / (species + '.json')),
            'asset_id': asset_id, 'release_listed': asset_id in release['requiredAssetIds'],
            'variants': variants,
            'ready_pair': all(v['digest_matches'] for v in variants.values()),
        })
    summary = {}
    for region in REGIONS:
        subset = [r for r in rows if r['region'] == region and r['kind'] == 'regional form']
        summary[region] = {'total': len(subset), 'ready_pairs': sum(r['ready_pair'] for r in subset),
                           'missing_pairs': sum(not r['ready_pair'] for r in subset)}
    # Samurott source evidence is separate from runtime availability.
    from scvi_identity import read_catalog
    catalog_path = sources / 'SV Every File/romfs/pokemon/catalog/catalog/poke_resource_table.trpmcatalog'
    catalog = read_catalog(catalog_path)
    matches = [r for r in catalog['entries'] if (r['national_dex_id'], r['form'], r['gender_code']) == (503, 1, 0)]
    assert len(matches) == 1
    source = matches[0]
    rid = source['resource_id']
    model_dir = sources / 'Pokémon SCVI Base + DLC Model Dump' / Path(source['model_path']).parent
    motion_dir = sources / 'SV Every File/romfs/pokemon/data' / Path(source['model_path']).parent
    files = [model_dir / (rid + suffix) for suffix in ['.trmdl', '.trmsh', '.trmbf', '.trskl', '.trmtr', '_rare.trmtr']]
    source.update({
        'catalog_sha256': digest(catalog_path),
        'model_directory': str(model_dir), 'motion_directory': str(motion_dir),
        'source_file_sha256': {p.name: digest(p) for p in files},
        'skeletal_motions': sorted(p.name for p in motion_dir.glob('*.tranm')),
        'material_motions': sorted(p.name for p in motion_dir.glob('*.tracm')),
        'rare_textures': sorted(p.name for p in model_dir.glob('*rare*.png')),
        'runtime_approved': False,
    })
    return {
        'schema': 1, 'scope': 'local regional Pokédex coverage; no production access or visual approval',
        'frontend_revision': revision(frontend), 'backend_revision': revision(backend),
        'pokedex_module_sha256': digest(module_path), 'visible_pokedex_rows': len(visible),
        'reviewed_catalog_sha256': digest(reviewed_path), 'release_sha256': digest(release_path),
        'index_sha256': digest(index_path), 'release_revision': release['revision'],
        'client_launcher_equal': True, 'regional_summary': summary,
        'extra_variants': {r['species']: r['ready_pair'] for r in rows if r['kind'] != 'regional form'},
        'entries': rows, 'samurott_hisui_source': source,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', type=Path, required=True)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    frontend = Path(__file__).resolve().parents[2]
    result = audit(frontend, args.backend.resolve(), args.sources.resolve())
    args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps(result['regional_summary'], indent=2))
    print('Extra variants:', result['extra_variants'])


if __name__ == '__main__':
    sys.dont_write_bytecode = True
    main()
