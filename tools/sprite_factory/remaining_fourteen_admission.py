"""Admit only the fourteen accepted, measured and package-tested local pairs."""
import argparse
import copy
import hashlib
import json
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from remaining_fourteen_battle import ROOT,HERE,WORK,NAMES,read,write,sha,run

BASE='580d2eafb86776e065824eb769db2273000d6909'
GAME=ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
LAUNCHER=ROOT/'launcher/data/reviewed_model_catalog.json'
RECEIPT=HERE/'remaining_fourteen_qualification.json'
INDEX=ROOT/'release/approved_3d_remaining_fourteen_index.json'


def canonical(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def qualify():
    accepted=read(WORK/'visual-acceptance.json')
    assert accepted['accepted']
    for field,file in [('preview_receipt_sha256','remaining_forms_preview_result.json'),
                       ('sleep_receipt_sha256','remaining_forms_sleep_result.json'),
                       ('previous_approval_sha256','remaining_forms_visual_approval.json')]:
        assert accepted[field]==sha(HERE/file)
    files=[WORK/'visual-acceptance.json']
    assets=[];fixtures={};entries={}
    for name in NAMES:
        native_path=WORK/'runtime-jobs'/name/'native/report.json'
        native=read(native_path)
        assert {r['species'] for r in native}=={name,name+'-shiny'}
        battle=WORK/'battle'/name
        measured=read(battle/'final/battle-review.json')
        assert measured['complete']
        for row in native:
            assert sha(row['runtime_path'])==row['runtime_sha256']
            assert sha(row['preview_runtime_path'])==row['preview_runtime_sha256']==accepted['scenes'][row['species']]
            expected_changes=['per_instance_material_ownership']
            if name.startswith('cramorant-'):
                expected_changes.append('constant_eye_texture_selection_as_visibility')
                assert row['eye_visibility_path']
            elif row.get('eye_states'):
                expected_changes.append('discrete_constant_texture_selection')
                assert row['discrete_texture_tracks']>0
            assert row['declared_changes_only'] and row['declared_changes']==expected_changes
            assert row['material_isolation_samples']==5*len(row['animations'])
            m=next(r for r in measured['entries'] if r['species']==row['species'])
            assert m['glb_sha256']==row['glb_sha256']==sha(row['path'])
            assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
            assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values())>=.025-1e-5
        delivery=WORK/'delivery'/name
        state=read(WORK/'status/delivery'/(name+'.json'))
        assert state['status']=='delivery_checked'
        for file,key in [('shared/index.json','index_sha256'),('shared/pixel-comparison.json','pixel_report_sha256'),('runtime-check.log','runtime_check_sha256')]:
            assert sha(delivery/file)==state[key]
        runtime_log=(delivery/'runtime-check.log').read_text()
        assert 'FORM_BATCH_RUNTIME_OK' in runtime_log and 'ERROR:' not in runtime_log and 'SCRIPT ERROR' not in runtime_log
        pixels=read(delivery/'shared/pixel-comparison.json')
        assert pixels['complete'] and len(pixels['models'])==2 and pixels['exact_frames']>=20
        assert all(r['pixels_exact'] for r in pixels['models'])
        asset,=read(delivery/'shared/index.json')['assets']
        pack=delivery/'shared/packs'/asset['object_key'].split('/')[-1]
        assert sha(pack)==asset['sha256'] and pack.stat().st_size==asset['size_bytes']
        assert len(asset['appearances'])==2
        fixture=read(delivery/'runtime-fixture.json')
        for appearance in asset['appearances']:
            row=next(r for r in native if r['variant']==appearance['variant'])
            assert appearance['source_sha256']==row['runtime_sha256']==fixture['models'][appearance['runtime_identity']]['sha256']
        files.extend([native_path,WORK/('prepare-'+name+'.log'),battle/'catalog.json',battle/'baseline/battle-review.json',
            battle/'placement.json',battle/'final/battle-review.json',delivery/'runtime-fixture.json',delivery/'shared/index.json',
            delivery/'shared/pixel-comparison.json',delivery/'shared/validated/receipts.jsonl',
            delivery/'shared/render-qualified/report.json',delivery/'runtime-check.log'])
        views=sum(len(r['shots']) for r in measured['entries'] if 'clips' in r)
        samples=0
        for renderer in ('gl_compatibility','mobile'):
            path=WORK/'ui'/name/renderer/'report.json'
            report=read(path)
            log=(WORK/('ui-'+name+'-'+renderer+'.log')).read_text()
            assert 'FOURTEEN_BATTLE_UI_OK' in log and 'ERROR:' not in log and 'SCRIPT ERROR' not in log
            assert report['complete'] and report['pairs']==6 and report['faint_replacements']==6
            expected=18*len(native[0]['animations'])
            assert report['material_isolation_samples']==expected==report['material_source_samples']
            assert report['downloads']<=1
            assert report['fixture_sha256']==sha(delivery/'runtime-fixture.json')
            assert report['index_sha256']==sha(delivery/'shared/index.json')
            assert len(report['shots'])==2*len(native[0]['animations'])
            samples+=expected;files.extend([path,WORK/('ui-'+name+'-'+renderer+'.log')])
            files.extend(path.parent/p for p in report['shots'])
        entries[name]={'runtime_approved':True,'bundle_size_bytes':asset['size_bytes'],
            'pixel_exact_frames':pixels['exact_frames'],'battle_views':views,'battle_appearance_samples':samples,
            'variants':{r['variant']:r['runtime_sha256'] for r in native}}
        if name.startswith('cramorant-'):
            parity_path=WORK/'preview-parity'/name/'report.json'
            parity=read(parity_path)
            assert parity['complete'] and parity['pixel_exact_frames']==20 and parity['renderer']=='mobile'
            for check in parity['records']:
                row=next(r for r in native if r['species'].replace('-shiny','@shiny')==check['identity'])
                assert check['source_sha256']==row['preview_runtime_sha256']
                assert check['candidate_sha256']==row['runtime_sha256']
                for frame,digest in check['candidate']['frames'].items():
                    assert digest in (check['source']['frames'][frame],check['repeat_source']['frames'][frame])
            entries[name]['approved_preview_pixel_exact_frames']=parity['pixel_exact_frames']
            files.extend([parity_path,WORK/('preview-parity-'+name+'.log')])
            for check in parity['records']:
                for kind in ('source','repeat_source','candidate'):
                    files.extend(Path(p) for p in check[kind]['paths'])
        assets.append(asset);fixtures[name]=fixture
    previous=read(HERE/'remaining_forms_repair_result.json')
    remaining=sorted(r['species'] for r in previous['entries'] if not r['runtime_approved'] and r['species'] not in NAMES+['zygarde-10'])
    assert len(remaining)==21
    receipt={'schema':1,'runtime_approved':True,'release_approved':False,'published':False,
        'admitted_registry_check_passed':False,'forms_admitted':14,'remaining_forms':len(remaining),
        'remaining_species':remaining,'restored_forms_across_original_229':229-len(remaining),
        'platform':'Linux Godot 4.6.2 Compatibility and Mobile; no physical Android/Windows/macOS tests.',
        'scope':'Accepted reconstructed colours, static form visibility, closed source eye cells and authored Cramorant sleep. No original-engine parity or form-transition claim.',
        'bundle_size_bytes':sum(a['size_bytes'] for a in assets),'entries':entries,
        'previous_result_sha256':sha(HERE/'zygarde_battle_qualification.json'),
        'preview_receipt_sha256':sha(HERE/'remaining_forms_preview_result.json'),
        'sleep_receipt_sha256':sha(HERE/'remaining_forms_sleep_result.json'),
        'evidence_sha256':{str(p.relative_to(WORK)):sha(p) for p in files}}
    return assets,fixtures,receipt


