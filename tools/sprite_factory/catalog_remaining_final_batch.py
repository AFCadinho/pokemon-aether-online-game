"""Resumeable review-only processing of every remaining source, with per-row errors."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
import ast
import re
import zipfile
import time
from pathlib import Path

from catalog_remaining_intake import probe_one
from phase5_review_actions import candidates
from catalog_remaining_explicit_actions import export
from catalog_remaining_native_emission import recover

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write(path, value):
    temporary = path.with_suffix(path.suffix + '.new')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def run(output):
    intake = json.loads((output / 'intake.json').read_text())
    previous = {}
    for folder in [ROOT / '.tmp/remaining-animation-recovery', ROOT / '.tmp/remaining-bulk']:
        if folder.exists():
            for path in folder.glob('probes/*/report.json'):
                report = json.loads(path.read_text())
                if 'action_names' in report and 'source_member' in report:
                    previous[report['species']] = path

    def process(row):
        if not row.get('legacy_source'):
            return {'species': row['species'], 'status': 'alternative_source_required',
                    'reason': 'No Biochao member; DLC models require separate motion import',
                    'runtime_approved': False}
        path = previous.get(row['species'])
        if path:
            report = json.loads(path.read_text())
            if report['source_member'] == row['legacy_source']['member']:
                return {'species': row['species'], 'status': 'probed', 'report': str(path),
                        'report_sha256': sha(path), 'runtime_approved': False}
        result = probe_one(row, output, HERE / 'catalog_remaining_legacy_worker.py')
        result['runtime_approved'] = False
        if result['status'] == 'probed':
            result['report_sha256'] = sha(result['report'])
        return result

    results = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(process, row) for row in intake['entries']]
        for future in as_completed(jobs):
            result = future.result()
            results.append(result)
            write(output / 'probe-status.json', {'schema': 1, 'total': len(jobs),
                  'processed': len(results), 'runtime_approved': False,
                  'entries': sorted(results, key=lambda row: row['species'])})
            print(len(results), result['species'], result['status'], result.get('reason', ''), flush=True)


def repair_variants(output):
    intake = json.loads((output / 'intake.json').read_text())
    results = json.loads((output / 'probe-status.json').read_text())
    rows = {r['species']: r for r in intake['entries']}
    def retry(result):
        if result['status'] != 'blocked':
            return result
        row = dict(rows[result['species']])
        reason = result.get('reason', '')
        if not reason.startswith('Ambiguous rig variants: '):
            return result
        identities = ast.literal_eval(reason.split(': ', 1)[1])
        member = row['legacy_source']['member']
        resource = re.search(r'pm\d{4}', member)[0]
        form = '12' if result['species'] in ['pumpkaboo-average', 'gourgeist-average'] else (
            '00' if any(name.startswith(resource+'_00') for name in identities) else '11')
        identity = resource + '_' + form
        matches = [name for name in identities if re.fullmatch(re.escape(identity)+r'(?:_00)?(?:\.trmdl)?', name)]
        if len(matches) != 1:
            return result
        with zipfile.ZipFile(row['legacy_source']['archive']) as archive:
            content = archive.read(member)
        selection = {'policy': 'explicit_source_variant_review_v1', 'rig': matches[0],
                     'expected_identity': identity, 'source_sha256': hashlib.sha256(content).hexdigest()}
        row['diagnostic_rig_selection'] = selection
        result = probe_one(row, output / 'explicit-variants', HERE / 'catalog_remaining_legacy_worker.py')
        result['runtime_approved'] = False
        result['diagnostic_rig_selection'] = selection
        if result['status'] == 'probed': result['report_sha256'] = sha(result['report'])
        return result
    updated = []
    with ThreadPoolExecutor(max_workers=2) as pool:
        for result in pool.map(retry, results['entries']):
            updated.append(result)
            write(output / 'variant-probe-status.json', dict(results, processed=len(updated), entries=updated))
            print('VARIANT', result['species'], result['status'], result.get('reason', ''), flush=True)


def owned_action_names(report):
    """Exclude material/node actions; prefer the selected rig's exact motion family."""
    rig = report['rig_name']
    names = report['action_names']
    direct = [n for n in names if '|' not in n or n.split('|', 1)[0] == rig]
    if any('|' in n for n in direct):
        return direct
    identity = report.get('rig_selection', {}).get('expected_identity')
    if not identity:
        match = re.match(r'pm\d{4}_\d{2}(?:_\d{2})?', rig)
        identity = match[0] if match else None
    candidates = []
    for name in names:
        parts = name.split('|')
        if len(parts) < 2 or not parts[0].startswith('Armature'):
            continue
        token = parts[1]
        if identity and not token.startswith(identity+'_'):
            continue
        candidates.append(name)
    return direct + candidates


