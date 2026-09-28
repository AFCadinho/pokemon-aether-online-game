#!/usr/bin/env python3
"""Package reviewed pairs, then admit only after transactional install checks."""
import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/remaining-ten-bundles'
BATTLE = ROOT / '.tmp/remaining-ten-battle'
PREFIX = 'catalog_remaining_ten_'
NAMES = ('blastoise', 'furret', 'yanma', 'entei', 'mudkip', 'solosis', 'reuniclus', 'incineroar', 'primarina', 'dewpider')
DEX = dict(zip(NAMES, (9, 162, 193, 244, 258, 577, 579, 727, 730, 751)))
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def evidence():
    appearance = read(HERE / 'catalog_remaining_visual_holds_review.json')
    qualification_path = HERE / (PREFIX + 'battle_qualification.json')
    qualification = read(qualification_path)
    profiles_path = HERE / (PREFIX + 'battle_profiles.json')
    assert appearance['user_review']['appearance_approved'] and qualification['user_review']['battle_approved']
    assert qualification['appearance_approved'] and qualification['camera_grounding_checks_passed']
    assert qualification['profiles_sha256'] == sha(profiles_path)
    assert qualification['camera_grounding_checks_passed'] and qualification['runtime_lifecycle_check_passed']
    for path, digest in qualification['evidence_sha256'].items():
        assert sha(ROOT / path) == digest, path
    expected = {(name, variant) for name in NAMES for variant in ('normal', 'shiny')}
    rows = read(BATTLE / 'runtime-catalog.json')
    assert len(rows) == 20 and {(r['species'], r['variant']) for r in rows} == expected
    decisions = {(e['species'], e['variant']): e for e in appearance['entries']}
    assert set(decisions) == expected
    for row in rows:
        decision = decisions[row['species'], row['variant']]
        for field, source in (('runtime_sha256', 'runtime_path'), ('glb_sha256', 'path')):
            assert sha(Path(row[source])) == row[field] == decision[field]
        assert decision['visual_approval'] == 'user_approved'
    return rows, read(profiles_path)


def package():
    rows, _ = evidence()
    catalog = WORK / 'source-catalog.json'
    if catalog.exists():
        raise ValueError('Output already exists; retain the previous artifacts.')
    WORK.mkdir(parents=True, exist_ok=True)
    catalog.write_bytes(encoded(rows))
    hashes = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r['runtime_sha256'] for r in rows}
    index = build(catalog, WORK / 'bundles', revision='remaining-ten-approved-v1',
                  species_set=NAMES, dex=DEX, candidate_hashes=hashes)
    print('Built', len(index['assets']), 'bundles;', sum(a['size_bytes'] for a in index['assets']), 'bytes')


def admit():
    rows, candidate = evidence()
    index_path = WORK / 'bundles/asset-index.json'
    index = read(index_path)
    assert {a['species_id'] for a in index['assets']} == set(NAMES) and len(index['assets']) == 10
    installed_path = WORK / 'installed/installed-catalog.json'
    installed = read(installed_path)
    expected = {(r['species'], r['variant']): r['runtime_sha256'] for r in rows}
    assert len(installed) == 20
    assert {(r['species'], r['variant']): r['runtime_sha256'] for r in installed} == expected
    for row in installed:
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
    log = (WORK / 'install.log').read_text()
    assert 'REMAINING_TEN_BUNDLES_OK bundles=10 scenes=20' in log and 'ERROR:' not in log
    for asset in index['assets']:
        archive = index_path.parent / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
        assert {a['variant']: a['runtime_sha256'] for a in asset['appearances']} == {
            v: expected[asset['species_id'], v] for v in ('normal', 'shiny')}
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    screened = read(ROOT / 'scripts/battle/battle_ui/screened_model_catalog.json')
    for name in NAMES:
        assert name not in registry['profiles']
        profile = copy.deepcopy(candidate['profiles'][name + '-normal'])
        rare = copy.deepcopy(candidate['profiles'][name + '-shiny'])
        profile['motion'].pop('sha256')
        rare['motion'].pop('sha256')
        assert profile == rare, 'Normal/shiny placement or timing differs'
        registry['profiles'][name] = profile
        for variant in ('normal', 'shiny'):
            identity = name + ('@shiny' if variant == 'shiny' else '')
            assert identity not in registry['models'] and identity not in screened['models']
            registry['models'][identity] = {**candidate['models'][identity], 'profile': name}
    receipt = {'schema': 1, 'runtime_approved': True, 'release_approved': False, 'published': False,
               'species': list(NAMES), 'bundle_index': index, 'evidence_sha256': {
                   str(path.relative_to(ROOT)): sha(path) for path in (
                       HERE / 'catalog_remaining_visual_holds_review.json', HERE / (PREFIX + 'battle_qualification.json'),
                       index_path, installed_path, WORK / 'install.log')},
               'remaining': ['installed-catalog production presenter check', 'release certification and publication']}
    receipt_path = HERE / (PREFIX + 'bundle_qualification.json')
    receipt_path.write_bytes(encoded(receipt))
    registry['remaining_ten_bundle_qualification_sha256'] = sha(receipt_path)
    payload = encoded(registry)
    game.write_bytes(payload)
    launcher.write_bytes(payload)
    print('Admitted ten pairs to local game/launcher registries; publication unchanged')


