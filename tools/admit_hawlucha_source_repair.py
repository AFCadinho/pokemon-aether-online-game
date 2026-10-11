#!/usr/bin/env python3
"""Admit one source replacement with fresh native/install/battle/pack evidence.

Run in the assigned slot after reviewing the retained source and battle sheets.
This changes local metadata only. Immutable uploads use a separate publisher.
Historical archive hashes remain recognizable, but their runtime poses are revoked.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/sprite_factory'))
from catalog_mega_battle_qualification import qualify

ASSET = 'pokemon_3d:hawlucha:mega'
IDENTITIES = {'hawlucha-mega', 'hawlucha-mega@shiny'}
REVISION = 'approved-pokemon-3d-v12'


def read(path): return json.loads(Path(path).read_bytes())
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def encoded(value): return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()
def write(path, value): Path(path).write_bytes(encoded(value))
def identity(row): return row['species'] + ('@shiny' if row.get('variant') == 'shiny' and not row['species'].endswith('@shiny') else '')


def checked_log(path, marker):
    text = path.read_text()
    assert marker in text and not re.search(r'(?:SCRIPT ERROR|^ERROR:)', text, re.M), path


def replace_asset(index, replacement, reference=False):
    positions = [i for i, row in enumerate(index['assets']) if row['asset_id'] == ASSET]
    assert len(positions) == 1
    old = index['assets'][positions[0]]
    if old.get('sha256') == replacement['sha256']:
        assert reference or old == replacement
        return
    if reference:
        assert old['format'] == 'model-pair-ref-v1'
        index['assets'][positions[0]] = {**old, 'sha256': replacement['sha256']}
    else:
        assert replacement['version'] > old['version']
        index['assets'][positions[0]] = replacement


def validate(source, work):
    delivery = work / 'hawlucha-delivery'
    fixture = read(delivery / 'runtime-fixture.json')
    expected = {k: v['sha256'] for k, v in fixture['models'].items()}
    assert set(expected) == IDENTITIES
    gate = read(source / 'hawlucha-battle/technical-qualification.json')
    native_path = source / 'hawlucha-battle/final/battle-review.json'
    assert gate['battle_report_sha256'] == sha(native_path)
    assert gate['technical_variant_count'] == 2 and not gate['held']
    native = read(native_path)
    assert native['complete']
    independent = qualify(native_path, source / 'hawlucha-battle/catalog.json', 1)
    assert independent['technical_variant_count'] == 2 and not independent['held']
    assert native['candidates_sha256'] == sha(source / 'hawlucha-battle/placement.json')
    placement = read(source / 'hawlucha-battle/placement.json')
    for name, model in fixture['models'].items():
        key = 'hawluchamega-shiny' if name.endswith('@shiny') else 'hawluchamega'
        motion = copy.deepcopy(placement['motion'][key])
        assert model['glb_sha256'] == motion['sha256']
        motion['sha256'] = model['sha256']
        assert fixture['profiles'][model['profile']]['motion'] == motion
    evidence = [native_path, source / 'hawlucha-battle/placement.json',
                source / 'hawlucha-battle/technical-qualification.json',
                delivery / 'runtime-fixture.json']
    for file in ['installed-megas/installed-catalog.json', 'on-demand-installed-catalog.json']:
        path = delivery / file
        rows = read(path)
        assert len(rows) == 2 and {identity(r): r['runtime_sha256'] for r in rows} == expected
        for row in rows: assert sha(row['runtime_path']) == row['runtime_sha256']
        evidence.append(path)
    for name, marker in [('install.log', 'MEGA_BUNDLES_OK bundles=1 scenes=2'),
                         ('runtime.log', 'MEGA_RUNTIME_OK pairs=1'), ('stress-v3.log', 'BATCH01_STRESS_OK')]:
        path = delivery / name
        checked_log(path, marker)
        evidence.append(path)
    stress = read(delivery / 'stress-v3.json')
    assert stress['complete'] and stress['catalog_sha256'] == sha(delivery / 'on-demand-installed-catalog.json')
    assert stress['species'] == ['hawlucha-mega']
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for arena, samples in [('classic', 480), ('stadium', 240)]:
        value = stress['steady_frame_p95_ms'][arena]
        assert value['samples'] >= samples and 0 < value['p95_ms'] <= 20
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 1
        assert 0 < cycle['frame_p95_ms'] <= 20 and cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation'] == 'threaded load dispatch/collect'), default=0) <= 1000 / 60
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024 * 1024
    evidence.append(delivery / 'stress-v3.json')
    index = read(work / 'replacement-bundles/asset-index.json')
    assert len(index['assets']) == 1 and index['assets'][0]['asset_id'] == ASSET
    asset = index['assets'][0]
    archive = work / 'replacement-bundles' / Path(asset['object_key']).name
    assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
    assert {a['runtime_identity']: a['runtime_sha256'] for a in asset['appearances']} == expected
    with zipfile.ZipFile(archive) as zipped:
        assert set(zipped.namelist()) == {'bundle.json', 'models/normal.scn', 'models/shiny.scn'}
        for appearance in asset['appearances']:
            assert hashlib.sha256(zipped.read('models/' + appearance['variant'] + '.scn')).hexdigest() == appearance['runtime_sha256']
    texture = read(work / 'shared-packs/textures/candidate-assets/0/asset.json')
    texture_proofs = list((work / 'shared-packs/textures/work').rglob('validated-*.receipts.jsonl'))
    assert len(texture_proofs) == 1
    texture_check = json.loads(texture_proofs[0].read_text().strip())
    assert texture_check['asset_id'] == ASSET and all(v['ok'] for v in texture_check['packs'].values())
    geometry_path = work / 'shared-packs/geometry/candidates.json'
    geometry_rows = read(geometry_path)
    assert len(geometry_rows) == 1 and geometry_rows[0]['verification']['ok']
    geometry = geometry_rows[0]['asset']
    for shared, path in [(texture, work / 'shared-packs/textures/packs' / Path(texture['object_key']).name),
                         (geometry, Path(geometry_rows[0]['path']))]:
        assert shared['asset_id'] == ASSET and sha(path) == shared['sha256'] and path.stat().st_size == shared['size_bytes']
        assert {a['runtime_identity']: a['source_sha256'] for a in shared['appearances']} == expected
    evidence += [work / 'replacement-bundles/asset-index.json', geometry_path, texture_proofs[0],
                 work / 'shared-packs/textures/candidate-assets/0/asset.json',
                 ROOT / 'tools/sprite_factory/catalog_mega_hawlucha_source_audit.json']
    receipt = dict(schema=1, pairs=1, models=2, appearance_approved=True, battle_approved=True,
                   runtime_approved=True, published=False, release_approved=False, bundle_index=index,
                   source='pm0761_51_00', superseded_source='pm0701_11_00 (Furfrou)',
                   native_qualification=gate, runtime_rounds=stress['rounds'],
                   steady_frame_p95_ms=stress['steady_frame_p95_ms'],
                   scope='One repaired source pair; sampled appearance and battle review, native 120 Hz clearance, launcher, on-demand, three real HUD battle rounds. Not whole release/platform certification.',
                   limitations=['Native faint_loop serves as sleep; no distinct native sleep clip.'],
                   evidence={str(p.relative_to(ROOT)): sha(p) for p in evidence})
    return fixture, asset, texture, geometry, receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    fixture, asset, texture, geometry, receipt = validate(args.source.resolve(), args.work.resolve())
    if not args.apply:
        print('HAWLUCHA_REPLACEMENT_QUALIFIED pairs=1')
        return
    receipt_path = ROOT / 'release/hawlucha_source_repair_qualification.json'
    write(receipt_path, receipt)
    registry_path = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    original = registry_path.read_text()
    registry = json.loads(original)
    bindings = read(args.work / 'shared-packs/source-bindings.json')
    # Normal and shiny share anatomy and native placement; only appearance hashes differ.
    shared_profile = copy.deepcopy(fixture['profiles']['hawlucha-mega-normal'])
    shared_profile['motion'].pop('sha256')
    shiny_profile = copy.deepcopy(fixture['profiles']['hawlucha-mega-shiny'])
    shiny_profile['motion'].pop('sha256')
    assert shared_profile == shiny_profile
    fixture['profiles'] = {'hawlucha-mega': shared_profile}
    for model in fixture['models'].values(): model['profile'] = 'hawlucha-mega'
    obsolete = ['hawlucha-mega-normal', 'hawlucha-mega-shiny']
    for key in obsolete: registry['profiles'].pop(key, None)
    for identity, replacement in fixture['models'].items():
        old = registry['models'][identity]
        if old['sha256'] == replacement['sha256']:
            assert old.get('revoked_runtime_sha256') == old.get('previous_sha256')
            previous = old['previous_sha256']
        else:
            previous = sorted(set([old['sha256'], *old.get('previous_sha256', [])]))
        assert replacement['sha256'] not in previous, 'Already admitted or unexpected previous source'
        registry['models'][identity] = {**replacement, 'previous_sha256': previous,
            'revoked_runtime_sha256': previous, 'cache_source_bytes': bindings[identity]['cache_source_bytes']}
        registry['profiles'][replacement['profile']] = fixture['profiles'][replacement['profile']]
    registry['hawlucha_source_repair_qualification_sha256'] = sha(receipt_path)
    # Splice only two model/profile values; preserve all unrelated floating-point spellings.
    for section in ['models', 'profiles']:
        before = json.loads(original)[section]
        for key in list(fixture[section]) + (obsolete if section == 'profiles' else []):
            # Locate the JSON value structurally rather than assuming formatter precision.
            section_start = original.index('\n\t"' + section + '":')
            match = re.search(r'\n\t\t"' + re.escape(key) + r'": ', original[section_start:])
            if key in obsolete:
                if match:
                    start = section_start + match.end()
                    _, size = json.JSONDecoder().raw_decode(original[start:])
                    end = start + size
                    assert original[end] == ','
                    original = original[:section_start + match.start()] + original[end + 1:]
                continue
            if match is None:
                assert section == 'profiles' and key not in before
                opening = original.index('{', section_start) + 1
                block = json.dumps(registry[section][key], indent='\t', sort_keys=True, ensure_ascii=False).replace('\n', '\n\t\t')
                original = original[:opening] + '\n\t\t' + json.dumps(key) + ': ' + block + ',' + original[opening:]
                continue
            start = section_start + match.end()
            _, size = json.JSONDecoder().raw_decode(original[start:])
            block = json.dumps(registry[section][key], indent='\t', sort_keys=True, ensure_ascii=False).replace('\n', '\n\t\t')
            original = original[:start] + block + original[start + size:]
    if '"hawlucha_source_repair_qualification_sha256"' not in original:
        original = original.replace('{\n', '{\n\t"hawlucha_source_repair_qualification_sha256": "' + sha(receipt_path) + '",\n', 1)
    assert json.loads(original) == registry
    registry_path.write_text(original)
    (ROOT / 'launcher/data/reviewed_model_catalog.json').write_text(original)
    index = read(ROOT / 'release/approved_3d_bundles_v11_index.json')
    replace_asset(index, asset)
    index['catalog_revision'] = REVISION
    index_path = ROOT / 'release/approved_3d_bundles_v12_index.json'
    write(index_path, index)
    descriptor = dict(schema=1, revision=REVISION, requiredAssetIds=[a['asset_id'] for a in index['assets']],
        index=dict(object_key='optional-assets/pokemon_3d/index/v12-' + sha(index_path) + '.json',
                   sha256=sha(index_path), size_bytes=index_path.stat().st_size))
    for prefix in ['data', 'launcher/data']: write(ROOT / prefix / 'approved_3d_release_v12.json', descriptor)
    for name, replacement, reference in [('model_pair_catalog', texture, False), ('model_pair_qualified', texture, True),
                                         ('model_pair_geometry_catalog', geometry, False), ('model_pair_geometry', geometry, True)]:
        path = ROOT / 'data' / (name + '.json')
        data = read(path)
        replace_asset(data, replacement, reference)
        if 'catalog_revision' in data and not data['catalog_revision'].endswith('-hawlucha-repair-1'):
            data['catalog_revision'] += '-hawlucha-repair-1'
        data['source_repair_qualification_sha256'] = sha(receipt_path)
        if name == 'model_pair_catalog':
            # Retain the established one-asset-per-line review format.
            header = json.dumps({k: v for k, v in data.items() if k != 'assets'}, indent=2, sort_keys=True)[:-2]
            payload = header + ',\n  "assets": [\n' + ',\n'.join('    ' + encoded(a).decode().strip() for a in data['assets']) + '\n  ]\n}\n'
            assert json.loads(payload) == data
            for prefix in ['data', 'launcher/data']: (ROOT / prefix / path.name).write_text(payload)
        else:
            for prefix in ['data', 'launcher/data']: write(ROOT / prefix / path.name, data)
    print('HAWLUCHA_REPLACEMENT_ADMITTED pairs=1 published=false')


if __name__ == '__main__': main()
