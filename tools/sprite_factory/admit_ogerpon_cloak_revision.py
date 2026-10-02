"""Prepare/admit three approved Ogerpon material-only bundle revisions locally."""
import argparse
import copy
import json
from pathlib import Path
import sys

from catalog_ogerpon_form_palette_review import ROOT, HERE, OLD, read, sha, write
from phase5_variant_parity import compare
sys.path.insert(0, str(ROOT/'tools'))
from package_optional_3d_bundle_prototype import build, encoded

WORK = ROOT/'.tmp/ogerpon-cloak-colors-v6'
APPROVED = WORK/'approved'
CHECKPOINT = HERE/'catalog_ogerpon_form_palette_checkpoint.json'
NAMES = ('ogerpon-wellspring', 'ogerpon-hearthflame', 'ogerpon-cornerstone')
REGISTRY = ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
LAUNCHER = ROOT/'launcher/data/reviewed_model_catalog.json'
QUALIFICATION = HERE/'catalog_ogerpon_cloak_revision_qualification.json'


def prepare():
    checkpoint = read(CHECKPOINT)
    assert checkpoint['user_approval'] == 'Oke, akkoord' and checkpoint['visual_approved']
    assert REGISTRY.read_bytes() == LAUNCHER.read_bytes()
    registry = read(REGISTRY)
    runtime = {r['species']:r for r in read(WORK/'runtime/report.json')}
    approvals = {(r['species'],r['variant']):r for r in checkpoint['entries']}
    old_raw = {r['species']:r for r in read(OLD/'runtime-v6/report.json')}
    old_final = read(OLD/'approved-final/runtime-catalog-final.json')
    catalog, fixture, parity, previous = [], {'models':{},'profiles':{}}, [], {'models':{},'profiles':{}}
    for name in NAMES:
        previous['profiles'][name] = registry['profiles'][name]
        for variant in ('normal','shiny'):
            raw_key = name+('-shiny' if variant=='shiny' else '')
            identity = name+('@shiny' if variant=='shiny' else '')
            row = copy.deepcopy(runtime[raw_key])
            prior = next(r for r in old_final if r['species']==name and r['variant']==variant)
            assert registry['models'][identity]['sha256'] == prior['runtime_sha256']
            assert sha(row['runtime_path']) == row['runtime_sha256']
            assert sha(row['path']) == row['glb_sha256'] == approvals[name,variant]['glb_sha256']
            compare(old_raw[raw_key]['path'], row['path'])
            assert row['action_timing'] == prior['action_timing']
            previous['models'][identity] = registry['models'][identity]
            profile = copy.deepcopy(registry['profiles'][name])
            profile['motion']['sha256'] = row['runtime_sha256']
            fixture['profiles'][name+'-'+variant] = profile
            fixture['models'][identity] = {'sha256':row['runtime_sha256'],
                'glb_sha256':row['glb_sha256'],'profile':name+'-'+variant}
            row.update(species=name, variant=variant, placement=profile['placement'])
            catalog.append(row)
            parity.extend([dict(old_raw[raw_key],species=raw_key),
                           dict(runtime[raw_key],species=raw_key+'@shiny')])
    APPROVED.mkdir(exist_ok=False)
    write(APPROVED/'runtime-catalog-final.json',catalog)
    write(APPROVED/'runtime-fixture.json',fixture)
    write(APPROVED/'previous-registry.json',previous)
    write(APPROVED/'parity-input.json',parity)
    hashes = {k:r['sha256'] for k,r in fixture['models'].items()}
    build(APPROVED/'runtime-catalog-final.json', APPROVED/'bundles', version=2,
          revision='ogerpon-native-cloak-colours-v2',species_set=NAMES,
          dex={n:1017 for n in NAMES},candidate_hashes=hashes)
    print('OGERPON_REVISION_PREPARED pairs=3 bundles=3 version=2')


