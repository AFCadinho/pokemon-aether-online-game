"""Bind approved v6 form scenes to measured profiles; prepare local bundles."""
import copy
import hashlib
import json
import math
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / '.tmp/battle-forms-first-five-v1'
WORK = BASE / 'approved-final'
sys.path.insert(0, str(ROOT / 'tools'))
from package_optional_3d_bundle_prototype import build, encoded

def read(path): return json.loads(Path(path).read_text())
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    checkpoint = read(HERE / 'catalog_battle_forms_first_five_checkpoint.json')
    assert checkpoint['visual_approved'] and len(checkpoint['entries']) == 10
    for name, digest in checkpoint['reports'].items(): assert sha(BASE / name) == digest
    raw = {r['species']:r for r in read(BASE / 'runtime-v6/report.json')}
    measured = {r['species']:r for r in read(BASE / 'battle-v6/status.json')['entries']}
    rows, fixture = [], {'models':{},'profiles':{}}
    for approval in checkpoint['entries']:
        name = approval['species']; source = raw[name]; battle = measured[name]
        assert approval['visual_approved'] and source['complete_pose_channels']
        for k, path in [('glb_sha256','path'),('runtime_sha256','runtime_path')]:
            assert sha(source[path]) == source[k] == approval[k]
        assert battle['glb_sha256'] == source['glb_sha256']
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in battle['shots'])
        assert approval['minimum_corrected_clearance'] >= .025-1e-5
        motion = copy.deepcopy(approval['motion_profile'])
        assert motion['sha256'] == source['glb_sha256']
        motion['sha256'] = source['runtime_sha256']
        if not motion['clips']:
            for action, clip in battle['clips'].items():
                if action != 'idle':
                    motion['clips'][action] = {'duration':clip['duration'],
                        'intent':'grounded_rest' if action == 'sleep' else 'clearance_only',
                        'offsets':[0.0]*(math.ceil(clip['duration']*60)+1)}
        species = name.removesuffix('-shiny'); variant = approval['variant']
        identity = species + ('@shiny' if variant == 'shiny' else '')
        placement = {k:motion[k] for k in ('scale','yaw_degrees')}
        bounds = {a:{'min':[v/motion['scale'] for v in c['envelope_min']],
                     'size':[v/motion['scale'] for v in c['envelope_size']]}
                  for a,c in battle['clips'].items()}
        if variant == 'shiny': bounds = copy.deepcopy(fixture['profiles'][species+'-normal']['bounds'])
        fixture['models'][identity] = {'sha256':source['runtime_sha256'],
            'glb_sha256':source['glb_sha256'],'profile':species+'-'+variant}
        fixture['profiles'][species+'-'+variant] = {'action_timing':source['action_timing'],
            'placement':placement,'grounding':dict(placement,lift=motion['lift']),
            'motion':motion,'bounds':bounds}
        if species.startswith('ogerpon-'):
            fixture['profiles'][species+'-'+variant]['attack_family_actions'] = {'body_charge':'physical_attack_2'}
        rows.append(dict(source,species=species,variant=variant,placement=placement))
    for species in sorted({r['species'] for r in rows}):
        a = copy.deepcopy(fixture['profiles'][species+'-normal'])
        b = copy.deepcopy(fixture['profiles'][species+'-shiny'])
        a['motion'].pop('sha256');b['motion'].pop('sha256');assert a == b, species
    WORK.mkdir(exist_ok=True)
    for filename,value in [('runtime-catalog-final.json',rows),('runtime-fixture.json',fixture)]:
        target=WORK/filename
        if target.exists(): assert read(target)==value
        else: target.write_bytes(encoded(value))
    hashes={k:v['sha256'] for k,v in fixture['models'].items()}
    names=tuple(sorted({r['species'] for r in rows}))
    dex={n:1017 if n.startswith('ogerpon-') else 1024 for n in names}
    if not (WORK/'bundles').exists():
        build(WORK/'runtime-catalog-final.json',WORK/'bundles',revision='battle-forms-first-five-approved-v1',
              species_set=names,dex=dex,candidate_hashes=hashes)
    print('FORMS_PREPARED pairs=5 scenes=10 bundles=5')
if __name__ == '__main__': main()
