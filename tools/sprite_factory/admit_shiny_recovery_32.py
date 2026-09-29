"""Admit the 32 reviewed recovery pairs after installed lifecycle checks.

Local catalog only; does not publish or upload bundles.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/shiny-151-recovery/battle'


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def main():
    appearance_path = HERE / 'catalog_shiny_151_first_32_appearance_review.json'
    appearance = read(appearance_path)
    names = {r['species'] for r in appearance['entries']}
    assert len(names) == 32 and appearance['user_review']['appearance_approved']
    review = read(WORK / 'battle-user-review.json')
    assert review['battle_approved'] and set(review['species']) == names
    metrics = read(WORK / 'final-metrics.json')
    assert set(metrics) == names
    assert all(m['minimum_floor_clearance_120hz'] >= .015 and
               m['minimum_idle_logical_pixels'] >= 60 for m in metrics.values())
    fixture = read(WORK / 'runtime-fixture.json')
    assert set(fixture['profiles']) == names
    assert set(fixture['models']) == {n + suffix for n in names for suffix in ('', '@shiny')}
    index = read(WORK / 'bundles/asset-index.json')
    installed = read(WORK / 'installed/installed-catalog.json')
    assert len(index['assets']) == 32 and len(installed) == 64
    install_log = (WORK / 'install.log').read_text()
    assert 'REMAINING_144_BUNDLES_OK bundles=32 scenes=64' in install_log and 'ERROR:' not in install_log
    installed_by_id = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r for r in installed}
    for a in appearance['entries']:
        assert a['appearance_approved']
        for variant, v in a['variants'].items():
            key = a['species'] + ('@shiny' if variant == 'shiny' else '')
            assert sha(Path(v['glb_path'])) == v['glb_sha256']
            assert sha(Path(v['scene_path'])) == v['scene_sha256']
            assert sha(Path(installed_by_id[key]['runtime_path'])) == v['scene_sha256']
            assert fixture['models'][key]['sha256'] == v['scene_sha256']
    stress = read(WORK / 'stress.json')
    log = (WORK / 'stress.log').read_text()
    assert stress['complete'] and set(stress['species']) == names
    assert stress['catalog_sha256'] == sha(WORK / 'installed/installed-catalog.json')
    assert 'BATCH01_STRESS_OK' in log and 'ERROR:' not in log
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 32
        assert 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert len(registry['profiles']) == 640 and len(registry['models']) == 1280
    assert not names.intersection(registry['profiles'])
    evidence = [appearance_path, WORK / 'battle-user-review.json', WORK / 'final-metrics.json',
                WORK / 'runtime-fixture.json', WORK / 'runtime-catalog.json',
                WORK / 'raw/battle-review.json', WORK / 'corrected/battle-review.json',
                WORK / 'motion-candidates.json', WORK / 'clearance-fix/motion-candidates.json',
                WORK / 'clearance-fix/corrected/battle-review.json', WORK / 'bundles/asset-index.json',
                WORK / 'installed/installed-catalog.json', WORK / 'install.log',
                WORK / 'stress.json', WORK / 'stress.log']
    receipt = {'schema': 1, 'date': '2026-09-29', 'species': sorted(names),
               'scope': '32 local normal/shiny pairs; reviewed appearance and battle, installed individual bundles',
               'runtime_approved': True, 'release_approved': False, 'published': False,
               'user_battle_review': review,
               'clearance_refinement': 'Local tapered offsets for Mamoswine physical_attack and Malamar physical_attack_2/faint_start; independently resampled at 120 Hz. Meshes and animation data unchanged.',
               'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
               'minimum_floor_clearance_120hz': min(m['minimum_floor_clearance_120hz'] for m in metrics.values()),
               'runtime_rounds': [{k: cycle[k] for k in ('arena', 'pairs', 'frame_p95_ms')} for cycle in stress['rounds']],
               'evidence_sha256': {str(path.relative_to(ROOT)): sha(path) for path in evidence}}
    receipt_path = HERE / 'catalog_shiny_151_first_32_admission.json'
    receipt_path.write_bytes(encoded(receipt))
    registry['profiles'].update(fixture['profiles'])
    registry['models'].update(fixture['models'])
    registry['catalog_shiny_151_first_32_admission_sha256'] = sha(receipt_path)
    game.write_bytes(encoded(registry)); launcher.write_bytes(encoded(registry))
    state_path = HERE / 'catalog_shiny_151_recovery_status.json'
    state = read(state_path)
    for r in state['entries']:
        if r['species'] in names:
            r.update(status='locally_admitted', battle_approved=True, runtime_approved=True,
                     user_battle_feedback=review['feedback'])
    state['counts']['locally_admitted'] = state['counts'].pop('awaiting_battle_qualification')
    state['scope'] = '151 original shiny holds; 32 locally admitted, 119 remaining; no publication'
    state_path.write_bytes(encoded(state))
    print('SHINY_RECOVERY_ADMITTED pairs=32 scenes=64 published=false')


if __name__ == '__main__':
    main()
