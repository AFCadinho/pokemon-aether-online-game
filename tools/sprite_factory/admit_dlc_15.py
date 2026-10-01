"""Package and admit the 15 DLC approved normal/shiny pairs locally."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/remaining-dlc-15-v1/approved-final'
NAMES = tuple(sorted({r['species'] for r in json.loads((HERE / 'catalog_remaining_dlc_battle_qualification.json').read_text())['records']}))
DEX = dict(zip(('dipplin', 'poltchageist', 'sinistcha', 'okidogi', 'munkidori', 'fezandipiti', 'ogerpon', 'archaludon', 'hydrapple', 'gouging-fire', 'raging-bolt', 'iron-boulder', 'iron-crown', 'terapagos', 'pecharunt'), range(1011,1026)))
EXPECTED = {(n, v) for n in NAMES for v in ('normal', 'shiny')}
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def evidence():
    receipt_path = HERE / 'catalog_remaining_dlc_battle_qualification.json'
    profiles_path = HERE / 'catalog_remaining_dlc_profiles.json'
    receipt = read(receipt_path)
    assert receipt['battle_approved'] and receipt['appearance_approved']
    assert receipt['profiles_sha256'] == sha(profiles_path)
    for group in ('evidence_sha256', 'capture_sha256'):
        for path, digest in receipt[group].items():
            assert sha(ROOT / path) == digest, path
    rows = read(WORK / 'runtime-catalog-final.json')
    assert len(rows) == 30 and {(r['species'],r['variant']) for r in rows} == EXPECTED
    accepted = {(r['species'],r['variant']):r for r in receipt['records']}
    for row in rows:
        approved = accepted[row['species'],row['variant']]
        assert approved['appearance_approved'] and approved['battle_approved']
        assert sha(Path(row['path'])) == row['glb_sha256'] == approved['glb_sha256']
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256'] == approved['runtime_sha256']
    return rows, read(profiles_path)


def package():
    rows, _ = evidence()
    hashes = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r['runtime_sha256'] for r in rows}
    index = build(WORK / 'runtime-catalog-final.json', WORK / 'bundles',
                  revision='remaining-dlc-15-approved-v1', species_set=NAMES,
                  dex=DEX, candidate_hashes=hashes)
    print('Built', len(index['assets']), 'bundles;', sum(a['size_bytes'] for a in index['assets']), 'bytes')


def admit():
    rows, fixture = evidence()
    index_path = WORK / 'bundles/asset-index.json'
    index = read(index_path)
    installed_path = WORK / 'installed/installed-catalog.json'
    installed = read(installed_path)
    expected = {(r['species'], r['variant']): r['runtime_sha256'] for r in rows}
    assert len(installed) == 30 and {(r['species'], r['variant']): r['runtime_sha256'] for r in installed} == expected
    assert len(index['assets']) == 15 and {a['species_id'] for a in index['assets']} == set(NAMES)
    for row in installed:
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
    for asset in index['assets']:
        archive = index_path.parent / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
        assert {a['variant']: a['runtime_sha256'] for a in asset['appearances']} == {
            v: expected[asset['species_id'], v] for v in ('normal', 'shiny')}
    assert 'DLC_PROFILES_OK models=30' in (WORK / 'profile-check.log').read_text()
    assert 'ERROR:' not in (WORK / 'profile-check.log').read_text()
    install_log = (WORK / 'install-launcher.log').read_text()
    assert 'REMAINING_144_BUNDLES_OK bundles=15 scenes=30 resumed=0 no_op=true restart=true' in install_log
    assert 'ERROR:' not in install_log
    stress = read(WORK / 'installed-stress.json')
    log = (WORK / 'installed-stress.log').read_text()
    assert stress['complete'] and stress['species'] == list(NAMES)
    assert stress['catalog_sha256'] == sha(installed_path)
    assert 'BATCH01_STRESS_OK' in log and 'ERROR:' not in log
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 15
        assert 0 < cycle['frame_p95_ms'] <= 20 and cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation'] == 'threaded load dispatch/collect'), default=0) <= 1000 / 60
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024 * 1024
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    screened = read(ROOT / 'scripts/battle/battle_ui/screened_model_catalog.json')
    before = len(registry['models'])
    for name in NAMES:
        assert name not in registry['profiles']
        profile = copy.deepcopy(fixture['profiles'][name + '-normal'])
        rare = copy.deepcopy(fixture['profiles'][name + '-shiny'])
        profile['motion'].pop('sha256')
        rare['motion'].pop('sha256')
        assert profile == rare, 'Variant timing or placement differs'
        registry['profiles'][name] = profile
        for variant in ('normal', 'shiny'):
            identity = name + ('@shiny' if variant == 'shiny' else '')
            assert identity not in registry['models'] and identity not in screened['models']
            registry['models'][identity] = {**fixture['models'][identity], 'profile': name}
    evidence_paths = [HERE / 'catalog_remaining_dlc_battle_qualification.json',
                      HERE / 'catalog_remaining_dlc_profiles.json', index_path,
                      installed_path, WORK / 'install-launcher.log', WORK / 'installed-stress.json',
                      WORK / 'installed-stress.log', WORK / 'runtime_check.gd', WORK / 'admitted_check.gd',
                      WORK / 'profile_check.gd', WORK / 'profile-check.log',
                      HERE / 'catalog_remaining_144_bundle_install_check.gd',
                      ROOT / 'tests/catalog_batch_01_candidate_stress_check.gd', Path(__file__)]
    receipt = {'schema': 1, 'date': '2026-10-01', 'species': list(NAMES),
               'appearance_approved': True, 'battle_approved': True, 'runtime_approved': True,
               'release_approved': False, 'published': False, 'bundle_index': index,
               'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
               'installed_runtime_check_passed': True, 'no_op_restart_check_passed': True,
               'runtime_rounds': stress['rounds'],
               'evidence_sha256': {str(f.relative_to(ROOT)): sha(f) for f in evidence_paths},
               'remaining': ['R2 publication', 'release certification and publication']}
    receipt_path = HERE / 'catalog_remaining_dlc_bundle_qualification.json'
    assert not receipt_path.exists()
    receipt_path.write_bytes(encoded(receipt))
    registry['remaining_dlc_bundle_qualification_sha256'] = sha(receipt_path)
    assert len(registry['models']) == before + 30
    game.write_bytes(encoded(registry))
    launcher.write_bytes(encoded(registry))
    print('DLC_ADMITTED pairs=15 scenes=30 bundles=15 published=false')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('package', 'admit'))
    args = parser.parse_args()
    {'package': package, 'admit': admit}[args.phase]()
