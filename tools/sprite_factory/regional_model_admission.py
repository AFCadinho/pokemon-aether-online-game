"""Prepare and qualify the 58 accepted regional pairs using exact installed scenes."""
import argparse
import copy
import json
import sys
from pathlib import Path

from catalog_galar_birds_candidates import sha
from catalog_mega_battle_qualification import qualify

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT/'.tmp/regional-production-v1'
WORK = BASE/'admission-v1'
CHECKPOINT = HERE/'regional_model_candidate_review.json'
RECEIPT = HERE/'regional_model_bundle_qualification.json'
sys.path.insert(0,str(ROOT/'tools'))
from package_optional_3d_bundle_prototype import build, encoded


def read(path):
    return json.loads(Path(path).read_text())


def installed_identity(row):
    # Presenter entries already include @shiny; launcher catalogs store the base.
    return row['species'].removesuffix('@shiny') + ('@shiny' if row['variant'] == 'shiny' else '')


def approved():
    approval = read(CHECKPOINT)
    assert approval['appearance_visual_approved'] and approval['battle_visual_approved']
    assert approval['pair_count'] == 58 and approval['variant_count'] == 116
    for path,digest in approval['reports'].items():
        assert sha(BASE/path) == digest, path
    gate = qualify(BASE/'battle-eyes-final-v1/battle-review.json',BASE/'eye-last-two-v2/catalog.json',58)
    assert gate['technical_variant_count'] == 116 and not gate['held']
    return approval


def prepare():
    approval = approved()
    WORK.mkdir(exist_ok=False)
    rows = read(BASE/approval['current_runtime_report'])
    placement = read(BASE/approval['current_placement'])
    measured = {r['species']:r for r in read(BASE/'battle-eyes-final-v1/battle-review.json')['entries']}
    dex = {r['species']:r['national_dex'] for r in read(HERE/'regional_model_batch_inputs.json')['source_scan']}
    fixture = {'models':{},'profiles':{}}
    catalog = []
    for source in rows:
        name = source['species']; species = name.removesuffix('-shiny')
        variant = 'shiny' if name.endswith('-shiny') else 'normal'
        identity = species+('@shiny' if variant == 'shiny' else '')
        assert sha(source['path']) == source['glb_sha256'] == measured[name]['glb_sha256']
        assert sha(source['runtime_path']) == source['runtime_sha256']
        assert source['complete_pose_channels']
        motion = copy.deepcopy(placement['motion'][name])
        assert motion['sha256'] == source['glb_sha256']
        assert abs(motion['scale']-measured[name]['scale']) < 1e-6
        assert abs(motion['lift']-measured[name]['candidate_lift']) < .001
        motion['sha256'] = source['runtime_sha256']
        profile_name = species+'-'+variant
        scale = measured[name]['scale']
        bounds = {a:{'min':[v/scale for v in c['envelope_min']], 'size':[v/scale for v in c['envelope_size']]}
                  for a,c in measured[name]['clips'].items()}
        position = {k:motion[k] for k in ['scale','yaw_degrees']}
        position['hover_height'] = placement['hover'][name]
        profile = {'action_timing':source['action_timing'],'placement':position,
                   'grounding':dict(position,lift=motion['lift']),'motion':motion,'bounds':bounds}
        if 'physical_attack_2' in source['animations']:
            profile['attack_family_actions'] = {'body_charge':'physical_attack_2'}
        fixture['models'][identity] = {'sha256':source['runtime_sha256'],'glb_sha256':source['glb_sha256'],'profile':profile_name}
        fixture['profiles'][profile_name] = profile
        catalog.append(dict(source,species=species,variant=variant,placement=position))
    names = sorted({r['species'] for r in catalog})
    assert len(names) == 58 and len(catalog) == 116 and set(names) <= dex.keys()
    (WORK/'approval.json').write_bytes(encoded(approval))
    (WORK/'runtime-fixture.json').write_bytes(encoded(fixture))
    (WORK/'runtime-catalog.json').write_bytes(encoded(catalog))
    index = build(WORK/'runtime-catalog.json',WORK/'bundles',revision='regional-58-approved-v1',
                  species_set=tuple(names),dex=dex,candidate_hashes={k:v['sha256'] for k,v in fixture['models'].items()})
    (WORK/'preparation.json').write_bytes(encoded({'pairs':58,'scenes':116,'names':names,
        'approval_sha256':sha(WORK/'approval.json'),'placement_sha256':sha(BASE/approval['current_placement']),
        'bundle_index_sha256':sha(WORK/'bundles/asset-index.json'),'total_bytes':sum(a['size_bytes'] for a in index['assets'])}))
    print('REGIONAL_PREPARED pairs=58 scenes=116 bundles=58')


