"""Bind the accepted reconstruction to its locally tested scene and pair pack."""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
from zygarde_battle_qualification import ROOT, HERE, WORK, PREVIEW, NAME, read, write, sha, run

BASE = '0b5541be1813c871aca4943efac393e82e31ecc1'
GAME = ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
LAUNCHER = ROOT/'launcher/data/reviewed_model_catalog.json'
RECEIPT = HERE/'zygarde_battle_qualification.json'
INDEX = ROOT/'release/approved_3d_zygarde_ten_index.json'


def canonical(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def qualify():
    accepted=read(WORK/'visual-acceptance.json')
    assert accepted['accepted'] and accepted['preview_receipt_sha256']==sha(HERE/'zygarde_preview_result.json')
    native=read(WORK/'runtime-jobs'/NAME/'native/report.json')
    assert {r['species'] for r in native}=={NAME,NAME+'-shiny'}
    battle=WORK/'battle'/NAME
    measured=read(battle/'final/battle-review.json')
    assert measured['complete']
    for row in native:
        assert sha(row['runtime_path'])==row['runtime_sha256']
        assert sha(row['preview_runtime_path'])==row['preview_runtime_sha256']
        assert row['declared_changes_only'] and row['declared_changes']==['per_instance_material_ownership']
        assert row['material_isolation_samples']==35
        m=next(r for r in measured['entries'] if r['species']==row['species'])
        assert m['glb_sha256']==row['glb_sha256']==sha(row['path'])
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
        assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values())>=.025-1e-5
    delivery=WORK/'delivery'/NAME
    state=read(WORK/'status/delivery'/(NAME+'.json'))
    assert state['status']=='delivery_checked'
    assert sha(delivery/'shared/index.json')==state['index_sha256']
    assert sha(delivery/'shared/pixel-comparison.json')==state['pixel_report_sha256']
    assert sha(delivery/'runtime-check.log')==state['runtime_check_sha256']
    pixels=read(delivery/'shared/pixel-comparison.json')
    assert pixels['complete'] and len(pixels['models'])==2
    assert pixels['exact_frames']>=20 and all(r['pixels_exact'] for r in pixels['models'])
    asset,=read(delivery/'shared/index.json')['assets']
    pack=delivery/'shared/packs'/asset['object_key'].split('/')[-1]
    assert sha(pack)==asset['sha256'] and pack.stat().st_size==asset['size_bytes']
    assert len(asset['appearances'])==2
    fixture=read(delivery/'runtime-fixture.json')
    for appearance in asset['appearances']:
        identity=appearance['runtime_identity']
        row=next(r for r in native if r['variant']==appearance['variant'])
        assert appearance['source_sha256']==row['runtime_sha256']==fixture['models'][identity]['sha256']
    files=[WORK/'visual-acceptance.json',WORK/'runtime-jobs'/NAME/'native/report.json',
        WORK/'prepare.log',battle/'catalog.json',battle/'baseline/battle-review.json',battle/'placement.json',
        battle/'final/battle-review.json',delivery/'runtime-fixture.json',delivery/'shared/index.json',
        delivery/'shared/pixel-comparison.json',delivery/'shared/validated/receipts.jsonl',
        delivery/'shared/render-qualified/report.json',delivery/'runtime-check.log']
    for renderer in ('gl_compatibility','mobile'):
        path=WORK/('ui-v3-'+renderer)/'report.json'
        report=read(path)
        assert report['complete'] and report['pairs']==6 and report['faint_replacements']==6
        assert report['material_isolation_samples']==126 and report['downloads']<=1
        assert report['material_source_samples']==1386
        assert report['fixture_sha256']==sha(delivery/'runtime-fixture.json')
        assert report['index_sha256']==sha(delivery/'shared/index.json')
        assert len(report['shots'])==14
        files.append(path)
        files.extend(path.parent/p for p in report['shots'])
    return asset,fixture,{'schema':1,'species':NAME,'runtime_approved':True,
        'release_approved':False,'published':False,'admitted_registry_check_passed':False,
        'appearance':'User accepted the reconstructed core and shell; original-engine parity is not claimed.',
        'platform':'Linux Godot 4.6.2; Compatibility and Mobile, not physical Android',
        'pixel_exact_frames':pixels['exact_frames'],'independent_material_samples':70+2*126,
        'battle_views':sum(len(r['shots']) for r in measured['entries'] if 'clips' in r),
        'bundle_size_bytes':asset['size_bytes'],'remaining_forms':35,
        'restored_forms_across_original_229':194,
        'previous_result_sha256':sha(HERE/'remaining_forms_repair_result.json'),
        'preview_receipt_sha256':sha(HERE/'zygarde_preview_result.json'),
        'evidence_sha256':{str(p.relative_to(WORK)):sha(p) for p in files}}


