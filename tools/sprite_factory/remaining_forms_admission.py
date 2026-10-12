"""Admit new qualified pairs without rewriting historical source approvals."""
import argparse
import copy
import os
import subprocess
from pathlib import Path
from remaining_forms_repair import ROOT, HERE, WORK, INTAKE, read, write, sha, context

RECEIPT = HERE/'remaining_forms_repair_qualification.json'
INDEX = ROOT/'release/approved_3d_remaining_forms_index.json'
GAME = ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
LAUNCHER = ROOT/'launcher/data/reviewed_model_catalog.json'


def source_evidence(name):
    paths = [WORK/'status/material'/(name+'.json')]
    if name in ('poltchageist-artisan','sinistcha-masterpiece'):
        bound = read(WORK/'export'/name/'binding.json')
        assert bound['bones_and_bind_matrices_exact']
        assert sha(WORK/'bound'/name/'prepared.blend') == bound['prepared_sha256']
        assert sha(HERE/'remaining_forms_tea_worker.py') == bound['worker_sha256']
        for path,digest in bound['source_files'].items(): assert sha(path) == digest
        for variant in ('normal','shiny'):
            proof = WORK/'materials'/name/variant/'proof.json'; paths.append(proof)
            assert read(proof)['binding_sha256'] == sha(WORK/'export'/name/'binding.json')
            assert read(proof)['rest']['native_geometry_and_clips_unchanged']
        paths += [WORK/'export'/name/'binding.json', WORK/'export'/name/'export.json',
                  WORK/'material-sources'/name/'source-pins.json']
    if name in ('rotom-fan','xerneas-neutral'):
        paths += [WORK/'renderer-sources'/(name+'.json'), WORK/'export'/name/'export.json',
                  WORK/'material-sources'/name/'source-pins.json']
        source=read(WORK/'renderer-sources'/(name+'.json'))
        from catalog_galar_birds_candidates import verify
        from alternate_forms_batch import SOURCE
        verify(source,SOURCE)
    return paths


def checked(path, expected):
    assert sha(path)==expected, str(path)
    return read(path)


