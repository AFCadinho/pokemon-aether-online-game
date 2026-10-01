"""Admit five exact form pairs after local bundle and rendered battle qualification."""
import copy
import json
from pathlib import Path
from prepare_battle_forms_admission import ROOT, HERE, BASE, WORK, read, sha
import sys
sys.path.insert(0,str(ROOT/'tools'))
from package_optional_3d_bundle_prototype import encoded

def main():
    checkpoint=read(HERE/'catalog_battle_forms_first_five_checkpoint.json')
    assert checkpoint['visual_approved']
    for path,digest in checkpoint['reports'].items(): assert sha(BASE/path)==digest
    catalog=read(WORK/'runtime-catalog-final.json');installed=read(WORK/'installed/installed-catalog.json')
    expected={(r['species'],r['variant']):r['runtime_sha256'] for r in catalog}
    assert len(catalog)==len(installed)==10
    assert {(r['species'],r['variant']):r['runtime_sha256'] for r in installed}==expected
    for row in installed: assert sha(row['runtime_path'])==row['runtime_sha256']
    index=read(WORK/'bundles/asset-index.json');assert len(index['assets'])==5
    for asset in index['assets']:
        p=WORK/'bundles'/Path(asset['object_key']).name
        assert sha(p)==asset['sha256'] and p.stat().st_size==asset['size_bytes']
        assert {a['variant']:a['runtime_sha256'] for a in asset['appearances']}=={
            v:expected[asset['species_id'],v] for v in ('normal','shiny')}
    for name,marker in [('install-launcher.log','REMAINING_144_BUNDLES_OK bundles=5 scenes=10'),
                        ('forms-check-v2.log','FIRST_FIVE_FORMS_OK'),
                        ('installed-stress-final.log','BATCH01_STRESS_OK')]:
        log=(WORK/name).read_text();assert marker in log and 'ERROR:' not in log, name
    stress=read(WORK/'installed-stress-final.json')
    assert stress['complete'] and stress['catalog_sha256']==sha(WORK/'installed/installed-catalog.json')
    assert [r['arena'] for r in stress['rounds']]==['classic','stadium','classic']
    for cycle in stress['rounds']:
        assert cycle['pairs']==cycle['faint_replacements']==5
        assert 0<cycle['frame_p95_ms']<=20
        assert cycle['retained_source_bytes']<=64*1024*1024
        assert not any(s['ms']>100 and not s['covered'] for s in cycle['stalls_over_50ms'])
        assert max((s['ms'] for s in cycle['load_spans'] if s['operation']=='threaded load dispatch/collect'),default=0)<=1000/60
    assert stress['rounds'][2]['static_bytes']-stress['rounds'][1]['static_bytes']<1024*1024
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
    evidence=[HERE/'catalog_battle_forms_first_five_checkpoint.json',HERE/'prepare_battle_forms_admission.py',Path(__file__),
              WORK/'runtime-catalog-final.json',WORK/'runtime-fixture.json',WORK/'installed/installed-catalog.json',
              WORK/'install-launcher.log',WORK/'forms-check-v2.log',WORK/'installed-stress-final.json',WORK/'installed-stress-final.log',
              WORK/'runtime_check.gd', WORK/'profile_check.gd',
              HERE/'catalog_remaining_144_bundle_install_check.gd',ROOT/'tests/phase5_candidate_stage.gd',
              ROOT/'tests/battle_3d_first_five_forms_check.gd',ROOT/'tests/catalog_batch_01_candidate_stress_check.gd',
              ROOT/'scripts/battle/battle_ui/experimental_battle_3d.gd',ROOT/'scripts/services/on_demand_3d_bundle_service.gd']
    receipt={'schema':1,'date':'2026-10-01','forms':names,'models':10,'appearance_approved':True,'battle_approved':True,
             'runtime_approved':True,'release_approved':False,'published':False,'bundle_index':index,
             'bundle_size_bytes':sum(a['size_bytes'] for a in index['assets']),
             'runtime_rounds':stress['rounds'],'installed_runtime_check_passed':True,
             'anticipated_form_download_and_loading_passed':True,'no_op_restart_check_passed':True,
             'evidence_sha256':{str(p.relative_to(ROOT)):sha(p) for p in evidence},
             'scope':'Local AMD Compatibility; fixture uses local archives, no public R2 or cross-platform certification',
             'remaining':['R2 publication','release content-index activation','release certification and publication']}
    receipt_path=HERE/'catalog_battle_forms_first_five_bundle_qualification.json';assert not receipt_path.exists()
    receipt_path.write_bytes(encoded(receipt));registry['battle_forms_first_five_bundle_qualification_sha256']=sha(receipt_path)
    assert len(registry['models'])==before+10
    game.write_bytes(encoded(registry));launcher.write_bytes(encoded(registry))
    print('FIRST_FIVE_FORMS_ADMITTED profiles=5 appearances=10 bundles=5 published=false')
def finalize():
    path=HERE/'catalog_battle_forms_first_five_bundle_qualification.json'
    receipt=read(path)
    log=(WORK/'admitted-check.log').read_text()
    assert 'FORMS_REGISTRY_OK pairs=5 scenes=10' in log and 'ERROR:' not in log
    game=ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
    launcher=ROOT/'launcher/data/reviewed_model_catalog.json'
    assert game.read_bytes()==launcher.read_bytes()
    registry=read(game)
    for row in read(WORK/'installed/installed-catalog.json'):
        key=row['species']+('@shiny' if row['variant']=='shiny' else '')
        assert registry['models'][key]['sha256']==row['runtime_sha256']==sha(row['runtime_path'])
    for p in [Path(__file__),WORK/'admitted_check.gd',WORK/'admitted-check.log']:
        receipt['evidence_sha256'][str(p.relative_to(ROOT))]=sha(p)
    receipt['admitted_registry_check_passed']=True
    path.write_bytes(encoded(receipt))
    registry['battle_forms_first_five_bundle_qualification_sha256']=sha(path)
    game.write_bytes(encoded(registry));launcher.write_bytes(encoded(registry))
    (ROOT/'release/approved_3d_battle_forms_first_five_index.json').write_bytes(encoded(receipt['bundle_index']))
    print('FIRST_FIVE_FORMS_FINALIZED published=false')

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=('admit','finalize'),default='admit',nargs='?')
    args=parser.parse_args()
    {'admit':main,'finalize':finalize}[args.phase]()