def validate():
    approval = approved()
    fixture = read(WORK/'runtime-fixture.json')
    expected = {k:v['sha256'] for k,v in fixture['models'].items()}
    assert len(expected) == 116
    for filename in ['installed/installed-catalog.json','on-demand-installed-catalog.json']:
        rows = read(WORK/filename)
        actual = {installed_identity(r):r['runtime_sha256'] for r in rows}
        assert len(rows) == 116 and actual == expected
        assert all(sha(r['runtime_path']) == r['runtime_sha256'] for r in rows)
    for filename,marker in [('install.log','MEGA_BUNDLES_OK bundles=58 scenes=116'),
                            ('runtime.log','REGIONAL_RUNTIME_OK pairs=58'),('stress.log','BATCH01_STRESS_OK')]:
        log = (WORK/filename).read_text()
        assert marker in log and 'ERROR:' not in log, filename
    stress = read(WORK/'stress.json')
    assert stress['complete'] and stress['catalog_sha256'] == sha(WORK/'on-demand-installed-catalog.json')
    assert stress['window_size'] == [1280, 720]
    assert stress['forced_test_frames'] == 0, 'Performance admission requires uninterrupted automatic rendering'
    assert set(stress['species']) == set(read(WORK/'preparation.json')['names'])
    assert [r['arena'] for r in stress['rounds']] == ['classic','stadium','classic']
    assert set(stress['steady_frame_p95_ms']) == {'classic','stadium'}
    for r in stress['steady_frame_p95_ms'].values():
        assert r['samples'] >= 58*240 and 0 < r['p95_ms'] <= 20
    for r in stress['rounds']:
        assert r['pairs'] == r['faint_replacements'] == 58
        assert 0 < r['frame_p95_ms'] <= 20
        assert r['retained_source_bytes'] <= 64*1024*1024
        assert not any(s['ms'] > 100 and not s['covered'] for s in r['stalls_over_50ms'])
        assert max((s['ms'] for s in r['load_spans'] if s['operation']=='threaded load dispatch/collect'),default=0) <= 1000/60
    assert stress['rounds'][2]['static_bytes'] - stress['rounds'][1]['static_bytes'] < 1024*1024
    index = read(WORK/'bundles/asset-index.json')
    assert len(index['assets']) == 58
    assert sha(WORK/'bundles/asset-index.json') == read(WORK/'preparation.json')['bundle_index_sha256']
    for asset in index['assets']:
        archive = WORK/'bundles'/Path(asset['object_key']).name
        assert sha(archive) == asset['sha256'] and archive.stat().st_size == asset['size_bytes']
        assert {a['runtime_identity']:a['runtime_sha256'] for a in asset['appearances']} == {
            k:v for k,v in expected.items() if k.removesuffix('@shiny')==asset['species_id']}
    # Bind every admitted profile to the exact accepted placement and scene.
    placement = read(BASE/approval['current_placement'])
    for r in read(WORK/'runtime-catalog.json'):
        key = r['species']+('@shiny' if r['variant']=='shiny' else '')
        raw = r['species']+('-shiny' if r['variant']=='shiny' else '')
        motion = copy.deepcopy(placement['motion'][raw])
        assert motion['sha256'] == fixture['models'][key]['glb_sha256']
        motion['sha256'] = expected[key]
        profile = fixture['profiles'][fixture['models'][key]['profile']]
        assert profile['motion'] == motion and profile['action_timing'] == r['action_timing']
        assert profile['placement']['hover_height'] == placement['hover'][raw]
    return fixture,index,stress


