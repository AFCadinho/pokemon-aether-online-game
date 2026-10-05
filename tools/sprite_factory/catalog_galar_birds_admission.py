"""Qualify the exact approved Galar bird bundles before local runtime admission."""
import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/galar-birds-admission-v1'
BASE = ROOT / '.tmp/galar-birds-battle-v1'
CHECKPOINT = HERE / 'catalog_galar_birds_battle_checkpoint.json'
RECEIPT = HERE / 'catalog_galar_birds_bundle_qualification.json'
NAMES = {'articuno-galar': 144, 'zapdos-galar': 145, 'moltres-galar': 146}
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded


def read(path):
    return json.loads(Path(path).read_text())


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def encoded_registry(value):
    # Keep the existing Godot catalog layout; avoid reformatting every profile.
    return (json.dumps(value, indent='\t', sort_keys=True, allow_nan=False) + '\n').encode()


def approved():
    accepted = read(HERE / 'catalog_galar_birds_candidate_checkpoint.json')
    checkpoint = read(CHECKPOINT)
    assert accepted['approvals']['appearance'] and checkpoint['battle_approved']
    for page, digest in [(BASE / 'review-v1', checkpoint['battle_user_approval']['manifest_sha256']),
                         (ROOT / '.tmp/galar-birds-candidates-v3/review-v1', accepted['appearance_review']['manifest_sha256'])]:
        assert sha(page / 'manifest.json') == digest
        for path, value in read(page / 'manifest.json')['files'].items():
            assert sha(page / path) == value
    for pin in checkpoint['reports']:
        assert sha(ROOT / pin['path']) == pin['sha256']
    return accepted, checkpoint


def prepare():
    accepted, checkpoint = approved()
    raw = {r['species']: r for r in read(ROOT / '.tmp/galar-birds-candidates-v3/runtime-v1/report.json')}
    measured = {r['species']: r for r in read(BASE / 'final/battle-review.json')['entries']}
    followup = read(WORK / 'zapdos-clearance/battle-review.json')
    assert followup['complete']
    for r in followup['entries']:
        if 'clips' in r:
            assert r['species'] in ('zapdos-galar', 'zapdos-galar-shiny')
            measured[r['species']] = r
    proposed = read(WORK / 'placement-v3.json')
    previous = read(BASE / 'placement-v2.json')
    assert proposed['technical_clearance_adjustment']['source_sha256'] == sha(BASE / 'placement-v2.json')
    assert not proposed['motion_holds']
    for name in raw:
        assert proposed['readability'][name] == previous['readability'][name]
        assert proposed['hover'][name] == previous['hover'][name]
        if not name.startswith('zapdos-'):
            assert proposed['motion'][name] == previous['motion'][name]
    fixture = {'models': {}, 'profiles': {}}
    rows = []
    for entry in accepted['entries']:
        name = entry['species']; source = raw[name]; m = measured[name]
        assert sha(source['path']) == source['glb_sha256'] == entry['glb_sha256'] == m['glb_sha256']
        assert sha(source['runtime_path']) == source['runtime_sha256'] == entry['runtime_sha256']
        assert source['complete_pose_channels']
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
        assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values()) >= .025 - 1e-5
        motion = copy.deepcopy(proposed['motion'][name])
        assert motion['sha256'] == source['glb_sha256']
        assert abs(motion['lift'] - m['candidate_lift']) < .001
        assert abs(motion['scale'] - m['scale']) < 1e-6
        motion['sha256'] = source['runtime_sha256']
        species = name.removesuffix('-shiny')
        variant = 'shiny' if name.endswith('-shiny') else 'normal'
        identity = species + ('@shiny' if variant == 'shiny' else '')
        placement = {k: motion[k] for k in ('scale', 'yaw_degrees')}
        placement['hover_height'] = proposed['hover'][name]
        normal = measured[species]
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
    assert len(rows) == 6 and {r['species'] for r in rows} == set(NAMES)
    for species in NAMES:
        a = copy.deepcopy(fixture['profiles'][species + '-normal'])
        b = copy.deepcopy(fixture['profiles'][species + '-shiny'])
        a['motion'].pop('sha256'); b['motion'].pop('sha256')
        assert a == b
    (WORK / 'approval-checkpoint.json').write_bytes(encoded(checkpoint))
    (WORK / 'runtime-catalog.json').write_bytes(encoded(rows))
    (WORK / 'runtime-fixture.json').write_bytes(encoded(fixture))
    build(WORK / 'runtime-catalog.json', WORK / 'bundles', revision='galar-birds-approved-v1',
          species_set=tuple(sorted(NAMES)), dex=NAMES,
          candidate_hashes={k: v['sha256'] for k, v in fixture['models'].items()})
    print('GALAR_PREPARED pairs=3 scenes=6 bundles=3')


def validate_stress(stress):
    assert set(stress['steady_frame_p95_ms']) == {'classic', 'stadium'}
    assert all(v['samples'] >= 720 and 0 < v['p95_ms'] <= 20 for v in stress['steady_frame_p95_ms'].values())
    assert stress['complete'] and stress['catalog_sha256'] == sha(WORK / 'installed/installed-catalog.json')
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 3
        assert 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation'] == 'threaded load dispatch/collect'), default=0) <= 1000 / 60
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024 * 1024


