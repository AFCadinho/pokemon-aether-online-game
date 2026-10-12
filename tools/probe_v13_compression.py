#!/usr/bin/env python3
"""Offline v13 lossless compression study. Never changes a production catalog.

Read approved local packs in place, preserve every decoded resource byte, and
measure complete candidate containers. Larger blocks are deliberately tested as
engine-only candidates: the current production PCK validator rejects them.
"""
import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import random
import statistics
import struct
import subprocess
import sys
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/sprite_factory'))
from native_resource_compression_probe import Zstd, blocks, decode, encode

CONFIGS = [(block, level) for block in (262144, 1048576) for level in (9, 15, 19)]
PIN_FIELDS = ('asset_id', 'object_key', 'sha256', 'size_bytes')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':')) + '\n').encode()


def read(path):
    return json.loads(Path(path).read_bytes())


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.partial')
    temporary.write_bytes(encoded(value))
    temporary.replace(path)


def checked_bytes(path, pin):
    data = Path(path).read_bytes()
    require(len(data) == pin['size_bytes'] and digest(data) == pin['sha256'], 'Source pin mismatch')
    return data


def catalog():
    release = read(ROOT / 'release/approved_3d_bundles_v13.json')
    full = {}
    for name in ('data/model_pair_catalog.json', 'data/model_pair_geometry_catalog.json',
                 'release/approved_3d_bundles_v11_index.json'):
        for asset in read(ROOT / name)['assets']:
            full[asset['object_key']] = asset
    assets = []
    for pin in release['bundles']:
        asset = full[pin['object_key']]
        require(all(asset[k] == pin[k] for k in PIN_FIELDS), 'Catalog pin differs from v13')
        assets.append(asset)
    require(len(assets) == 1200, 'Incomplete v13 catalog')
    return assets


