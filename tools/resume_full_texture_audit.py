#!/usr/bin/env python3
"""Resume frozen full-audit encoders with bounded content caching and eight workers."""
import argparse
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
from pathlib import Path
import signal
import struct
import threading

import audit_full_texture_storage as audit
import study_lossless_texture_storage as base
import study_strict_webp_texture_storage as strict
from probe_v13_compression import decode, read, require, write, Zstd
from study_new_pair_geometry import diagnostic_project

original_encode = strict.exact_webp_buffer
cache = OrderedDict()
cache_lock = threading.Lock()
locks = [threading.Lock() for _ in range(1024)]
hits = 0


def cached_encode(row, source):
    global hits
    raw = decode(Path(source).read_bytes(), Zstd())
    header = struct.pack('<HH4I', 0, 2, row['format'], row['mipmaps']+1, row['width'], row['height'])
    start = raw.find(header)
    require(start >= 4 and raw.find(header, start+1) == -1, 'Ambiguous cached PNG buffer')
    length, = struct.unpack_from('<I', raw, start-4)
    require(start+length <= len(raw) and length >= 20, 'Malformed cached PNG boundary')
    key = hashlib.sha256(raw[start:start+length]).hexdigest()
    del raw
    with locks[int(key[:4], 16) % len(locks)]:
        with cache_lock:
            value = cache.get(key)
        if value is None:
            value = original_encode(row, source)
            with cache_lock:
                cache[key] = value
                while len(cache) > 512: cache.popitem(last=False)
        else:
            # Content-identical PNG buffers include format, shape and every
            # authored mip. Every hit also binds the current native source
            # pixel hashes; the final cold Godot proof is never cached.
            require([m['source_sha256'] for m in value[1]] ==
                    [m['source_sha256'] for m in row['codecs']['png']['mips']], 'Cached pixels differ from current source')
            require(len(row['codecs']['png']['mips']) == row['mipmaps']+1 and
                    all(m['width'] == max(1, row['width'] >> i) and m['height'] == max(1, row['height'] >> i)
                        for i,m in enumerate(row['codecs']['png']['mips'])), 'Changed cached mip dimensions')
            with cache_lock: hits += 1
        return value[0], [dict(m) for m in value[1]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    config = read(output/'configuration.json')
    require(config['inputs'] == {p: base.sha(base.ROOT/p) for p in config['inputs']}, 'Frozen encoder inputs changed')
    execution_sha = base.sha(Path(__file__))
    meta, assets = base.catalog()
    assets.sort(key=lambda a: a['asset_id'])
    require(config['asset_ids'] == [a['asset_id'] for a in assets], 'Incomplete frozen collection')
    workers = 8
    rows = []
    strict.exact_webp_buffer = cached_encode
    try:
        with diagnostic_project(), ThreadPoolExecutor(max_workers=workers) as pool:
            jobs = [pool.submit(audit.resume, asset, Path(config['sources'][asset['asset_id']]), output, i)
                    for i, asset in enumerate(assets)]
            try:
                for job in as_completed(jobs):
                    rows.append(job.result())
                    print(f"FULL_TEXTURE_PAIR_OK {len(rows)}/1365 {rows[-1]['asset_id']} "
                          f"saved={sum(r['source_bytes']-r['selected_bytes'] for r in rows)} cache_hits={hits}", flush=True)
            except BaseException:
                for job in jobs: job.cancel()
                raise
    finally: strict.exact_webp_buffer = original_encode
    require(config['inputs'] == {p: base.sha(base.ROOT/p) for p in config['inputs']} and
            execution_sha == base.sha(Path(__file__)), 'Changed audit implementation')
    rows.sort(key=lambda r: r['asset_id'])
    require(len(rows) == 1365 and sum(r['source_bytes'] for r in rows)+126699042 == meta['total_bundle_bytes'], 'Wrong collection coverage')
    saved = sum(r['source_bytes']-r['selected_bytes'] for r in rows)
    report = {'schema': 1, 'complete': True, 'measured_complete': True, 'prototype_only': True,
              'production_approved': False, 'baseline_revision': meta['revision'],
              'baseline_collection_bytes': meta['total_bundle_bytes'], 'retained_zip_pairs': 55,
              'retained_zip_bytes': 126699042, 'pairs': 1365, 'saved_bytes': saved,
              'selected_collection_bytes': meta['total_bundle_bytes']-saved,
              'textures': sum(len(r['textures']) for r in rows),
              'mip_levels': sum(len(t['mips']) for r in rows for t in r['textures']),
              'held_textures': sum(bool(t['hold']) for r in rows for t in r['textures']),
              'configuration_sha256': base.sha(output/'configuration.json'),
              'execution_driver_sha256': execution_sha, 'resumed_workers': workers,
              'content_cache_hits': hits, 'records': rows}
    write(output/'report.json', report)
    print('FULL_TEXTURE_COMPLETE '+str({k:v for k,v in report.items() if k != 'records'}), flush=True)


if __name__ == '__main__':
    def interrupted(signum, _frame):
        raise InterruptedError(f'Audit interrupted by signal {signum}; checkpoints retained')
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    main()
