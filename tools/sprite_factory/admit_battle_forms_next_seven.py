"""Admit seven exact form pairs after local bundle and rendered battle qualification."""
import copy
import json
from pathlib import Path
from prepare_battle_forms_next_seven_admission import ROOT, HERE, BASE, WORK, read, sha
import sys
sys.path.insert(0,str(ROOT/'tools'))
from package_optional_3d_bundle_prototype import encoded

def main():
    checkpoint=read(HERE/'catalog_battle_forms_next_seven_checkpoint.json')
    assert checkpoint['appearance_approved'] and checkpoint['battle_approved']
    for path,digest in checkpoint['battle_measurement']['evidence_sha256'].items(): assert sha(ROOT/path)==digest
    assert sha(ROOT/checkpoint['runtime_pose_order_check']['report'])==checkpoint['runtime_pose_order_check']['sha256']
    catalog=read(WORK/'runtime-catalog-final.json');installed=read(WORK/'installed/installed-catalog.json')
    expected={(r['species'],r['variant']):r['runtime_sha256'] for r in catalog}
    assert len(catalog)==len(installed)==14
    assert {(r['species'],r['variant']):r['runtime_sha256'] for r in installed}==expected
    for row in installed: assert sha(row['runtime_path'])==row['runtime_sha256']
    index=read(WORK/'bundles/asset-index.json');assert len(index['assets'])==7
    for asset in index['assets']:
        p=WORK/'bundles'/Path(asset['object_key']).name
        assert sha(p)==asset['sha256'] and p.stat().st_size==asset['size_bytes']
        assert {a['variant']:a['runtime_sha256'] for a in asset['appearances']}=={
            v:expected[asset['species_id'],v] for v in ('normal','shiny')}
    for name,marker in [('install-launcher.log','REMAINING_144_BUNDLES_OK bundles=7 scenes=14'),
                        ('forms-check.log','NEXT_SEVEN_FORMS_OK'),
                        ('installed-stress-final.log','BATCH01_STRESS_OK')]:
        log=(WORK/name).read_text();assert marker in log and 'ERROR:' not in log, name
    stress=read(WORK/'installed-stress-final.json')
    assert stress['complete'] and stress['catalog_sha256']==sha(WORK/'battle-catalog.json')
    assert [r['arena'] for r in stress['rounds']]==['classic','stadium','classic']
    for cycle in stress['rounds']:
        assert cycle['pairs']==cycle['faint_replacements']==7
        assert 0<cycle['frame_p95_ms']<=20
        assert cycle['retained_source_bytes']<=64*1024*1024
        assert not any(s['ms']>100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation']=='threaded load dispatch/collect'),default=0)<=1000/60
    assert stress['rounds'][2]['static_bytes']-stress['rounds'][1]['static_bytes']<1024*1024
    batch_log=(WORK/'stadium-batch-check.log').read_text()
    assert 'STADIUM_STATIC_BATCH_OK boxes=624 batches=16' in batch_log and 'ERROR:' not in batch_log
    fixture=read(WORK/'runtime-fixture.json')
    game=ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json';launcher=ROOT/'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes()==launcher.read_bytes()
    registry=read(game);before=len(registry['models'])
    names=sorted({r['species'] for r in catalog})
    for name in names:
        assert name not in registry['profiles']
        profile=copy.deepcopy(fixture['profiles'][name+'-normal'])
        rare=copy.deepcopy(fixture['profiles'][name+'-shiny'])
        profile['motion'].pop('sha256');rare['motion'].pop('sha256');assert profile==rare
        registry['profiles'][name]=profile
        for variant in ('normal','shiny'):
            identity=name+('@shiny' if variant=='shiny' else '')
            assert identity not in registry['models']
            registry['models'][identity]=dict(fixture['models'][identity],profile=name)
    evidence=[HERE/'catalog_battle_forms_next_seven_checkpoint.json',HERE/'prepare_battle_forms_next_seven_admission.py',Path(__file__),
              WORK/'runtime-catalog-final.json',WORK/'runtime-fixture.json',WORK/'installed/installed-catalog.json',
              WORK/'install-launcher.log',WORK/'forms-check.log',WORK/'installed-stress-final.json',WORK/'installed-stress-final.log',
              WORK/'battle-catalog.json',WORK/'base-control-stress.json',WORK/'diagnostic-stress.json',WORK/'installed-stress.json',WORK/'quiet-stress-first.json',WORK/'arena-cost.json',WORK/'arena-cost.log',WORK/'arena_cost_diagnostic.gd',WORK/'pre-batching-stress.json',WORK/'boxes-only-stress.json',WORK/'batched-diagnostic-stress.json',WORK/'per-context.json',WORK/'stadium-batch-check.log',ROOT/'tests/stadium_static_batch_check.gd',ROOT/'scripts/battle/arenas/generic/stadium_arena.gd',
              HERE/'catalog_remaining_144_bundle_install_check.gd',ROOT/'tests/phase5_candidate_stage.gd',
              ROOT/'tests/battle_3d_next_seven_forms_check.gd',ROOT/'tests/battle_3d_next_seven_stress_check.gd',ROOT/'tests/catalog_batch_01_candidate_stress_check.gd',
              ROOT/'scripts/battle/battle_ui/experimental_battle_3d.gd',ROOT/'scripts/services/on_demand_3d_bundle_service.gd']
    receipt={'schema':1,'date':'2026-10-02','forms':names,'models':14,'appearance_approved':True,'battle_approved':True,
             'runtime_approved':True,'release_approved':False,'published':False,'bundle_index':index,
             'bundle_size_bytes':sum(a['size_bytes'] for a in index['assets']),
             'runtime_rounds':stress['rounds'],'installed_runtime_check_passed':True,
             'performance_diagnosis':{'initial_p95_ms':[r['frame_p95_ms'] for r in read(WORK/'installed-stress.json')['rounds']], 'first_quiet_p95_ms':[r['frame_p95_ms'] for r in read(WORK/'quiet-stress-first.json')['rounds']], 'arena_component_probe':read(WORK/'arena-cost.json'), 'approved_base_control_p95_ms':[r['frame_p95_ms'] for r in read(WORK/'base-control-stress.json')['rounds']], 'pre_batching_p95_ms':[r['frame_p95_ms'] for r in read(WORK/'pre-batching-stress.json')['rounds']], 'confirmation':'Unchanged gate after grouping 624 unchanged static stand boxes into 16 material batches and splitting unchanged spectators/lights per stand for off-camera culling; competing Tiled closed by user. Original run-to-run timing variation not fully explained'},
             'source_limitations':['Wishiwashi sleep uses swimming idle; faint uses own-rig damage and an authored endpoint hold','Darmanitan native faint start ends in an authored constant hold','Local performance failures and approved-base control are retained as evidence'],
             'anticipated_form_download_and_loading_passed':True,'no_op_restart_check_passed':True,
             'evidence_sha256':{str(p.relative_to(ROOT)):sha(p) for p in evidence},
             'scope':'Local AMD Compatibility; fixture uses local archives, no public R2 or cross-platform certification',
             'remaining':['R2 publication','release content-index activation','release certification and publication']}
    receipt_path=HERE/'catalog_battle_forms_next_seven_bundle_qualification.json';assert not receipt_path.exists()
    receipt_path.write_bytes(encoded(receipt));registry['battle_forms_next_seven_bundle_qualification_sha256']=sha(receipt_path)
    assert len(registry['models'])==before+14
    game.write_bytes(encoded(registry));launcher.write_bytes(encoded(registry))
    print('NEXT_SEVEN_FORMS_ADMITTED profiles=7 appearances=14 bundles=7 published=false')
def finalize():
    path=HERE/'catalog_battle_forms_next_seven_bundle_qualification.json'
    receipt=read(path)
    log=(WORK/'admitted-check.log').read_text()
    assert 'FORMS_REGISTRY_OK pairs=7 scenes=14' in log and 'ERROR:' not in log
    game=ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher=ROOT/'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes()==launcher.read_bytes()
    registry=read(game)
    for row in read(WORK/'installed/installed-catalog.json'):
        key=row['species']+('@shiny' if row['variant']=='shiny' else '')
        assert registry['models'][key]['sha256']==row['runtime_sha256']==sha(row['runtime_path'])
    for p in [Path(__file__),HERE/'catalog_battle_forms_next_seven_checkpoint.json',WORK/'admitted_check.gd',WORK/'admitted-check.log']:
        receipt['evidence_sha256'][str(p.relative_to(ROOT))]=sha(p)
    receipt['admitted_registry_check_passed']=True
    path.write_bytes(encoded(receipt))
    registry['battle_forms_next_seven_bundle_qualification_sha256']=sha(path)
    game.write_bytes(encoded(registry));launcher.write_bytes(encoded(registry))
    (ROOT/'release/approved_3d_battle_forms_next_seven_index.json').write_bytes(encoded(receipt['bundle_index']))
    print('NEXT_SEVEN_FORMS_FINALIZED published=false')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=('admit','finalize'),default='admit',nargs='?')
    args=parser.parse_args()
    {'admit':main,'finalize':finalize}[args.phase]()