def qualify(name, visual, contracts):
    job = WORK/'runtime-jobs'/name
    delivery = WORK/'delivery'/name
    battle = WORK/'battle'/name
    state = read(WORK/'status/delivery'/(name+'.json'))
    assert state['status'] == 'delivery_checked'
    index = checked(delivery/'shared/index.json', state['index_sha256'])
    pixels = checked(delivery/'shared/pixel-comparison.json', state['pixel_report_sha256'])
    assert pixels['complete'] and len(pixels['models']) == 2
    assert all(r['pixels_exact'] and r['frames'] for r in pixels['models'])
    assert sha(delivery/'runtime-check.log') == state['runtime_check_sha256']
    log = (delivery/'runtime-check.log').read_text()
    assert 'FORM_BATCH_RUNTIME_OK' in log and 'ERROR:' not in log
    appearance = read(WORK/'appearance'/name/'godot-review.json')
    assert len(appearance['entries']) == 2
    for row in appearance['entries']:
        accepted = visual['appearances'][row['species']]
        assert accepted['appearance_approved'] and not row['errors']
        checked(WORK/'appearance'/name/'godot-review.json', accepted['report_sha256'])
    battle_state = read(WORK/'status/battle'/(name+'.json'))
    assert battle_state['status'] == 'measured'
    measured = checked(battle/'final/battle-review.json', battle_state['battle_report_sha256'])
    checked(battle/'placement.json', battle_state['placement_sha256'])
    battle_visual = visual['battle'][name]
    assert battle_visual['approved'] and battle_visual['report_sha256'] == sha(battle/'final/battle-review.json')
    native = read(job/'native/report.json')
    transitions = read(job/'transitions.json')
    assert not transitions['failures'] and len(transitions['entries']) == 2
    assert measured['complete']
    for row in native:
        checked_sha = row['runtime_sha256']
        assert sha(row['runtime_path']) == checked_sha and sha(row['path']) == row['glb_sha256']
        assert contracts[row['species']]['runtime_sha256'] == checked_sha
        assert contracts[row['species']]['declared_changes_only']
        expected_changes=['visibility_sampling']+(['independent_layer_sampling'] if name=='rotom-fan' else [])
        assert contracts[row['species']]['declared_changes']==expected_changes
        assert next(r for r in transitions['entries'] if r['species']==row['species'])['runtime_sha256'] == checked_sha
        m = next(r for r in measured['entries'] if r['species']==row['species'])
        assert m['glb_sha256'] == row['glb_sha256']
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
        assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values()) >= .025-1e-5
    asset, = index['assets']
    assert asset['species_id'] == name and len(asset['appearances']) == 2
    comparisons = {r['identity']:r for r in pixels['models']}
    assert set(comparisons) == {a['runtime_identity'] for a in asset['appearances']}
    for appearance in asset['appearances']:
        compared = comparisons[appearance['runtime_identity']]
        assert compared['source_sha256'] == appearance['source_sha256']
        assert compared['candidate_sha256'] == appearance['runtime_sha256']
    validation = read(delivery/'shared/validate-input.json')
    assert validation['jobs'][0]['packs']['shared']['asset'] == asset
    pack = delivery/'shared/packs'/Path(asset['object_key']).name
    assert sha(pack) == asset['sha256'] and pack.stat().st_size == asset['size_bytes']
    fixture = read(delivery/'runtime-fixture.json')
    for row in native:
        identity = row['species'].removesuffix('-shiny')+('@shiny' if row['species'].endswith('-shiny') else '')
        assert fixture['models'][identity]['sha256'] == row['runtime_sha256']
        assert next(a for a in asset['appearances'] if a['runtime_identity']==identity)['source_sha256'] == row['runtime_sha256']
    evidence = [job/'native/report.json', job/'transitions.json', WORK/'appearance'/name/'godot-review.json',
        battle/'final/battle-review.json', battle/'placement.json', delivery/'runtime-fixture.json',
        delivery/'shared/index.json', delivery/'shared/pixel-comparison.json',
        delivery/'shared/validated/receipts.jsonl', delivery/'shared/validate-input.json',
        delivery/'shared/render-qualified/report.json', delivery/'runtime-check.log']
    palette = WORK/'material-palettes'/name/'palette-proof.json'
    if palette.exists():
        from alternate_forms_palettes import validate_bindings
        from catalog_remaining_eye_bake import chunks
        document, _ = chunks(WORK/'export'/name/'model.glb')
        for proof in read(palette):
            validate_bindings(document, proof['bindings'])
        evidence.append(palette)
    evidence.extend(source_evidence(name))
    return asset, fixture, {'species':name, 'pixel_exact_frames':pixels['exact_frames'],
        'transition_switches':sum(r['switches'] for r in transitions['entries']),
        'source_visibility_samples':sum(r['source_visibility_samples'] for r in transitions['entries']),
        'battle_views':sum(len(r['shots']) for r in measured['entries'] if 'clips' in r),
        'evidence_sha256':{str(p.relative_to(WORK)):sha(p) for p in evidence}}



def verifier():
    context(None)
    import alternate_forms_recovery_admission as v
    v.WORK=WORK; v.INTAKE=INTAKE; v.recovery_evidence=source_evidence; v.qualify=qualify
    return v


def save_registry(registry):
    data=(__import__('json').dumps(registry,indent='\t',allow_nan=False)+'\n').encode()
    GAME.write_bytes(data); LAUNCHER.write_bytes(data)


def admit():
    visual=read(WORK/'visual-review.json'); contracts=read(WORK/'source-contract-current.json')
    assert contracts['complete'] and GAME.read_bytes()==LAUNCHER.read_bytes()
    v=verifier(); by_name={r['species']:r for r in contracts['entries']}
    results=[v.qualify(n,visual,by_name) for n in sorted(visual['battle'])]
    registry=read(GAME); assets=[]; records=[]
    previous=read(RECEIPT)['forms'] if RECEIPT.exists() else []
    for asset,fixture,record in results:
        name=record['species']; profile=copy.deepcopy(fixture['profiles'][name+'-normal']);profile['motion'].pop('sha256')
        assert name in previous or name not in registry['profiles']
        registry['profiles'][name]=profile
        for identity,model in fixture['models'].items():
            assert name in previous or identity not in registry['models']
            registry['models'][identity]=dict(model,profile=name)
        assets.append(asset);records.append(record)
    write(INDEX,{'schema':1,'kind':'pokeaether-optional-asset-index','catalog_revision':'remaining-forms-local-v1',
                 'runtime_contract':{'pokemon_3d':2,'godot':'4.6'},'assets':assets})
    receipt={'schema':1,'runtime_approved':True,'release_approved':False,'published':False,
             'forms':[r['species'] for r in records],'models':2*len(records),
             'admitted_registry_check_passed':False,'source_intake_sha256':sha(INTAKE),
             'bundle_index_sha256':sha(INDEX),'visual_review_sha256':sha(WORK/'visual-review.json'),
             'source_contract_sha256':sha(WORK/'source-contract-current.json'),'entries':records,
             'bundle_size_bytes':sum(a['size_bytes'] for a in assets),
             'native_scene_bytes':sum(v['cache_source_bytes'] for a in assets for v in a['appearances']),
             'pixel_exact_frames':sum(r['pixel_exact_frames'] for r in records),
             'historical_code_sha256':{p:h for p,h in read(HERE/'alternate_forms_recovery_qualification.json')['code_sha256'].items()
                                      if p=='scripts/battle/battle_ui/reviewed_model_catalog.gd'},
             'scope':'Linux Godot 4.6.2; source, poses, transitions, battle placement, Mobile pixels and actual game',
             'remaining':['Release certification and publication']}
    write(RECEIPT,receipt);registry['remaining_forms_repair_qualification_sha256']=sha(RECEIPT);save_registry(registry)
    print('REMAINING_FORMS_ADMITTED',len(records), 'pairs; published=false')


