"""Bind eight visually approved pairs to exact scenes and measured profiles."""
import copy
import hashlib
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BASE = ROOT / '.tmp/remaining-142-production'
WORK = BASE / 'approved-eight'

def read(p): return json.loads(p.read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d): p.write_text(json.dumps(d,indent=2,sort_keys=True,allow_nan=False)+'\n')

def main():
    source = HERE / 'catalog_remaining_142_battle_candidates.json'
    proof = read(source)
    appearance = read(HERE / 'catalog_remaining_142_shiny_candidates.json')
    assert not proof['visual_battle_review_pending'] and not appearance['appearance_approval_pending']
    assert proof['battle_user_approval']['answer'] == 'de 8 zien er goed uit.'
    for evidence in [proof,appearance]:
        for p,h in evidence['evidence_sha256'].items(): assert sha(ROOT/p)==h,p
    scenes = {v:read(BASE / ('normal-runtime-v1' if v=='normal' else 'shiny-runtime-v3') / 'report.json') for v in ['normal','shiny']}
    measured = {v:{r['species']:r for r in read(BASE / ('battle-eight-v1' if v=='normal' else 'battle-eight-shiny-v1') / 'corrected/battle-review.json')['entries']} for v in scenes}
    fixture={'models':{},'profiles':{}}; rows=[]; records=[]
    for approved in proof['entries']:
        name,v=approved['species'],approved['variant'];identity=name+('@shiny' if v=='shiny' else '');key=name+'-'+v
        assert approved['visual_battle_approved'] and approved['minimum_clearance_120hz'] >= .015
        assert approved['all_camera_shots_in_view'] and approved['hud_proxy_overlap_shots']==0
        row=copy.deepcopy(next(r for r in scenes[v] if r['species']==name))
        assert sha(Path(row['path']))==row['glb_sha256']==approved['glb_sha256']
        assert sha(Path(row['runtime_path']))==row['runtime_sha256']==approved['runtime_sha256']
        m=measured[v][name]; motion=approved['motion_profile'];place={k:motion[k] for k in ['scale','yaw_degrees']}
        assert abs(m['scale']-motion['scale'])<1e-8 and abs(m['candidate_lift']-motion['lift'])<.001
        # Use the normal measured bounds for both variants: accessors are identical.
        bounds={a:{'min':[x/motion['scale'] for x in c['envelope_min']],'size':[x/motion['scale'] for x in c['envelope_size']]} for a,c in measured['normal'][name]['clips'].items()}
        fixture['models'][identity]={'sha256':row['runtime_sha256'],'glb_sha256':row['glb_sha256'],'profile':key}
        fixture['profiles'][key]={'action_timing':row['action_timing'],'placement':place,'grounding':dict(place,lift=motion['lift']),'motion':motion,'bounds':bounds}
        row.update(species=name,variant=v,placement=place);rows.append(row)
        records.append({'species':name,'variant':v,'glb_sha256':row['glb_sha256'],'runtime_sha256':row['runtime_sha256'],'appearance_approved':True,'battle_approved':True})
    names={r['species'] for r in rows};assert len(names)==8 and len(rows)==16
    for name in names:
        n=copy.deepcopy(fixture['profiles'][name+'-normal']);s=copy.deepcopy(fixture['profiles'][name+'-shiny']);n['motion'].pop('sha256');s['motion'].pop('sha256');assert n==s
    WORK.mkdir(exist_ok=False);rows.sort(key=lambda r:(r['species'],r['variant']))
    write(WORK/'runtime-catalog-final.json',rows);write(WORK/'runtime-fixture.json',fixture)
    profiles=HERE/'catalog_remaining_142_eight_profiles.json';write(profiles,fixture)
    images={}
    for v,directory in [('normal','battle-eight-v1'),('shiny','battle-eight-shiny-v1')]:
        p=BASE/directory/'corrected'
        for r in measured[v].values():
            if r['species']=='dragonite':continue
            for shot in r['shots']:
                image=p/shot['image'];images[str(image.relative_to(ROOT))]=sha(image)
    assert len(images)==256
    files=[source,HERE/'catalog_remaining_142_shiny_candidates.json',profiles,Path(__file__),WORK/'runtime-catalog-final.json',WORK/'runtime-fixture.json']
    write(HERE/'catalog_remaining_142_eight_battle_qualification.json',{'schema':1,'date':'2026-10-01','runtime_approved':False,'appearance_approved_pairs':8,'battle_visual_approval':True,'battle_approval_answer':proof['battle_user_approval']['answer'],'profiles_sha256':sha(profiles),'records':records,'evidence_sha256':{str(p.relative_to(ROOT)):sha(p) for p in files},'capture_sha256':images,'scope':'16 exact standalone scenes; independent120Hz clearance and256 actual camera captures; user appearance/battle approved; bundle installation and performance gate pending'})
    print('APPROVED_EIGHT_INPUTS scenes=16 captures=256')
if __name__=='__main__': main()
