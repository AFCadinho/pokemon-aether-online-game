"""Finish each exported native pair while the larger export queue runs."""
import os
import hashlib
import json
from pathlib import Path
import time
from alternate_forms_material_sources import prepare
from alternate_forms_batch import ROOT, INTAKE, WORK, SOURCE, read, write, sha, material, verify, cohort_rows


def main():
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name
    rows = cohort_rows()
    results = {}
    while len(results) < len(rows):
        progressed = False
        for row in rows:
            name = row['species']
            if name in results: continue
            exported = WORK / 'status/export' / (name + '.json')
            if not exported.exists(): continue
            record = read(exported)
            if record['status'] == 'held':
                result = {'species': name, 'status': 'held', 'reason': 'export: ' + record['reason']}
            else:
                try:
                    verify(row, SOURCE)
                    row = prepare(row)
                    fingerprint=hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest()
                    saved = WORK / 'status/material' / (name + '.json')
                    old = read(saved) if saved.exists() else {}
                    if old.get('status') == 'candidate' and old.get('input_fingerprint') == fingerprint and all(Path(v['path']).is_file() and sha(v['path']) == v['glb_sha256'] for v in old['variants']):
                        result = old
                    else:
                        result = {**material(row, SOURCE, WORK), 'status': 'candidate','input_fingerprint':fingerprint}
                except Exception as error:
                    result = {'species': name, 'status': 'held', 'reason': type(error).__name__ + ': ' + str(error)}
            result['intake_sha256'] = sha(INTAKE)
            results[name] = result
            write(WORK / 'status/material' / (name + '.json'), result)
            write(WORK / ('material-status-'+os.environ.get('POKEAETHER_FORM_BATCH_COHORT','native')+'.json'), {'runtime_approved': False, 'entries': sorted(results.values(), key=lambda r:r['species'])})
            print('MATERIAL', name, result['status'], result.get('reason',''), flush=True)
            progressed = True
        if not progressed: time.sleep(5)


if __name__ == '__main__': main()
