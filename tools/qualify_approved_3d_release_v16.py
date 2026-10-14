#!/usr/bin/env python3
"""Compare the entire newly assembled PCK cohort with approved v15 on Linux GL."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess

from probe_v13_compression import read, write, require
from run_shared_texture_runtime_checks import project
from study_lossless_texture_storage import ROOT, sha


def qualify(work, configuration, previous_sources, workers):
    require(work.is_relative_to(ROOT / '.tmp') and not work.exists(), 'Fresh slot-local qualification required')
    config = read(configuration)
    require(config['complete'] and not config['production_approved'], 'Unexpected assembly state')
    previous = {a['asset_id']: a for a in read(ROOT / 'data/model_pair_release_v15_catalog.json')['assets']}
    sources = read(previous_sources)
    require(sources['metadata_sha256'] == sha(ROOT / 'release/approved_3d_bundles_v15.json'), 'Changed previous sources')
    pool = next(j for j in config['jobs'] if j['asset'].get('format') == 'model-texture-pck-v1')
    jobs = [{**j, 'previous': previous[j['asset']['asset_id']], 'previous_path': sources['sources'][j['asset']['asset_id']]}
            for j in config['jobs'] if j['asset'].get('format') == 'model-pair-pck-v1']
    require(len(jobs) == 1365 and len(config['jobs']) == 1421, 'Incomplete assembled collection')
    work.mkdir(parents=True)
    folders = [project(work / f'shard-{i}', ['tests/model_release_v16_native_check.gd']) for i in range(workers)]
    inputs = {str(p.relative_to(work)): sha(p) for folder in folders for p in folder.rglob('*') if p.is_symlink()}
    driver_inputs = {p: sha(ROOT / p) for p in ['tools/qualify_approved_3d_release_v16.py',
        'tools/package_approved_3d_release_v16.py', 'tools/rebind_release_resource_paths.py']}
    for i, folder in enumerate(folders):
        with (work / f'import-{i}.log').open('w') as log:
            imported = subprocess.run(['godot', '--headless', '--editor', '--path', str(folder),
                '--log-file', str(work / f'import-engine-{i}.log'), '--import'], stdout=log, stderr=subprocess.STDOUT, timeout=180)
        require(imported.returncode == 0 and 'ERROR:' not in (work / f'import-{i}.log').read_text(), 'Native project import failed')

    def shard(index):
        folder = folders[index]
        fixture = work / f'input-{index}.json'
        output = work / f'report-{index}.json'
        write(fixture, {'pool': pool, 'jobs': jobs[index::workers]})
        with (work / f'stdout-{index}.log').open('w') as log:
            result = subprocess.run(['godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
                '--path', str(folder), '--log-file', str(work / f'engine-{index}.log'),
                '--script', 'res://tests/model_release_v16_native_check.gd', '--', str(fixture), str(output)],
                stdout=log, stderr=subprocess.STDOUT, timeout=10800)
        text = (work / f'stdout-{index}.log').read_text()
        require(result.returncode == 0 and 'ERROR:' not in text and 'SCRIPT ERROR' not in text and output.exists(), f'Native shard {index} failed')
        report = read(output)
        require(report['complete'] and report['input_sha256'] == sha(fixture), 'Incomplete native report')
        return report

    with ThreadPoolExecutor(max_workers=workers) as executor:
        reports = list(executor.map(shard, range(workers)))
    require(inputs == {str(p.relative_to(work)): sha(p) for folder in folders for p in folder.rglob('*') if p.is_symlink()}, 'Linked source changed during qualification')
    require(driver_inputs == {p: sha(ROOT / p) for p in driver_inputs}, 'Driver changed during qualification')
    records = sorted((r for report in reports for r in report['records']), key=lambda r: r['asset_id'])
    require(len(records) == len({r['asset_id'] for r in records}) == 1365, 'Native coverage incomplete')
    require(sum(len(r['looks']) for r in records) == 2730, 'Appearance coverage incomplete')
    receipt = {'schema': 1, 'complete': True, 'runtime_approved': False, 'publication_approved': False,
        'qualification': 'linux-full-v16-native', 'configuration_sha256': sha(configuration),
        'records': records, 'motion_samples': sum(r['motion_samples'] for r in reports),
        'scene_states_exact': True, 'deep_duplicates_exact': True, 'other_platforms_qualified': False,
        'inputs': inputs, 'driver_inputs': driver_inputs,
        'reports': {f'report-{i}.json': sha(work / f'report-{i}.json') for i in range(workers)},
        'devices': [r['device'] for r in reports]}
    write(work / 'qualification.json', receipt)
    print(f'V16_FULL_NATIVE_COMPLETE pairs=1365 samples={receipt["motion_samples"]}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--configuration', type=Path, required=True)
    parser.add_argument('--previous-sources', type=Path, required=True)
    parser.add_argument('--workers', type=int, choices=[1, 2], default=2)
    args = parser.parse_args()
    qualify(args.work.resolve(), args.configuration.resolve(), args.previous_sources, args.workers)
