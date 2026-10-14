#!/usr/bin/env python3
"""Measure every v15 external texture without changing deployed asset bindings."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
from pathlib import Path
import signal
import subprocess

from PIL import features
import study_lossless_texture_storage as base
import study_strict_webp_texture_storage as strict
from portable_texture_buffer import replace_buffer
from probe_v13_compression import checked_bytes, decode, encode, read, require, unpack_pck, write, Zstd
from study_new_pair_geometry import diagnostic_project

SCRIPT = 'tools/sprite_factory/full_texture_storage_audit.gd'
CODE = list(dict.fromkeys([*base.CODE, SCRIPT, strict.SCRIPT,
                          'tools/study_strict_webp_texture_storage.py', 'tools/portable_texture_buffer.py',
                          'tools/audit_full_texture_storage.py']))


def native_run(mode, config, output, script=SCRIPT):
    output.mkdir(parents=True, exist_ok=False)
    job = output / 'input.json'
    write(job, config)
    log = output / 'engine.stdout.log'
    command = ['godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
               '--path', str(base.ROOT), '--log-file', str(output/'engine.log'),
               '--script', 'res://'+script, '--', mode, str(job), str(output)]
    with log.open('w') as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
    text = log.read_text()
    require(result.returncode == 0 and 'LOSSLESS_TEXTURE_ENGINE_OK' in text and
            'ERROR:' not in text and 'SCRIPT ERROR' not in text, f'Native audit failed: {log}')
    report = read(output/'report.json')
    require(report['complete'] and report['input_sha256'] == base.sha(job) and
            report['pack_sha256'] == config['asset']['sha256'], 'Unbound native evidence')
    return report


def measure(asset, path, folder):
    folder.mkdir()
    original = checked_bytes(path, asset)
    members, _ = unpack_pck(original, asset)
    source = native_run('encode', {'asset': asset, 'path': str(path)}, folder/'source')
    expected = {r['path'] for r in asset['pair_manifest']['files'] if r['path'].startswith('textures/')}
    require({r['path'] for r in source['textures']} == expected, 'Missing source textures')
    codec = Zstd()
    choices, evidence = {}, []
    for row in source['textures']:
        name = row['path']
        choices[name] = [('original', members[name])]
        receipt = {'path': name, 'source_bytes': len(members[name]), 'source_sha256': hashlib.sha256(members[name]).hexdigest(),
                   'state_signature': row['state_signature'], 'hold': row.get('hold'), 'mips': []}
        png = row['codecs'].get('png', {})
        if png.get('exact'):
            raw = decode(Path(png['path']).read_bytes(), codec)
            packed = encode(raw, 262144, 19, codec)
            require(decode(packed, codec) == raw, 'PNG framing changed resource')
            choices[name].append(('png', packed))
            buffer, mips = strict.exact_webp_buffer(row, png['path'])
            webp_raw, other_bytes_sha256 = replace_buffer(raw, row, buffer)
            webp_packed = encode(webp_raw, 262144, 19, codec)
            require(decode(webp_packed, codec) == webp_raw, 'WebP framing changed resource')
            choices[name].append(('strict_webp', webp_packed))
            receipt['non_buffer_raw_sha256'] = other_bytes_sha256
            receipt['webp_buffer_sha256'] = hashlib.sha256(buffer).hexdigest()
            receipt['mips'] = mips
        elif not receipt['hold']:
            receipt['hold'] = 'png_roundtrip_not_exact'
        evidence.append(receipt)
    replacements = {}
    for row in evidence:
        name = row['path']
        label, payload = min(choices[name], key=lambda c: (len(c[1]), c[0]))
        row.update(selected=label, selected_bytes=len(payload), selected_sha256=hashlib.sha256(payload).hexdigest(),
                   alternatives={k: len(v) for k, v in choices[name]})
        if label != 'original': replacements[name] = payload
    candidate, candidate_path = base.rewrite_pack(asset, original, replacements, folder)
    verified = native_run('verify', {'asset': candidate, 'path': str(candidate_path)}, folder/'cold')
    require({r['path']: r['state_signature'] for r in verified['textures']} ==
            {r['path']: r['state_signature'] for r in source['textures']}, 'Cold decoded texture changed')
    require(all(r['deep_duplicate_exact'] for r in verified['textures']), 'Cold deep duplicate changed')
    require(base.sha(path) == asset['sha256'], 'Source changed during audit')
    record = {'asset_id': asset['asset_id'], 'source_bytes': len(original), 'source_sha256': asset['sha256'],
              'candidate_bytes': candidate['size_bytes'], 'selected_bytes': min(len(original), candidate['size_bytes']),
              'path': str(candidate_path), 'sha256': candidate['sha256'], 'textures': evidence,
              'native_non_texture_bytes_exact': True, 'cold_native_verified': True,
              'source_report_sha256': base.sha(folder/'source/report.json'),
              'cold_report_sha256': base.sha(folder/'cold/report.json')}
    write(folder/'checkpoint.json', record)
    return record


def resume(asset, source, output, index):
    found = list(output.glob(f'pair-{index:04d}*/checkpoint.json'))
    require(len(found) <= 1, 'Ambiguous checkpoint')
    if found:
        row = read(found[0])
        require(row['asset_id'] == asset['asset_id'] and row['source_sha256'] == asset['sha256'] and
                row['source_bytes'] == asset['size_bytes'] and base.sha(source) == asset['sha256'], 'Unbound checkpoint')
        require(row['cold_native_verified'] and row['native_non_texture_bytes_exact'] and
                base.sha(row['path']) == row['sha256'], 'Changed candidate')
        for name in ('source', 'cold'):
            require(base.sha(found[0].parent/name/'report.json') == row[name+'_report_sha256'], 'Changed native evidence')
        return row
    folder = output/f'pair-{index:04d}'
    attempt = 0
    while folder.exists():
        attempt += 1
        folder = output/f'pair-{index:04d}-attempt-{attempt}'
    return measure(asset, source, folder)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=4, choices=range(1, 9))
    parser.add_argument('--limit', type=int)
    args = parser.parse_args()
    meta, assets = base.catalog()
    external_ids = {a['asset_id'] for a in assets}
    retained_zip = [a for a in meta['bundles'] if a['asset_id'] not in external_ids]
    require(len(retained_zip) == 55 and sum(a['size_bytes'] for a in retained_zip) == 126699042,
            'Changed retained ZIP cohort')
    assets.sort(key=lambda a: a['asset_id'])
    if args.limit is not None:
        require(args.limit > 0, 'Positive pilot limit required')
        assets = assets[:args.limit]
    mapping = read(args.sources)
    require(mapping['revision'] == meta['revision'] and mapping['metadata_sha256'] ==
            base.sha(base.ROOT/'release/approved_3d_bundles_v15.json'), 'Wrong source map')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    # Keep offline artifacts out of Godot's UID/project scan. Read-only pack
    # access and explicitly addressed probe scripts still work normally.
    (base.ROOT/'.tmp/.gdignore').touch(exist_ok=True)
    for asset in retained_zip:
        checked_bytes(mapping['sources'][asset['asset_id']], asset)
    configuration = {'schema': 1, 'revision': meta['revision'], 'inputs': {p: base.sha(base.ROOT/p) for p in CODE},
                     'asset_ids': [a['asset_id'] for a in assets], 'source_map_sha256': base.sha(args.sources),
                     'sources': {a['asset_id']: mapping['sources'][a['asset_id']] for a in assets},
                     'webp_library': features.version('webp'), 'zstd_level': 19, 'zstd_block_size': 262144,
                     'webp_method': 6, 'webp_lossless': True, 'webp_exact': True,
                     'native_keep_all_compressed_buffers': True, 'workers': args.workers}
    if (output/'configuration.json').exists():
        require(read(output/'configuration.json') == configuration, 'Changed audit configuration')
    else: write(output/'configuration.json', configuration)
    records = []
    with diagnostic_project(), ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = [pool.submit(resume, a, Path(mapping['sources'][a['asset_id']]), output, i) for i, a in enumerate(assets)]
        for future in as_completed(futures):
            try: records.append(future.result())
            except BaseException:
                for pending in futures: pending.cancel()
                raise
            print(f"FULL_TEXTURE_PAIR_OK {len(records)}/{len(assets)} {records[-1]['asset_id']} "
                  f"saved={sum(r['source_bytes']-r['selected_bytes'] for r in records)}", flush=True)
    require(configuration['inputs'] == {p: base.sha(base.ROOT/p) for p in CODE}, 'Changed audit code')
    records.sort(key=lambda r: r['asset_id'])
    saved = sum(r['source_bytes']-r['selected_bytes'] for r in records)
    require([r['asset_id'] for r in records] == configuration['asset_ids'], 'Missing or duplicate result')
    if len(records) == 1365:
        require(sum(r['source_bytes'] for r in records)+126699042 == meta['total_bundle_bytes'], 'Wrong whole-catalog baseline')
    report = {'schema': 1, 'complete': len(records) == 1365, 'measured_complete': len(records) == len(assets),
              'prototype_only': True, 'production_approved': False, 'baseline_revision': meta['revision'],
              'baseline_collection_bytes': meta['total_bundle_bytes'], 'retained_zip_pairs': 55,
              'retained_zip_bytes': 126699042, 'pairs': len(records), 'saved_bytes': saved,
              'selected_collection_bytes': meta['total_bundle_bytes']-saved,
              'textures': sum(len(r['textures']) for r in records),
              'mip_levels': sum(len(t['mips']) for r in records for t in r['textures']),
              'held_textures': sum(bool(t['hold']) for r in records for t in r['textures']),
              'configuration_sha256': base.sha(output/'configuration.json'), 'records': records}
    write(output/'report.json', report)
    print('FULL_TEXTURE_COMPLETE '+str({k:v for k,v in report.items() if k != 'records'}), flush=True)


if __name__ == '__main__':
    def interrupted(signum, _frame):
        raise InterruptedError(f'Audit interrupted by signal {signum}; checkpoints retained')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    main()