def finalize():
    evidence()
    path = WORK / 'installed-stress.json'
    stress = read(path)
    log = WORK / 'installed-stress.log'
    assert stress['complete'] and stress['species'] == list(NAMES)
    assert stress['catalog_sha256'] == sha(WORK / 'installed/installed-catalog.json')
    assert 'BATCH01_STRESS_OK' in log.read_text() and 'ERROR:' not in log.read_text()
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for row in stress['rounds']:
        assert row['pairs'] == 10 and row['faint_replacements'] == 10
        assert 0 < row['frame_p95_ms'] <= 20
        assert row['retained_source_bytes'] <= 64 * 1024 * 1024
        assert max((s['ms'] for s in row['load_spans'] if s['operation'] == 'threaded load dispatch/collect'), default=0) <= 1000 / 60
        assert not any(s['ms'] > 100 and not s['covered'] for s in row['stalls_over_50ms'])
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024 * 1024
    noop = (WORK / 'noop.log').read_text()
    assert 'REMAINING_TEN_BUNDLES_OK bundles=10 scenes=20 resumed=10' in noop and 'ERROR:' not in noop
    probe = (WORK / 'update-probe.log').read_text()
    assert 'REMAINING_TEN_UPDATE_OK single=blastoise other=furret corruption=true rollback=true restart=true scenes=2' in probe
    assert 'ERROR:' not in probe
    update_index = read(WORK / 'update-v2/asset-index.json')
    assert len(update_index['assets']) == 1 and update_index['assets'][0]['species_id'] == 'blastoise'
    assert update_index['assets'][0]['version'] == 2
    updated_archive = WORK / 'update-v2' / Path(update_index['assets'][0]['object_key']).name
    assert sha(updated_archive) == update_index['assets'][0]['sha256']
    receipt_path = HERE / (PREFIX + 'bundle_qualification.json')
    receipt = read(receipt_path)
    for relative, digest in receipt['evidence_sha256'].items():
        assert sha(ROOT / relative) == digest
    receipt['installed_runtime_check_passed'] = True
    receipt['no_op_restart_check_passed'] = True
    receipt['single_species_update_corruption_rollback_check_passed'] = True
    receipt['installed_runtime_rounds'] = stress['rounds']
    receipt['remaining'] = ['release certification and publication']
    for source in (path, log, WORK / 'install_check.gd', WORK / 'noop.log',
                   WORK / 'update-probe.log', WORK / 'update_probe.gd',
                   WORK / 'update-v2/asset-index.json', updated_archive, Path(__file__)):
        receipt['evidence_sha256'][str(source.relative_to(ROOT))] = sha(source)
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    receipt_path.write_bytes(encoded(receipt))
    registry['remaining_ten_bundle_qualification_sha256'] = sha(receipt_path)
    for target in (game, launcher):
        target.write_bytes(encoded(registry))
    print('Installed production-presenter checks passed; local bundle qualification complete')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('package', 'admit', 'finalize'))
    args = parser.parse_args()
    {'package': package, 'admit': admit, 'finalize': finalize}[args.phase]()
