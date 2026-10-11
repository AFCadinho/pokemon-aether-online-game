#!/usr/bin/env python3
"""Compare exact normal/shiny geometry, skin and animation resources offline."""
import argparse
import concurrent.futures
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/sprite_factory'))
from native_resource_compression_probe import Zstd, decode, encode


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(Path(path).read_bytes())


def run_batch(batch, work):
    directory = work / f'batch-{batch[0]:04}'
    directory.mkdir()
    inputs = directory / 'input.json'
    inputs.write_text(json.dumps({'jobs': batch[1]}, separators=(',', ':')) + '\n')
    env = os.environ.copy()
    for name in ('DATA', 'CONFIG', 'CACHE'):
        path = directory / ('xdg-' + name.lower())
        path.mkdir()
        env['XDG_' + name + '_HOME'] = str(path)
    started = time.monotonic()
    command = ['godot', '--headless', '--path', str(ROOT), '--log-file', str(directory / 'engine.log'),
               '--script', 'res://tools/sprite_factory/shared_geometry_catalog_probe.gd',
               '--', str(inputs), str(directory / 'output')]
    with (directory / 'process.log').open('w') as log:
        child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
        try:
            code = child.wait(timeout=1200)
        except BaseException:
            child.terminate()
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
            raise
    text = (directory / 'process.log').read_text()
    if code or re.search(r'(?:SCRIPT ERROR|^ERROR:|GEOMETRY_PROBE_ERROR)', text, re.M):
        raise RuntimeError('Godot batch failed: ' + str(directory))
    rows = [json.loads(line) for line in (directory / 'output/records.jsonl').read_text().splitlines()]
    if len(rows) != len(batch[1]):
        raise RuntimeError('Incomplete batch: ' + str(directory))
    codec = Zstd()
    for row in rows:
        row['duplicate_standalone_bytes'] = {}
        row['exact_cross_variant_components'] = {}
        for category, components in row['components'].items():
            duplicate_bytes, count = 0, 0
            for component in components.values():
                payload = Path(component['path']).read_bytes()
                raw = decode(payload, codec)
                native = encode(raw, 262144, 9, codec)
                if decode(native, codec) != raw:
                    raise ValueError('Compression changed resource bytes')
                component['native_bytes'] = len(native)
                component['native_sha256'] = hashlib.sha256(native).hexdigest()
                if component['shareable'] and set(component['variants']) == {'normal', 'shiny'}:
                    count += 1
                    duplicate_bytes += len(native)
            row['duplicate_standalone_bytes'][category] = duplicate_bytes
            row['exact_cross_variant_components'][category] = count
    execution = {'input_sha256': sha(inputs), 'process_log_sha256': sha(directory / 'process.log'),
                 'engine_log_sha256': sha(directory / 'engine.log'), 'exit_code': code,
                 'elapsed_seconds': time.monotonic() - started, 'pairs': len(rows)}
    (directory / 'execution.json').write_text(json.dumps(execution, indent=2) + '\n')
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--limit', type=int)
    parser.add_argument('--asset', action='append', default=[])
    parser.add_argument('--workers', type=int, default=2, choices=(1, 2))
    parser.add_argument('--batch-size', type=int, default=20)
    args = parser.parse_args()
    if os.environ.get('POKEAETHER_SLOT') != ROOT.parent.name:
        parser.error('Use slot-env for the assigned slot')
    if args.batch_size not in range(1, 41):
        parser.error('Batch size must be between 1 and 40')
    output = args.output.resolve()
    output.relative_to(ROOT / '.tmp')
    output.mkdir(parents=True, exist_ok=False)
    sources = read(args.sources)['sources']
    wire = read(ROOT / 'data/model_pair_qualified.json')
    full = {a['asset_id']: a for a in read(ROOT / 'data/model_pair_catalog.json')['assets']}
    published = read(ROOT / 'release/shared_model_collection_r2_receipt.json')
    assert published['content_index']['sha256'] == sha(ROOT / 'data/model_pair_qualified.json')
    rows = {a['asset_id']: a for a in published['bundles']}
    jobs = []
    for compact in wire['assets']:
        asset = full[compact['asset_id']] if compact.get('format') == 'model-pair-ref-v1' else compact
        if args.asset and asset['asset_id'] not in args.asset:
            continue
        assert all(rows[asset['asset_id']][k] == asset[k] for k in ('sha256', 'object_key', 'size_bytes'))
        path = Path(sources[asset['asset_id']])
        assert path.is_absolute() and path.is_file() and not path.is_symlink()
        assert path.stat().st_size == asset['size_bytes']
        jobs.append({'asset': asset, 'source': str(path)})
    if args.limit:
        jobs = jobs[:args.limit]
    assert jobs and (not args.asset or len(jobs) == len(args.asset))
    files = ['tools/audit_shared_geometry.py', 'tools/sprite_factory/model_geometry_audit.gd',
             'tools/sprite_factory/shared_geometry_catalog_probe.gd', 'tools/sprite_factory/model_texture_audit.gd',
             'tools/sprite_factory/native_resource_compression_probe.py', 'data/model_pair_qualified.json',
             'data/model_pair_catalog.json', 'release/shared_model_collection_r2_receipt.json']
    input_hashes = {name: sha(ROOT / name) for name in files}
    source_commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    (output / 'configuration.json').write_text(json.dumps({'source_commit': source_commit, 'inputs': input_hashes,
        'pairs': len(jobs), 'workers': args.workers, 'batch_size': args.batch_size}, indent=2) + '\n')
    lock = (ROOT / '.tmp/diagnostic-project.lock').open('a+')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    project = ROOT / 'project.godot'
    original = project.read_bytes()
    config = re.sub(r'\[autoload\].*?(?=\n\[)', '', original.decode(), flags=re.S)
    config = re.sub(r'\[editor_plugins\].*?(?=\n\[)', '', config, flags=re.S)
    def interrupt(_signal, _frame):
        raise KeyboardInterrupt('Audit interrupted; restoring assigned project')
    signal.signal(signal.SIGTERM, interrupt)
    started = time.monotonic()
    results = []
    try:
        project.write_text(config)
        batches = [(i, jobs[i:i + args.batch_size]) for i in range(0, len(jobs), args.batch_size)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            pending = [pool.submit(run_batch, batch, output) for batch in batches]
            for future in concurrent.futures.as_completed(pending):
                results.extend(future.result())
                print('GEOMETRY_AUDITED', len(results), '/', len(jobs), flush=True)
    finally:
        project.write_bytes(original)
        lock.close()
    assert {name: sha(ROOT / name) for name in files} == input_hashes
    results.sort(key=lambda r: r['asset_id'])
    totals = {kind: sum(r['duplicate_standalone_bytes'][kind] for r in results) for kind in ('meshes', 'skins', 'libraries')}
    report = {'schema': 1, 'complete': len(results) == len(jobs), 'scope': 'Exact offline component comparison; no runtime or production approval',
              'pairs': len(results), 'same_structure_pairs': sum(r['same_structure'] for r in results),
              'same_skeleton_pairs': sum(r['same_skeleton'] for r in results),
              'same_mesh_binding_pairs': sum(r['same_mesh_bindings'] for r in results),
              'same_skin_binding_pairs': sum(r['same_skin_bindings'] for r in results),
              'same_animation_binding_pairs': sum(r['same_animation_bindings'] for r in results),
              'same_nonmaterial_model_pairs': sum(all(r[k] for k in ('same_structure', 'same_mesh_bindings', 'same_skin_bindings', 'same_animation_bindings', 'same_skeleton')) for r in results),
              'pairs_with_cross_variant_duplicates': {kind: sum(r['exact_cross_variant_components'][kind] > 0 for r in results) for kind in totals},
              'standalone_duplicate_bytes': totals,
              'measurement_note': 'Standalone native resources, Zstd level 9/block 262144. These sizes indicate duplicate components, not exact total pack savings.',
              'source_commit': source_commit, 'inputs': input_hashes, 'elapsed_seconds': time.monotonic() - started, 'records': results}
    (output / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print('SHARED_GEOMETRY_AUDIT_OK', json.dumps({k: v for k, v in report.items() if k not in ('records', 'inputs')}), flush=True)


if __name__ == '__main__':
    main()
