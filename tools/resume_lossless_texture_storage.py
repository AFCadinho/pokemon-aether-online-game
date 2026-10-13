#!/usr/bin/env python3
"""Resume frozen texture checkpoints with two bounded independent GPU workers."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import signal

import study_lossless_texture_storage as study
from probe_v13_compression import read, require, write
from study_new_pair_geometry import diagnostic_project


def resume(output):
    output = output.resolve()
    configuration = read(output / 'configuration.json')
    require(configuration['inputs'] == {p: study.sha(study.ROOT / p) for p in study.CODE}, 'Frozen study inputs changed')
    meta, assets = study.catalog()
    by_id = {a['asset_id']: a for a in assets}
    expected = [a['asset_id'] for a in study.select(assets)]
    require(configuration['sample_ids'] == expected and len(expected) == 20, 'Incomplete or changed sample')

    def worker(index, key):
        asset = by_id[key]
        source = Path(configuration['sources'][key]['path'])
        require(study.sha(source) == asset['sha256'], 'Source archive changed')
        folders = [output / f'pair-{index:04d}', *sorted(output.glob(f'pair-{index:04d}-attempt-*'))]
        for folder in folders:
            checkpoint = folder / 'checkpoint.json'
            if not checkpoint.exists(): continue
            row = read(checkpoint)
            require(row['asset_id'] == key and row['source_sha256'] == asset['sha256'], 'Checkpoint belongs to different input')
            require(study.sha(folder / 'source/report.json') == row['source_engine_report_sha256'], 'Source evidence changed')
            for candidate in row['candidates']:
                require(study.sha(candidate['path']) == candidate['sha256'], 'Candidate archive changed')
                if candidate['codec'] == 'best':
                    require(candidate['cold_native_verified'] and study.sha(Path(candidate['path']).parent / 'cold-verify/report.json') == candidate['engine_report_sha256'], 'Candidate evidence changed')
            return row
        folder = output / f'pair-{index:04d}'
        attempt = 0
        while folder.exists():
            attempt += 1
            folder = output / f'pair-{index:04d}-attempt-{attempt}'
        return study.measure(asset, source, folder)

    records = []
    # One project lock owns the temporary source configuration for the whole
    # pool. Each process has separate packs, logs and reports. No cache copy.
    with diagnostic_project(), ThreadPoolExecutor(max_workers=2) as pool:
        pending = [pool.submit(worker, i, key) for i, key in enumerate(expected)]
        for result in as_completed(pending):
            records.append(result.result())
            print(f"LOSSLESS_TEXTURE_RESUMED {len(records)}/20 {records[-1]['asset_id']}", flush=True)
    require(configuration['inputs'] == {p: study.sha(study.ROOT / p) for p in study.CODE}, 'Inputs changed during execution')
    records.sort(key=lambda r: r['asset_id'])
    totals = {label: sum(next(c['bytes'] for c in r['candidates'] if c['codec'] == label) for r in records) for label in ('png', 'webp', 'best')}
    baseline = sum(r['source_bytes'] for r in records)
    selected = sum(min(r['source_bytes'], next(c['bytes'] for c in r['candidates'] if c['codec'] == 'best')) for r in records)
    report = {'schema': 1, 'complete': True, 'sample_complete': True, 'prototype_only': True, 'production_approved': False,
              'baseline_revision': meta['revision'], 'baseline_collection_bytes': meta['total_bundle_bytes'], 'excluded_zip_pairs': 55,
              'pairs': 20, 'source_sample_bytes': baseline, 'source_texture_bytes': sum(r['source_texture_bytes'] for r in records),
              'candidate_sample_bytes': totals, 'saved_sample_bytes': {k: baseline-v for k, v in totals.items()},
              'selected_sample_bytes': selected, 'selected_saved_bytes': baseline-selected,
              'textures': sum(len(r['textures']) for r in records), 'motion_samples': sum(r['motion_samples'] for r in records),
              'configuration_sha256': study.sha(output / 'configuration.json'), 'execution_driver_sha256': study.sha(Path(__file__)),
              'workers': 2, 'records': records}
    write(output / 'report.json', report)
    print('LOSSLESS_TEXTURE_COMPLETE ' + str({k: v for k, v in report.items() if k != 'records'}), flush=True)


if __name__ == '__main__':
    def terminated(signum, _frame):
        raise InterruptedError(f'Texture study interrupted by signal {signum}')
    signal.signal(signal.SIGTERM, terminated)
    signal.signal(signal.SIGHUP, terminated)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    resume(parser.parse_args().output)
