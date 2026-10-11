#!/usr/bin/env python3
"""Build schema-2 pairs for the strict audit cohort and verify actual installed packs."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import struct
import subprocess
import sys
import time
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/sprite_factory'))
from native_resource_compression_probe import Zstd, decode, encode


CHILDREN = set()
CHILDREN_LOCK = threading.Lock()
CANCELED = threading.Event()


def cancel():
    CANCELED.set()
    with CHILDREN_LOCK:
        for child in CHILDREN: child.terminate()


def sha(path):
    with Path(path).open('rb') as f: return hashlib.file_digest(f, 'sha256').hexdigest()


def read(path): return json.loads(Path(path).read_bytes())
def write(path, data): Path(path).write_text(json.dumps(data, sort_keys=True, separators=(',', ':')) + '\n')


def run(stage, jobs, directory, recipe):
    directory.mkdir(parents=True)
    write(directory / 'input.json', {'jobs': jobs, 'recipe': recipe})
    env = os.environ.copy()
    for name in ('DATA', 'CONFIG', 'CACHE'):
        target = directory / ('xdg-' + name.lower()); target.mkdir()
        env['XDG_' + name + '_HOME'] = str(target)
    command = ['godot', '--headless', '--path', str(ROOT), '--log-file', str(directory / 'engine.log'),
               '--script', 'res://tools/sprite_factory/shared_geometry_collection.gd', '--', stage,
               str(directory / 'input.json'), str(directory / 'output')]
    with (directory / 'process.log').open('w') as log:
        with CHILDREN_LOCK:
            if CANCELED.is_set(): raise RuntimeError('Collection canceled')
            child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
            CHILDREN.add(child)
        try: code = child.wait(timeout=1800)
        except BaseException:
            child.terminate()
            try: child.wait(timeout=10)
            except subprocess.TimeoutExpired: child.kill(); child.wait()
            raise
        finally:
            with CHILDREN_LOCK: CHILDREN.discard(child)
    text = (directory / 'process.log').read_text()
    if code or re.search(r'(?:SCRIPT ERROR|^ERROR:|GEOMETRY_PROTOTYPE_ERROR)', text, re.M):
        raise RuntimeError('Failed ' + str(directory) + '\n' + text[-2500:])
    rows = [json.loads(line) for line in (directory / 'output/records.jsonl').read_text().splitlines()]
    assert len(rows) == len(jobs)
    return rows


def batch(jobs, output, recipe, bindings):
    base = output
    attempt = 0
    while output.exists():
        checkpoint = output / 'checkpoint.json'
        if checkpoint.exists():
            pin = read(checkpoint)
            assert pin['recipe'] == recipe and pin['sources'] == [j['asset']['sha256'] for j in jobs]
            assert sha(output / 'candidates.json') == pin['candidates_sha256']
            rows = read(output / 'candidates.json')
            assert len(rows) == len(jobs)
            for row in rows:
                assert row['verification']['ok'] and sha(row['path']) == row['asset']['sha256']
            return rows
        attempt += 1
        output = base.with_name(base.name + '-attempt-' + str(attempt))
    produced = run('produce', jobs, output / 'produce', recipe)
    codec = Zstd(); pack_jobs = []; candidates = []
    for job, row in zip(jobs, produced, strict=True):
        previous = job['asset']; files = row['files']; appearances = []
        for path in files.values():
            target = Path(path); raw = decode(target.read_bytes(), codec)
            native = encode(raw, 262144, 9, codec); assert decode(native, codec) == raw
            target.write_bytes(native)
        for model, before in zip(row['models'], previous['appearances'], strict=True):
            name = 'models/' + model['variant'] + '.scn'; path = Path(files[name])
            model['candidate_sha256'] = sha(path)
            appearances.append({'variant': model['variant'], 'runtime_identity': model['identity'], 'runtime_path': name,
                'runtime_sha256': sha(path), 'bytes': path.stat().st_size,
                'source_sha256': before.get('source_sha256', before['runtime_sha256']),
                'cache_source_bytes': int(before.get('cache_source_bytes', bindings[model['identity']]['cache_source_bytes'])),
                'semantic_sha256': model['effective_sha256']})
        manifest = {'schema': 2, 'kind': 'pokeaether-model-pair', 'resource_root': row['resource_root'],
            **{k: previous[k] for k in ('asset_id', 'species_id', 'form_id', 'dependencies')},
            'version': int(previous['version']) + 1, 'appearances': appearances,
            'files': [{'path': name, 'bytes': Path(path).stat().st_size, 'sha256': sha(path),
                       'decoded_bytes': struct.unpack_from('<I', Path(path).read_bytes(), 12)[0]}
                      for name, path in sorted(files.items())]}
        assert 2 <= len(manifest['files']) < 128, previous['asset_id']
        manifest_path = Path(files['models/normal.scn']).parent.parent / 'bundle.json'
        write(manifest_path, manifest); files['bundle.json'] = str(manifest_path)
        path = output / (str(len(pack_jobs)) + '.pck')
        pack_jobs.append({'resource_root': row['resource_root'], 'files': files, 'path': str(path)})
        asset = {k: v for k, v in previous.items() if k not in ('sha256', 'size_bytes', 'object_key', 'appearances', 'version', 'pair_manifest')}
        asset.update(format='model-pair-pck-v1', version=manifest['version'], appearances=appearances, pair_manifest=manifest)
        candidates.append({'asset': asset, 'path': str(path), 'models': row['models'], 'baseline_bytes': int(previous['size_bytes'])})
    run('pack', pack_jobs, output / 'pack', recipe)
    for row in candidates:
        path = Path(row['path']); asset = row['asset']; asset.update(sha256=sha(path), size_bytes=path.stat().st_size)
        name = f'v{asset["version"]}-{asset["sha256"]}.pck'
        asset['object_key'] = f'optional-assets/pokemon_3d/{asset["species_id"]}/{asset["form_id"]}/{name}'
        target = output / name; path.rename(target); row['path'] = str(target)
    verified = run('verify', candidates, output / 'verify', recipe)
    for row, checked in zip(candidates, verified, strict=True):
        assert checked['ok'] and checked['asset_id'] == row['asset']['asset_id']
        row['verification'] = checked
        row['smaller'] = row['asset']['size_bytes'] < row['baseline_bytes']
    write(output / 'candidates.json', candidates)
    write(output / 'checkpoint.json', {'recipe': recipe, 'sources': [j['asset']['sha256'] for j in jobs], 'candidates_sha256': sha(output / 'candidates.json')})
    return candidates


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--audit', type=Path, required=True); p.add_argument('--sources', type=Path, required=True)
    p.add_argument('--resume', action='store_true')
    p.add_argument('--output', type=Path, required=True); p.add_argument('--limit', type=int)
    p.add_argument('--asset', action='append', default=[]); p.add_argument('--workers', type=int, choices=(1, 2), default=2)
    args = p.parse_args()
    assert os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name, 'Use slot-env'
    output = args.output.resolve(); output.relative_to(ROOT / '.tmp'); output.mkdir(parents=True, exist_ok=args.resume)
    audit = read(args.audit)
    assert sha(args.audit) == read(ROOT / 'release/shared_model_geometry_research.json')['evidence']['.tmp/shared-geometry/full-v2/report.json']
    source_map = read(args.sources)['sources']; wire = read(ROOT / 'data/model_pair_qualified.json')
    full = {a['asset_id']: a for a in read(ROOT / 'data/model_pair_catalog.json')['assets']}
    assets = {a['asset_id']: full[a['asset_id']] if a.get('format') == 'model-pair-ref-v1' else a for a in wire['assets']}
    eligible = [r for r in audit['records'] if all(r[k] for k in ('same_structure', 'same_skeleton', 'same_mesh_bindings', 'same_skin_bindings', 'same_animation_bindings')) and not any(v['sensitive_tracks'] for v in r['variants'])]
    assert len(eligible) == 1031
    if args.asset: eligible = [r for r in eligible if r['asset_id'] in args.asset]; assert len(eligible) == len(args.asset)
    if args.limit: eligible = eligible[:args.limit]
    jobs = []
    for row in eligible:
        asset = assets[row['asset_id']]; source = Path(source_map[row['asset_id']])
        assert asset['sha256'] == row['source_sha256'] == sha(source)
        jobs.append({'asset': asset, 'source': str(source)})
    pins = {str(path.relative_to(ROOT)): sha(path) for path in [Path(__file__), ROOT / 'tools/sprite_factory/shared_geometry_collection.gd', ROOT / 'tools/sprite_factory/shared_geometry_prototype.gd', ROOT / 'tools/sprite_factory/model_geometry_audit.gd', ROOT / 'tools/sprite_factory/model_texture_audit.gd', ROOT / 'scripts/services/model_pair_pack.gd', ROOT / 'tools/sprite_factory/native_resource_compression_probe.py', ROOT / 'data/model_pair_qualified.json', ROOT / 'data/model_pair_catalog.json', ROOT / 'release/approved_3d_lossless_binding.json']}
    recipe = hashlib.sha256(json.dumps(pins, sort_keys=True).encode()).hexdigest()
    source_commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    configuration = {'source_commit': source_commit, 'inputs': pins, 'recipe': recipe, 'pairs': len(jobs), 'audit_sha256': sha(args.audit), 'asset_ids': [j['asset']['asset_id'] for j in jobs]}
    if args.resume: assert read(output / 'configuration.json') == configuration, 'Frozen inputs changed'
    else: write(output / 'configuration.json', configuration)
    lock = (ROOT / '.tmp/diagnostic-project.lock').open('a+'); fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    project = ROOT / 'project.godot'; original = project.read_bytes()
    config = re.sub(r'\[autoload\].*?(?=\n\[)', '', original.decode(), flags=re.S)
    config = re.sub(r'\[editor_plugins\].*?(?=\n\[)', '', config, flags=re.S)
    def interrupt(_signal, _frame):
        cancel()
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupt)
    bindings = read(ROOT / 'release/approved_3d_lossless_binding.json')['models']; results = []; started = time.monotonic()
    try:
        project.write_text(config)
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            futures = [pool.submit(batch, jobs[i:i+10], output / f'batch-{i:04}', recipe, bindings) for i in range(0, len(jobs), 10)]
            try:
                for future in as_completed(futures):
                    results.extend(future.result()); print('GEOMETRY_BUILT', len(results), '/', len(jobs), flush=True)
            except BaseException:
                cancel()
                for future in futures: future.cancel()
                raise
    finally:
        project.write_bytes(original); lock.close()
    assert pins == {name: sha(ROOT / name) for name in pins}
    results.sort(key=lambda r: r['asset']['asset_id']); selected = [r for r in results if r['smaller']]
    replaced = {r['asset']['asset_id']: r for r in selected}
    index = dict(wire, catalog_revision='shared-geometry-test-v1', prototype_only=True, production_approved=False)
    index.pop('qualification_sha256', None)
    index['assets'] = [{'format': 'model-pair-ref-v1', 'asset_id': a['asset_id'], 'sha256': replaced[a['asset_id']]['asset']['sha256']} if a['asset_id'] in replaced else a for a in wire['assets']]
    write(output / 'catalog.json', {'schema': 1, 'assets': [r['asset'] for r in selected]})
    write(output / 'index.json', index)
    write(output / 'sources.json', {'sources': {key: replaced[key]['path'] if key in replaced else value for key, value in source_map.items()}})
    report = {'complete': len(results) == len(jobs), 'prototype_only': True, 'production_approved': False, 'pairs_built': len(results), 'pairs_smaller': len(selected), 'saved_download_bytes': sum(r['baseline_bytes'] - r['asset']['size_bytes'] for r in selected), 'source_commit': source_commit, 'motion_samples': sum(r['verification']['motion_samples'] for r in results), 'elapsed_seconds': time.monotonic()-started, 'inputs': pins, 'records': results}
    write(output / 'report.json', report)
    print('GEOMETRY_COLLECTION_OK', json.dumps({k:v for k,v in report.items() if k not in ('records','inputs')}), flush=True)

if __name__ == '__main__': main()
