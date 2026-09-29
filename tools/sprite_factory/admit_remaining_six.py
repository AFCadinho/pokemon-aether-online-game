"""Package six reviewed Biochao pairs; admit after isolated installation/battle checks."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/remaining-six-shiny-battle/final-battle'
NAMES = ('unown', 'darmanitan-standard', 'wishiwashi', 'silvally', 'obstagoon', 'cursola')
DEX = dict(zip(NAMES, (201, 555, 746, 773, 862, 864)))
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def evidence():
    appearance_path = HERE / 'catalog_remaining_six_appearance_review.json'
    battle_path = HERE / 'catalog_remaining_six_battle_qualification.json'
    profiles_path = HERE / 'catalog_remaining_six_battle_profiles.json'
    appearance, battle = read(appearance_path), read(battle_path)
    assert appearance['appearance_approved'] and battle['user_review']['battle_approved']
    assert battle['appearance_receipt_sha256'] == sha(appearance_path)
    assert battle['profiles_sha256'] == sha(profiles_path)
    assert battle['camera_grounding_checks_passed'] and battle['runtime_lifecycle_check_passed']
    for receipt in (appearance, battle):
        for path, digest in receipt['evidence_sha256'].items():
            assert sha(ROOT / path) == digest, path
    for path, digest in battle['capture_sha256'].items():
        assert sha(ROOT / path) == digest, path
    rows = read(WORK / 'runtime-catalog.json')
    expected = {(name, variant) for name in NAMES for variant in ('normal', 'shiny')}
    assert len(rows) == 12 and {(r['species'], r['variant']) for r in rows} == expected
    approvals = {(r['species'], r['variant']): r for r in appearance['entries']}
    for row in rows:
        approved = approvals[row['species'], row['variant']]
        assert sha(Path(row['path'])) == row['glb_sha256'] == approved['glb_sha256']
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256'] == approved['final_runtime_sha256']
    return rows, read(profiles_path)


def package():
    rows, _ = evidence()
    hashes = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r['runtime_sha256'] for r in rows}
    index = build(WORK / 'runtime-catalog.json', WORK / 'bundles',
                  revision='remaining-six-approved-v1', species_set=NAMES,
                  dex=DEX, candidate_hashes=hashes)
    print('Built', len(index['assets']), 'bundles;', sum(a['size_bytes'] for a in index['assets']), 'bytes')


def admit():
    rows, fixture = evidence()
    index_path = WORK / 'bundles/asset-index.json'
    index = read(index_path)
    installed_path = WORK / 'installed/installed-catalog.json'
    installed = read(installed_path)
    assert len(index['assets']) == 6 and {a['species_id'] for a in index['assets']} == set(NAMES)
    expected = {(r['species'], r['variant']): r['runtime_sha256'] for r in rows}
    assert len(installed) == 12 and {(r['species'], r['variant']): r['runtime_sha256'] for r in installed} == expected
    for row in installed:
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
    for asset in index['assets']:
        archive = index_path.parent / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
        assert {a['variant']: a['runtime_sha256'] for a in asset['appearances']} == {
            variant: expected[asset['species_id'], variant] for variant in ('normal', 'shiny')}
    install_log = (WORK / 'install.log').read_text()
    assert 'REMAINING_144_BUNDLES_OK bundles=6 scenes=12 resumed=0 no_op=true restart=true' in install_log
    assert 'ERROR:' not in install_log
    stress = read(WORK / 'installed-stress.json')
    stress_log = (WORK / 'installed-stress.log').read_text()
    assert stress['complete'] and stress['species'] == list(NAMES)
    assert stress['catalog_sha256'] == sha(installed_path)
    assert 'BATCH01_STRESS_OK' in stress_log and 'ERROR:' not in stress_log
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 6
        assert 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
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
        assert profile == rare, 'Normal/shiny timing or placement differs'
        registry['profiles'][name] = profile
        for variant in ('normal', 'shiny'):
            identity = name + ('@shiny' if variant == 'shiny' else '')
            assert identity not in registry['models'] and identity not in screened['models']
            registry['models'][identity] = {**fixture['models'][identity], 'profile': name}
    evidence_paths = [HERE / 'catalog_remaining_six_appearance_review.json',
                      HERE / 'catalog_remaining_six_battle_qualification.json',
                      HERE / 'catalog_remaining_six_battle_profiles.json',
                      index_path, installed_path, WORK / 'install.log',
                      WORK / 'installed-stress.json', WORK / 'installed-stress.log', Path(__file__)]
    receipt = {'schema': 1, 'date': '2026-09-29', 'species': list(NAMES),
               'appearance_approved': True, 'battle_approved': True,
               'runtime_approved': True, 'release_approved': False, 'published': False,
               'bundle_index': index, 'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
               'installed_runtime_check_passed': True, 'no_op_restart_check_passed': True,
               'runtime_rounds': stress['rounds'],
               'evidence_sha256': {str(f.relative_to(ROOT)): sha(f) for f in evidence_paths},
               'remaining': ['R2 publication', 'desktop release certification and publication']}
    receipt_path = HERE / 'catalog_remaining_six_bundle_qualification.json'
    assert not receipt_path.exists()
    receipt_path.write_bytes(encoded(receipt))
    registry['remaining_six_bundle_qualification_sha256'] = sha(receipt_path)
    assert len(registry['models']) == before + 12
    game.write_bytes(encoded(registry))
    launcher.write_bytes(encoded(registry))
    print('SIX_ADMITTED pairs=6 scenes=12 bundles=6 published=false')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('package', 'admit'))
    args = parser.parse_args()
    {'package': package, 'admit': admit}[args.phase]()
