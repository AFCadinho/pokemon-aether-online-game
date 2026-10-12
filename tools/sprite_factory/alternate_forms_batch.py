"""Resumable source-pinned batch for every missing alternate form in the audit.

Candidate generation only. No runtime registry, release selection or publication.
"""
import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import zipfile

from catalog_galar_birds_candidates import export, material as source_material, verify
from scvi_batch import source_entry
from scvi_identity import read_catalog
from scvi_material_probe import inspect_materials

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
WORK = ROOT / '.tmp/alternate-forms-batch-v1'
SOURCE = Path('/run/media/adinho/AFC_Adinho/3d_models')
MODELS = SOURCE / 'Pokémon SCVI Base + DLC Model Dump'
MOTIONS = SOURCE / 'SV Every File/romfs/pokemon/data'
INTAKE = HERE / 'alternate_forms_source_intake.json'


def material(row, source_root, work):
    from alternate_forms_static_effects import colour
    return source_material(row, source_root, work,
        static_effect_colour=colour if row.get('preserve_source_static_effects') else None)


def cohort_rows():
    mode = os.environ.get('POKEAETHER_FORM_BATCH_COHORT', 'native')
    if mode == 'native':
        return [r for r in read(INTAKE)['entries'] if r['status']=='native_candidate']
    if mode == 'legacy':
        return [r for r in read(WORK/'legacy-material-status.json')['entries'] if r['status']=='candidate']
    if mode == 'za':
        return [r for r in read(HERE/'alternate_forms_za_intake.json')['entries'] if r['status']=='native_candidate']
    if mode == 'colours':
        return [r for r in read(HERE/'alternate_forms_colour_intake.json')['entries'] if r['status']=='native_candidate']
    raise ValueError('Unknown batch cohort: '+mode)

# Explicit proposals. All require source-icon and rendered-pose review before admission.
GROUPS = {
 'rotom': (479, 12, ['heat', 'wash', 'frost', 'fan', 'mow']),
 'deerling': (585, 12, ['summer', 'autumn', 'winter']),
 'sawsbuck': (586, 12, ['summer', 'autumn', 'winter']),
 'flabebe': (713, 12, ['yellow', 'orange', 'blue', 'white']),
 'floette': (714, 12, ['yellow', 'orange', 'blue', 'white']),
 'florges': (715, 12, ['yellow', 'orange', 'blue', 'white']),
 'vivillon': (708, 11, ['icy-snow','polar','tundra','continental','garden','elegant',
     'meadow','modern','marine','archipelago','high-plains','sandstorm','river',
     'monsoon','savanna','sun','ocean','jungle','fancy','pokeball']),
 'alcremie': (925, 12, ['ruby-cream','matcha-cream','mint-cream','lemon-cream',
     'salted-cream','ruby-swirl','caramel-swirl','rainbow-swirl']),
 'deoxys': (386, 12, ['attack','defense','speed']),
 'oricorio': (825, 12, ['pom-pom','pau','sensu']),
 'lycanroc': (829, 12, ['midnight','dusk']),
 'tatsugiri': (1056, 12, ['droopy','stretchy']),
}
EXPLICIT = {
 'basculegion-f':'pm1006_12_41', 'basculin-blue-striped':'pm0550_12_00',
 'basculin-white-striped':'pm0550_00_41', 'dialga-origin':'pm0483_12_00',
 'palkia-origin':'pm0484_12_00', 'giratina-origin':'pm0487_12_00',
 'dudunsparce-three-segment':'pm1021_12_00', 'enamorus-therian':'pm1004_12_00',
 'gastrodon-east':'pm0423_12_00','shellos-east':'pm0422_12_00',
 'gimmighoul-roaming':'pm1080_12_00','hoopa-unbound':'pm0774_12_00',
 'indeedee-f':'pm0942_01_00','oinkologne-f':'pm1020_01_00',
 'magearna-original':'pm0882_12_00','maushold-four':'pm1050_12_00',
 'meloetta-pirouette':'pm0648_12_00','meowstic-f':'pm0734_01_00',
 'polteageist-antique':'pm0973_12_00','sinistea-antique':'pm0972_12_00',
 'toxtricity-low-key':'pm0922_12_00','zarude-dada':'pm0988_12_00',
 'keldeo-resolute':'pm0647_12_00','shaymin-sky':'pm0492_12_00',
 'cramorant-gulping':'pm0917_12_00','cramorant-gorging':'pm0917_13_00',
 'necrozma-dusk-mane':'pm0865_12_00','necrozma-dawn-wings':'pm0865_13_00',
 'ursaluna-bloodmoon':'pm1007_11_00',
 'pikachu-original':'pm0025_11_00','pikachu-hoenn':'pm0025_12_00',
 'pikachu-sinnoh':'pm0025_13_00','pikachu-unova':'pm0025_14_00',
 'pikachu-kalos':'pm0025_15_00','pikachu-partner':'pm0025_17_00',
 'pikachu-world':'pm0025_18_00',
}
for family, (pm, first, forms) in GROUPS.items():
    for offset, form in enumerate(forms):
        EXPLICIT[family + '-' + form] = f'pm{pm:04}_{first + offset:02}_00'


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda: f.read(1024 * 1024), b''): h.update(b)
    return h.hexdigest()