def select(assets):
    cohorts = defaultdict(list)
    for asset in assets:
        cohorts[asset.get('pair_manifest', {}).get('schema', 0)].append(asset)
    mandatory = {'pokemon_3d:hydreigon:base', 'pokemon_3d:tyranitar:base', 'pokemon_3d:quaquaval:base'}
    chosen = [a for a in cohorts[2] if a['asset_id'] in mandatory]
    require(len(chosen) == 3, 'Missing fixed sample cases')
    rest = sorted([a for a in cohorts[2] if a not in chosen], key=lambda a: (a['size_bytes'], a['asset_id']))
    rng = random.Random(20261012)
    for index, count in enumerate((4, 3, 3, 4)):
        chosen.extend(rng.sample(rest[len(rest)*index//4:len(rest)*(index+1)//4], count))
    other = sorted(cohorts[1], key=lambda a: (a['size_bytes'], a['asset_id']))
    chosen.extend([other[len(other)//4], other[3*len(other)//4]])
    chosen.append(max(cohorts[0], key=lambda a: a['size_bytes']))
    require(len({a['asset_id'] for a in chosen}) == 20, 'Invalid sample')
    return sorted(chosen, key=lambda a: a['asset_id'])


def unpack_pck(data, asset):
    require(len(data) >= 108, 'Truncated PCK')
    magic, version, major, minor, patch, flags, base, table = struct.unpack_from('<6I2Q', data)
    require((magic, version, major, minor, flags) == (0x43504447, 3, 4, 6, 2), 'Unsupported PCK')
    require(not any(data[40:104]) and 104 <= base <= table <= len(data)-4, 'Invalid PCK header')
    manifest = asset['pair_manifest']
    expected = {f['path']: f for f in manifest['files']}
    count, = struct.unpack_from('<I', data, table)
    require(count == len(expected)+1 and count <= 128, 'Invalid member count')
    cursor = table+4
    prefix = manifest['resource_root'].removeprefix('res://') + '/'
    members = {}; ranges = []
    for _ in range(count):
        require(cursor+4 <= len(data), 'Truncated member table')
        length, = struct.unpack_from('<I', data, cursor); cursor += 4
        require(0 < length <= 512 and cursor+length+36 <= len(data), 'Invalid member name length')
        name = data[cursor:cursor+length].rstrip(b'\0').decode('utf-8'); cursor += length
        require(name.startswith(prefix), 'Member outside namespace')
        name = name[len(prefix):]
        require(name not in members and (name == 'bundle.json' or name in expected), 'Unexpected member')
        offset, size = struct.unpack_from('<QQ', data, cursor); cursor += 16
        md5 = data[cursor:cursor+16]; cursor += 16
        flags, = struct.unpack_from('<I', data, cursor); cursor += 4
        require(flags == 0 and size > 0 and offset+size <= table-base, 'Invalid member range')
        payload = data[base+offset:base+offset+size]
        require(hashlib.md5(payload).digest() == md5, 'Member MD5 mismatch')
        if name == 'bundle.json':
            require(json.loads(payload) == manifest, 'Manifest mismatch')
        else:
            require(len(payload) == expected[name]['bytes'] and digest(payload) == expected[name]['sha256'],
                    'Member SHA/size mismatch')
        members[name] = payload; ranges.append((base+offset, base+offset+size))
    require(cursor == len(data), 'Trailing PCK bytes')
    ranges.sort()
    require(all(a[1] <= b[0] for a, b in zip(ranges, ranges[1:])), 'Overlapping members')
    return members, patch


def pack_pck(members, namespace, patch=2):
    # Same native Godot v3 layout/alignment as the existing PCKPacker output.
    output = bytearray(128)
    entries = []
    for relative, data in sorted(members.items()):
        name = (namespace.removeprefix('res://') + '/' + relative).encode()
        name += b'\0' * (-len(name) % 4)
        entries.append(struct.pack('<I', len(name)) + name
                       + struct.pack('<QQ', len(output)-128, len(data))
                       + hashlib.md5(data).digest() + struct.pack('<I', 0))
        output.extend(data); output.extend(b'\0' * (-len(output) % 32))
    table = len(output)
    output.extend(struct.pack('<I', len(entries)) + b''.join(entries))
    struct.pack_into('<6I2Q', output, 0, 0x43504447, 3, 4, 6, patch, 2, 128, table)
    return bytes(output)


def zip_payload(members, infos):
    output = io.BytesIO()
    with zipfile.ZipFile(output, 'w') as archive:
        for info in infos:
            archive.writestr(copy.copy(info), members[info.filename], compress_type=info.compress_type, compresslevel=9)
    return output.getvalue()


def zip_manifest(manifest, members):
    # Preserve the original schema; update only fields binding native file bytes.
    result = copy.deepcopy(manifest)
    for appearance in result['appearances']:
        data = members[appearance['runtime_path']]
        appearance['bytes'] = len(data)
        appearance['runtime_sha256'] = digest(data)
    return result


def source_paths(args, chosen):
    geometry = read(args.geometry_report)
    require(geometry.get('complete') is True, 'Incomplete geometry source report')
    paths = {r['asset']['object_key']: r['path'] for r in geometry['records']}
    textures = read(args.texture_sources)['sources']
    for asset in chosen:
        if asset['object_key'].endswith('.zip'):
            paths[asset['object_key']] = str(args.zip_backup / 'objects' / asset['object_key'])
        elif asset['object_key'] not in paths:
            paths[asset['object_key']] = textures[asset['asset_id']]
        require(Path(paths[asset['object_key']]).is_file(), 'Missing selected local source')
    return paths


def measure_pair(asset, path, output):
    codec = Zstd()
    original = checked_bytes(path, asset)
    is_pck = asset['object_key'].endswith('.pck')
    if is_pck:
        members, patch = unpack_pck(original, asset)
        source_manifest = asset['pair_manifest']
        native_names = sorted(f['path'] for f in source_manifest['files'])
    else:
        with zipfile.ZipFile(io.BytesIO(original)) as archive:
            infos = archive.infolist()
            require(len({i.filename for i in infos}) == len(infos), 'Duplicate ZIP member')
            members = {i.filename: archive.read(i) for i in infos}
        require(set(members) == {'bundle.json', 'models/normal.scn', 'models/shiny.scn'}, 'Unexpected ZIP payload')
        source_manifest = json.loads(members['bundle.json'])
        native_names = ['models/normal.scn', 'models/shiny.scn']
        for a in asset['appearances']:
            entry = next(r for r in source_manifest['appearances'] if r['variant'] == a['variant'])
            data = members['models/' + a['variant'] + '.scn']
            require(len(data) == entry['bytes'] and digest(data) == a['runtime_sha256'] == entry['runtime_sha256'],
                    'ZIP appearance mismatch')
    result = {'asset_id': asset['asset_id'], 'source_path': str(path), 'source_sha256': asset['sha256'],
              'source_bytes': len(original), 'schema': source_manifest['schema'], 'format': 'pck' if is_pck else 'zip',
              'members': [], 'configurations': []}
    payloads = {config: dict(members) for config in CONFIGS}
    for name in native_names:
        original_native = members[name]
        raw = decode(original_native, codec)
        record = {'path': name, 'source_bytes': len(original_native), 'source_sha256': digest(original_native),
                  'raw_bytes': len(raw), 'raw_sha256': digest(raw), 'source_block_size': blocks(original_native)[0],
                  'configurations': []}
        for block, level in CONFIGS:
            started = time.perf_counter()
            candidate = encode(raw, block, level, codec)
            encoding_ms = (time.perf_counter()-started)*1000
            started = time.perf_counter()
            restored = decode(candidate, codec)
            decoding_ms = (time.perf_counter()-started)*1000
            require(restored == raw, 'Decoded stream changed')
            payloads[block, level][name] = candidate
            record['configurations'].append({'block_size': block, 'level': level, 'bytes': len(candidate),
                'sha256': digest(candidate), 'encoding_ms': encoding_ms, 'decoding_ms': decoding_ms,
                'raw_byte_exact': True})
        result['members'].append(record)
    directory = output / asset['asset_id'].replace(':', '_')
    directory.mkdir(parents=True)
    # ZIP scenes are fixture inputs, not a copied installation/cache.
    if not is_pck:
        for name in native_names:
            target = directory / 'baseline' / name
            target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(members[name])
    write(directory / 'baseline-asset.json', asset)
    for block, level in CONFIGS:
        candidate_members = payloads[block, level]
        candidate_asset = copy.deepcopy(asset)
        if is_pck:
            manifest = candidate_asset['pair_manifest']
            for f in manifest['files']:
                data = candidate_members[f['path']]; f.update(bytes=len(data), sha256=digest(data))
            for appearance in candidate_asset['appearances']:
                data = candidate_members[appearance['runtime_path']]
                appearance.update(bytes=len(data), runtime_sha256=digest(data))
            manifest['appearances'] = copy.deepcopy(candidate_asset['appearances'])
            candidate_members['bundle.json'] = encoded(manifest)
            candidate = pack_pck(candidate_members, manifest['resource_root'], patch)
            unpack_pck(candidate, candidate_asset)
        else:
            manifest = zip_manifest(source_manifest, candidate_members)
            candidate_members['bundle.json'] = encoded(manifest)
            candidate = zip_payload(candidate_members, infos)
            for appearance in candidate_asset['appearances']:
                data = candidate_members['models/' + appearance['variant'] + '.scn']
                appearance.update(runtime_sha256=digest(data))
        label = f'b{block}-l{level}'
        target = directory / (label + ('.pck' if is_pck else '.zip'))
        target.write_bytes(candidate)
        candidate_asset.update(size_bytes=len(candidate), sha256=digest(candidate))
        write(directory / (label+'-asset.json'), candidate_asset)
        if not is_pck:
            for name in native_names:
                scene = directory / label / name; scene.parent.mkdir(parents=True, exist_ok=True)
                scene.write_bytes(candidate_members[name])
        result['configurations'].append({'block_size': block, 'level': level, 'pack_bytes': len(candidate),
            'pack_sha256': digest(candidate), 'path': str(target), 'asset_path': str(directory / (label+'-asset.json')),
            'existing_pck_codec_supported': block == 262144,
            'native_payload_bytes': sum(len(candidate_members[n]) for n in native_names)})
    require(digest(Path(path).read_bytes()) == asset['sha256'], 'Source changed during probe')
    write(directory / 'measurement.json', result)
    print('V13_COMPRESSION_MEASURED', asset['asset_id'], flush=True)
    return result


def build(args):
    require(not args.output.exists(), 'A fresh output directory is required')
    selected = select(catalog()); paths = source_paths(args, selected)
    args.output.mkdir(parents=True)
    report = {'schema': 1, 'complete': False, 'production_approved': False, 'prototype_only': True,
        'selection_method': '17 schema-2 (3 fixed cases plus 14 size-stratified seed 20261012); 2 schema-1 quartile cases; largest retained ZIP. Not a random whole-catalog estimate.',
        'libzstd': Zstd().version, 'source_script_sha256': digest(Path(__file__).read_bytes()),
        'v13_metadata_sha256': digest((ROOT/'release/approved_3d_bundles_v13.json').read_bytes()),
        'source_total_bytes': sum(a['size_bytes'] for a in selected), 'pairs': []}
    write(args.output / 'selection.json', [{**{k:a[k] for k in PIN_FIELDS}, 'path':paths[a['object_key']]} for a in selected])
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(measure_pair, a, paths[a['object_key']], args.output) for a in selected]
        for job in as_completed(jobs):
            report['pairs'].append(job.result()); write(args.output/'report.json', report)
    report['pairs'].sort(key=lambda r:r['asset_id'])
    report['configurations'] = []
    for index, (block, level) in enumerate(CONFIGS):
        total = sum(p['configurations'][index]['pack_bytes'] for p in report['pairs'])
        report['configurations'].append({'block_size':block, 'level':level, 'pack_bytes':total,
            'saved_bytes':report['source_total_bytes']-total, 'saved_percent':100*(1-total/report['source_total_bytes']),
            'encoding_seconds':sum(m['configurations'][index]['encoding_ms'] for p in report['pairs'] for m in p['members'])/1000,
            'decode_seconds_single_pass':sum(m['configurations'][index]['decoding_ms'] for p in report['pairs'] for m in p['members'])/1000})
    report['complete'] = True; write(args.output/'report.json', report)
    print(json.dumps(report['configurations'], indent=2), flush=True)


def qualify(args):
    report = read(args.output/'report.json'); require(report['complete'], 'Incomplete measurements')
    choices = [min((r for r in report['configurations'] if r['block_size'] == b), key=lambda r:r['pack_bytes'])
               for b in (262144,1048576)]
    project = args.output/'engine-probe'; project.mkdir()
    (project/'project.godot').write_text('config_version=5\n[application]\nconfig/name="V13 compression probe"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    for name in ('tools/sprite_factory/v13_compression_check.gd','tools/sprite_factory/model_texture_audit.gd',
                 'scripts/services/model_pair_pack.gd'):
        target = project/name; target.parent.mkdir(parents=True, exist_ok=True); target.symlink_to(ROOT/name)
    jobs = []
    for pair in report['pairs']:
        directory = args.output / pair['asset_id'].replace(':','_')
        for choice in [None, *choices]:
            label = 'baseline' if choice is None else f"b{choice['block_size']}-l{choice['level']}"
            config = None if choice is None else next(r for r in pair['configurations'] if r['block_size']==choice['block_size'] and r['level']==choice['level'])
            job = {'asset_id':pair['asset_id'], 'label':label, 'format':pair['format'],
                   'asset': read(directory/('baseline-asset.json' if config is None else label+'-asset.json')),
                   'pack':pair['source_path'] if config is None else config['path'],
                   'scene_directory':str(directory/label),
                   'expect_production_codec':choice is None or choice['block_size']==262144,
                   'output':str(directory/(label+'-engine.json'))}
            job_path = directory/(label+'-job.json'); write(job_path, job); jobs.append((job_path,job))
    random.Random(20261012).shuffle(jobs)
    completed=[]
    for index,(job_path,job) in enumerate(jobs,1):
        log_path=job_path.with_suffix('.log')
        with log_path.open('w') as log:
            process=subprocess.run(['godot','--headless','--path',str(project),'--script',
                'res://tools/sprite_factory/v13_compression_check.gd','--',str(job_path)],
                stdout=log,stderr=subprocess.STDOUT,timeout=180)
        text=log_path.read_text()
        require(process.returncode==0 and Path(job['output']).is_file() and 'SCRIPT ERROR' not in text and 'ERROR:' not in text,
                'Godot check failed: '+str(log_path)+'\n'+text[-2000:])
        result=read(job['output']); require(result.get('complete') is True and not result['errors'], 'Engine result incomplete')
        completed.append(result)
        print('V13_ENGINE_CHECK',index,'/',len(jobs),job['asset_id'],job['label'],flush=True)
    by=defaultdict(dict)
    for r in completed: by[r['asset_id']][r['label']]=r
    for asset_id, variants in by.items():
        original=variants['baseline']
        for label,r in variants.items():
            require(r['appearances']==original['appearances'], 'Engine semantics/motion differs: '+asset_id+' '+label)
    labels=sorted({r['label'] for r in completed})
    result={'schema':1,'complete':True,'production_approved':False,'linux_headless_only':True,
            'timing_note':'Three uncached resource loads per appearance, warm filesystem; other workspace tasks may be active. Diagnostic, not a battle/FPS or cross-platform performance certification.',
            'checks':completed,'summary':[]}
    for label in labels:
        rows=[r for r in completed if r['label']==label]
        result['summary'].append({'label':label,'pairs':len(rows),'appearances':sum(len(r['appearances']) for r in rows),
            'load_instantiate_median_ms':statistics.median(ms for r in rows for ms in r['load_instantiate_ms']),
            'load_instantiate_p95_ms':sorted(ms for r in rows for ms in r['load_instantiate_ms'])[int(sum(len(r['load_instantiate_ms']) for r in rows)*.95)-1],
            'peak_process_rss_max_bytes':max(r['peak_rss_bytes'] for r in rows),
            'peak_process_rss_median_bytes':statistics.median(r['peak_rss_bytes'] for r in rows)})
    write(args.output/'engine-report.json',result)
    print('V13_ENGINE_QUALIFIED',json.dumps(result['summary']),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=('measure','qualify'))
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--geometry-report',type=Path)
    parser.add_argument('--texture-sources',type=Path)
    parser.add_argument('--zip-backup',type=Path)
    args=parser.parse_args()
    require(os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name,'Run through the assigned slot-env')
    args.output=args.output.resolve();args.output.relative_to(ROOT/'.tmp')
    if args.mode=='measure':
        require(all([args.geometry_report,args.texture_sources,args.zip_backup]),'Missing source report paths')
        build(args)
    else:qualify(args)


if __name__=='__main__':
    main()
