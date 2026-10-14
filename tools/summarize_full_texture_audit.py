#!/usr/bin/env python3
"""Validate the finished physical audit and measure remaining duplicate payloads."""
import argparse
from collections import defaultdict
from pathlib import Path
import study_lossless_texture_storage as base
from probe_v13_compression import checked_bytes, read, require, unpack_pck, write


def summarize(path):
    report = read(path)
    configuration = read(path.parent/'configuration.json')
    require(report['complete'] and report['measured_complete'] and report['pairs'] == 1365,
            'A partial audit cannot establish a whole-collection result')
    require(base.sha(path.parent/'configuration.json') == report['configuration_sha256'], 'Changed configuration')
    require(configuration['inputs'] == {p: base.sha(base.ROOT/p) for p in configuration['inputs']}, 'Changed audit code')
    if 'execution_driver_sha256' in report:
        require(base.sha(base.ROOT/'tools/resume_full_texture_audit.py') == report['execution_driver_sha256'], 'Changed resume driver')
    if 'isolated_execution_driver_sha256' in report:
        require(base.sha(base.ROOT/'tools/resume_isolated_texture_audit.py') == report['isolated_execution_driver_sha256'], 'Changed isolation driver')
        require(report['isolation_inputs'] == {p: base.sha(base.ROOT/p) for p in report['isolation_inputs']}, 'Changed isolated scripts')
        require(base.sha(Path(report['isolated_project_path'])/'project.godot') == report['isolated_project_sha256'], 'Changed isolated configuration')
    meta, assets = base.catalog()
    by_id = {a['asset_id']: a for a in assets}
    rows = report['records']
    require(sorted(r['asset_id'] for r in rows) == sorted(by_id), 'Duplicate or missing model pair')
    groups = defaultdict(list)
    for row in rows:
        asset = by_id[row['asset_id']]
        require(row['source_sha256'] == asset['sha256'] and row['source_bytes'] == asset['size_bytes'], 'Unbound original')
        original_members, _ = unpack_pck(checked_bytes(configuration['sources'][row['asset_id']], asset), asset)
        candidate = read(Path(row['path']).parent/'asset.json')
        require(row['candidate_bytes'] == candidate['size_bytes'] and row['sha256'] == candidate['sha256'], 'Unbound candidate')
        candidate_members, _ = unpack_pck(checked_bytes(row['path'], candidate), candidate)
        require(row['selected_bytes'] == min(row['source_bytes'], row['candidate_bytes']) and
                row['cold_native_verified'] and row['native_non_texture_bytes_exact'], 'Unqualified selection')
        for name in ('source', 'cold'):
            require(base.sha(Path(row['path']).parent/name/'report.json') == row[name+'_report_sha256'], 'Changed native proof')
        source = read(Path(row['path']).parent/'source/report.json')
        cold = read(Path(row['path']).parent/'cold/report.json')
        expected_states = {t['path']: t['state_signature'] for t in row['textures']}
        require({t['path']: t['state_signature'] for t in source['textures']} == expected_states and
                {t['path']: t['state_signature'] for t in cold['textures']} == expected_states and
                all(t['deep_duplicate_exact'] for t in cold['textures']), 'Changed native texture state')
        require(all(candidate_members[k] == v for k,v in original_members.items()
                    if k != 'bundle.json' and not k.startswith('textures/')), 'Changed non-texture bytes')
        require({t['path'] for t in row['textures']} ==
                {f['path'] for f in asset['pair_manifest']['files'] if f['path'].startswith('textures/')}, 'Missing texture')
        for texture in row['textures']:
            require(len(original_members[texture['path']]) == texture['source_bytes'] and
                    len(candidate_members[texture['path']]) == texture['selected_bytes'], 'Wrong texture payload sizes')
            require(all(m['source_sha256'] == m['decoded_sha256'] for m in texture['mips']), 'Changed decoded mip')
            effective_bytes = texture['selected_bytes'] if row['candidate_bytes'] <= row['source_bytes'] else texture['source_bytes']
            groups[texture['state_signature']].append({'asset_id': row['asset_id'], 'path': texture['path'], 'bytes': effective_bytes})
    saved = sum(r['source_bytes']-r['selected_bytes'] for r in rows)
    require(report['textures'] == sum(len(r['textures']) for r in rows) and
            report['mip_levels'] == sum(len(t['mips']) for r in rows for t in r['textures']) and
            report['held_textures'] == sum(bool(t['hold']) for r in rows for t in r['textures']), 'Wrong texture totals')
    require(saved == report['saved_bytes'] and sum(r['source_bytes'] for r in rows)+126699042 == meta['total_bundle_bytes'],
            'Wrong physical total')
    selected = meta['total_bundle_bytes']-saved
    require(selected == report['selected_collection_bytes'], 'Wrong selected collection total')
    # A remaining opportunity indicator, never added to measured pack savings.
    # Shared-pool framing and scene/catalog rebinding have not been built here.
    duplicates = [{'state_signature': key, 'occurrences': len(group),
                   'duplicate_payload_bytes': sum(r['bytes'] for r in group)-min(r['bytes'] for r in group),
                   'references': group}
                  for key, group in groups.items() if len({r['asset_id'] for r in group}) > 1]
    duplicates.sort(key=lambda g: (-g['duplicate_payload_bytes'], g['state_signature']))
    opportunity = sum(g['duplicate_payload_bytes'] for g in duplicates)
    return {'schema': 1, 'complete': True, 'prototype_only': True, 'production_approved': False,
            'baseline_revision': meta['revision'], 'baseline_collection_bytes': meta['total_bundle_bytes'],
            'selected_collection_bytes': selected, 'saved_bytes': saved, 'pairs': 1420,
            'measured_pck_pairs': 1365, 'retained_zip_pairs': 55, 'retained_zip_bytes': 126699042,
            'textures': report['textures'], 'mip_levels': report['mip_levels'], 'held_textures': report['held_textures'],
            'under_7_decimal_gb': selected < 7000000000,
            'remaining_cross_form_duplicate_payload_bytes': opportunity,
            'remaining_cross_form_groups': len(duplicates),
            'optimistic_bytes_before_unbuilt_shared_pool_overhead': selected-opportunity,
            'cross_form_sharing_is_measured_release_saving': False,
            'report_path': str(path.resolve()), 'report_sha256': base.sha(path),
            'configuration_sha256': report['configuration_sha256'], 'inputs': configuration['inputs'],
            'execution_driver_sha256': report.get('execution_driver_sha256'),
            'resumed_workers': report.get('resumed_workers'), 'content_cache_hits': report.get('content_cache_hits'),
            'isolated_execution_driver_sha256': report.get('isolated_execution_driver_sha256'),
            'isolated_project_sha256': report.get('isolated_project_sha256'), 'isolation_inputs': report.get('isolation_inputs'),
            'records': [{k:r[k] for k in ('asset_id', 'source_bytes', 'source_sha256', 'candidate_bytes',
                                         'selected_bytes', 'sha256', 'source_report_sha256', 'cold_report_sha256')}
                        for r in rows], 'duplicate_groups': duplicates}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = summarize(args.report)
    result['summary_driver_sha256'] = base.sha(Path(__file__))
    write(args.output, result)
    print('FULL_TEXTURE_RECEIPT_OK '+str({k:v for k,v in result.items() if k not in ('records','duplicate_groups','inputs')}))


if __name__ == '__main__': main()
