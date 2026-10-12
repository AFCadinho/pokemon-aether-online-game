#!/usr/bin/env python3
"""Resumable, offline full-v13 measurement at native 256 KiB / Zstd level 19.

Every persisted candidate is independently decoded and compared with its pinned
source. Only smaller complete archives contribute to the proposed total. Engine
admission is a separate cold-load check, not a production activation or rollout.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import copy
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import zipfile

from probe_v13_compression import (ROOT, PIN_FIELDS, Zstd, catalog, checked_bytes,
    decode, digest, measure_pair, read, require, source_paths, unpack_pck, write)

CONFIG = (262144, 19)
SOURCES = ('tools/audit_v13_compression.py', 'tools/probe_v13_compression.py',
           'tools/sprite_factory/native_resource_compression_probe.py')


def file_sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def validate_saved(asset, source_path, row, codec=None):
    """Reopen written archives and compare actual decoded bytes, not receipt flags."""
    require(row['asset_id'] == asset['asset_id'] and row['source_sha256'] == asset['sha256']
            and row['source_bytes'] == asset['size_bytes'], 'Checkpoint source differs')
    require(len(row['configurations']) == 1, 'Wrong candidate configuration count')
    config = row['configurations'][0]
    require((config['block_size'], config['level']) == CONFIG, 'Checkpoint codec differs')
    original = checked_bytes(source_path, asset)
    candidate_asset = read(config['asset_path'])
    candidate = checked_bytes(config['path'], candidate_asset)
    require(config['pack_sha256'] == candidate_asset['sha256']
            and config['pack_bytes'] == candidate_asset['size_bytes'], 'Checkpoint candidate pin differs')
    is_pck = asset['object_key'].endswith('.pck')
    if is_pck:
        before, _ = unpack_pck(original, asset)
        after, _ = unpack_pck(candidate, candidate_asset)
        manifest = candidate_asset['pair_manifest']
        restored_metadata = copy.deepcopy(candidate_asset)
        restored_metadata['pair_manifest'] = copy.deepcopy(asset['pair_manifest'])
        restored_metadata['appearances'] = copy.deepcopy(asset['appearances'])
        expected_manifest = copy.deepcopy(asset['pair_manifest'])
        for entry in expected_manifest['files']:
            payload = after[entry['path']]
            entry.update(bytes=len(payload), sha256=digest(payload))
        for appearance in expected_manifest['appearances']:
            payload = after[appearance['runtime_path']]
            appearance.update(bytes=len(payload), runtime_sha256=digest(payload))
        require(manifest == expected_manifest and candidate_asset['appearances'] == manifest['appearances'],
                'Candidate altered model metadata beyond byte bindings')
    else:
        with zipfile.ZipFile(io.BytesIO(original)) as archive:
            before = {name: archive.read(name) for name in archive.namelist()}
        with zipfile.ZipFile(io.BytesIO(candidate)) as archive:
            require(len(set(archive.namelist())) == len(archive.namelist()), 'Duplicate candidate ZIP member')
            after = {name: archive.read(name) for name in archive.namelist()}
        expected_manifest = json.loads(before['bundle.json'])
        for appearance in expected_manifest['appearances']:
            payload = after[appearance['runtime_path']]
            appearance.update(bytes=len(payload), runtime_sha256=digest(payload))
        require(json.loads(after['bundle.json']) == expected_manifest, 'ZIP model metadata changed')
        expected_appearances = copy.deepcopy(asset['appearances'])
        for appearance in expected_appearances:
            appearance['runtime_sha256'] = digest(after['models/'+appearance['variant']+'.scn'])
        require(candidate_asset['appearances'] == expected_appearances, 'ZIP appearance metadata changed')
        restored_metadata = copy.deepcopy(candidate_asset)
        restored_metadata['appearances'] = copy.deepcopy(asset['appearances'])
    restored_metadata.update(size_bytes=asset['size_bytes'], sha256=asset['sha256'])
    require(restored_metadata == asset, 'Candidate changed asset metadata')
    require(before.keys() == after.keys(), 'Candidate added/removed members')
    native_names = sorted(name for name in before if name != 'bundle.json')
    require({m['path'] for m in row['members']} == set(native_names), 'Incomplete native evidence')
    codec = codec or Zstd()
    entries = {m['path']: m for m in row['members']}
    for name in native_names:
        raw = decode(before[name], codec)
        restored = decode(after[name], codec)
        require(raw == restored, 'Persisted candidate changed decoded resource: '+name)
        record = entries[name]
        require(record['raw_sha256'] == digest(raw) and record['raw_bytes'] == len(raw)
                and record['source_sha256'] == digest(before[name]), 'Decoded evidence differs')
        require(len(record['configurations']) == 1
                and record['configurations'][0]['sha256'] == digest(after[name])
                and record['configurations'][0]['bytes'] == len(after[name])
                and record['configurations'][0]['raw_byte_exact'] is True, 'Candidate member evidence differs')
    return {'native_members':len(native_names), 'candidate_bytes':len(candidate),
            'selected':len(candidate) < len(original), 'selected_bytes':min(len(candidate),len(original)),
            'persisted_streams_byte_exact':True}


def measure_one(asset, path, directory):
    directory.mkdir(parents=True, exist_ok=True)
    checkpoint = directory/'checkpoint.json'
    if checkpoint.exists():
        row = read(checkpoint)
        return row, validate_saved(asset, path, row), True
    attempt = 0
    while (directory/f'attempt-{attempt:03}').exists(): attempt += 1
    row = measure_pair(asset, path, directory/f'attempt-{attempt:03}', (CONFIG,), quiet=True)
    proof = validate_saved(asset, path, row)
    write(checkpoint, row)
    return row, proof, False


def binding(args, assets, paths):
    return {'schema':1, 'codec':{'block_size':CONFIG[0], 'level':CONFIG[1], 'libzstd':Zstd().version},
        'source_sha256':{name:file_sha(ROOT/name) for name in SOURCES},
        'v13_metadata_sha256':file_sha(ROOT/'release/approved_3d_bundles_v13.json'),
        'selection':[{**{k:a[k] for k in PIN_FIELDS}, 'source_path':str(Path(paths[a['object_key']]).resolve())}
                     for a in assets]}


def measurement(args):
    assets = sorted(catalog(), key=lambda a:a['asset_id'])
    paths = source_paths(args, assets, args.replacement_pack)
    pin = binding(args, assets, paths)
    binding_path = args.output/'binding.json'
    if binding_path.exists():
        require(read(binding_path) == pin, 'Resume inputs/tool/codec changed; use a fresh output')
    else:
        require(not list(args.output.iterdir()), 'Unbound nonempty output')
        require(shutil.disk_usage(args.output).free > 2*sum(a['size_bytes'] for a in assets)+2*1024**3,
                'Insufficient candidate disk headroom')
        write(binding_path, pin)
    # Refuse stale repaired packs and missing/corrupt sources before expensive work.
    for asset in assets: checked_bytes(paths[asset['object_key']], asset)
    print('FULL_V13_SOURCES_OK pairs=1200 bytes='+str(sum(a['size_bytes'] for a in assets)), flush=True)
    started = time.monotonic(); records = []; checks = []; resumed = 0
    pool = ThreadPoolExecutor(max_workers=args.workers)
    futures = []
    try:
        futures = [pool.submit(measure_one,a,paths[a['object_key']],args.output/'pairs'/a['asset_id'].replace(':','_')) for a in assets]
        for future in as_completed(futures):
            row, proof, reused = future.result()
            records.append(row); checks.append({'asset_id':row['asset_id'],**proof}); resumed += int(reused)
            if len(records)%25 == 0 or len(records) == len(assets):
                progress = {'complete':False, 'completed':len(records), 'expected':len(assets), 'resumed':resumed,
                    'source_bytes_completed':sum(r['source_bytes'] for r in records),
                    'candidate_bytes_completed':sum(r['candidate_bytes'] for r in checks),
                    'selected_bytes_completed':sum(r['selected_bytes'] for r in checks),
                    'elapsed_seconds':time.monotonic()-started}
                write(args.output/'progress.json',progress)
                print('FULL_V13_PROGRESS',json.dumps(progress),flush=True)
    except BaseException:
        for future in futures: future.cancel()
        raise
    finally:
        pool.shutdown(wait=True,cancel_futures=True)
    require({r['asset_id'] for r in records} == {a['asset_id'] for a in assets}, 'Incomplete full result')
    records.sort(key=lambda r:r['asset_id']); checks.sort(key=lambda r:r['asset_id'])
    source_total = sum(a['size_bytes'] for a in assets)
    selected_total = sum(r['selected_bytes'] for r in checks)
    report = {'schema':1, 'complete':True, 'prototype_only':True, 'production_approved':False,
        'codec':pin['codec'], 'binding_sha256':file_sha(binding_path), 'pairs':records, 'checks':checks,
        'source_total_bytes':source_total, 'all_candidate_bytes':sum(r['candidate_bytes'] for r in checks),
        'selected_total_bytes':selected_total, 'saved_bytes':source_total-selected_total,
        'saved_percent':100*(1-selected_total/source_total),
        'smaller_pairs':sum(r['selected'] for r in checks), 'retained_pairs':sum(not r['selected'] for r in checks),
        'native_members':sum(r['native_members'] for r in checks),
        'elapsed_seconds_this_invocation':time.monotonic()-started, 'resumed_pairs':resumed}
    write(args.output/'report.json',report)
    print('FULL_V13_MEASUREMENT_OK',json.dumps({k:v for k,v in report.items() if k not in ('pairs','checks')}),flush=True)


def engine_one(job, project, directory, engine_pin):
    directory.mkdir(parents=True, exist_ok=True)
    checkpoint = directory/'complete.json'
    if checkpoint.exists():
        proof = read(checkpoint)
        require(proof['engine_pin'] == engine_pin and proof['job'] == job, 'Engine resume binding differs')
        require(file_sha(job['pack']) == job['asset']['sha256'], 'Admitted pack changed')
        result = read(proof['result'])
        require(file_sha(proof['result']) == proof['result_sha256'], 'Engine evidence changed')
        return result
    attempt=0
    while (directory/f'run-{attempt:03}.json').exists(): attempt+=1
    input_path=directory/f'run-{attempt:03}.json'
    result_path=directory/f'run-{attempt:03}-result.json'
    actual={**job,'output':str(result_path)};write(input_path,actual)
    log_path=directory/f'run-{attempt:03}.log'
    with log_path.open('w') as log:
        process=subprocess.run(['godot','--headless','--path',str(project),'--script',
            'res://tools/sprite_factory/v13_compression_check.gd','--',str(input_path)],
            stdout=log,stderr=subprocess.STDOUT,timeout=180)
    text=log_path.read_text()
    require(process.returncode==0 and result_path.is_file() and 'ERROR:' not in text,
            'Engine admission failed: '+str(log_path)+'\n'+text[-1600:])
    result=read(result_path)
    require(result.get('complete') is True and not result['errors'] and len(result['appearances'])==2,
            'Incomplete engine admission')
    expected={r['variant']:r['runtime_sha256'] for r in job['asset']['appearances']}
    require({r['variant']:r['runtime_sha256'] for r in result['appearances']}==expected
            and all(r['loaded'] for r in result['appearances']), 'Engine appearance evidence differs')
    if job['format']=='pck': require(result['production_validator_error']=='','PCK admission failed')
    write(checkpoint,{'engine_pin':engine_pin,'job':job,'result':str(result_path),'result_sha256':file_sha(result_path)})
    return result


def admission(args):
    report=read(args.output/'report.json');require(report.get('complete') is True,'Incomplete measurement')
    assets={a['asset_id']:a for a in catalog()}
    require(len(report['pairs'])==len(assets)==1200,'Incomplete catalog')
    project=args.output/'engine-project'
    names=('tools/sprite_factory/v13_compression_check.gd','tools/sprite_factory/model_texture_audit.gd',
           'scripts/services/model_pair_pack.gd')
    if not project.exists():
        project.mkdir()
        (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Full v13 compression admission"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for name in names:
            target=project/name;target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to(ROOT/name)
    pin={'measurement_sha256':file_sha(args.output/'report.json'),
         'source_sha256':{name:file_sha(ROOT/name) for name in (*names,'tools/audit_v13_compression.py')},
         'godot':subprocess.check_output(['godot','--version'],text=True).strip()}
    pin_path=args.output/'engine-binding.json'
    if pin_path.exists(): require(read(pin_path)==pin,'Engine inputs changed; preserve prior evidence')
    else:write(pin_path,pin)
    jobs=[]
    for pair in report['pairs']:
        original=assets[pair['asset_id']]
        require(pair['source_sha256']==original['sha256'],'Catalog source changed')
        config=pair['configurations'][0]
        # Validate all candidates, including any too small to produce a net saving.
        asset=read(config['asset_path'])
        job={'asset_id':pair['asset_id'],'label':'b262144-l19','format':pair['format'],
             'asset':asset,'pack':config['path'],'expect_production_codec':True,
             'load_only':True,'load_cycles':1,
             'scene_directory':str(Path(config['path']).parent/'b262144-l19')}
        jobs.append((job,args.output/'engine'/pair['asset_id'].replace(':','_')))
    results=[]
    pool = ThreadPoolExecutor(max_workers=min(args.workers,2))
    futures = []
    try:
        futures=[pool.submit(engine_one,job,project,directory,pin) for job,directory in jobs]
        for future in as_completed(futures):
            results.append(future.result())
            if len(results)%50==0: print('FULL_V13_ENGINE',len(results),'/ 1200',flush=True)
    finally:
        pool.shutdown(wait=True,cancel_futures=True)
    results.sort(key=lambda r:r['asset_id'])
    require({r['asset_id'] for r in results}==set(assets),'Incomplete admission results')
    result={'schema':1,'complete':True,'production_approved':False,'linux_headless_only':True,
            'binding_sha256':file_sha(pin_path),'pairs':1200,'appearances':2400,
            'pck_validator_passes':sum('production_validator_error' in r for r in results),
            'checks':results,'scope':'Cold load/instantiate only. Exact decoded-byte proof is in the measurement; sample motion/semantic checks remain separate. No performance or visual certification.'}
    write(args.output/'engine-report.json',result)
    print('FULL_V13_ENGINE_OK pairs=1200 appearances=2400 pcks='+str(result['pck_validator_passes']),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=('measure','admit'))
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--geometry-report',type=Path)
    parser.add_argument('--texture-sources',type=Path)
    parser.add_argument('--zip-backup',type=Path)
    parser.add_argument('--replacement-pack',type=Path,action='append',default=[])
    parser.add_argument('--workers',type=int,default=4)
    args=parser.parse_args()
    require(os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name,'Run through the assigned slot-env')
    require(1<=args.workers<=4,'Use one to four bounded workers')
    args.output=args.output.resolve();args.output.relative_to(ROOT/'.tmp')
    args.output.mkdir(parents=True,exist_ok=True)
    # Sibling lock does not pollute an otherwise fresh measurement directory.
    with args.output.with_suffix('.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        if args.mode=='measure':
            require(all((args.geometry_report,args.texture_sources,args.zip_backup)),'Missing source paths')
            measurement(args)
        else:admission(args)


if __name__=='__main__':main()
