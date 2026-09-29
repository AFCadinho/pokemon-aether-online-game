"""Admit the reviewed ZA normal/shiny pairs into the local game catalogs."""

from collections import Counter
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
WORK = ROOT / '.tmp/shiny-151-recovery/za-17-final-pilot'
NAMES = {'pidgey', 'farfetchd', 'cubone', 'marowak', 'staryu', 'mawile',
         'manectric', 'sharpedo', 'absol', 'purrloin', 'munna', 'audino',
         'cofagrigus', 'trubbish', 'vanilluxe', 'emolga', 'stunfisk'}


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encoded(value):
    return (json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + '\n').encode()


def main():
    feedback = read(WORK / 'user-review.json')
    assert feedback['appearance_approved'] and feedback['battle_approved']
    assert set(feedback['species']) == NAMES
    source = {r['species']: r for r in read(WORK / 'status.json')['entries']}
    assert set(source) == NAMES and all(r['status'] == 'review_candidate' for r in source.values())
    fixture = read(WORK / 'delivery/runtime-fixture.json')
    rows = read(WORK / 'delivery/runtime-catalog.json')
    metrics = read(WORK / 'delivery/final-metrics.json')
    index = read(WORK / 'delivery/bundles/asset-index.json')
    installed = read(WORK / 'delivery/installed/installed-catalog.json')
    assert set(fixture['profiles']) == set(metrics) == NAMES
    assert len(rows) == len(installed) == 34 and len(index['assets']) == 17
    assert set(fixture['models']) == {name + suffix for name in NAMES for suffix in ('', '@shiny')}
    by_identity = {r['species'] + ('@shiny' if r['variant'] == 'shiny' else ''): r for r in installed}
    assert set(by_identity) == set(fixture['models'])
    for row in rows:
        ident = row['species'] + ('@shiny' if row['variant'] == 'shiny' else '')
        assert sha(Path(row['path'])) == row['glb_sha256']
        assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
        assert sha(Path(by_identity[ident]['runtime_path'])) == row['runtime_sha256']
        assert fixture['models'][ident]['sha256'] == row['runtime_sha256']
    assert all(value['minimum_floor_clearance_120hz'] >= .015 and
               value['minimum_idle_logical_pixels'] >= 60 for value in metrics.values())
    assert {a['species_id'] for a in index['assets']} == NAMES
    for asset in index['assets']:
        archive = WORK / 'delivery/bundles' / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
    install_log = (WORK / 'delivery/install.log').read_text()
    assert 'REMAINING_144_BUNDLES_OK bundles=17 scenes=34 resumed=0 no_op=true restart=true' in install_log
    assert 'ERROR:' not in install_log
    stress = read(WORK / 'delivery/stress.json')
    stress_log = (WORK / 'delivery/stress.log').read_text()
    assert stress['complete'] and set(stress['species']) == NAMES
    assert stress['catalog_sha256'] == sha(WORK / 'delivery/installed/installed-catalog.json')
    assert 'BATCH01_STRESS_OK' in stress_log and 'ERROR:' not in stress_log
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 17
        assert 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert len(registry['profiles']) == 688 and len(registry['models']) == 1376
    assert not NAMES.intersection(registry['profiles'])
    evidence = [WORK / 'status.json', WORK / 'user-review.json',
                WORK / 'user-appearance-review.json',
                WORK / 'battle-sized/battle-review.json',
                WORK / 'battle-corrected/battle-review.json',
                WORK / 'battle-stable-input/motion-candidates.json',
                WORK / 'delivery/final-metrics.json',
                WORK / 'delivery/runtime-fixture.json',
                WORK / 'delivery/runtime-catalog.json',
                WORK / 'delivery/bundles/asset-index.json',
                WORK / 'delivery/installed/installed-catalog.json',
                WORK / 'delivery/install.log', WORK / 'delivery/stress.json',
                WORK / 'delivery/stress.log', HERE / 'admit_shiny_za_seventeen.py',
                HERE / 'catalog_shiny_za_17_probe.py']
    receipt = {'schema': 1, 'date': '2026-09-29', 'species': sorted(NAMES),
               'scope': '17 local ZA normal/shiny pairs, individually bundled and battle checked',
               'appearance_approved': True, 'battle_approved': True,
               'runtime_approved': True, 'release_approved': False, 'published': False,
               'user_review': feedback,
               'bundle_size_bytes': sum(a['size_bytes'] for a in index['assets']),
               'minimum_floor_clearance_120hz': min(m['minimum_floor_clearance_120hz'] for m in metrics.values()),
               'runtime_rounds': [{k: cycle[k] for k in ('arena', 'pairs', 'frame_p95_ms')}
                                  for cycle in stress['rounds']],
               'evidence_sha256': {str(path.relative_to(ROOT)): sha(path) for path in evidence}}
    receipt_path = HERE / 'catalog_shiny_za_seventeen_admission.json'
    assert not receipt_path.exists()
    receipt_path.write_bytes(encoded(receipt))
    registry['profiles'].update(fixture['profiles'])
    registry['models'].update(fixture['models'])
    registry['catalog_shiny_za_seventeen_admission_sha256'] = sha(receipt_path)
    assert len(registry['profiles']) == 705 and len(registry['models']) == 1410
    game.write_bytes(encoded(registry))
    launcher.write_bytes(encoded(registry))
    status_path = HERE / 'catalog_shiny_151_recovery_status.json'
    status = read(status_path)
    for row in status['entries']:
        if row['species'] in NAMES:
            assert row['status'] == 'za_binding_hold'
            row.update(status='locally_admitted', appearance_approved=True,
                       battle_approved=True, runtime_approved=True,
                       release_approved=False,
                       admission_receipt='tools/sprite_factory/catalog_shiny_za_seventeen_admission.json')
    status['counts'] = dict(sorted(Counter(row['status'] for row in status['entries']).items()))
    assert status['counts'] == {'locally_admitted': 65, 'missing_compatible_shiny_source': 86}
    status['scope'] = '151 original shiny holds; 65 locally admitted, 86 source holds; no publication'
    status['user_review_pending'] = False
    status_path.write_bytes(encoded(status))
    print('ZA_SEVENTEEN_ADMITTED pairs=17 scenes=34 bundles=17 published=false')


if __name__ == '__main__':
    main()
