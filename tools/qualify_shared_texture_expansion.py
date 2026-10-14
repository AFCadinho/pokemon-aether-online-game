#!/usr/bin/env python3
"""Cold and reverse-restart native equivalence checks for unpublished pools."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess

from probe_v13_compression import read, write, require
from run_shared_texture_runtime_checks import project
from study_lossless_texture_storage import ROOT, sha

SCRIPT = 'tests/shared_texture_expansion_native_check.gd'


def qualify(work, configuration, workers):
    require(work.is_relative_to(ROOT / '.tmp') and not work.exists(), 'Fresh slot-local qualification required')
    config = read(configuration)
    require(config['complete'] and config['prototype_only'] and not config['production_approved'], 'Unexpected assembly state')
    require(sha(ROOT / 'tools/study_shared_texture_expansion.py') == config['builder_sha256'], 'Builder changed')
    require(sha(config['baseline_assembly_path']) == config['baseline_assembly_sha256'], 'Baseline changed')
    jobs = config['jobs']
    require(len(jobs) == len({j['asset']['asset_id'] for j in jobs}) and len(jobs) > 0, 'Invalid cohort')
    pools = config['baseline_pools'] + config['new_pools']
    work.mkdir(parents=True)
    folders = [project(work / f'shard-{i}', [SCRIPT]) for i in range(workers)]
    inputs = {str(p.relative_to(work)): sha(p) for folder in folders for p in folder.rglob('*') if p.is_symlink()}
    driver_inputs = {p: sha(ROOT / p) for p in ['tools/study_shared_texture_expansion.py',
                    'tools/qualify_shared_texture_expansion.py', 'tools/rebind_release_resource_paths.py',
                    'tools/probe_v13_compression.py', 'tools/run_shared_texture_runtime_checks.py']}
    for i, folder in enumerate(folders):
        with (work / f'import-{i}.log').open('w') as log:
            result = subprocess.run(['godot', '--headless', '--editor', '--path', str(folder),
                '--log-file', str(work / f'import-engine-{i}.log'), '--import'], stdout=log, stderr=subprocess.STDOUT, timeout=180)
        require(result.returncode == 0 and 'ERROR:' not in (work / f'import-{i}.log').read_text(), 'Native import failed')

    def shard(index, phase):
        selected = jobs[index::workers]
        if phase == 'restart':
            selected = list(reversed(selected))
        fixture = work / f'{phase}-input-{index}.json'
        output = work / f'{phase}-report-{index}.json'
        write(fixture, {'pools': pools, 'jobs': selected})
        log = work / f'{phase}-stdout-{index}.log'
        with log.open('w') as stream:
            result = subprocess.run(['godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
                '--path', str(folders[index]), '--log-file', str(work / f'{phase}-engine-{index}.log'),
                '--script', 'res://' + SCRIPT, '--', str(fixture), str(output)],
                stdout=stream, stderr=subprocess.STDOUT, timeout=10800)
        require(result.returncode == 0 and 'ERROR:' not in log.read_text() and output.exists(), f'{phase} shard {index} failed: {log}')
        report = read(output)
        require(report['complete'] and report['input_sha256'] == sha(fixture), 'Incomplete native report')
        require({r['asset_id']: r['candidate_sha256'] for r in report['records']} ==
                {j['asset']['asset_id']: j['asset']['sha256'] for j in selected}, 'Native coverage changed')
        return report

    phases = {}
    for phase in ['cold', 'restart']:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            reports = list(executor.map(lambda i: shard(i, phase), range(workers)))
        records = sorted((r for report in reports for r in report['records']), key=lambda r: r['asset_id'])
        require(len(records) == len(jobs), 'Incomplete cohort')
        phases[phase] = records
    require(phases['cold'] == phases['restart'], 'Reverse-order restart changed results')
    require(inputs == {str(p.relative_to(work)): sha(p) for folder in folders for p in folder.rglob('*') if p.is_symlink()}, 'Linked inputs changed')
    require(driver_inputs == {p: sha(ROOT / p) for p in driver_inputs}, 'Driver inputs changed')
    records = phases['cold']
    receipt = {'schema': 1, 'complete': True, 'prototype_only': True,
        'runtime_approved': False, 'publication_approved': False,
        'qualification': 'linux-v16-shared-texture-expansion',
        'configuration_path': str(configuration), 'configuration_sha256': sha(configuration),
        'pairs': len(records), 'looks': sum(len(r['looks']) for r in records),
        'motion_samples_per_phase': sum(look['motion_samples'] for r in records for look in r['looks']),
        'new_pools': len(config['new_pools']), 'shared_groups': config['groups'],
        'baseline_bytes': config['baseline_bytes'], 'total_bundle_bytes': config['total_bundle_bytes'],
        'net_saved_bytes': config['net_saved_bytes'], 'records': records,
        'scene_texture_states_exact': True, 'deep_duplicates_exact': True,
        'simultaneous_actor_lifecycle_exact': True, 'reverse_restart_exact': True,
        'other_platforms_qualified': False, 'inputs': inputs, 'driver_inputs': driver_inputs,
        'reports': {f'{phase}-report-{i}.json': sha(work / f'{phase}-report-{i}.json')
                    for phase in phases for i in range(workers)}}
    write(work / 'qualification.json', receipt)
    print('EXPANSION_QUALIFIED', {k: receipt[k] for k in ['pairs', 'looks', 'net_saved_bytes', 'total_bundle_bytes']}, flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--configuration', type=Path, required=True)
    parser.add_argument('--workers', type=int, choices=[1, 2], default=2)
    args = parser.parse_args()
    qualify(args.work.resolve(), args.configuration.resolve(), args.workers)