def admit():
    fixture,index,stress = validate()
    game = ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher = ROOT/'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert not RECEIPT.exists()
    assert not set(fixture['models']) & registry['models'].keys()
    assert not set(fixture['profiles']) & registry['profiles'].keys()
    for name,profile in fixture['profiles'].items():
        profile = copy.deepcopy(profile)
        profile['motion'].pop('sha256')
        registry['profiles'][name] = profile
    registry['models'].update(fixture['models'])
    evidence = [WORK/p for p in ['approval.json','preparation.json','runtime-fixture.json','runtime-catalog.json',
        'installed/installed-catalog.json','on-demand-installed-catalog.json','install.log','runtime.log','stress.log','stress.json']]
    evidence += [Path(__file__),ROOT/'tests/battle_3d_regional_forms_check.gd',ROOT/'tests/battle_3d_regional_stress_check.gd',
        ROOT/'tests/battle_3d_mega_catalog_stress_check.gd',ROOT/'tests/battle_3d_galar_birds_check.gd',
        ROOT/'tools/sprite_factory/catalog_mega_bundle_install_check.gd',
        ROOT/'scripts/battle/battle_ui/model_form_dependencies.gd',
        ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.gd',
        ROOT/'scripts/battle/battle_ui/experimental_battle_3d.gd',
        ROOT/'tests/battle_3d_raster_size_check.gd',
        BASE/'performance-investigation/transforms.log',
        BASE/'performance-investigation/raster-fixed-control.json',
        ROOT/'tests/battle_3d_legendary_stress_check.gd',ROOT/'tests/catalog_batch_01_candidate_stress_check.gd',
        BASE/'battle-eyes-final-v1/receipt.json',BASE/'battle-eyes-final-v1/qualification.json']
    receipt = {'schema':1,'pairs':58,'models':116,'appearance_approved':True,'battle_approved':True,
        'runtime_approved':True,'published':False,'release_approved':False,'bundle_index':index,
        'bundle_size_bytes':sum(a['size_bytes'] for a in index['assets']),
        'runtime_rounds':stress['rounds'],'steady_frame_p95_ms':stress['steady_frame_p95_ms'],
        'installed_runtime_check_passed':True,'local_download_before_reveal_check_passed':True,
        'evidence_sha256':{str(p.relative_to(ROOT)):sha(p) for p in evidence},
        'scope':'Local Compatibility, exact installed scenes; no production, R2 or cross-platform certification',
        'source_limitations_document':'docs/3d/regional-model-production.md',
        'remaining':['Post-admission runtime check','Local integration','R2 upload and release index activation']}
    RECEIPT.write_bytes(encoded(receipt))
    registry['regional_58_bundle_qualification_sha256'] = sha(RECEIPT)
    payload = (json.dumps(registry,indent='\t')+'\n').encode()
    game.write_bytes(payload); launcher.write_bytes(payload)
    (ROOT/'release/approved_3d_regional_58_index.json').write_bytes(encoded(index))
    print('REGIONAL_ADMITTED models=116 bundles=58 published=false')


def finalize():
    log = WORK/'admitted-runtime.log'
    assert 'REGIONAL_RUNTIME_OK pairs=58' in log.read_text() and 'ERROR:' not in log.read_text()
    fixture = read(WORK/'runtime-fixture.json')
    installed = read(WORK/'admitted-installed-catalog.json')
    assert len(installed) == 116
    assert {installed_identity(r):r['runtime_sha256'] for r in installed} == {
        k:v['sha256'] for k,v in fixture['models'].items()}
    receipt = read(RECEIPT)
    receipt['admitted_registry_check_passed'] = True
    receipt['remaining'] = ['Local integration','R2 upload and release index activation']
    receipt['evidence_sha256'].update({str(p.relative_to(ROOT)):sha(p) for p in [log,WORK/'admitted-installed-catalog.json',Path(__file__)]})
    RECEIPT.write_bytes(encoded(receipt))
    game = ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'; launcher = ROOT/'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes() == launcher.read_bytes()
    registry = read(game)
    assert all(registry['models'][k] == v for k,v in fixture['models'].items())
    registry['regional_58_bundle_qualification_sha256'] = sha(RECEIPT)
    payload = (json.dumps(registry,indent='\t')+'\n').encode()
    game.write_bytes(payload); launcher.write_bytes(payload)
    checkpoint = read(CHECKPOINT)
    checkpoint.update(status='qualified_locally_not_published',runtime_approved=True,performance_qualified=True,
        registry_admitted=True,bundles_built=True,bundle_qualification_sha256=sha(RECEIPT))
    CHECKPOINT.write_bytes(encoded(checkpoint))
    print('REGIONAL_FINALIZED models=116 bundles=58 published=false')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('phase',choices=['prepare','validate','admit','finalize'])
    phase = parser.parse_args().phase
    {'prepare':prepare,'validate':validate,'admit':admit,'finalize':finalize}[phase]()
