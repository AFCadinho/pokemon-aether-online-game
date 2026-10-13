#!/usr/bin/env python3
"""Resume exact-channel WebP comparison with two isolated native workers."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import subprocess

from PIL import features
import study_lossless_texture_storage as base
import study_strict_webp_texture_storage as strict
from probe_v13_compression import read, require, write
from study_new_pair_geometry import diagnostic_project

BASE_SCRIPT = base.SCRIPT


def native_run(mode, config, output):
    # Explicit dispatch avoids the serial encoder's process-global SCRIPT
    # selection. Every invocation has separate paths, reports and pack mounts.
    script = strict.SCRIPT if 'buffers' in config else BASE_SCRIPT
    output.mkdir(parents=True, exist_ok=False)
    job = output / 'input.json'
    write(job, config)
    log = output / 'engine.stdout.log'
    command = ['godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
               '--path', str(base.ROOT), '--log-file', str(output / 'engine.log'),
               '--script', 'res://' + script, '--', mode, str(job), str(output)]
    with log.open('w') as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
    text = log.read_text()
    require(result.returncode == 0 and 'LOSSLESS_TEXTURE_ENGINE_OK' in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text, str(log))
    report = read(output / 'report.json')
    require(report['complete'] and report['input_sha256'] == base.sha(job) and report['pack_sha256'] == config['asset']['sha256'], 'Unbound native report')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    baseline, output = args.baseline.resolve(), args.output.resolve()
    config = read(baseline / 'configuration.json')
    require(config['inputs'] == {p: base.sha(base.ROOT/p) for p in base.CODE}, 'Source study changed')
    _, assets = base.catalog()
    by_id = {a['asset_id']: a for a in assets}
    ids = config['sample_ids']
    require(len(ids) == 20 and ids == [a['asset_id'] for a in base.select(assets)], 'Changed sample')
    bindings = {p: base.sha(base.ROOT/p) for p in [strict.SCRIPT, 'tools/study_strict_webp_texture_storage.py', *base.CODE]}

    def worker(index, key):
        matches = [p for p in output.glob(f'pair-{index:04d}*/checkpoint.json') if read(p)['asset_id'] == key]
        require(len(matches) <= 1, 'Ambiguous strict checkpoint')
        if matches:
            row = read(matches[0])
            require(base.sha(row['path']) == row['sha256'] and row['cold_native_verified'], 'Changed strict candidate')
            require(base.sha(matches[0].parent/'cold-verify/report.json') == row['engine_report_sha256'], 'Changed strict engine evidence')
            return row
        previous = [p for p in baseline.glob(f'pair-{index:04d}*/checkpoint.json') if read(p)['asset_id'] == key]
        require(len(previous) == 1, 'Missing baseline checkpoint')
        folder = previous[0].parent
        parent = {'source_path': config['sources'][key]['path'], 'source_report': str(folder/'source/report.json'), 'checkpoint': str(previous[0])}
        target = output/f'pair-{index:04d}'
        attempt = 0
        while target.exists():
            attempt += 1
            target = output/f'pair-{index:04d}-attempt-{attempt}'
        return strict.measure(key, by_id[key], parent, target)

    original_run = base.native_run
    base.native_run = native_run
    records = []
    try:
        with diagnostic_project(), ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(worker, i, key) for i, key in enumerate(ids)]
            for result in as_completed(futures):
                records.append(result.result())
                print(f'STRICT_WEBP_RESUMED {len(records)}/20 {records[-1]["asset_id"]}', flush=True)
    finally:
        base.native_run = original_run
    require(bindings == {p: base.sha(base.ROOT/p) for p in bindings}, 'Encoder inputs changed')
    records.sort(key=lambda r:r['asset_id'])
    report = {'schema': 1, 'complete': True, 'prototype_only': True, 'production_approved': False,
              'pairs': 20, 'pillow_webp': features.version('webp'), 'inputs': bindings,
              'baseline_configuration_sha256': base.sha(baseline/'configuration.json'),
              'baseline_report_sha256': base.sha(baseline/'report.json'),
              'execution_driver_sha256': base.sha(Path(__file__)), 'workers': 2,
              'source_sample_bytes': sum(r['source_bytes'] for r in records),
              'selected_sample_bytes': sum(r['selected_bytes'] for r in records), 'records': records}
    write(output/'report.json', report)
    print('STRICT_WEBP_COMPLETE '+str({k:v for k,v in report.items() if k not in ('records','inputs')}), flush=True)


if __name__ == '__main__': main()