def save(registry):
    data=(json.dumps(registry,indent='\t',allow_nan=False)+'\n').encode()
    GAME.write_bytes(data);LAUNCHER.write_bytes(data)


def admit():
    assets,fixtures,receipt=qualify()
    assert GAME.read_bytes()==LAUNCHER.read_bytes()
    registry=read(GAME)
    before=json.loads(subprocess.check_output(['git','show',BASE+':scripts/battle/battle_ui/reviewed_model_catalog.json'],cwd=ROOT))
    assert registry==before,'Catalog changed since task base; review before admission'
    receipt['previous_registry']={k+'_sha256':canonical(before[k]) for k in ('models','profiles')}
    for name,fixture in fixtures.items():
        profile=copy.deepcopy(fixture['profiles'][name+'-normal']);profile['motion'].pop('sha256')
        other=copy.deepcopy(fixture['profiles'][name+'-shiny']);other['motion'].pop('sha256')
        assert profile==other
        assert name not in registry['profiles'] and not any(k in registry['models'] for k in fixture['models'])
        registry['profiles'][name]=profile
        registry['models'].update({k:dict(v,profile=name) for k,v in fixture['models'].items()})
    write(INDEX,dict(schema=1,kind='pokeaether-optional-asset-index',catalog_revision='remaining-fourteen-local-v1',
        runtime_contract={'pokemon_3d':2,'godot':'4.6'},assets=assets))
    receipt['bundle_index_sha256']=sha(INDEX)
    write(RECEIPT,receipt)
    registry['remaining_fourteen_qualification_sha256']=sha(RECEIPT);save(registry)
    print('FOURTEEN_LOCAL_ADMISSION_PENDING_FINAL_CHECK',flush=True)


