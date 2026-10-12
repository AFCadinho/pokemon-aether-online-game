"""Admit only individually qualified pairs; never select or publish a release."""
import argparse
import copy
import json
import os
from pathlib import Path
import subprocess
from alternate_forms_recovery import ROOT, WORK, INTAKE, read, write, sha

RECEIPT = Path(__file__).with_name('alternate_forms_recovery_qualification.json')
INDEX = ROOT/'release/approved_3d_alternate_forms_recovery_index.json'
GAME = ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
LAUNCHER = ROOT/'launcher/data/reviewed_model_catalog.json'


def checked(path, expected):
    if sha(path) != expected:
        raise ValueError('Evidence changed: '+str(path))
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
        expected_changes=['visibility_sampling']+(['opaque_surface_order'] if name.startswith('sawsbuck-') else [])
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
    evidence.extend(recovery_evidence(name))
    return asset, fixture, {'species':name, 'pixel_exact_frames':pixels['exact_frames'],
        'transition_switches':sum(r['switches'] for r in transitions['entries']),
        'source_visibility_samples':sum(r['source_visibility_samples'] for r in transitions['entries']),
        'battle_views':sum(len(r['shots']) for r in measured['entries'] if 'clips' in r),
        'evidence_sha256':{str(p.relative_to(WORK)):sha(p) for p in evidence}}


def recovery_evidence(name):
    row, = [r for r in read(INTAKE)['entries'] if r['species']==name]
    if 'source' in row:
        assert sha(row['source']['path']) == row['source']['sha256']
    else:
        from alternate_forms_batch import SOURCE
        for record in [*row.get('scvi_files',[]),*row.get('selected_motion_files',[])]:
            assert sha(SOURCE/record['path']) == record['sha256']
    roots = ['archive-bake','export','material-palettes','size-proofs']
    paths=[]
    for root in roots:
        directory=WORK/root/name
        if directory.is_dir():
            paths.extend(p for p in directory.rglob('*.json') if p.name in
                         ('bake.json','binding-proof.json','material-proof.json','mesh-palette-proof.json','export.json','job.json'))
    size=WORK/'size-proofs'/(name+'.json')
    if size.exists():
        proof=read(size);assert sha(proof['path'])==proof['sha256'];paths.append(size)
    if row['route']=='archive-unown':
        proof=read(WORK/'archive-bake'/name/'bake.json')
        worker=('alternate_forms_recovery_question_bake.py' if name=='unown-question' else
                'alternate_forms_recovery_unown_u_bake.py' if name in ('unown-i','unown-u') else
                'alternate_forms_recovery_shared_palette_bake.py' if 'palette_reference_sha256' in proof else
                'alternate_forms_recovery_archive_bake.py')
        assert proof['worker_sha256']==sha(Path(__file__).with_name(worker))
        assert proof['source_sha256']==row['source']['sha256']
        for texture in proof['textures']:
            assert sha(texture['path'])==texture['sha256']
    return paths


def save_registry(registry):
    data = (json.dumps(registry, indent='\t', sort_keys=False, allow_nan=False)+'\n').encode()
    GAME.write_bytes(data)
    LAUNCHER.write_bytes(data)


def admit():
    visual = read(WORK/'visual-review.json')
    source = read(WORK/'source-contract-current.json')
    assert source['complete']
    contracts = {r['species']:r for r in source['entries']}
    names, held = [], {}
    for name in sorted(visual['battle']):
        state = read(WORK/'status/delivery'/(name+'.json'))
        if state['status'] == 'delivery_checked':
            names.append(name)
        else:
            assert state['status'] == 'held' and state.get('reason')
            held[name] = state['reason']
    assert names and GAME.read_bytes() == LAUNCHER.read_bytes()
    registry = read(GAME)
    results = [qualify(n, visual, contracts) for n in names] # Validate all before mutation.
    assets, receipts = [], []
    for asset, fixture, record in results:
        name = record['species']
        profile = copy.deepcopy(fixture['profiles'][name+'-normal'])
        profile['motion'].pop('sha256')
        assert name not in registry['profiles']
        registry['profiles'][name] = profile
        for identity, model in fixture['models'].items():
            assert identity not in registry['models']
            registry['models'][identity] = dict(model, profile=name)
        assets.append(asset)
        receipts.append(record)
    index = {'schema':1, 'kind':'pokeaether-optional-asset-index',
        'catalog_revision':'alternate-forms-recovery-local-v1', 'runtime_contract':{'pokemon_3d':2,'godot':'4.6'}, 'assets':assets}
    write(INDEX,index)
    receipt = {'schema':1,'runtime_approved':True,'release_approved':False,'published':False,
        'admitted_registry_check_passed':False,'forms':names,'models':2*len(names),
        'scope':'Linux Godot 4.6.2; native appearance, transitions, 120 Hz floor clearance, both cameras, Mobile pair packs and actual game stages',
        'previous_qualification_sha256':sha(Path(__file__).with_name('alternate_forms_qualification.json')),
        'sharing':'Lossless Zstd and shared pair textures; independent scenes retain animated eye materials',
        'source_intake_sha256':sha(INTAKE),'bundle_index_sha256':sha(INDEX),
        'additional_source_evidence_sha256':{str(INTAKE.relative_to(ROOT)):sha(INTAKE)},
        'delivery_holds':held,
        'bundle_size_bytes':sum(a['size_bytes'] for a in assets),
        'native_scene_bytes':sum(v['cache_source_bytes'] for a in assets for v in a['appearances']),
        'pixel_exact_frames':sum(r['pixel_exact_frames'] for r in receipts),
        'visual_review_sha256':sha(WORK/'visual-review.json'),
        'source_contract_sha256':sha(WORK/'source-contract-current.json'),
        'entries':receipts,'remaining':['Include in a selected model release','Release certification and publication']}
    write(RECEIPT,receipt)
    registry['alternate_forms_recovery_qualification_sha256'] = sha(RECEIPT)
    save_registry(registry)
    print('ALTERNATE_FORMS_ADMITTED',len(names),'pairs; published=false')