def mapping(output):
    intake = {r['species']: r for r in json.loads((output / 'intake.json').read_text())['entries']}
    results = json.loads((output / 'variant-probe-status.json').read_text())
    ready, held = [], []
    for result in results['entries']:
        if result['status'] != 'probed':
            held.append(result); continue
        report = json.loads(Path(result['report']).read_text())
        original = owned_action_names(report)
        def normalized(name):
            name = name.split('|')[1] if '|' in name else name
            return re.sub(r'(?:\.gfbanm)?(?:\.\d{3})?$', '', name, flags=re.I)
        aliases = {normalized(n)+'.':n for n in original}
        prefix = re.match(r'(pm\d{4}_\d{2}(?:_\d{2})?)', report['rig_name'])
        own = {n:o for n,o in aliases.items() if not prefix or n.startswith(prefix[0]+'_')}
        if not own: own = aliases
        found = candidates(list(own))
        actions = {}
        for bank in [2, 1, 0]:
            values = candidates(list(own), bank=bank)
            battle_wait = [n for n in values['idle'] if '_battlewait01_loop.' in n]
            if len(battle_wait) == 1:
                values['idle'] = battle_wait
            choice = {k:own[v[0]] for k,v in values.items() if len(v)==1}
            # Sleep comes from the same selected source rig even when it is a
            # field bank; exact names and this exception are frozen in receipt.
            if 'sleep' not in choice and len(found['sleep'])==1:
                choice['sleep']=own[found['sleep'][0]]
            if len(choice) > len(actions): actions=choice
        simple = {'idle':['idle','idle2'], 'physical_attack':['attack1','attack'],
                  'physical_attack_2':['attack2'], 'special_attack':['attack2'],
                  'damage':['hit','damage'], 'faint_start':['down','faint'], 'sleep':['sleep']}
        for key, names in simple.items():
            if key not in actions:
                for name in names:
                    if name+'.' in own: actions[key]=own[name+'.']; break
        # Old names include wait variants A/B and authored wait loops. Prefer
        # a uniquely named battle wait, retaining its original exact spelling.
        if 'idle' not in actions:
            wait = [o for n,o in own.items() if re.search(r'_(?:ba10_wait[A-Z]01|fi01_wait01)\.$',n,re.I)]
            if len(wait)==1: actions['idle']=wait[0]
        review_aliases = {}
        if 'sleep' not in actions and 'idle' in actions:
            actions['sleep']=actions['idle']
            review_aliases['sleep']='Source idle used as resting proposal; not native sleep; face closure still requires verification'
        if 'physical_attack' not in actions and 'special_attack' in actions:
            actions['physical_attack']=actions['special_attack']
            review_aliases['physical_attack']='Source special attack reused; no separate source physical clip exists'
        if 'special_attack' not in actions and 'physical_attack' in actions:
            actions['special_attack']=actions['physical_attack']
            review_aliases['special_attack']='Source physical attack reused; no separate source special clip exists'
        required={'idle','physical_attack','special_attack','damage','sleep','faint_start'}
        if not required <= actions.keys():
            held.append(dict(result,status='native_motion_repair_required',missing=sorted(required-actions.keys())));continue
        row=intake[result['species']]
        ready.append({'species':row['species'],'national_dex':row['national_dex'],'source':row['legacy_source'],
                      'source_sha256':report['source_sha256'],'probe':result['report'],'probe_sha256':result['report_sha256'],
                      'actions':actions,'review_action_aliases':review_aliases,
                      **({'diagnostic_rig_selection':result['diagnostic_rig_selection']} if result.get('diagnostic_rig_selection') else {})})
    write(output/'action-mappings.json',{'schema':1,'runtime_approved':False,'entries':ready})
    write(output/'mapping-holds.json',{'schema':1,'runtime_approved':False,'entries':held})
    print('MAPPINGS',len(ready),'HOLD',len(held),flush=True)


