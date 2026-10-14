#!/usr/bin/env python3
"""Offline Minior shared-texture packs; no production admission changes."""
import argparse
import copy
import hashlib
from pathlib import Path
import struct
import subprocess

from probe_v13_compression import checked_bytes, decode, encode, encoded, pack_pck, read, require, unpack_pck, write, Zstd
from study_lossless_texture_storage import ROOT, sha
from resume_isolated_texture_audit import PROJECT, SCRIPTS

SCRIPT = 'tools/sprite_factory/shared_form_texture_probe.gd'
RECIPE = 'offline-minior-shared-textures-v1'
CODE = [*SCRIPTS, SCRIPT, 'tools/study_shared_form_textures.py', 'tools/probe_v13_compression.py',
        'tools/sprite_factory/native_resource_compression_probe.py', 'tools/resume_isolated_texture_audit.py',
        'tools/study_lossless_texture_storage.py']


def digest(data):
    return hashlib.sha256(data).hexdigest()


def rebind_external_paths(raw, mapping):
    """Godot 4.6 binary v6: change ONLY equal-length external path strings.

    Header, UIDs, property names, types, internal offsets and all resource body
    bytes remain untouched. Unknown layout/UIDs, unbound paths and size changes
    fail closed. Cold native scene/texture comparison is separately mandatory.
    """
    cursor = 0

    def number(kind='<I'):
        nonlocal cursor
        size = struct.calcsize(kind)
        require(cursor + size <= len(raw), 'Truncated native header')
        value, = struct.unpack_from(kind, raw, cursor)
        cursor += size
        return value

    def string():
        nonlocal cursor
        size = number()
        require(0 < size <= 8192 and cursor + size <= len(raw), 'Unbounded native string')
        start = cursor
        cursor += size
        data = raw[start:cursor]
        require(data.endswith(b'\0') and b'\0' not in data[:-1], 'Malformed native string')
        return data[:-1].decode('utf-8'), start, cursor - 1

    require([number() for _ in range(5)] == [0, 0, 4, 6, 6], 'Unsupported native version')
    cls, _, _ = string()
    require(cls in ['PackedScene', 'ImageTexture', 'PortableCompressedTexture2D', 'ArrayMesh', 'Skin', 'AnimationLibrary'], 'Unexpected native class')
    require(number('<Q') == 0 and number() == 3, 'Unexpected native imports/flags')
    require(number('<Q') == 2**64-1, 'Named native resource UID requires separate qualification')
    require([number() for _ in range(11)] == [0]*11, 'Unexpected reserved native fields')
    count = number()
    require(count <= 65536, 'Unbounded name table')
    for _ in range(count): string()
    count = number()
    require(count <= 128 and (cls == 'PackedScene' or count == 0), 'Unexpected external graph')
    result = bytearray(raw)
    spans = []
    for _ in range(count):
        kind, _, _ = string()
        path, start, end = string()
        require(kind in ['Texture2D', 'ImageTexture', 'ArrayMesh', 'Skin', 'AnimationLibrary'], 'Unexpected external type')
        require(number('<Q') == 2**64-1, 'External UID could redirect binding')
        require(path in mapping, 'Unbound external resource path')
        replacement = mapping[path].encode('utf-8')
        require(len(replacement) == end-start, 'External path length changed')
        result[start:end] = replacement
        spans.append((start, end))
    internal = number()
    require(1 <= internal <= 4096, 'Unbounded internal resource table')
    offsets = []
    for _ in range(internal):
        name, _, _ = string()
        require(name.startswith('local://'), 'Unexpected internal resource name')
        offsets.append(number('<Q'))
    require(offsets == sorted(set(offsets)) and offsets[0] == cursor and offsets[-1] < len(raw)-4 and raw.endswith(b'RSRC'), 'Malformed native body offsets')
    result = bytes(result)
    # Reconstruct the source by restoring only admitted path spans.
    restored = bytearray(result)
    for start, end in spans: restored[start:end] = raw[start:end]
    require(bytes(restored) == raw and len(result) == len(raw), 'Non-path native bytes changed')
    return result, {'external_paths': count, 'body_exact': result[cursor:] == raw[cursor:],
                    'source_raw_sha256': digest(raw), 'candidate_raw_sha256': digest(result)}


def persist(asset, members, folder):
    folder.mkdir(parents=True, exist_ok=False)
    members = dict(members)
    members['bundle.json'] = encoded(asset['pair_manifest'])
    data = pack_pck(members, asset['pair_manifest']['resource_root'])
    path = folder/'candidate.pck'
    path.write_bytes(data)
    asset.update(size_bytes=len(data), sha256=digest(data))
    restored, _ = unpack_pck(checked_bytes(path, asset), asset)
    require(restored == members, 'Persisted PCK changed')
    write(folder/'asset.json', asset)
    return {'asset': asset, 'path': str(path)}


def members_manifest(members, codec):
    return [{'path': path, 'bytes': len(data), 'sha256': digest(data), 'decoded_bytes': len(decode(data, codec))}
            for path, data in sorted(members.items())]