def finalize():
    receipt=read(RECEIPT)
    assets,_,_=qualify()
    assert read(INDEX)['assets']==assets and sha(INDEX)==receipt['bundle_index_sha256']
    def check(name):
        env=dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(WORK/'delivery'/name),POKEAETHER_FORM_BATCH_SHARED='1',
            POKEAETHER_FORM_BATCH_ADMITTED='1',POKEAETHER_CATALOG_WORK_ROOT=str(WORK))
        label='admitted-check-'+name
        run(label,['--path',str(ROOT),'--rendering-method','mobile',
            '--script','res://tests/battle_3d_alternate_form_check.gd'],env)
        assert 'FORM_BATCH_RUNTIME_OK' in (WORK/(label+'.log')).read_text()
        print('ADMITTED_CHECK_OK',name,flush=True)
        return label+'.log',sha(WORK/(label+'.log'))
    with ThreadPoolExecutor(max_workers=2) as pool:
        receipt['evidence_sha256'].update(dict(pool.map(check,NAMES)))
    receipt['admitted_registry_check_passed']=True
    paths=[HERE/'remaining_fourteen_battle.py',Path(__file__),ROOT/'tests/battle_3d_fourteen_check.gd',
        HERE/'zygarde_battle_prepare.gd',HERE/'remaining_fourteen_prepare.gd',HERE/'remaining_cramorant_eyes.gd',HERE/'remaining_cramorant_render.gd',HERE/'alternate_forms_delivery.py',HERE/'alternate_forms_recovery_battle.py',
        HERE/'model_pair_texture_probe.gd',ROOT/'tests/battle_3d_alternate_form_check.gd',
        ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.gd',ROOT/'scripts/battle/battle_ui/material_effect.gd']
    receipt['code_sha256']={str(p.relative_to(ROOT)):sha(p) for p in paths}
    write(RECEIPT,receipt)
    registry=read(GAME);registry['remaining_fourteen_qualification_sha256']=sha(RECEIPT);save(registry)
    print('FOURTEEN_LOCAL_QUALIFIED remaining=21 published=false',flush=True)


if __name__=='__main__':
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=['admit','finalize']);args=parser.parse_args()
    globals()[args.phase]()