def admit():
    checkpoint = read(CHECKPOINT)
    assert checkpoint['visual_approved'] and checkpoint['user_approval']=='Oke, akkoord'
    rows = read(APPROVED/'runtime-catalog-final.json')
    installed = read(APPROVED/'installed/installed-catalog.json')
    assert len(rows)==len(installed)==6
    key = lambda r:(r['species'],r['variant'])
    assert {key(r):r['runtime_sha256'] for r in rows} == {key(r):r['runtime_sha256'] for r in installed}
    for row in rows+installed:assert sha(row['runtime_path'])==row['runtime_sha256']
    proof = read(APPROVED/'runtime-parity.json')
    assert proof['report_sha256']==sha(APPROVED/'parity-input.json') and len(proof['pairs'])==6
    for pair in proof['pairs']:
        expected=next(r for r in rows if r['species']+('-shiny' if r['variant']=='shiny' else '')==pair['species'])
        assert pair['shiny_runtime_sha256']==expected['runtime_sha256']
    for path,marker in [('install.log','REMAINING_144_BUNDLES_OK bundles=3 scenes=6'),
                        ('update.log','OGERPON_V1_V2_UPDATE_OK'),
                        ('battle-check.log','OGERPON_CLOAK_BATTLE_OK')]:
        log=(APPROVED/path).read_text();assert marker in log and 'ERROR:' not in log
    index = read(APPROVED/'bundles/asset-index.json')
    assert len(index['assets'])==3
    for asset in index['assets']:
        archive=APPROVED/'bundles'/Path(asset['object_key']).name
        assert asset['version']==2 and sha(archive)==asset['sha256'] and archive.stat().st_size==asset['size_bytes']
    previous = read(APPROVED/'previous-registry.json')
    fixture = read(APPROVED/'runtime-fixture.json')
    assert REGISTRY.read_bytes()==LAUNCHER.read_bytes()
    registry = read(REGISTRY)
    before = len(registry['models'])
    for name in NAMES:
        assert registry['profiles'][name]==previous['profiles'][name]
        # Texture-only changes reuse the exact approved clocks, placement,
        # clearance, bounds and attack mappings; v1 scenes remain supported.
        for variant in ('normal','shiny'):
            identity=name+('@shiny' if variant=='shiny' else '')
            old=previous['models'][identity]
            assert registry['models'][identity]==old
            registry['models'][identity]={**old,**fixture['models'][identity], 'profile':name,
                'previous_sha256':sorted(set(old.get('previous_sha256',[])+[old['sha256']]))}
    assert len(registry['models'])==before
    evidence = [CHECKPOINT, Path(__file__), HERE/'scvi_form_material.py',
                HERE/'catalog_animation_material_worker.py', HERE/'catalog_ogerpon_form_palette_review.py',
                ROOT/'tests/battle_3d_ogerpon_cloak_revision_check.gd',
                ROOT/'tests/battle_3d_ogerpon_bundle_update_check.gd']
    evidence += [APPROVED/p for p in ('runtime-catalog-final.json','runtime-fixture.json',
        'previous-registry.json','parity-input.json','runtime-parity.json','bundles/asset-index.json',
        'installed/installed-catalog.json','install.log','update.log','battle-check.log')]
    evidence += [WORK/p for p in ('captures/godot-review.json','maskless/godot-review.json')]
    receipt={'schema':1,'date':'2026-10-02','species':list(NAMES),'models':6,'appearance_approved':True,
        'battle_approved':True,'runtime_approved':True,'published':False,'release_approved':False,
        'bundle_index':index,'bundle_size_bytes':sum(a['size_bytes'] for a in index['assets']),
        'evidence_sha256':{str(p.relative_to(ROOT)):sha(p) for p in evidence},
        'previous_qualification_sha256':sha(HERE/'catalog_battle_forms_first_five_bundle_qualification.json'),
        'scope':'Native mesh-bound TRMMT cloak palettes; exact previous/new scene geometry/skin/motion parity; '
                'approved profiles preserved; six standalone pose checks; native shiny faces confirmed; '
                'local fresh install and v1-to-v2 update/no-op/restart; real battle normal/shiny loading and attacks. '
                'Previous geometry, camera clearance and performance qualifications reused for material-only revision.',
        'remaining':['R2 publication','release content-index activation','release certification/publication']}
    assert not QUALIFICATION.exists()
    QUALIFICATION.write_bytes(encoded(receipt))
    registry['ogerpon_cloak_revision_qualification_sha256']=sha(QUALIFICATION)
    REGISTRY.write_bytes(encoded(registry));LAUNCHER.write_bytes(REGISTRY.read_bytes())
    (ROOT/'release/approved_3d_ogerpon_cloak_v2_index.json').write_bytes(encoded(index))
    print('OGERPON_CLOAK_ADMITTED pairs=3 bundles=3 version=2 old_hashes_retained=true published=false')


def finalize():
    log = APPROVED/'registry-check.log'
    assert 'OGERPON_REGISTRY_REVISION_OK models=6' in log.read_text() and 'ERROR:' not in log.read_text()
    checkpoint = read(CHECKPOINT)
    assert checkpoint['visual_approved'] and checkpoint['user_approval']=='Oke, akkoord'
    checkpoint.update(status='locally_qualified_bundles_v2_pending_publication',runtime_approved=True)
    write(CHECKPOINT, checkpoint)
    receipt = read(QUALIFICATION)
    receipt['admitted_registry_check_passed']=True
    for path in (CHECKPOINT, Path(__file__), log, ROOT/'tests/battle_3d_ogerpon_registry_revision_check.gd'):
        receipt['evidence_sha256'][str(path.relative_to(ROOT))]=sha(path)
    QUALIFICATION.write_bytes(encoded(receipt))
    assert REGISTRY.read_bytes()==LAUNCHER.read_bytes()
    registry=read(REGISTRY)
    registry['ogerpon_cloak_revision_qualification_sha256']=sha(QUALIFICATION)
    REGISTRY.write_bytes(encoded(registry));LAUNCHER.write_bytes(REGISTRY.read_bytes())
    print('OGERPON_CLOAK_FINALIZED registry_check=true published=false')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=('prepare','admit','finalize'))
    {'prepare':prepare,'admit':admit,'finalize':finalize}[p.parse_args().phase]()