def finalize():
    receipt = read(RECEIPT)
    command = [str(ROOT.parents[2]/'ops/worktrees/slot-env'),ROOT.parent.name,'--','godot',
        '--path',str(ROOT),'--rendering-method','mobile','--script','res://tests/battle_3d_alternate_form_check.gd']
    def check_form(name):
        directory = WORK/'delivery'/name
        log = directory/'admitted-check.log'
        input_pin = directory/'admitted-input.json'
        registry = read(GAME)
        inputs = {'test_sha256':sha(ROOT/'tests/battle_3d_alternate_form_check.gd'),
            'fixture_sha256':sha(directory/'runtime-fixture.json'),
            'index_sha256':sha(directory/'shared/index.json'),
            'models':{k:registry['models'][k] for k in (name,name+'@shiny')},
            'profile':registry['profiles'][name]}
        reusable = input_pin.exists() and read(input_pin) == inputs
        if not reusable or not log.exists() or 'FORM_BATCH_RUNTIME_OK' not in log.read_text():
            env = dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(directory),POKEAETHER_FORM_BATCH_SHARED='1',
                POKEAETHER_FORM_BATCH_ADMITTED='1',POKEAETHER_CATALOG_WORK_ROOT=str(WORK))
            with log.open('w') as handle:
                # Separate userdata within the assigned slot: independent
                # processes must not publish the same runtime-catalog.json.
                data = ROOT.parent/'.runtime/alternate-forms'/name/'xdg-data'
                data.mkdir(parents=True,exist_ok=True)
                isolated = command[:3]+['env','XDG_DATA_HOME='+str(data)]+command[3:]
                subprocess.run(isolated,env=env,stdout=handle,stderr=subprocess.STDOUT,check=True,timeout=600)
        assert 'FORM_BATCH_RUNTIME_OK' in log.read_text() and 'ERROR:' not in log.read_text()
        write(input_pin,inputs)
        print('ADMITTED_CHECK',name,flush=True)
        return name, sha(log)
    # Real desktop windows share one GPU/compositor. Run this final drawn-frame
    # check serially so covered competing test windows cannot stall readiness.
    for form in receipt['forms']:
        name, digest = check_form(form)
        next(r for r in receipt['entries'] if r['species']==name)['admitted_check_sha256'] = digest
    visual = checked(WORK/'visual-review.json', receipt['visual_review_sha256'])
    source = checked(WORK/'source-contract-current.json', receipt['source_contract_sha256'])
    contracts = {r['species']:r for r in source['entries']}
    approved = checked(INDEX, receipt['bundle_index_sha256'])
    approved_assets = {a['species_id']:a for a in approved['assets']}
    for position, old in enumerate(receipt['entries']):
        asset, _, record = qualify(old['species'], visual, contracts)
        assert asset == approved_assets[old['species']]
        record['admitted_check_sha256'] = old['admitted_check_sha256']
        receipt['entries'][position] = record
    receipt['admitted_registry_check_passed'] = True
    paths = [*Path(__file__).parent.glob('alternate_forms_*.py'),*Path(__file__).parent.glob('alternate_forms_*.gd'),
        ROOT/'tests/battle_3d_alternate_form_check.gd', ROOT/'scripts/battle/animations/source_visibility_pack.gd',
        ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.gd',
        Path(__file__).with_name('catalog_galar_birds_candidates.py'),
        Path(__file__).with_name('audit_alternate_model_coverage.py')]
    receipt['code_sha256'] = {str(p.relative_to(ROOT)):sha(p) for p in sorted(paths)}
    write(RECEIPT,receipt)
    assert GAME.read_bytes() == LAUNCHER.read_bytes()
    registry = read(GAME)
    registry['alternate_forms_recovery_qualification_sha256'] = sha(RECEIPT)
    save_registry(registry)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase',choices=('admit','finalize'))
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    globals()[parser.parse_args().phase]()