def finalize():
    receipt=read(RECEIPT)
    visual=checked(WORK/'visual-review.json',receipt['visual_review_sha256'])
    contracts=checked(WORK/'source-contract-current.json',receipt['source_contract_sha256'])
    approved=checked(INDEX,receipt['bundle_index_sha256'])
    for name in receipt['forms']:
        asset,_,_=qualify(name,visual,{r['species']:r for r in contracts['entries']})
        assert asset==next(a for a in approved['assets'] if a['species_id']==name)
    for row in receipt['entries']:
        name=row['species']; directory=WORK/'delivery'/name
        data=ROOT.parent/'.runtime/remaining-admitted'/name/'xdg-data';data.mkdir(parents=True,exist_ok=True)
        command=[str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--','env','XDG_DATA_HOME='+str(data),
                 'godot','--path',str(ROOT),'--rendering-method','mobile','--script','res://tests/battle_3d_alternate_form_check.gd']
        env=dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(directory),POKEAETHER_FORM_BATCH_SHARED='1',
                 POKEAETHER_FORM_BATCH_ADMITTED='1',POKEAETHER_CATALOG_WORK_ROOT=str(WORK))
        log=directory/'admitted-check.log'
        with log.open('w') as handle: subprocess.run(command,env=env,stdout=handle,stderr=subprocess.STDOUT,check=True,timeout=600)
        assert 'FORM_BATCH_RUNTIME_OK' in log.read_text() and 'ERROR:' not in log.read_text()
        row['admitted_check_sha256']=sha(log)
        print('REMAINING_ADMITTED_CHECK',name,flush=True)
    aliases=read(WORK/'alias-runtime/report.json');assert aliases['complete'] and aliases['forms']==13
    assert aliases['input_sha256']==sha(WORK/'alias-input.json')
    receipt['shared_forms']={'forms':[r['species'] for r in aliases['entries']], 'additional_model_bytes':0,
                            'report_sha256':sha(WORK/'alias-runtime/report.json'),'input_sha256':sha(WORK/'alias-input.json'),
                            'visual_contact_sha256':sha(WORK/'alias-contacts.jpg'),'appearances':26,'arena_views':26}
    paths=[*HERE.glob('remaining_forms_*.py'),*HERE.glob('remaining_forms_*.gd'),
           ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.gd',ROOT/'scripts/battle/battle_ui/shared_form_models.gd',
           ROOT/'scripts/battle/battle_ui/model_form_dependencies.gd',ROOT/'scripts/services/model_pair_pilot.gd',
           ROOT/'scripts/battle/battle_ui/material_effect.gd', ROOT/'scripts/battle/battle_ui/material_layered_static.gd',
           ROOT/'scripts/battle/battle_ui/material_effect_layered_static.gdshader',
           ROOT/'tests/layered_static_material_check.gd',
           ROOT/'tests/shared_form_models_check.gd',ROOT/'tests/shared_form_models_runtime_check.gd']
    receipt['code_sha256']={str(p.relative_to(ROOT)):sha(p) for p in sorted(paths)}
    receipt['admitted_registry_check_passed']=True
    write(RECEIPT,receipt);registry=read(GAME);registry['remaining_forms_repair_qualification_sha256']=sha(RECEIPT);save_registry(registry)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['admit','finalize']);args=p.parse_args()
    assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
    globals()[args.phase]()
