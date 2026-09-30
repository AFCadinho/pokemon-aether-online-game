"""Re-probe animation holds and export only complete native action sets for review.

This intake never changes the approved catalog. Missing motions and competing
animation banks remain holds; no inferred substitute motion is exported.
"""

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

from catalog_remaining_intake import inventory, probe_one
from catalog_remaining_normal_export import REQUIRED, choose_actions, export_one


HERE = Path(__file__).resolve().parent


def sha(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def classify(entry, probe):
    row = {'national_dex': entry['national_dex'], 'species': entry['species'],
           'source': entry['legacy_source'], 'runtime_approved': False}
    if probe['status'] != 'probed':
        return row | {'status': 'probe_hold', 'reason': probe.get('reason', '')}
    report_path = Path(probe['report'])
    report = json.loads(report_path.read_text())
    mapping, bank = choose_actions(report)
    candidates = report['action_candidates']
    row.update(source_sha256=report['source_sha256'],
               probe_sha256=sha(report_path),
               missing_actions=sorted(k for k in REQUIRED if not candidates.get(k)),
               ambiguous_actions=sorted(k for k in REQUIRED if len(candidates.get(k, [])) > 1))
    if mapping:
        row.update(status='native_actions_ready', actions=mapping, bank=bank)
    else:
        row.update(status='native_actions_missing' if row['missing_actions'] else
                   'native_actions_ambiguous', reason=bank)
    return row


def receipt(rows, total):
    return {'schema': 1, 'scope': 'remaining_animation_holds_review_only',
            'runtime_approved': False, 'release_approved': False, 'published': False,
            'total': total, 'processed': len(rows),
            'counts': dict(Counter(row['status'] for row in rows)), 'entries': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--frontend', type=Path, required=True)
    parser.add_argument('--backend', type=Path, required=True)
    parser.add_argument('--archives', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, choices=(1, 2), default=2)
    parser.add_argument('--export', action='store_true')
    args = parser.parse_args()
    frontend, backend, archives, output = [p.resolve() for p in
        (args.frontend, args.backend, args.archives, args.output)]
    output.mkdir(parents=True, exist_ok=True)
    intake = inventory(frontend, backend, archives)
    previous_path = HERE / 'catalog_remaining_bulk_status.json'
    previous = json.loads(previous_path.read_text())
    target_names = {r['species'] for r in previous['entries']
                    if r['reason'] == 'missing_or_ambiguous_native_actions'}
    entries = [r for r in intake['entries'] if r['species'] in target_names]
    intake['entries'] = entries
    (output / 'animation-inventory.json').write_text(json.dumps(intake, indent=2) + '\n')
    probes, rows = [], []
    worker = HERE / 'catalog_remaining_legacy_worker.py'
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for entry, probe in zip(entries, pool.map(lambda e: probe_one(e, output, worker), entries)):
            probes.append(probe)
            rows.append(classify(entry, probe))
            (output / 'probe-status.json').write_text(json.dumps({'entries': probes}, indent=2) + '\n')
            result = receipt(rows, len(entries))
            result['previous_status_sha256'] = sha(previous_path)
            result['reviewed_catalog_sha256'] = sha(frontend / 'scripts/battle/battle_ui/reviewed_model_catalog.json')
            (output / 'audit.json').write_text(json.dumps(result, indent=2) + '\n')
            print(len(rows), entry['species'], rows[-1]['status'], flush=True)
    if not args.export:
        return
    ready = {r['species'] for r in rows if r['status'] == 'native_actions_ready'}
    sources = [e for e in entries if e['species'] in ready]
    by_name = {p['species']: p for p in probes}
    normal = output / 'normal'
    normal.mkdir(exist_ok=True)
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for result in pool.map(lambda e: export_one(e, by_name, normal,
                                  HERE / 'phase5_godot_export_worker.py'), sources):
            results.append(result)
            (normal / 'status.json').write_text(json.dumps(receipt(results, len(sources)), indent=2) + '\n')
            print('EXPORT', result['species'], result['status'], result.get('reason', ''), flush=True)


if __name__ == '__main__':
    main()
