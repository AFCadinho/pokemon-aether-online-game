"""Prepare and admit two exact reviewed Kyurem pairs after installed runtime gates."""
import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / '.tmp/legendary-kyurem-forms-v2'
WORK = BASE / 'approved-v1'
CHECKPOINT = HERE / 'catalog_kyurem_forms_checkpoint.json'
RECEIPT = HERE / 'catalog_kyurem_forms_bundle_qualification.json'
NAMES = {'kyurem-black': 646, 'kyurem-white': 646}
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded


def read(path):
    return json.loads(Path(path).read_text())


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def approved():
    checkpoint = read(CHECKPOINT)
    assert checkpoint['appearance_approved'] and checkpoint['battle_approved']
    gate = checkpoint['battle_measurement']
    for key in ('report', 'catalog', 'candidates'):
        assert sha(ROOT / gate[key]) == gate['sha256' if key == 'report' else key + '_sha256']
    page = BASE / 'review-neutral-v1/battle-review-v1'
    assert sha(page / 'manifest.json') == checkpoint['battle_user_approval']['manifest_sha256']
    for path, digest in read(page / 'manifest.json')['files'].items():
        assert sha(page / path) == digest
    assert all(r['appearance_approved'] and r['battle_approved'] for r in checkpoint['entries'])
    return checkpoint


def prepare():
    checkpoint = approved()
    raw = {r['species']: r for r in read(BASE / 'runtime-neutral-v1/report.json')}
    measures = {r['species']: r for r in read(ROOT / checkpoint['battle_measurement']['report'])['entries'] if 'clips' in r}
    candidates = read(ROOT / checkpoint['battle_measurement']['candidates'])
    assert not candidates['motion_holds']
    fixture = {'models': {}, 'profiles': {}}
    rows = []
    for entry in checkpoint['entries']:
        name = entry['species']; source = raw[name]; measured = measures[name]
        assert sha(source['path']) == entry['glb_sha256'] == measured['glb_sha256']
        assert sha(source['runtime_path']) == entry['runtime_sha256'] == source['runtime_sha256']
        assert source['complete_pose_channels']
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in measured['shots'])
        assert min(c['minimum_y'] for c in measured['corrected_clearance_120hz'].values()) >= .025 - 1e-5
        motion = copy.deepcopy(candidates['motion'][name])
        assert motion['sha256'] == source['glb_sha256']
        assert abs(motion['lift'] - measured['candidate_lift']) < .001
        assert abs(motion['scale'] - measured['scale']) < 1e-6
        motion['sha256'] = source['runtime_sha256']
        species = name.removesuffix('-shiny')
        variant = 'shiny' if name.endswith('-shiny') else 'normal'
        identity = species + ('@shiny' if variant == 'shiny' else '')
        placement = {k: motion[k] for k in ('scale', 'yaw_degrees')}
        normal = measures[species]
        bounds = {a: {'min': [v / normal['scale'] for v in c['envelope_min']],
                      'size': [v / normal['scale'] for v in c['envelope_size']]}
                  for a, c in normal['clips'].items()}
        fixture['models'][identity] = {'sha256': source['runtime_sha256'],
            'glb_sha256': source['glb_sha256'], 'profile': species + '-' + variant}
        fixture['profiles'][species + '-' + variant] = {'action_timing': source['action_timing'],
            'placement': placement, 'grounding': dict(placement, lift=motion['lift']),
            'motion': motion, 'bounds': bounds,
            'attack_family_actions': {'body_charge': 'physical_attack_2'}}
        rows.append(dict(source, species=species, variant=variant, placement=placement))
    assert len(rows) == 4 and {r['species'] for r in rows} == set(NAMES)
    for species in NAMES:
        a = copy.deepcopy(fixture['profiles'][species + '-normal'])
        b = copy.deepcopy(fixture['profiles'][species + '-shiny'])
        a['motion'].pop('sha256'); b['motion'].pop('sha256')
        assert a == b
    WORK.mkdir(exist_ok=False)
    (WORK / 'approval-checkpoint.json').write_bytes(encoded(checkpoint))
    (WORK / 'runtime-catalog.json').write_bytes(encoded(rows))
    (WORK / 'runtime-fixture.json').write_bytes(encoded(fixture))
    build(WORK / 'runtime-catalog.json', WORK / 'bundles', revision='kyurem-forms-approved-v1',
          species_set=tuple(sorted(NAMES)), dex=NAMES,
          candidate_hashes={k: v['sha256'] for k, v in fixture['models'].items()})
    print('KYUREM_PREPARED pairs=2 scenes=4 bundles=2')