def read(path):
    return json.loads(Path(path).read_bytes())


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + '.writing')
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(path)


def pin(path):
    return {'path': str(path.relative_to(SOURCE)), 'bytes': path.stat().st_size, 'sha256': sha(path)}


def intake(backend):
    audit_path = HERE / 'alternate_model_coverage_audit.json'
    rows = [r for r in read(audit_path)['entries'] if r['visible_pokedex'] and r['status'] == 'missing_pair']
    assert len(rows) == 229 and len({r['species'] for r in rows}) == 229
    catalog_path = SOURCE / 'SV Every File/romfs/pokemon/catalog/catalog/poke_resource_table.trpmcatalog'
    catalog = read_catalog(catalog_path)['entries']
    dev_ids = {}; archives = []
    for archive in sorted((SOURCE / 'Biochao').glob('Gen*.zip')):
        with zipfile.ZipFile(archive) as z:
            for item in z.infolist():
                if item.filename.endswith('.blend'):
                    archives.append({'archive': str(archive.relative_to(SOURCE)), 'member': item.filename,
                        'bytes': item.file_size, 'crc32': f'{item.CRC:08x}'})
            if '_pokemon_dev_numbers.csv' in z.namelist():
                for fields in csv.reader(io.StringIO(z.read('_pokemon_dev_numbers.csv').decode())):
                    if len(fields) > 1 and fields[0].isdigit() and fields[1].isdigit():
                        dev_ids[int(fields[0])] = int(fields[1])
    results = []
    for row in rows:
        name = row['species']; species_path = backend / 'pokemon-data/data/species' / (name + '.json')
        data = read(species_path); base = data['catch_rate_source']['pokemon_species']
        base_path = species_path.with_name(base + '.json')
        number = read(base_path)['id'] if base_path.exists() else data['id']
        matches = [r for r in catalog if r['national_dex_id'] == number]
        pm = dev_ids.get(number, number if number < 650 else int(matches[0]['resource_id'][2:6]) if matches else -1)
        if name.startswith('ogerpon-'): pm = 1120
        if name.startswith('poltchageist-'): pm = 1123
        if name.startswith('sinistcha-'): pm = 1124
        resource = EXPLICIT.get(name)
        directory = MODELS / f'pm{pm:04}'
        entry = {'species': name, 'national_dex': number, 'family': row['family'],
            'species_data_sha256': sha(species_path), 'resource': resource,
            'status': 'source_mapping_review', 'runtime_approved': False,
            'identity_reviewed': False, 'catalog_rows': matches,
            'source_directories': sorted(str(p.relative_to(SOURCE)) for p in directory.glob('*') if p.is_dir()),
            'archive_candidates': [r for r in archives if r['member'].startswith(f'pm{pm:04}')],
            'holds': []}
        if name == 'necrozma-ultra':
            entry['archive_candidates'] += [r for r in archives if r['member'] == 'pm0800.blend' and 'Gen7' in r['archive']]
        if resource:
            modeldir = MODELS / resource[:6] / resource
            entry['scvi_files'] = [pin(p) for p in sorted(modeldir.rglob('*')) if p.is_file() and p.name != 'desktop.ini']
            entry['icons'] = [p['path'] for p in entry['scvi_files'] if '/icon/' in p['path'] and p['path'].endswith('.png')]
            source = source_entry({'species': name, 'pm': int(resource[2:6]), 'resource_id': resource}, MODELS, MOTIONS)
            entry['actions'] = {a: Path(p).stem for a, p in source['motions'].items() if p}
            entry['motion_selection'] = {k: source[k] for k in ['motion_bank','motion_selection_policy','alternatives']}
            paths = [Path(p) for p in [*source['motions'].values(), *source['motion_channels'].values()] if p]
            entry['selected_motion_files'] = [pin(p) for p in sorted(set(paths))]
            entry['rare_texture_replacements'] = []
            entry['dynamic_visibility_review'] = True
            native_holds = [w for w in source['warnings'] if w.startswith(('missing_action:', 'motion_bank_hold:', 'missing_model'))]
            if any(source['motions'][a] and not source['motion_channels'][a] for a in source['motions']):
                native_holds.append('missing_material_motion_companion')
            normal, rare = modeldir/(resource+'.trmtr'), modeldir/(resource+'_rare.trmtr')
            if not normal.exists() or not rare.exists():
                native_holds.append('missing_normal_or_rare_material_table')
            else:
                entry['identical_source_variant_review'] = inspect_materials(normal) == inspect_materials(rare)
            shared = [r for r in matches if r['resource_id'] == resource]
            if len(shared) > 1:
                native_holds.append('shared_form_material_selector_requires_explicit_sampling')
            entry['holds'] = native_holds
            entry['status'] = 'native_candidate' if not native_holds else 'native_source_hold'
        else:
            if name.startswith(('arceus-', 'silvally-', 'squawkabilly-', 'minior-')):
                entry['holds'].append('form_material_selector_requires_explicit_sampling')
            elif '-totem' in name or name in ['rockruff-dusk','eevee-starter','pikachu-starter']:
                entry['holds'].append('shared_base_geometry_and_source_scale_require_verification')
            else:
                entry['holds'].append('archive_or_raw_variant_identity_requires_review')
        results.append(entry)
    write(INTAKE, {'schema': 1, 'audit_sha256': sha(audit_path), 'source_root': str(SOURCE),
        'identity_catalog': pin(catalog_path), 'runtime_approved': False, 'entries': results})
    print(json.dumps(Counter(r['status'] for r in results), indent=2), flush=True)


