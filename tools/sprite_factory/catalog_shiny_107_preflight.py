"""Recheck all 107 held shiny pairs in one guarded, per-species intake run.

This audits pinned normal assets and available normal/rare source tables. It
routes material repairs separately from genuine missing rare source data. It
never invents shiny colours or approves a model.
"""
import hashlib
import json
from collections import Counter
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/shiny-151-recovery'
EXTERNAL = Path('/home/adinho/Documents/3d_models')
FOLDERS = [ROOT / '.tmp/catalog-remaining-normal', ROOT / '.tmp/catalog-remaining-normal-legacy7',
           ROOT / '.tmp/remaining-catalog-intake/rig-recovered-normal']


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    ledger_path = HERE / 'catalog_shiny_151_recovery_status.json'
    inventory_path = WORK / 'inventory.json'
    ledger, inventory = read(ledger_path), read(inventory_path)
    held = {r['species']: r for r in ledger['entries'] if r['status'] != 'locally_admitted'}
    sources = {r['species']: r for r in inventory['entries']}
    assert len(held) == 107 and set(held) <= set(sources)
    zip_cache = {}
    rows = []
    try:
        for name, entry in sorted(held.items(), key=lambda item: item[1]['national_dex']):
            source = sources[name]
            assert entry['original_normal_sha256'] == source['source']['normal_glb_sha256']
            filename = f"{entry['national_dex']:04d}-{name}/model.glb"
            paths = [folder / filename for folder in FOLDERS if (folder / filename).is_file()]
            matches = [path for path in paths if sha(path) == entry['original_normal_sha256']]
            if len(matches) != 1:
                raise ValueError(f'{name}: pinned normal source missing or ambiguous')
            archive = Path(source['source']['source']['archive'])
            member = source['source']['source']['member']
            if archive not in zip_cache:
                zip_cache[archive] = zipfile.ZipFile(archive)
            info = zip_cache[archive].getinfo(member)
            if info.file_size != source['source']['source']['bytes'] or info.CRC != int(source['source']['source']['crc32'], 16):
                raise ValueError(f'{name}: authored normal source archive changed')
            resource = source['resource_id']
            za = WORK / 'za-materials' / resource / f'{resource}_00_00'
            scvi = EXTERNAL / 'Pokémon SCVI Base + DLC Model Dump' / resource / f'{resource}_00_00'
            tables = []
            for family, directory in [('za', za), ('scvi', scvi)]:
                rare = directory / f'{resource}_00_00_rare.trmtr'
                normal = directory / f'{resource}_00_00.trmtr'
                if rare.is_file() and normal.is_file():
                    tables.append({'family': family, 'normal': str(normal), 'normal_sha256': sha(normal),
                                   'rare': str(rare), 'rare_sha256': sha(rare)})
            expected = {'missing_compatible_shiny_source': 'source_required',
                        'za_binding_hold': 'material_binding_repair',
                        'scvi_material_hold': 'material_shader_repair'}[entry['status']]
            if expected == 'source_required' and tables:
                # An alternative source has appeared since the previous probe.
                stage = 'source_reprobe_ready'
            elif expected != 'source_required' and not tables:
                raise ValueError(f'{name}: pinned source tables disappeared')
            else:
                stage = expected
            rows.append({'species': name, 'national_dex': entry['national_dex'], 'status': stage,
                         'previous_status': entry['status'], 'reason': entry['reason'],
                         'normal_glb': str(matches[0]), 'normal_glb_sha256': entry['original_normal_sha256'],
                         'source_archive': str(archive), 'source_member': member,
                         'normal_source_crc32': source['source']['source']['crc32'],
                         'matched_source_tables': tables,
                         'appearance_approved': False, 'battle_approved': False,
                         'runtime_approved': False})
    finally:
        for opened in zip_cache.values():
            opened.close()
    counts = Counter(r['status'] for r in rows)
    assert sum(counts.values()) == 107
    out = {'schema': 1, 'date': '2026-09-29', 'scope': '107 held shiny pairs, one pinned intake pass',
           'catalog_approved_base_species': 683, 'model_production_complete': False,
           'counts': dict(sorted(counts.items())),
           'limitations': ['Missing rare material tables are a source requirement, not a converter retry.',
                           'Material repairs need exact mesh/texture binding and visual battle review before admission.'],
           'input_sha256': {str(ledger_path.relative_to(ROOT)): sha(ledger_path),
                            str(inventory_path.relative_to(ROOT)): sha(inventory_path)},
           'entries': rows}
    output = HERE / 'catalog_shiny_107_preflight.json'
    output.write_text(json.dumps(out, indent=2) + '\n')
    print('SHINY_107_PREFLIGHT',dict(sorted(counts.items())))


if __name__ == '__main__':
    main()
