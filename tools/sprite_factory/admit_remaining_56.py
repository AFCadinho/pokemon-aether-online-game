"""Package and admit the 56 approved recovered normal/shiny pairs locally."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/remaining-274-production/approved-56'
NAMES = ('abra', 'aerodactyl', 'aggron', 'alakazam', 'aron', 'beedrill', 'blaziken', 'carvanha', 'clobbopus', 'combusken', 'crobat', 'electrike', 'garbodor', 'golbat', 'grapploct', 'kadabra', 'kakuna', 'kangaskhan', 'kecleon', 'lairon', 'machamp', 'machoke', 'machop', 'meganium', 'milotic', 'mr-mime', 'musharna', 'onix', 'panpour', 'pansage', 'pansear', 'patrat', 'pidgeot', 'pidgeotto', 'pinsir', 'roserade', 'sawk', 'scolipede', 'simipour', 'simisage', 'simisear', 'skarmory', 'starmie', 'steelix', 'swirlix', 'throh', 'vanillish', 'vanillite', 'venipede', 'venusaur', 'watchog', 'weedle', 'whirlipede', 'wimpod', 'yamask', 'zubat')
EXPECTED = {(n, v) for n in NAMES for v in ('normal', 'shiny')}
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded


def read(path):
    return json.loads(path.read_text())


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def evidence():
    receipt_path = HERE / 'catalog_remaining_56_checkpoint.json'
    profiles_path = HERE / 'catalog_remaining_56_profiles.json'
    receipt = read(receipt_path)
    assert receipt['battle_visual_approval'] and receipt['appearance_approved_pairs'] == 56
    assert receipt['profiles_sha256'] == sha(profiles_path)
    for group in ('evidence_sha256', 'capture_sha256'):
        for path, digest in receipt[group].items():
            assert sha(ROOT / path) == digest, path
    rows = read(WORK / 'runtime-catalog-final.json')
    assert len(rows) == 112 and {(r['species'], r['variant']) for r in rows} == EXPECTED
    accepted = {(r['species'],r['variant']):r for r in receipt['records']}
    captures = read(WORK / 'captures/battle-review.json')
    assert captures['complete']
    camera = {r['species']:r for r in captures['entries'] if 'shots' in r}
    assert len(camera) == 112
    proofs = {r['species']:r for r in read(WORK.parent / 'final-parity-v3.json')['pairs']}
    measurements = read(WORK.parent / 'battle-56-final/normal-validated.json')
    for source in measurements['inputs']:
        for field in ('report','runtime','motion'):
            assert sha(Path(source[field])) == source[field + '_sha256']
    for row in rows:
        key = (row['species'],row['variant'])
        approved = accepted[key]
        assert approved['appearance_approved']
        assert sha(Path(row['path'])) == row['glb_sha256'] == approved['glb_sha256']
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256'] == approved['runtime_sha256']
        proof = proofs[row['species']]
        assert proof[row['variant'] + '_runtime_sha256'] == row['runtime_sha256']
        shots = camera[row['species'] + '-' + row['variant']]
        assert len(shots['shots']) == 16 and all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in shots['shots'])
        assert min(c['minimum_y'] for c in shots['corrected_clearance_120hz'].values()) >= .015
        assert proof[row['variant'] + '_runtime_sha256'] == row['runtime_sha256']
    return rows, read(profiles_path)


def package():
    rows, _ = evidence()
    hashes = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r['runtime_sha256'] for r in rows}
    index = build(WORK / 'runtime-catalog-final.json', WORK / 'bundles',
                  revision='remaining-56-approved-v1', species_set=NAMES,
                  dex={'abra': 63, 'aerodactyl': 142, 'aggron': 306, 'alakazam': 65, 'aron': 304, 'beedrill': 15, 'blaziken': 257, 'carvanha': 318, 'clobbopus': 852, 'combusken': 256, 'crobat': 169, 'electrike': 309, 'garbodor': 569, 'golbat': 42, 'grapploct': 853, 'kadabra': 64, 'kakuna': 14, 'kangaskhan': 115, 'kecleon': 352, 'lairon': 305, 'machamp': 68, 'machoke': 67, 'machop': 66, 'meganium': 154, 'milotic': 350, 'mr-mime': 122, 'musharna': 518, 'onix': 95, 'panpour': 515, 'pansage': 511, 'pansear': 513, 'patrat': 504, 'pidgeot': 18, 'pidgeotto': 17, 'pinsir': 127, 'roserade': 407, 'sawk': 539, 'scolipede': 545, 'simipour': 516, 'simisage': 512, 'simisear': 514, 'skarmory': 227, 'starmie': 121, 'steelix': 208, 'swirlix': 684, 'throh': 538, 'vanillish': 583, 'vanillite': 582, 'venipede': 543, 'venusaur': 3, 'watchog': 505, 'weedle': 13, 'whirlipede': 544, 'wimpod': 767, 'yamask': 562, 'zubat': 41}, candidate_hashes=hashes)
    print('Built', len(index['assets']), 'bundles;', sum(a['size_bytes'] for a in index['assets']), 'bytes')


def admit():
    rows, fixture = evidence()
    index_path = WORK / 'bundles/asset-index.json'
    index = read(index_path)
    installed_path = WORK / 'installed/installed-catalog.json'
    installed = read(installed_path)
    expected = {(r['species'], r['variant']): r['runtime_sha256'] for r in rows}
    assert len(installed) == 112 and {(r['species'], r['variant']): r['runtime_sha256'] for r in installed} == expected
    assert len(index['assets']) == 56 and {a['species_id'] for a in index['assets']} == set(NAMES)
    for row in installed:
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
    for asset in index['assets']:
        archive = index_path.parent / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
        assert {a['variant']: a['runtime_sha256'] for a in asset['appearances']} == {
            v: expected[asset['species_id'], v] for v in ('normal', 'shiny')}
    install_log = (WORK / 'install-launcher.log').read_text()
    assert 'REMAINING_144_BUNDLES_OK bundles=56 scenes=112 resumed=0 no_op=true restart=true' in install_log
    assert 'ERROR:' not in install_log
    stress = read(WORK / 'installed-stress.json')
    log = (WORK / 'installed-stress.log').read_text()
    assert stress['complete'] and stress['species'] == list(NAMES)
    assert stress['catalog_sha256'] == sha(installed_path)
    assert 'BATCH01_STRESS_OK' in log and 'ERROR:' not in log
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 56
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
    evidence_paths = [HERE / 'catalog_remaining_56_checkpoint.json',
                      HERE / 'catalog_remaining_56_profiles.json', index_path,
                      installed_path, WORK / 'install-launcher.log', WORK / 'installed-stress.json',
                      WORK / 'installed-stress.log', Path(__file__)]
    receipt = {'schema': 1, 'date': '2026-09-30', 'species': list(NAMES),
               'appearance_approved': True, 'battle_approved': True, 'runtime_approved': True,
               'release_approved': False, 'published': False, 'bundle_index': index,
               'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
               'installed_runtime_check_passed': True, 'no_op_restart_check_passed': True,
               'runtime_rounds': stress['rounds'],
               'evidence_sha256': {str(f.relative_to(ROOT)): sha(f) for f in evidence_paths},
               'remaining': ['R2 publication', 'release certification and publication']}
    receipt_path = HERE / 'catalog_remaining_56_bundle_qualification.json'
    assert not receipt_path.exists()
    receipt_path.write_bytes(encoded(receipt))
    registry['remaining_56_bundle_qualification_sha256'] = sha(receipt_path)
    assert len(registry['models']) == before + 112
    game.write_bytes(encoded(registry))
    launcher.write_bytes(encoded(registry))
    print('RECOVERY_56_ADMITTED pairs=56 scenes=112 bundles=56 published=false')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('package', 'admit'))
    args = parser.parse_args()
    {'package': package, 'admit': admit}[args.phase]()
