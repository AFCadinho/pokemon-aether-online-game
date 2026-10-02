"""Prepare exact user-approved battle-form pairs for installed runtime qualification."""
import copy
import hashlib
import json
import math
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
BASE=ROOT/'.tmp/battle-forms-next-seven-v1'
WORK=BASE/'approved-final'
sys.path.insert(0,str(ROOT/'tools'))
from package_optional_3d_bundle_prototype import build, encoded
NAMES={'aegislash-blade':681,'darmanitan-zen':555,'eiscue-noice':875,'mimikyu-busted':778,'morpeko-hangry':877,'palafin-hero':964,'wishiwashi-school':746}
def read(p):return json.loads(Path(p).read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    approval=read(HERE/'catalog_battle_forms_next_seven_checkpoint.json')
    assert approval['appearance_approved'] and approval['battle_approved'] and len(approval['entries'])==14
    for p,h in approval['battle_measurement']['evidence_sha256'].items():assert sha(ROOT/p)==h,p
    assert sha(ROOT/approval['runtime_pose_order_check']['report'])==approval['runtime_pose_order_check']['sha256']
    page=ROOT/approval['battle_review_page']['path'];manifest=read(page.parent/'manifest.json')
    assert sha(page.parent/'manifest.json')==approval['user_final_approval']['review_manifest_sha256']
    for p,h in manifest['files'].items():assert sha(page.parent/p)==h,p
    raw={r['species']:r for r in read(BASE/'final-runtime-combined-v4/report.json')}
    measures={r['species']:r for r in read(BASE/'final-battle-combined-v4/battle-review.json')['entries'] if 'clips' in r}
    candidates=read(BASE/'final-stage-v4/candidates.json');fixture={'models':{},'profiles':{}};rows=[]
    for accepted in sorted(approval['entries'],key=lambda r:r['species']):
        name=accepted['species'];source=raw[name];m=measures[name]
        assert accepted['appearance_approved'] and accepted['battle_approved'] and source['complete_pose_channels']
        assert sha(source['path'])==accepted['glb_sha256']==source['glb_sha256']==m['glb_sha256']
        assert sha(source['runtime_path'])==source['runtime_sha256']
        assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
        assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values())>=.025-1e-5
        motion=copy.deepcopy(candidates['motion'][name]);assert motion['sha256']==source['glb_sha256']
        assert abs(motion['lift']-m['candidate_lift'])<.001 and abs(motion['scale']-m['scale'])<1e-6
        motion['sha256']=source['runtime_sha256']
        if not motion['clips']:
            for action,clip in m['clips'].items():
                if action!='idle':motion['clips'][action]={'duration':clip['duration'],'intent':'grounded_rest' if action=='sleep' else 'clearance_only','offsets':[0.]*(math.ceil(clip['duration']*60)+1)}
        species=name.removesuffix('-shiny');variant='shiny' if name.endswith('-shiny') else 'normal';identity=species+('@shiny' if variant=='shiny' else '')
        placement={k:motion[k] for k in ('scale','yaw_degrees')}
        normal=measures[species]
        bounds={a:{'min':[v/normal['scale'] for v in c['envelope_min']],'size':[v/normal['scale'] for v in c['envelope_size']]} for a,c in normal['clips'].items()}
        fixture['models'][identity]={'sha256':source['runtime_sha256'],'glb_sha256':source['glb_sha256'],'profile':species+'-'+variant}
        fixture['profiles'][species+'-'+variant]={'action_timing':source['action_timing'],'placement':placement,'grounding':dict(placement,lift=motion['lift']),'motion':motion,'bounds':bounds}
        if 'physical_attack_2' in source['action_timing']:
            fixture['profiles'][species+'-'+variant]['attack_family_actions']={'body_charge':'physical_attack_2'}
        rows.append(dict(source,species=species,variant=variant,placement=placement))
    assert {r['species'] for r in rows}==set(NAMES)
    for name in NAMES:
        a=copy.deepcopy(fixture['profiles'][name+'-normal']);b=copy.deepcopy(fixture['profiles'][name+'-shiny']);a['motion'].pop('sha256');b['motion'].pop('sha256');assert a==b,name
    WORK.mkdir(exist_ok=False)
    (WORK/'runtime-catalog-final.json').write_bytes(encoded(rows));(WORK/'runtime-fixture.json').write_bytes(encoded(fixture))
    build(WORK/'runtime-catalog-final.json',WORK/'bundles',revision='battle-forms-next-seven-approved-v1',species_set=tuple(sorted(NAMES)),dex=NAMES,candidate_hashes={k:v['sha256'] for k,v in fixture['models'].items()})
    print('NEXT_SEVEN_PREPARED pairs=7 scenes=14 bundles=7')
if __name__=='__main__':main()