def save(registry):
    data=(json.dumps(registry,indent='\t',allow_nan=False)+'\n').encode()
    GAME.write_bytes(data);LAUNCHER.write_bytes(data)


def admit():
    asset,fixture,receipt=qualify()
    assert GAME.read_bytes()==LAUNCHER.read_bytes()
    registry=read(GAME)
    before=json.loads(subprocess.check_output(['git','show',BASE+':scripts/battle/battle_ui/reviewed_model_catalog.json'],cwd=ROOT))
    for key in ('models','profiles'):
        assert all(registry[key][k]==v for k,v in before[key].items())
    receipt['previous_registry']={k+'_sha256':canonical(before[k]) for k in ('models','profiles')}
    profile=copy.deepcopy(fixture['profiles'][NAME+'-normal']);profile['motion'].pop('sha256')
    other=copy.deepcopy(fixture['profiles'][NAME+'-shiny']);other['motion'].pop('sha256')
    assert profile==other
    assert NAME not in registry['profiles'] and not any(k in registry['models'] for k in fixture['models'])
    registry['profiles'][NAME]=profile
    registry['models'].update({k:dict(v,profile=NAME) for k,v in fixture['models'].items()})
    write(INDEX,dict(schema=1,kind='pokeaether-optional-asset-index',catalog_revision='zygarde-ten-local-v1',
        runtime_contract={'pokemon_3d':2,'godot':'4.6'},assets=[asset]))
    receipt['bundle_index_sha256']=sha(INDEX)
    write(RECEIPT,receipt)
    registry['zygarde_ten_qualification_sha256']=sha(RECEIPT)
    save(registry)
    print('ZYGARDE_LOCAL_ADMISSION_PENDING_FINAL_CHECK')


def finalize():
    receipt=read(RECEIPT)
    asset,_,_=qualify()
    assert read(INDEX)['assets']==[asset] and sha(INDEX)==receipt['bundle_index_sha256']
    delivery=WORK/'delivery'/NAME
    env=dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(delivery),POKEAETHER_FORM_BATCH_SHARED='1',
        POKEAETHER_FORM_BATCH_ADMITTED='1',POKEAETHER_CATALOG_WORK_ROOT=str(WORK))
    run('admitted-check',['--path',str(ROOT),'--rendering-method','mobile',
        '--script','res://tests/battle_3d_alternate_form_check.gd'],env)
    assert 'FORM_BATCH_RUNTIME_OK' in (WORK/'admitted-check.log').read_text()
    receipt['admitted_registry_check_passed']=True
    receipt['evidence_sha256']['admitted-check.log']=sha(WORK/'admitted-check.log')
    paths=[HERE/'zygarde_battle_qualification.py',HERE/'zygarde_battle_prepare.gd',Path(__file__),
        ROOT/'tests/battle_3d_zygarde_check.gd',HERE/'alternate_forms_delivery.py',
        HERE/'alternate_forms_recovery_battle.py',HERE/'model_pair_texture_probe.gd',
        ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.gd',
        ROOT/'scripts/battle/battle_ui/material_effect.gd']
    receipt['code_sha256']={str(p.relative_to(ROOT)):sha(p) for p in paths}
    write(RECEIPT,receipt)
    registry=read(GAME);registry['zygarde_ten_qualification_sha256']=sha(RECEIPT);save(registry)
    print('ZYGARDE_LOCAL_QUALIFIED remaining=35 published=false')


if __name__=='__main__':
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['admit','finalize']);args=parser.parse_args()
    globals()[args.phase]()