def admit():
    approved()
    fixture = read(WORK / 'runtime-fixture.json')
    installed = read(WORK / 'installed/installed-catalog.json')
    expected = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r['runtime_sha256'] for r in installed}
    assert len(installed) == 6 and expected == {k: v['sha256'] for k, v in fixture['models'].items()}
    for row in installed:
        assert sha(row['runtime_path']) == row['runtime_sha256']
    for name, marker in [('install.log', 'REMAINING_144_BUNDLES_OK bundles=3 scenes=6'),
                         ('runtime-check.log', 'GALAR_RUNTIME_OK'),
                         ('runtime-cold-driver-cache.log', 'GALAR_RUNTIME_OK'),
                         ('stress.log', 'BATCH01_STRESS_OK')]:
        log = (WORK / name).read_text()
        assert marker in log and 'ERROR:' not in log, name
    stress = read(WORK / 'stress.json'); validate_stress(stress)
    index = read(WORK / 'bundles/asset-index.json')
    assert len(index['assets']) == 3
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
    evidence = [WORK / p for p in ['approval-checkpoint.json', 'runtime-fixture.json', 'runtime-catalog.json',
        'installed/installed-catalog.json', 'placement-v3.json', 'zapdos-clearance/battle-review.json',
        'install.log', 'runtime-check.log', 'runtime-cold-driver-cache.log',
        'runtime-shader-stall.log', 'runtime-undrawn-window.log', 'runtime-wrong-release-fixture.log',
        'install-wrong-project.log', 'stress-outdated-adapter.log', 'stress.json', 'stress.log']]
    evidence += [Path(__file__), ROOT / 'tests/battle_3d_galar_birds_check.gd',
        ROOT / 'tests/battle_3d_legendary_stress_check.gd', ROOT / 'tests/catalog_batch_01_candidate_stress_check.gd',
        ROOT / 'tests/phase5_candidate_stage.gd']
    receipt = {'schema': 1, 'forms': sorted(NAMES), 'models': 6, 'appearance_approved': True,
        'battle_approved': True, 'runtime_approved': True, 'published': False, 'release_approved': False,
        'bundle_index': index, 'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
        'runtime_rounds': stress['rounds'], 'steady_frame_p95_ms': stress['steady_frame_p95_ms'],
        'installed_runtime_check_passed': True,
        'test_diagnosis': 'Installer must run in launcher project. Runtime fixture pins the selected candidate release rather than mutating an unselected older descriptor. Stress adapter forwards the current preserve_actors argument. Shader timeout diagnosis: models resolved but desktop window drew zero frames; explicit visible test window passes with a fresh Mesa driver cache. Failed logs retained. No performance or readiness thresholds relaxed.',
        'evidence_sha256': {str(p.relative_to(ROOT)): sha(p) for p in evidence},
        'scope': 'Local Compatibility; exact installed bundles; no public R2 or cross-platform certification',
        'source_limitations': ['Moltres uses approved native skeletal fire and source UV colours without auxiliary displacement'],
        'remaining': ['R2 publication', 'release content-index activation', 'release certification']}
    assert not RECEIPT.exists()
    RECEIPT.write_bytes(encoded(receipt))
    registry['galar_birds_bundle_qualification_sha256'] = sha(RECEIPT)
    game.write_bytes(encoded_registry(registry)); launcher.write_bytes(encoded_registry(registry))
    (ROOT / 'release/approved_3d_galar_birds_index.json').write_bytes(encoded(index))
    print('GALAR_ADMITTED pairs=3 scenes=6 bundles=3 published=false')


def finalize():
    log = WORK / 'admitted-check.log'
    assert 'GALAR_RUNTIME_OK' in log.read_text() and 'ERROR:' not in log.read_text()
    receipt = read(RECEIPT); receipt['admitted_registry_check_passed'] = True
    receipt['evidence_sha256'][str(log.relative_to(ROOT))] = sha(log)
    receipt['evidence_sha256'][str(Path(__file__).relative_to(ROOT))] = sha(Path(__file__))
    RECEIPT.write_bytes(encoded(receipt))
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game); registry['galar_birds_bundle_qualification_sha256'] = sha(RECEIPT)
    game.write_bytes(encoded_registry(registry)); launcher.write_bytes(encoded_registry(registry))
    checkpoint = read(CHECKPOINT)
    checkpoint.update(runtime_approved=True, performance_approved=True,
                      runtime_qualification={'receipt':str(RECEIPT.relative_to(ROOT)), 'sha256':sha(RECEIPT)})
    checkpoint['remaining'] = receipt['remaining']
    CHECKPOINT.write_bytes(encoded(checkpoint))
    candidate_path = HERE / 'catalog_galar_birds_candidate_checkpoint.json'
    candidate = read(candidate_path)
    candidate['status'] = 'locally_qualified_not_published'
    candidate['approvals'].update(performance=True, runtime=True, bundles=True)
    candidate['remaining'] = receipt['remaining']
    candidate['runtime_qualification'] = checkpoint['runtime_qualification']
    candidate_path.write_bytes(encoded(candidate))
    print('GALAR_FINALIZED published=false')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('prepare', 'admit', 'finalize'))
    {'prepare': prepare, 'admit': admit, 'finalize': finalize}[parser.parse_args().phase]()
