"""Explicit same-rig legacy regional action mapping and candidate exports."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import re
from catalog_remaining_explicit_actions import export, sha
from catalog_shiny_za_17_probe import write
from phase5_review_actions import candidates

HERE=Path(__file__).resolve().parent
WORK=HERE.parents[1]/'.tmp/regional-production-v1/legacy'


def mappings():
    rows={r['species']:r for r in json.loads((WORK/'intake.json').read_text())['entries']}
    ready=[];held=[]
    for result in json.loads((WORK/'probe-status.json').read_text())['entries']:
        if result['status']!='probed':held.append(result);continue
        report=json.loads(Path(result['report']).read_text());rig=re.sub(r'\.(trmdl|gfbmdl)$','',report['rig_name'])
        prefix = {'rapidash-galar':'pm0078_00_31', 'zigzagoon-galar':'pm0263_00_31'}.get(result['species'], rig)
        names=[n for n in report['action_names'] if n.startswith(prefix+'_')]
        rig = prefix
        actions={}
        for bank in [0,2,1]:
            found=candidates(names,bank)
            idle=[n for n in found['idle']if '_battlewait01_loop.'in n]
            if len(idle)==1:found['idle']=idle
            selected={k:v[0]for k,v in found.items()if len(v)==1}
            if len(selected)>len(actions):actions=selected
        for key,suffixes in {'idle':['idle','ba10_waitA01'],'physical_attack':['attack1','ba20_buturi01'],
                'physical_attack_2':['attack2'],'special_attack':['attack2','ba21_tokusyu01'],
                'damage':['hit','ba30_damageS01'],'sleep':['sleepLoop','kw20_drowseB01'],
                'faint_start':['down','ba41_down01']}.items():
            if key in actions:continue
            for suffix in suffixes:
                matches=[n for n in names if n==rig+'_'+suffix or n==rig+'_'+suffix+'.gfbanm']
                if len(matches)==1:actions[key]=matches[0];break
        aliases={}
        if result['species']=='darmanitan-galar-zen' and 'sleep'not in actions:
            actions['sleep']=actions['idle'];aliases['sleep']='Native Zen idle used as rest proposal; no source sleep clip. Eye closure requires review.'
        if result['species']=='vulpix-alola':
            for action,suffix in {'physical_attack':'00300_roar01','special_attack':'00300_roar01','damage':'00512_stun01_end'}.items():
                exact=rig+'_'+suffix+'.gfbanm'
                assert exact in names
                actions[action]=exact;aliases[action]='Own-rig source gesture proposal; archived source lacks this battle action.'
        missing={'idle','physical_attack','special_attack','damage','sleep','faint_start'}-actions.keys()
        row=rows[result['species']]
        entry={'species':row['species'],'national_dex':row['national_dex'],'source':row['legacy_source'],
               'source_sha256':report['source_sha256'],'probe':result['report'],'probe_sha256':sha(Path(result['report'])),
               'actions':actions,'review_action_aliases':aliases,'runtime_approved':False}
        if row.get('diagnostic_rig_selection'):entry['diagnostic_rig_selection']=row['diagnostic_rig_selection']
        if missing:held.append(dict(entry,status='motion_repair_required',missing=sorted(missing)))
        else:ready.append(entry)
    write(WORK/'action-mappings.json',{'schema':1,'entries':ready,'held':held,'runtime_approved':False})
    print('Mapped',len(ready),'held',[(r['species'],r.get('missing',r.get('reason')))for r in held])


def exports():
    rows=json.loads((WORK/'action-mappings.json').read_text())['entries'];directory=WORK/'normal-exports';directory.mkdir(exist_ok=True)
    results=[]
    def one(row):
        path=directory/row['species']/'export.json'
        if path.exists():
            d=json.loads(path.read_text());assert sha(Path(d['path']))==d['glb_sha256']
            return dict(species=row['species'],status='normal_review_candidate',report=str(path),runtime_approved=False)
        return export(row,directory)
    with ThreadPoolExecutor(max_workers=2)as pool:
        for future in as_completed([pool.submit(one,r)for r in rows]):
            r=future.result();results.append(r);write(directory/'status.json',dict(total=len(rows),processed=len(results),entries=results,runtime_approved=False));print(r['species'],r['status'],r.get('reason',''),flush=True)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('phase',choices=['mapping','export']);a=p.parse_args()
    mappings()if a.phase=='mapping'else exports()