def exports(output):
    rows=json.loads((output/'action-mappings.json').read_text())['entries']
    rows=[r for r in rows if r['species'] not in ['ponyta','rapidash','centiskorch']]
    directory=output/'normal-exports';directory.mkdir(exist_ok=True)
    results=[]
    def process(row):
        path=directory/row['species']/'export.json'
        if path.exists():
            receipt=json.loads(path.read_text())
            if sha(receipt['path'])!=receipt['glb_sha256']: raise ValueError('Existing export changed')
            return {'species':row['species'],'status':'normal_review_candidate','report':str(path),'runtime_approved':False}
        if (directory/row['species']).exists():
            return {'species':row['species'],'status':'held','reason':'Failed prior export preserved; retry requires new directory','runtime_approved':False}
        result=export(row,directory)
        if result['status']=='held':
            log=directory/row['species']/'export.log'
            if log.exists():
                errors=re.findall(r'(?:ValueError|RuntimeError|OSError): ([^\n]+)',log.read_text(errors='replace'))
                if errors: result['reason']=errors[-1]
        return result
    with ThreadPoolExecutor(max_workers=2) as pool:
        futures=[pool.submit(process,row) for row in rows]
        for future in as_completed(futures):
            result=future.result();results.append(result)
            write(directory/'status.json',{'total':len(rows),'processed':len(results),'runtime_approved':False,'entries':sorted(results,key=lambda r:r['species'])})
            print('EXPORT',len(results),result['species'],result['status'],result.get('reason',''),flush=True)


def materials(output):
    mappings={r['species']:r for r in json.loads((output/'action-mappings.json').read_text())['entries']}
    directory=output/'native-materials';directory.mkdir(exist_ok=True)
    results=[];submitted=set();futures={}
    with ThreadPoolExecutor(max_workers=2) as pool:
        while True:
            exported=json.loads((output/'normal-exports/status.json').read_text())
            for result in exported['entries']:
                name=result['species']
                if result['status']!='normal_review_candidate' or name in submitted:continue
                submitted.add(name)
                entry=json.loads(Path(result['report']).read_text())
                row=dict(mappings[name],normal_path=entry['path'],normal_glb_sha256=entry['glb_sha256'])
                if (directory/name/'export.json').exists():
                    saved=json.loads((directory/name/'export.json').read_text());assert sha(saved['path'])==saved['glb_sha256']
                    results.append({'species':name,'status':'normal_review_candidate','path':saved['path'],'glb_sha256':saved['glb_sha256'],'runtime_approved':False})
                elif (directory/name).exists():
                    results.append({'species':name,'status':'held','reason':'Previous material failure preserved; retry in new directory','runtime_approved':False})
                else:futures[pool.submit(recover,row,directory)]=name
            done=[f for f in futures if f.done()]
            for future in done:
                result=future.result();results.append(result);del futures[future]
                if result['status']=='held':
                    log=directory/result['species']/'bake.log'
                    if log.exists():
                        errors=re.findall(r'(?:ValueError|RuntimeError|OSError): ([^\n]+)',log.read_text(errors='replace'))
                        if errors:result['reason']=errors[-1]
                print('MATERIAL',len(results),result['species'],result['status'],result.get('reason',''),flush=True)
            complete=exported['processed']==exported['total'] and not futures
            write(directory/'status.json',{'schema':1,'runtime_approved':False,'complete':complete,'total':len(submitted),'processed':len(results),'entries':sorted(results,key=lambda r:r['species'])})
            if complete:break
            time.sleep(2)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--phase', choices=['probe','variants','mapping','export','materials'], default='probe')
    args = parser.parse_args()
    {'probe':run,'variants':repair_variants,'mapping':mapping,'export':exports,'materials':materials}[args.phase](args.output.resolve())