def admit():
    approved()
    fixture = read(WORK / 'runtime-fixture.json')
    installed = read(WORK / 'installed/installed-catalog.json')
    expected = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r['runtime_sha256'] for r in installed}
    assert len(installed) == 4 and expected == {k: v['sha256'] for k, v in fixture['models'].items()}
    for row in installed:
        assert sha(row['runtime_path']) == row['runtime_sha256']
    for name, marker in [('install.log', 'REMAINING_144_BUNDLES_OK bundles=2 scenes=4'),
                         ('runtime-check-v3.log', 'KYUREM_RUNTIME_OK'), ('stress-v2.log', 'BATCH01_STRESS_OK')]:
        log = (WORK / name).read_text()
        assert marker in log and 'ERROR:' not in log, name
    stress = read(WORK / 'stress-v2.json')
    assert set(stress['steady_frame_p95_ms']) == {'classic', 'stadium'}
    assert all(v['samples'] >= 480 and 0 < v['p95_ms'] <= 20 for v in stress['steady_frame_p95_ms'].values())
    assert stress['complete'] and stress['catalog_sha256'] == sha(WORK / 'installed/installed-catalog.json')
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 2
        assert 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation'] == 'threaded load dispatch/collect'), default=0) <= 1000 / 60
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024 * 1024
    index = read(WORK / 'bundles/asset-index.json')
    assert len(index['assets']) == 2
    for asset in index['assets']:
        archive = WORK / 'bundles' / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
        assert {a['runtime_identity']: a['runtime_sha256'] for a in asset['appearances']} == {k: v for k, v in expected.items() if k.split('@')[0] == asset['species_id']}
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    for species in NAMES:
        profile = copy.deepcopy(fixture['profiles'][species + '-normal']); profile['motion'].pop('sha256')
        assert species not in registry['profiles']
        registry['profiles'][species] = profile
        for variant in ('normal', 'shiny'):
            identity = species + ('@shiny' if variant == 'shiny' else '')
            assert identity not in registry['models']
            registry['models'][identity] = dict(fixture['models'][identity], profile=species)
    evidence = [WORK / 'approval-checkpoint.json', Path(__file__), ROOT / 'tests/battle_3d_kyurem_forms_check.gd',
                ROOT / 'tests/battle_3d_kyurem_stress_check.gd', ROOT / 'tests/catalog_batch_01_candidate_stress_check.gd',
                ROOT / 'scripts/battle/arenas/generic/stadium_arena.gd',
                WORK / 'runtime-fixture.json', WORK / 'runtime-catalog.json', WORK / 'installed/installed-catalog.json',
                WORK / 'install.log', WORK / 'runtime-check.log', WORK / 'runtime-check-v2.log', WORK / 'runtime-check-v3.log', WORK / 'stress.json', WORK / 'stress.log', WORK / 'stress-v2.json', WORK / 'stress-v2.log',
                WORK / 'base-control-stress.json', WORK / 'base-control-stress.log']
    receipt = {'schema': 1, 'forms': sorted(NAMES), 'models': 4, 'appearance_approved': True,
        'battle_approved': True, 'runtime_approved': True, 'published': False, 'release_approved': False,
        'bundle_index': index, 'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
        'runtime_rounds': stress['rounds'], 'steady_frame_p95_ms': stress['steady_frame_p95_ms'],
        'performance_diagnosis': 'Initial short two-pair test failed p95; approved base controls also failed stadium. Two-second prepared battle observations per pair preserve all loading/lifecycle checks and unchanged 20 ms gate; original evidence retained.', 'installed_runtime_check_passed': True,
        'evidence_sha256': {str(p.relative_to(ROOT)): sha(p) for p in evidence},
        'scope': 'Local AMD Compatibility; installed exact bundles; no public R2 or cross-platform certification',
        'source_limitations': ['Neutral forms only; charged Overdrive accessory visibility requires separate qualification'],
        'remaining': ['R2 publication', 'release content-index activation', 'release certification']}
    assert not RECEIPT.exists()
    RECEIPT.write_bytes(encoded(receipt))
    registry['kyurem_forms_bundle_qualification_sha256'] = sha(RECEIPT)
    game.write_bytes(encoded(registry)); launcher.write_bytes(encoded(registry))
    (ROOT / 'release/approved_3d_kyurem_forms_index.json').write_bytes(encoded(index))
    print('KYUREM_ADMITTED pairs=2 scenes=4 bundles=2 published=false')


def finalize():
    log = WORK / 'admitted-check.log'
    assert 'KYUREM_RUNTIME_OK' in log.read_text() and 'ERROR:' not in log.read_text()
    receipt = read(RECEIPT)
    receipt['admitted_registry_check_passed'] = True
    receipt['evidence_sha256'][str(log.relative_to(ROOT))] = sha(log)
    RECEIPT.write_bytes(encoded(receipt))
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    registry['kyurem_forms_bundle_qualification_sha256'] = sha(RECEIPT)
    game.write_bytes(encoded(registry)); launcher.write_bytes(encoded(registry))
    checkpoint = read(CHECKPOINT)
    checkpoint['runtime_approved'] = True
    for row in checkpoint['entries']:
        row['runtime_approved'] = True
    checkpoint['runtime_qualification'] = {'receipt': str(RECEIPT.relative_to(ROOT)), 'sha256': sha(RECEIPT)}
    CHECKPOINT.write_bytes(encoded(checkpoint))
    # The receipt pins the checkpoint before runtime admission to avoid a hash cycle.
    print('KYUREM_FINALIZED published=false')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('prepare', 'admit', 'finalize'))
    {'prepare': prepare, 'admit': admit, 'finalize': finalize}[parser.parse_args().phase]()
