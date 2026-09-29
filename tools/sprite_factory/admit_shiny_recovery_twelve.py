"""Admit twelve appearance/battle-approved shiny pairs after installed-bundle checks.

This only updates the local candidate catalog; it does not publish content.
"""
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/shiny-151-recovery/twelve-delivery'


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n').encode()


def main():
    reviewed_path = HERE / 'catalog_shiny_twelve_battle_qualification.json'
    xerneas_path = HERE / 'catalog_shiny_xerneas_battle_scale_review.json'
    reviewed, xerneas = read(reviewed_path), read(xerneas_path)
    assert reviewed['appearance_approved'] and reviewed['pairs'] == 12
    assert xerneas['scale_approved'] and xerneas['candidate_scale'] == .75
    feedback = read(WORK / 'battle-user-review.json')
    names = set(feedback['species'])
    assert feedback['battle_approved'] and len(names) == 12 and names == {r['species'].split('@')[0] for r in reviewed['variants']}
    fixture = read(WORK / 'runtime-fixture.json')
    rows = read(WORK / 'runtime-catalog.json')
    metrics = read(WORK / 'final-metrics.json')
    index = read(WORK / 'bundles/asset-index.json')
    installed = read(WORK / 'installed/installed-catalog.json')
    assert len(rows) == len(installed) == 24 and len(index['assets']) == 12
    assert set(metrics) == set(fixture['profiles']) == names
    assert set(fixture['models']) == {n + suffix for n in names for suffix in ('', '@shiny')}
    installed_by_identity = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r for r in installed}
    for row in rows:
        key = row['species'] + ('@shiny' if row['variant'] == 'shiny' else '')
        assert sha(Path(row['path'])) == row['glb_sha256']
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
        assert sha(Path(installed_by_identity[key]['runtime_path'])) == row['runtime_sha256']
        assert fixture['models'][key]['sha256'] == row['runtime_sha256']
    for name, value in metrics.items():
        assert value['minimum_floor_clearance_120hz'] >= .015
        assert value['minimum_idle_logical_pixels'] >= 60
        if name == 'xerneas':
            assert fixture['profiles'][name]['placement']['scale'] == .75
    for asset in index['assets']:
        archive = WORK / 'bundles' / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
    install_log = (WORK / 'install.log').read_text()
    assert 'REMAINING_144_BUNDLES_OK bundles=12 scenes=24' in install_log and 'ERROR:' not in install_log
    stress = read(WORK / 'stress.json')
    stress_log = (WORK / 'stress.log').read_text()
    assert stress['complete'] and set(stress['species']) == names
    assert stress['catalog_sha256'] == sha(WORK / 'installed/installed-catalog.json')
    assert 'BATCH01_STRESS_OK' in stress_log and 'ERROR:' not in stress_log
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 12
        assert 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert len(registry['profiles']) == 672 and len(registry['models']) == 1344
    assert not names.intersection(registry['profiles'])
    evidence = [reviewed_path, xerneas_path, WORK / 'battle-user-review.json',
                WORK / 'final-metrics.json', WORK / 'runtime-fixture.json',
                WORK / 'runtime-catalog.json', WORK / 'bundles/asset-index.json',
                WORK / 'installed/installed-catalog.json', WORK / 'install.log',
                WORK / 'stress.json', WORK / 'stress.log',
                ROOT / '.tmp/shiny-151-recovery/twelve-battle/final/battle-review.json',
                ROOT / '.tmp/shiny-151-recovery/twelve-battle/xerneas-size-v1/corrected/battle-review.json',
                HERE / 'admit_shiny_recovery_twelve.py']
    receipt = {'schema': 1, 'date': '2026-09-29', 'species': sorted(names),
               'scope': '12 local normal/shiny pairs; appearance and battle reviewed, individual bundles installed and stress checked',
               'appearance_approved': True, 'battle_approved': True, 'runtime_approved': True,
               'release_approved': False, 'published': False,
               'user_battle_review': feedback,
               'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
               'minimum_floor_clearance_120hz': min(m['minimum_floor_clearance_120hz'] for m in metrics.values()),
               'runtime_rounds': [{k: cycle[k] for k in ('arena', 'pairs', 'frame_p95_ms')} for cycle in stress['rounds']],
               'evidence_sha256': {str(path.relative_to(ROOT)): sha(path) for path in evidence}}
    receipt_path = HERE / 'catalog_shiny_twelve_admission.json'
    receipt_path.write_bytes(encoded(receipt))
    registry['profiles'].update(fixture['profiles'])
    registry['models'].update(fixture['models'])
    registry['catalog_shiny_twelve_admission_sha256'] = sha(receipt_path)
    assert len(registry['profiles']) == 684 and len(registry['models']) == 1368
    game.write_bytes(encoded(registry))
    launcher.write_bytes(encoded(registry))
    state_path = HERE / 'catalog_shiny_151_recovery_status.json'
    state = read(state_path)
    for row in state['entries']:
        if row['species'] in names:
            assert row['status'] == 'battle_review_pending' and row['appearance_approved']
            row.update(status='locally_admitted', battle_approved=True, runtime_approved=True,
                       user_battle_feedback=feedback['feedback'])
            row['battle_review']['status'] = 'accepted_and_admitted'
    state['counts'] = dict(sorted(Counter(row['status'] for row in state['entries']).items()))
    assert state['counts'] == {'locally_admitted': 44, 'missing_compatible_shiny_source': 86,
                               'scvi_material_hold': 4, 'za_binding_hold': 17}
    state['scope'] = '151 original shiny holds; 44 locally admitted, 107 source/material holds; no publication'
    state['user_review_pending'] = False
    state_path.write_bytes(encoded(state))
    print('SHINY_RECOVERY_ADMITTED pairs=12 scenes=24 bundles=12 published=false')


if __name__ == '__main__':
    main()