def candidates(phase, only=None):
    spec = read(INTAKE)
    assert sha(SOURCE / spec['identity_catalog']['path']) == spec['identity_catalog']['sha256']
    rows = [r for r in cohort_rows() if not only or r['species'] in only]
    WORK.mkdir(parents=True, exist_ok=True)
    def one(row):
        saved = WORK / 'status' / phase / (row['species'] + '.json')
        if saved.exists():
            record = read(saved)
            if record.get('intake_sha256') == sha(INTAKE) and record['status'] == 'candidate':
                # Cache existence is not proof: reusable workers re-check pinned inputs/outputs.
                pass
        try:
            verify(row, SOURCE)
            if phase == 'material':
                from alternate_forms_material_sources import prepare
                row = prepare(row)
            result = (export if phase == 'export' else material)(row, SOURCE, WORK)
            record = {'species': row['species'], 'status': 'candidate', 'intake_sha256': sha(INTAKE), **result}
        except Exception as error:
            record = {'species': row['species'], 'status': 'held', 'intake_sha256': sha(INTAKE),
                      'reason': type(error).__name__ + ': ' + str(error)}
        write(saved, record)
        return record
    results = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(one, row) for row in rows]
        for future in as_completed(futures):
            result = future.result(); results.append(result)
            print(phase.upper(), result['species'], result['status'], result.get('reason',''), flush=True)
            write(WORK / (phase + '-status.json'), {'runtime_approved': False, 'entries': sorted(results, key=lambda r:r['species'])})


def sheets():
    from PIL import Image, ImageDraw
    rows = [r for r in read(INTAKE)['entries'] if r.get('icons')]
    out = WORK / 'source-review'; out.mkdir(parents=True, exist_ok=True)
    for offset in range(0, len(rows), 30):
        page = Image.new('RGB', (1000, 1080), '#d0d5df'); draw = ImageDraw.Draw(page)
        for i, row in enumerate(rows[offset:offset + 30]):
            x, y = (i % 5) * 200, (i // 5) * 180
            selected = next((p for p in row['icons'] if p.endswith('_big.png')), row['icons'][0])
            icon = Image.open(SOURCE / selected).convert('RGBA'); icon.thumbnail((160,140))
            page.paste(icon, (x + (200-icon.width)//2, y+2), icon)
            draw.text((x+4,y+143), row['species'], fill='black')
            draw.text((x+4,y+158), row['resource'], fill='black')
        page.save(out / f'icons-{offset//30+1}.png')
    print('SOURCE_ICON_PAGES', (len(rows)+29)//30)


if __name__ == '__main__':
    sys.dont_write_bytecode = True
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('phase', choices=['intake','export','material','sheets'])
    p.add_argument('--backend', type=Path)
    p.add_argument('--only', help='Comma-separated candidate identities')
    args = p.parse_args()
    if os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        p.error('Run through the assigned slot-env')
    if args.phase == 'intake': intake(args.backend.resolve())
    elif args.phase == 'sheets': sheets()
    else: candidates(args.phase, set(args.only.split(',')) if args.only else None)