def make_project(output):
    project = output/'native-project'
    project.mkdir()
    (project/'project.godot').write_text(PROJECT)
    for name in [*SCRIPTS, SCRIPT]:
        path = project/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(ROOT/name)
    return project


def native_run(project, mode, jobs, pool, directory):
    directory.mkdir()
    config = {'jobs': jobs, 'pool': pool}
    job = directory/'input.json'
    write(job, config)
    log = directory/'stdout.log'
    command = ['godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--path', str(project),
               '--log-file', str(directory/'engine.log'), '--script', 'res://'+SCRIPT,
               '--', mode, str(job), str(directory)]
    with log.open('w') as stream:
        run = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    text = log.read_text()
    require(run.returncode == 0 and 'SHARED_FORM_TEXTURE_OK' in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text,
            f'Native {mode} failed; see {log}')
    report = read(directory/'report.json')
    require(report['complete'] and report['input_sha256'] == sha(job), 'Unbound native result')
    require(report['packs'] == {j['asset']['asset_id']: j['asset']['sha256'] for j in jobs}, 'Unbound native packs')
    require(report['pool_sha256'] == (pool['asset']['sha256'] if pool else ''), 'Unbound native pool')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    require(output.is_relative_to(ROOT/'.tmp'), 'Experiment output must stay in own slot .tmp')
    output.mkdir(parents=True, exist_ok=False)
    (ROOT/'.tmp/.gdignore').touch(exist_ok=True)
    pins = ROOT/'release/full_texture_storage_audit_v15.json'
    parent = read(pins)
    require(sha(parent['report_path']) == parent['report_sha256'] and
            sha(parent['validated_receipt_path']) == parent['validated_receipt_sha256'], 'Changed full audit evidence')
    full = read(parent['report_path'])
    validation = read(parent['validated_receipt_path'])
    require(full['complete'] and full['selected_collection_bytes'] == parent['selected_collection_bytes'], 'Incomplete baseline')
    rows = [r for r in full['records'] if r['asset_id'].startswith('pokemon_3d:minior')]
    require(len(rows) == 8 and len({r['asset_id'] for r in rows}) == 8, 'Incomplete Minior group')
    source_jobs = []
    original = {}
    codec = Zstd()
    for row in rows:
        require(row['selected_bytes'] == row['candidate_bytes'], 'Pilot requires selected complete candidates')
        path = Path(row['path'])
        asset = read(path.with_name('asset.json'))
        require(asset['sha256'] == row['sha256'] and asset['size_bytes'] == row['selected_bytes'], 'Unbound candidate')
        members, _ = unpack_pck(checked_bytes(path, asset), asset)
        source_jobs.append({'asset': asset, 'path': str(path), 'textures': {t['path']: t['state_signature'] for t in row['textures']}})
        original[asset['asset_id']] = members
    ids = set(original)
    shared = {}
    pooled = {}
    pool_groups = []
    for group in validation['duplicate_groups']:
        refs = [r for r in group['references'] if r['asset_id'] in ids]
        if len({r['asset_id'] for r in refs}) < 2: continue
        state = group['state_signature']
        target = 'textures/'+state+'.res'
        choice = min(refs, key=lambda r: (r['bytes'], r['asset_id'], r['path']))
        pooled[target] = original[choice['asset_id']][choice['path']]
        for ref in refs:
            key = (ref['asset_id'], ref['path'])
            require(key not in shared, 'Ambiguous shared mapping')
            job = next(j for j in source_jobs if j['asset']['asset_id'] == ref['asset_id'])
            require(job['textures'][ref['path']] == state and len(original[ref['asset_id']][ref['path']]) == ref['bytes'], 'Changed shared reference')
            shared[key] = target
        pool_groups.append({'state_signature': state, 'path': target, 'references': refs})
    require(pool_groups, 'Empty shared pool')
    namespace = 'res://pokemon-pairs/'+digest(encoded([RECIPE, pool_groups, {k:digest(v) for k,v in pooled.items()}]))
    pool_asset = {'asset_id': 'offline:minior-texture-pool', 'format': 'offline-shared-texture-pool-v1',
                  'pair_manifest': {'schema': 1, 'kind': 'offline-shared-texture-pool', 'resource_root': namespace,
                                    'files': members_manifest(pooled, codec)}}
    pool = persist(pool_asset, pooled, output/'pool')
    pool['groups'] = pool_groups
    jobs = []
    rewrites = []
    for source in source_jobs:
        asset = copy.deepcopy(source['asset'])
        oldroot = asset['pair_manifest']['resource_root']
        newroot = 'res://pokemon-pairs/'+digest(encoded([RECIPE, asset['sha256'], pool_asset['sha256']]))
        asset['version'] += 1
        asset['pair_manifest']['version'] = asset['version']
        asset['pair_manifest']['resource_root'] = newroot
        # Bind the entire dependency object, not only its namespace.
        asset['dependencies'] = [{'asset_id': pool_asset['asset_id'], 'sha256': pool_asset['sha256'], 'size_bytes': pool_asset['size_bytes']}]
        asset['pair_manifest']['dependencies'] = copy.deepcopy(asset['dependencies'])
        members = {}
        paths = {}
        mapping = {}
        for name in original[asset['asset_id']]:
            if name == 'bundle.json': continue
            target = shared.get((asset['asset_id'], name))
            paths[name] = namespace+'/'+target if target else newroot+'/'+name
            mapping[oldroot+'/'+name] = paths[name]
        for name, data in original[asset['asset_id']].items():
            if name == 'bundle.json' or (asset['asset_id'], name) in shared: continue
            raw = decode(data, codec)
            rebound, evidence = rebind_external_paths(raw, mapping)
            members[name] = encode(rebound, 262144, 19, codec) if rebound != raw else data
            require(decode(members[name], codec) == rebound, 'Compression altered resource')
            rewrites.append({'asset_id': asset['asset_id'], 'path': name, **evidence})
        asset['pair_manifest']['files'] = members_manifest(members, codec)
        filemap = {r['path']: r for r in asset['pair_manifest']['files']}
        for appearance in asset['appearances']:
            scene = filemap[appearance['runtime_path']]
            appearance.update(bytes=scene['bytes'], runtime_sha256=scene['sha256'])
        asset['pair_manifest']['appearances'] = copy.deepcopy(asset['appearances'])
        job = persist(asset, members, output/asset['species_id'])
        job.update(textures=source['textures'], texture_paths={n: paths[n] for n in source['textures']})
        jobs.append(job)
    bindings = {name: sha(ROOT/name) for name in CODE}
    project = make_project(output)
    configuration = {'recipe': RECIPE, 'inputs': bindings, 'parent_receipt_sha256': sha(pins),
                     'parent_report_sha256': parent['report_sha256'], 'parent_validation_sha256': parent['validated_receipt_sha256'],
                     'project_sha256': sha(project/'project.godot'), 'source_jobs': source_jobs, 'jobs': jobs, 'pool': pool}
    write(output/'configuration.json', configuration)
    source = native_run(project, 'source', source_jobs, {}, output/'source')
    candidate = native_run(project, 'shared', jobs, pool, output/'cold')
    require(candidate['models'] == source['models'] and candidate['textures'] == source['textures'], 'Scene, motion or texture state changed')
    restart = native_run(project, 'shared', list(reversed(jobs)), pool, output/'restart')
    require(restart['models'] == source['models'] and restart['textures'] == source['textures'], 'Reverse-order restart changed model')
    require(bindings == {name: sha(ROOT/name) for name in CODE}, 'Inputs changed during experiment')
    for job in [*source_jobs, *jobs, pool]: checked_bytes(job['path'], job['asset'])
    before = sum(j['asset']['size_bytes'] for j in source_jobs)
    after = sum(j['asset']['size_bytes'] for j in jobs)+pool_asset['size_bytes']
    net = before-after
    total = parent['selected_collection_bytes']-net
    report = {'schema': 1, 'complete': True, 'prototype_only': True, 'production_approved': False,
              'recipe': RECIPE, 'inputs': bindings, 'configuration_sha256': sha(output/'configuration.json'),
              'parent_receipt_sha256': sha(pins), 'baseline_collection_bytes': parent['baseline_collection_bytes'],
              'codec_collection_bytes': parent['selected_collection_bytes'], 'pairs': len(jobs), 'looks': len(candidate['models']),
              'shared_groups': len(pool_groups), 'removed_texture_members': len(shared),
              'pilot_before_bytes': before, 'pilot_after_including_pool_bytes': after, 'pool_bytes': pool_asset['size_bytes'],
              'net_saved_bytes': net, 'combined_prototype_collection_bytes': total,
              'saved_from_v15_bytes': parent['baseline_collection_bytes']-total, 'under_7_decimal_gb': total < 7000000000,
              'source_report_sha256': sha(output/'source/report.json'), 'cold_report_sha256': sha(output/'cold/report.json'),
              'restart_report_sha256': sha(output/'restart/report.json'), 'native': {k:candidate[k] for k in ['godot','renderer','device','ownership']},
              'motion_samples': sum(len(m['motion']) for m in candidate['models'].values()),
              'source_packs': [{k:j['asset'][k] for k in ['asset_id','sha256','size_bytes']} for j in source_jobs],
              'candidate_packs': [{k:j['asset'][k] for k in ['asset_id','sha256','size_bytes']} for j in jobs],
              'pool': {k:pool_asset[k] for k in ['asset_id','sha256','size_bytes']}, 'groups': pool_groups, 'rewrites': rewrites}
    write(output/'report.json', report)
    print('SHARED_FORM_TEXTURE_STUDY_OK '+str({k:report[k] for k in ['pairs','shared_groups','net_saved_bytes','combined_prototype_collection_bytes','under_7_decimal_gb']}), flush=True)


if __name__ == '__main__': main()
