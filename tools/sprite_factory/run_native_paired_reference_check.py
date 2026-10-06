#!/usr/bin/env python3
"""Compare each native appearance in a fresh renderer, with an exact A/A control.

The independent original/candidate actors stay alive for A/B/A captures. A fresh
renderer for every appearance bounds allocator history without changing pixels,
materials, geometry, poses, lights, camera or MSAA. No production admission.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture', type=Path)
    parser.add_argument('project', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.relative_to(root / '.tmp')
    output.mkdir(parents=True, exist_ok=False)
    fixture = json.loads(args.fixture.read_text())
    report = {'complete': False, 'production_approved': False, 'entries': [],
              'fixture_sha256': hashlib.sha256(args.fixture.read_bytes()).hexdigest()}
    report['renderer_check_sha256'] = hashlib.sha256((root / 'tools/sprite_factory/native_paired_reference_check.gd').read_bytes()).hexdigest()
    (output / 'report.json').write_text(json.dumps(report, indent=2))
    for entry in fixture['entries']:
        for label, control, reverse in [('original-control', True, False), ('candidate', False, False), ('candidate-first', False, True)]:
            work = output / entry['identity'] / label
            work.mkdir(parents=True)
            (work / 'report.json').write_text(json.dumps({'complete': True, 'entries': [entry]}))
            env = os.environ.copy()
            env.update(NATIVE_COMPRESSION_OUTPUT=str(work), STORAGE_COMPONENT_REPORT=str(work / 'check.json'),
                       NATIVE_ORIGINAL_ONLY='1' if control else '0', NATIVE_CANDIDATE_FIRST='1' if reverse else '0')
            with (work / 'check.log').open('w') as log:
                result = subprocess.run([env.get('GODOT_BIN', 'godot'), '--path', str(args.project.resolve()),
                    '--script', 'res://paired-reference.gd'], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=90)
            messages = (work / 'check.log').read_text()
            check = json.loads((work / 'check.json').read_text())
            assert result.returncode == 0 and check['complete'] and 'SCRIPT ERROR:' not in messages and '\nERROR:' not in messages
            assert all(row['pixel_exact'] and row['repeat_exact'] for row in check['comparisons'])
            report['entries'].append({'identity': entry['identity'], 'phase': label,
                'comparisons': len(check['comparisons']), 'response_skipped': check.get('response_skipped', []),
                'report_sha256': hashlib.sha256((work / 'check.json').read_bytes()).hexdigest()})
            (output / 'report.json').write_text(json.dumps(report, indent=2))
        print('ISOLATED_NATIVE_REFERENCE_OK', entry['identity'], flush=True)
    report['complete'] = True
    report['appearances'] = len(fixture['entries'])
    report['comparisons'] = sum(row['comparisons'] for row in report['entries'])
    report['scope'] = 'Cold per-appearance renderer qualification. Warm multi-model reference remains separately observable.'
    (output / 'report.json').write_text(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
