"""Admit the exact local Mega cohort only after all native, install and performance gates."""
import argparse
import copy
import json
import math
from pathlib import Path

from catalog_mega_3d_production import sha
from catalog_mega_battle_qualification import qualify

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
COHORT = ROOT / '.tmp/mega-battle-71-v1'
WORK = COHORT / 'local-candidates-v1'
RECEIPT = HERE / 'catalog_mega_71_bundle_qualification.json'


def read(path):
    return json.loads(path.read_text())


def identity(row):
    name = row['species']
    return name if name.endswith('@shiny') else name + ('@shiny' if row.get('variant') == 'shiny' else '')


def precision_compatible(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(precision_compatible(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(precision_compatible(x, y) for x, y in zip(a, b))
    if isinstance(a, bool) or isinstance(b, bool):
        return type(a) is type(b) and a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return math.isfinite(a) and math.isfinite(b) and abs(a - b) <= 1e-9
    return type(a) is type(b) and a == b


def validate():
    approval = read(HERE / 'catalog_mega_battle_checkpoint.json')
    assert approval['battle_visual_approved'] and approval['appearance_pair_count'] == 71
    followup = approval['focused_placement_approval']
    for key, digest_key in [('review_manifest', 'review_manifest_sha256'),
                            ('native_report', 'native_report_sha256'), ('profiles', 'profiles_sha256')]:
        assert sha(Path(followup[key])) == followup[digest_key]
    for key in ('catalog', 'runtime_catalog', 'review_manifest'):
        pinned = approval['evidence'][key]
        assert sha(Path(pinned['path'])) == pinned['sha256']
    for manifest_path in (Path(approval['evidence']['review_manifest']['path']), Path(followup['review_manifest'])):
        for name, digest in read(manifest_path)['files'].items():
            assert sha(manifest_path.parent / name) == digest
    native = COHORT / 'final-native-v2/battle-review.json'
    gate = qualify(native, COHORT / 'catalog.json')
    assert gate['technical_variant_count'] == 142 and not gate['held']
    profiles = COHORT / 'placement-followup-v2.json'
    assert read(native)['candidates_sha256'] == sha(profiles)
    preparation = read(WORK / 'preparation.json')
    assert preparation['profiles_sha256'] == sha(profiles)
    assert preparation['bundle_index_sha256'] == sha(WORK / 'bundles/asset-index.json')
    fixture = read(WORK / 'runtime-fixture.json')
    expected = {name: row['sha256'] for name, row in fixture['models'].items()}
    assert len(expected) == 142
    mapping = {r['showdown_id']: r['name'] for r in read(HERE / 'catalog_mega_3d_source_intake.json')['entries']}
    final_profiles = read(profiles)['motion']
    native_rows = {r['species']: r for r in read(native)['entries']}
    for raw_name, approved_motion in final_profiles.items():
        species = mapping[raw_name.removesuffix('-shiny')]
        variant = 'shiny' if raw_name.endswith('-shiny') else 'normal'
        key = species + ('@shiny' if variant == 'shiny' else '')
        motion = copy.deepcopy(approved_motion)
        assert fixture['models'][key]['glb_sha256'] == motion['sha256']
        motion['sha256'] = expected[key]
        profile = fixture['profiles'][species + '-' + variant]
        assert profile['motion'] == motion
        for action, timing in profile['action_timing'].items():
            assert abs(timing['frames'] / 60 - native_rows[raw_name]['clips'][action]['duration']) < 1e-5
    # Both transactional launcher and on-demand game installation are required.
    for catalog in (WORK / 'installed-megas/installed-catalog.json', WORK / 'on-demand-installed-catalog.json'):
        rows = read(catalog)
        assert len(rows) == 142 and {identity(r): r['runtime_sha256'] for r in rows} == expected
        for row in rows:
            assert sha(Path(row['runtime_path'])) == row['runtime_sha256']
    for name, marker in [('install-megas.log', 'MEGA_BUNDLES_OK bundles=71 scenes=142'),
                         ('runtime-final.log', 'MEGA_RUNTIME_OK pairs=71'), ('stress-v1.log', 'BATCH01_STRESS_OK')]:
        log = (WORK / name).read_text()
        assert marker in log and 'ERROR:' not in log, name
    stress = read(WORK / 'stress-v1.json')
    assert stress['complete'] and stress['catalog_sha256'] == sha(WORK / 'on-demand-installed-catalog.json')
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    assert set(stress['steady_frame_p95_ms']) == {'classic', 'stadium'}
    for value in stress['steady_frame_p95_ms'].values():
        assert value['samples'] >= 960 and 0 < value['p95_ms'] <= 20
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 71
        assert 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation'] == 'threaded load dispatch/collect'), default=0) <= 1000 / 60
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024 * 1024
    index = read(WORK / 'bundles/asset-index.json')
    assert len(index['assets']) == 71
    for asset in index['assets']:
        archive = WORK / 'bundles' / Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
        assert {a['runtime_identity']: a['runtime_sha256'] for a in asset['appearances']} == {
            name: digest for name, digest in expected.items()
            if name.removesuffix('@shiny') == asset['species_id'] + '-' + asset['form_id']}
    evidence = [HERE / 'catalog_mega_battle_checkpoint.json', native, profiles,
        WORK / 'preparation.json', WORK / 'runtime-fixture.json', WORK / 'runtime-catalog.json',
        WORK / 'on-demand-installed-catalog.json', WORK / 'installed-megas/installed-catalog.json',
        WORK / 'install-megas.log', WORK / 'runtime-final.log', WORK / 'stress-v1.log', WORK / 'stress-v1.json',
        ROOT / 'tests/battle_3d_mega_catalog_check.gd', ROOT / 'tests/battle_3d_mega_catalog_stress_check.gd',
        ROOT / 'tests/battle_3d_legendary_stress_check.gd', ROOT / 'tests/catalog_batch_01_candidate_stress_check.gd',
        ROOT / 'scripts/services/on_demand_3d_bundle_service.gd', HERE / 'catalog_mega_bundle_install_check.gd',
        HERE / 'catalog_mega_battle_qualification.py', Path(__file__)]
    receipt = dict(schema=1, date='2026-10-02', pairs=71, models=142,
        appearance_approved=True, battle_approved=True, runtime_approved=True,
        published=False, release_approved=False, technical_qualification=gate, bundle_index=index,
        bundle_size_bytes=sum(a['size_bytes'] for a in index['assets']),
        runtime_rounds=stress['rounds'], steady_frame_p95_ms=stress['steady_frame_p95_ms'],
        source_limitations=['70 forms use the visually approved own-Mega down loop as resting sleep; Hawlucha has native sleep',
                           'Static source material tables; native material animations are not replayed',
                           'Steelix metallic/crystal surfaces are a reviewed static PBR approximation'],
        evidence_sha256={str(p.relative_to(ROOT)): sha(p) for p in evidence},
        installed_runtime_check_passed=True, local_download_before_reveal_check_passed=True,
        scope='Local AMD Compatibility, exact installed SCNs; no production, R2 or cross-platform certification',
        remaining=['R2 publication', 'release content-index activation', 'release certification'])
    return fixture, receipt


def admit():
    fixture, receipt = validate()
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert not RECEIPT.exists()
    registry = read(game)
    # The inherited game catalog was reserialized in commit 99c22a443 while the
    # launcher retained the earlier float spelling. Preserve the game's values
    # and reject every difference beyond representation-level numeric precision.
    assert precision_compatible(registry, read(launcher)), 'Existing catalogs differ beyond float precision'
    receipt['inherited_catalog_precision_sync'] = dict(game_sha256=sha(game), launcher_sha256=sha(launcher),
        numeric_tolerance=1e-9, policy='Preserve game values; keys, hashes, strings and booleans must match exactly')
    names = sorted({name.removesuffix('@shiny') for name in fixture['models']})
    assert len(names) == 71
    for name in names:
        normal = copy.deepcopy(fixture['profiles'][name + '-normal'])
        shiny = copy.deepcopy(fixture['profiles'][name + '-shiny'])
        normal['motion'].pop('sha256'); shiny['motion'].pop('sha256')
        assert normal == shiny and name not in registry['profiles']
        registry['profiles'][name] = normal
        for variant in ('normal', 'shiny'):
            key = name + ('@shiny' if variant == 'shiny' else '')
            assert key not in registry['models']
            registry['models'][key] = dict(fixture['models'][key], profile=name)
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    registry['mega_71_bundle_qualification_sha256'] = sha(RECEIPT)
    payload = json.dumps(registry, indent='\t', sort_keys=True) + '\n'
    game.write_text(payload); launcher.write_text(payload)
    (ROOT / 'release/approved_3d_mega_71_index.json').write_text(json.dumps(receipt['bundle_index'], indent=2, sort_keys=True) + '\n')
    print('MEGA_71_ADMITTED pairs=71 models=142 bundles=71 published=false')


def finalize():
    log = WORK / 'admitted-check-v2.log'
    assert 'MEGA_RUNTIME_OK pairs=71' in log.read_text() and 'ERROR:' not in log.read_text()
    fixture = read(WORK / 'runtime-fixture.json')
    installed = read(WORK / 'admitted-installed-catalog.json')
    assert {identity(r): r['runtime_sha256'] for r in installed} == {
        key: row['sha256'] for key, row in fixture['models'].items()}
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    for key, model in fixture['models'].items():
        assert registry['models'][key]['sha256'] == model['sha256']
    receipt = read(RECEIPT)
    receipt['admitted_registry_check_passed'] = True
    receipt['evidence_sha256'].update({str(p.relative_to(ROOT)): sha(p) for p in (log, WORK / 'admitted-installed-catalog.json', Path(__file__))})
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    registry['mega_71_bundle_qualification_sha256'] = sha(RECEIPT)
    payload = json.dumps(registry, indent='\t', sort_keys=True) + '\n'
    game.write_text(payload); launcher.write_text(payload)
    print('MEGA_71_FINALIZED admitted_registry_check=true published=false')


def post_merge_hud():
    """Pin the actual admitted-registry replay after incorporating newer HUD code."""
    report = WORK / 'post-merge-hud.json'
    log = WORK / 'post-merge-hud.log'
    stress = read(report)
    assert 'BATCH01_STRESS_OK' in log.read_text() and 'ERROR:' not in log.read_text()
    catalog = WORK / 'on-demand-installed-catalog.json'
    assert stress['complete'] and stress['catalog_sha256'] == sha(catalog)
    expected = {key: row['sha256'] for key, row in read(WORK / 'runtime-fixture.json')['models'].items()}
    assert {identity(row): row['runtime_sha256'] for row in read(catalog)} == expected
    assert [r['arena'] for r in stress['rounds']] == ['classic', 'stadium', 'classic']
    for cycle in stress['rounds']:
        assert cycle['pairs'] == cycle['faint_replacements'] == 71
        assert math.isfinite(cycle['frame_p95_ms']) and 0 < cycle['frame_p95_ms'] <= 20
        assert cycle['retained_source_bytes'] <= 64 * 1024 * 1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation'] == 'threaded load dispatch/collect'), default=0) <= 1000 / 60
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024 * 1024
    game = ROOT / 'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT / 'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    receipt = read(RECEIPT)
    old_digest = sha(RECEIPT)
    assert receipt['admitted_registry_check_passed'] and registry['mega_71_bundle_qualification_sha256'] == old_digest
    assert all(registry['models'][key]['sha256'] == digest for key, digest in expected.items())
    receipt['post_merge_hud_check_passed'] = True
    receipt['post_merge_hud_rounds'] = stress['rounds']
    evidence = [report, log, Path(__file__), ROOT / 'tests/catalog_batch_01_candidate_stress_check.gd',
        ROOT / 'scenes/battle/battle_screen_host.tscn', ROOT / 'scripts/battle/battle.gd',
        ROOT / 'scripts/battle/battle_screen_host.gd', ROOT / 'scripts/battle/battle_display_data_presenter.gd']
    evidence.extend(ROOT / 'scripts/battle/battle_ui' / name for name in (
        'battle_damage_calc_panel.gd', 'immersive_hud.gd', 'immersive_layout.gd',
        'party_hover_card.gd', 'pokemon_hud_panel.gd'))
    receipt['evidence_sha256'].update({str(p.relative_to(ROOT)): sha(p) for p in evidence})
    intake_path = HERE / 'catalog_mega_3d_source_intake.json'
    intake = read(intake_path)
    qualified = [row for row in intake['entries'] if row.get('bundle_qualification_sha256') == old_digest]
    assert len(qualified) == 71
    RECEIPT.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    registry['mega_71_bundle_qualification_sha256'] = sha(RECEIPT)
    payload = json.dumps(registry, indent='\t', sort_keys=True) + '\n'
    game.write_text(payload); launcher.write_text(payload)
    for row in qualified:
        row['bundle_qualification_sha256'] = sha(RECEIPT)
    intake_path.write_text(json.dumps(intake, indent=2, ensure_ascii=False) + '\n')
    print('MEGA_71_POST_MERGE_HUD_OK pairs=71 rounds=3 published=false')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('phase', choices=('validate', 'admit', 'finalize', 'post-merge-hud'))
    phase = p.parse_args().phase
    if phase == 'admit':
        admit()
    elif phase == 'finalize':
        finalize()
    elif phase == 'post-merge-hud':
        post_merge_hud()
    else:
        validate(); print('MEGA_71_GATES_OK')
