#!/usr/bin/env python3
"""Resume the frozen new-pair study with two isolated native worker processes.

Uses the same immutable inputs, native producer, validator and checkpoint checks
as the serial study. GPU PNG comparisons remain sequential and separate.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import os
from pathlib import Path
import signal
import time

import study_new_pair_geometry as study


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--audit', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    study.require(os.environ.get('POKEAETHER_SLOT') == study.ROOT.parent.name, 'Use slot-env')
    output = args.output.resolve()
    output.relative_to(study.ROOT / '.tmp')
    meta, jobs = study.jobs_from_sources(args.sources)
    audit = study.read(args.audit / 'report.json')
    frozen = study.pins()
    study.require(audit['complete'] and audit['inputs'] == frozen, 'Unbound audit')
    audited = {r['asset_id']: r for r in audit['records']}
    eligible = [j for j in jobs if not study.hold_reasons(audited[j['asset']['asset_id']])]
    recipe = hashlib.sha256(study.encoded(frozen)).hexdigest()
    configuration = {'recipe': recipe, 'audit_sha256': study.release.sha(args.audit / 'report.json'),
                     'asset_ids': [j['asset']['asset_id'] for j in eligible]}
    study.require(study.read(output / 'configuration.json') == configuration, 'Resume configuration mismatch')
    driver_sha256 = study.release.sha(__file__)
    started = time.monotonic()

    def worker(index, job):
        study.require(audited[job['asset']['asset_id']]['source_sha256'] == job['asset']['sha256'], 'Audit source mismatch')
        base = output / f'pair-{index:04}'
        attempts = [base, *sorted(output.glob(f'pair-{index:04}-attempt-*'))]
        for attempt in attempts:
            checkpoint = attempt / 'checkpoint.json'
            if checkpoint.exists():
                row = study.read(checkpoint)
                study.require(row['recipe'] == recipe and row['baseline_sha256'] == job['asset']['sha256'], 'Changed checkpoint')
                study.checked_bytes(row['path'], row['asset'])
                study.require(row['verification']['ok'] and row['verification']['asset_id'] == job['asset']['asset_id'], 'Unverified checkpoint')
                return row
        directory = base
        attempt = 0
        while directory.exists():
            attempt += 1
            directory = output / f'pair-{index:04}-attempt-{attempt}'
        return study.build_one(job, directory, recipe)

    results = []
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    with study.diagnostic_project(), ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(worker, i, job) for i, job in enumerate(eligible)]
        try:
            for future in as_completed(futures):
                row = future.result()
                results.append(row)
                study.write(output / 'progress.json', {'completed_pairs': len(results), 'pairs': len(eligible),
                            'saved_bytes_so_far': sum(r['baseline_bytes']-r['asset']['size_bytes'] for r in results if r['smaller'])})
                print(f"NEW_PAIR_BUILT {len(results)}/{len(eligible)} {row['asset']['asset_id']} saved={row['baseline_bytes']-row['asset']['size_bytes']}", flush=True)
        except BaseException:
            for future in futures:
                future.cancel()
            raise
    study.require(study.pins() == frozen and study.release.sha(__file__) == driver_sha256, 'Study implementation changed')
    study.require(len(results) == audit['eligible_pairs'] == len({r['asset']['asset_id'] for r in results}), 'Incomplete cohort')
    results.sort(key=lambda r: r['asset']['asset_id'])
    selected = [r for r in results if r['smaller']]
    saved = sum(r['baseline_bytes']-r['asset']['size_bytes'] for r in selected)
    report = {'schema': 1, 'complete': True, 'prototype_only': True, 'production_approved': False,
              'source_collection_bytes': meta['total_bundle_bytes'], 'selected_collection_bytes': meta['total_bundle_bytes']-saved,
              'eligible_pairs': audit['eligible_pairs'], 'pairs_built': len(results), 'pairs_smaller': len(selected),
              'saved_download_bytes': saved, 'source_cohort_bytes': audit['source_cohort_bytes'],
              'motion_samples': sum(r['verification']['motion_samples'] for r in results),
              'decoded_members_byte_exact': sum(r['decoded_members_byte_exact'] for r in results),
              'inputs': frozen, 'execution_driver_sha256': driver_sha256,
              'elapsed_resume_seconds': time.monotonic()-started, 'configuration': configuration,
              'holds': audit['holds'], 'records': results}
    study.write(output / 'report.json', report)
    print(f'NEW_PAIR_BUILD_OK pairs={len(results)} smaller={len(selected)} saved={saved}', flush=True)


if __name__ == '__main__':
    main()
