#!/usr/bin/env python3
"""Offline complete-pack geometry-sharing study of the 220 new v14 pairs."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time

import audit_cross_form_resources as release
import audit_shared_geometry as geometry
from probe_v13_compression import checked_bytes, decode, encode, encoded, pack_pck, read, require, unpack_pck, write, Zstd

ROOT = Path(__file__).resolve().parents[1]
FIELDS = ('same_structure', 'same_skeleton', 'same_mesh_bindings', 'same_skin_bindings', 'same_animation_bindings')
CODE = ['tools/study_new_pair_geometry.py', 'tools/audit_cross_form_resources.py',
        'tools/audit_shared_geometry.py', 'tools/sprite_factory/shared_geometry_catalog_probe.gd',
        'tools/sprite_factory/new_pair_geometry_build.gd', 'tools/sprite_factory/shared_geometry_collection.gd',
        'tools/sprite_factory/new_pair_geometry_render.gd', 'tools/sprite_factory/model_texture_render_probe.gd',
        'tools/sprite_factory/shared_geometry_prototype.gd', 'tools/sprite_factory/model_geometry_audit.gd',
        'tools/sprite_factory/model_texture_audit.gd', 'tools/sprite_factory/native_resource_compression_probe.py',
        'tools/probe_v13_compression.py', 'scripts/services/model_pair_pack.gd',
        'release/approved_3d_bundles_v14.json', 'release/approved_3d_v14_binding.json',
        'data/model_pair_release_v14_catalog.json']


def pins():
    return {p: release.sha(ROOT / p) for p in CODE}


def hold_reasons(row):
    reasons = [field for field in FIELDS if not row[field]]
    if any(v['sensitive_tracks'] for v in row['variants']):
        reasons.append('material_mesh_or_method_animation_tracks')
    if any(not c['shareable'] for category in row['components'].values() for c in category.values()):
        reasons.append('scene_local_or_dependent_resource')
    return reasons


def jobs_from_sources(path):
    meta, assets = release.catalog()
    mapping = read(path)
    require(mapping['revision'] == meta['revision'] and mapping['metadata_sha256'] == release.sha(ROOT / 'release/approved_3d_bundles_v14.json'), 'Source mapping pin mismatch')
    binding = read(ROOT / 'release/approved_3d_v14_binding.json')
    added = {key for key, proof in binding['proofs'].items() if not proof.get('compression', False)}
    require(len(added) == 220, 'Unexpected new-pair cohort')
    jobs = []
    for asset in assets:
        if asset['asset_id'] not in added:
            continue
        require(asset.get('format') == 'model-pair-pck-v1' and asset['pair_manifest']['schema'] == 1, 'Expected new texture-sharing pair')
        source = Path(mapping['sources'][asset['asset_id']])
        require(source.is_absolute() and not source.is_symlink(), 'Invalid source path')
        unpack_pck(checked_bytes(source, asset), asset)
        jobs.append({'asset': asset, 'source': str(source)})
    require(len(jobs) == 220, 'Incomplete new-pair cohort')
    return meta, jobs


@contextmanager
def diagnostic_project():
    lock = (ROOT / '.tmp/diagnostic-project.lock').open('a+')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    project = ROOT / 'project.godot'
    original = project.read_bytes()
    config = re.sub(r'\[autoload\].*?(?=\n\[)', '', original.decode(), flags=re.S)
    config = re.sub(r'\[editor_plugins\].*?(?=\n\[)', '', config, flags=re.S)
    try:
        project.write_text(config)
        yield
    finally:
        project.write_bytes(original)
        lock.close()


def audit(sources, output, workers):
    require(not output.exists(), 'Fresh audit output required')
    meta, jobs = jobs_from_sources(sources)
    output.mkdir(parents=True)
    frozen = pins()
    write(output / 'configuration.json', {'inputs': frozen, 'asset_ids': [j['asset']['asset_id'] for j in jobs]})
    records = []
    started = time.monotonic()
    with diagnostic_project(), ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(geometry.run_batch, (i, jobs[i:i+10]), output) for i in range(0, len(jobs), 10)]
        for future in as_completed(futures):
            records.extend(future.result())
            print(f'NEW_PAIR_AUDITED {len(records)}/220', flush=True)
    require(pins() == frozen, 'Study inputs changed')
    require(len(records) == 220 and len({r['asset_id'] for r in records}) == 220, 'Incomplete audit')
    records.sort(key=lambda r: r['asset_id'])
    holds = [{'asset_id': r['asset_id'], 'reasons': hold_reasons(r)} for r in records if hold_reasons(r)]
    write(output / 'report.json', {'schema': 1, 'complete': True, 'prototype_only': True, 'production_approved': False,
          'pairs': 220, 'eligible_pairs': 220-len(holds), 'source_collection_bytes': meta['total_bundle_bytes'],
          'source_cohort_bytes': sum(j['asset']['size_bytes'] for j in jobs), 'inputs': frozen,
          'elapsed_seconds': time.monotonic()-started, 'holds': holds, 'records': records})
    print(f'NEW_PAIR_AUDIT_OK eligible={220-len(holds)} holds={len(holds)}', flush=True)


def run_engine(stage, jobs, directory, recipe):
    directory.mkdir(parents=True)
    write(directory / 'input.json', {'jobs': jobs, 'recipe': recipe})
    env = os.environ.copy()
    for name in ('DATA', 'CONFIG', 'CACHE'):
        target = directory / ('xdg-' + name.lower())
        target.mkdir()
        env['XDG_' + name + '_HOME'] = str(target)
    command = ['godot', '--path', str(ROOT), '--rendering-method', 'gl_compatibility',
               '--resolution', '64x64', '--position', '-1600,-1600', '--log-file', str(directory / 'engine.log'),
               '--script', 'res://tools/sprite_factory/new_pair_geometry_build.gd', '--',
               stage, str(directory / 'input.json'), str(directory / 'output')]
    with (directory / 'process.log').open('w') as log:
        child = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
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
    require(not code and not re.search(r'(?:SCRIPT ERROR|^ERROR:|GEOMETRY_PROTOTYPE_ERROR)', text, re.M), 'Engine failure: ' + str(directory))
    records = [json.loads(line) for line in (directory / 'output/records.jsonl').read_text().splitlines()]
    require(len(records) == len(jobs), 'Incomplete engine stage')
    return records


def build_one(job, directory, recipe):
    produced, = run_engine('produce', [job], directory / 'produce', recipe)
    before = job['asset']
    codec = Zstd()
    members = {}
    exact_members = 0
    for name, path in produced['files'].items():
        original = Path(path).read_bytes()
        raw = decode(original, codec)
        members[name] = encode(raw, 262144, 19, codec)
        require(decode(members[name], codec) == raw, 'Native compression changed bytes')
        exact_members += 1
    appearances = []
    for model, previous in zip(produced['models'], before['appearances'], strict=True):
        name = 'models/' + model['variant'] + '.scn'
        require(model['identity'] == previous['runtime_identity'], 'Changed appearance identity')
        digest = hashlib.sha256(members[name]).hexdigest()
        model['candidate_sha256'] = digest
        appearances.append({'variant': model['variant'], 'runtime_identity': model['identity'], 'runtime_path': name,
                            'runtime_sha256': digest, 'bytes': len(members[name]), 'semantic_sha256': model['effective_sha256'],
                            'source_sha256': previous['source_sha256'], 'cache_source_bytes': previous['cache_source_bytes']})
    manifest = {'schema': 2, 'kind': 'pokeaether-model-pair', 'resource_root': produced['resource_root'],
                **{k: before[k] for k in ('asset_id', 'species_id', 'form_id', 'dependencies')},
                'version': before['version']+1, 'appearances': appearances,
                'files': [{'path': name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                           'decoded_bytes': len(decode(data, codec))} for name, data in sorted(members.items())]}
    require(2 <= len(manifest['files']) < 128, 'Candidate exceeds production member budget')
    members['bundle.json'] = encoded(manifest)
    data = pack_pck(members, manifest['resource_root'])
    asset = {k: v for k, v in before.items() if k not in ('sha256', 'size_bytes', 'object_key', 'appearances', 'version', 'pair_manifest')}
    asset.update(format='model-pair-pck-v1', version=manifest['version'], appearances=appearances, pair_manifest=manifest,
                 sha256=hashlib.sha256(data).hexdigest(), size_bytes=len(data))
    asset['object_key'] = before['object_key'].rsplit('/', 1)[0] + f"/v{asset['version']}-{asset['sha256']}.pck"
    path = directory / 'candidate.pck'
    path.write_bytes(data)
    restored, _ = unpack_pck(path.read_bytes(), asset)
    require(restored == members, 'Persisted pack changed member bytes')
    row = {'asset': asset, 'path': str(path), 'models': produced['models'], 'baseline_bytes': before['size_bytes'],
           'baseline_sha256': before['sha256'], 'decoded_members_byte_exact': exact_members,
           'smaller': len(data) < before['size_bytes'], 'recipe': recipe}
    verification, = run_engine('verify', [row], directory / 'verify', recipe)
    require(verification['ok'] and verification['asset_id'] == before['asset_id'], 'Candidate verification failed')
    row['verification'] = verification
    write(directory / 'checkpoint.json', row)
    return row


def build(sources, audit_dir, output, resume, limit):
    meta, jobs = jobs_from_sources(sources)
    audited = read(audit_dir / 'report.json')
    require(audited['complete'] and audited['pairs'] == 220 and audited['inputs'] == pins(), 'Unbound or changed audit')
    records = {r['asset_id']: r for r in audited['records']}
    eligible = [j for j in jobs if not hold_reasons(records[j['asset']['asset_id']])]
    if limit:
        eligible = eligible[:limit]
    output.mkdir(parents=True, exist_ok=resume)
    recipe = hashlib.sha256(encoded(pins())).hexdigest()
    configuration = {'recipe': recipe, 'audit_sha256': release.sha(audit_dir / 'report.json'), 'asset_ids': [j['asset']['asset_id'] for j in eligible]}
    if resume:
        require(read(output / 'configuration.json') == configuration, 'Resume inputs changed')
    else:
        write(output / 'configuration.json', configuration)
    results = []
    started = time.monotonic()
    with diagnostic_project():
        for i, job in enumerate(eligible):
            directory = output / f'pair-{i:04}'
            checkpoint = directory / 'checkpoint.json'
            if checkpoint.exists():
                row = read(checkpoint)
                require(row['recipe'] == recipe and row['baseline_sha256'] == job['asset']['sha256'], 'Changed checkpoint')
                checked_bytes(row['path'], row['asset'])
            else:
                # Failed attempts are retained, never mistaken for checkpoints.
                attempt = 0
                while directory.exists():
                    attempt += 1
                    directory = output / f'pair-{i:04}-attempt-{attempt}'
                row = build_one(job, directory, recipe)
            results.append(row)
            print(f"NEW_PAIR_BUILT {len(results)}/{len(eligible)} {job['asset']['asset_id']} saved={row['baseline_bytes']-row['asset']['size_bytes']}", flush=True)
    require(audited['inputs'] == pins(), 'Study inputs changed')
    selected = [r for r in results if r['smaller']]
    saved = sum(r['baseline_bytes']-r['asset']['size_bytes'] for r in selected)
    report = {'schema': 1, 'complete': len(results) == audited['eligible_pairs'], 'prototype_only': True, 'production_approved': False,
              'source_collection_bytes': meta['total_bundle_bytes'], 'selected_collection_bytes': meta['total_bundle_bytes']-saved,
              'eligible_pairs': audited['eligible_pairs'], 'pairs_built': len(results), 'pairs_smaller': len(selected),
              'saved_download_bytes': saved, 'source_cohort_bytes': audited['source_cohort_bytes'],
              'motion_samples': sum(r['verification']['motion_samples'] for r in results),
              'decoded_members_byte_exact': sum(r['decoded_members_byte_exact'] for r in results),
              'elapsed_seconds': time.monotonic()-started, 'inputs': pins(), 'configuration': configuration,
              'holds': audited['holds'], 'records': results}
    write(output / 'report.json', report)
    print('NEW_PAIR_BUILD_OK ' + json.dumps({k: report[k] for k in ('complete', 'pairs_built', 'pairs_smaller', 'saved_download_bytes', 'selected_collection_bytes')}), flush=True)


def render(sources, collection, output, selected):
    from PIL import Image
    _, jobs = jobs_from_sources(sources)
    original = {j['asset']['asset_id']: j for j in jobs}
    report = read(collection / 'report.json')
    require(report['inputs'] == pins(), 'Changed build implementation')
    candidates = {r['asset']['asset_id']: r for r in report['records'] if r['smaller']}
    require(bool(candidates), 'No smaller candidates to render')
    if not selected:
        ranked = sorted(candidates, key=lambda k: candidates[k]['asset']['size_bytes'])
        selected = list(dict.fromkeys([ranked[0], ranked[-1], ranked[len(ranked)//3], ranked[2*len(ranked)//3]]))
    require(len(selected) == len(set(selected)) and all(k in candidates for k in selected), 'Invalid render selection')
    output.mkdir(parents=True)
    fixture = {'packs': [], 'models': []}
    for identity in selected:
        candidate = candidates[identity]
        baseline = original[identity]
        checked_bytes(candidate['path'], candidate['asset'])
        fixture['packs'].extend([{'asset': baseline['asset'], 'path': baseline['source']},
                                 {'asset': candidate['asset'], 'path': candidate['path']}])
        for before, after in zip(baseline['asset']['appearances'], candidate['asset']['appearances'], strict=True):
            fixture['models'].append({'identity': before['runtime_identity'],
              'source_path': baseline['asset']['pair_manifest']['resource_root'] + '/' + before['runtime_path'],
              'source_sha256': before['runtime_sha256'],
              'candidate_path': candidate['asset']['pair_manifest']['resource_root'] + '/' + after['runtime_path'],
              'candidate_sha256': after['runtime_sha256']})
    write(output / 'input.json', fixture)
    command = ['godot', '--path', str(ROOT), '--rendering-method', 'gl_compatibility', '--resolution', '640x480',
               '--position', '-1600,-1600', '--log-file', str(output / 'engine.log'),
               '--script', 'res://tools/sprite_factory/new_pair_geometry_render.gd', '--',
               str(output / 'input.json'), str(output / 'render')]
    with diagnostic_project(), (output / 'process.log').open('w') as log:
        child = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        try:
            code = child.wait(timeout=1200)
        except BaseException:
            child.terminate()
            child.wait(timeout=10)
            raise
    require(code == 0, 'GPU render failed: ' + str(output))
    rendered = read(output / 'render/report.json')
    require(rendered['complete'] and len(rendered['records']) == len(fixture['models']), 'Incomplete GPU report')
    require(rendered['input_sha256'] == release.sha(output / 'input.json'), 'Unbound GPU input')
    frames = 0
    for row in rendered['records']:
        controls = [row[k] for k in ('source', 'repeat_source', 'candidate')]
        require(all(c['frames'] == controls[0]['frames'] for c in controls), 'Frame hashes differ')
        for key in controls[0]['frames']:
            decoded = []
            for control in controls:
                paths = [Path(p).resolve() for p in control['paths'] if Path(p).stem == key]
                require(len(paths) == 1, 'Missing rendered PNG')
                paths[0].relative_to(output.resolve())
                with Image.open(paths[0]) as image:
                    require(image.size == (512, 512) and image.mode == 'RGBA', 'Unexpected GPU image')
                    data = image.tobytes()
                require(hashlib.sha256(data).hexdigest() == control['frames'][key], 'PNG does not match GPU hash')
                decoded.append(data)
            require(decoded[0] == decoded[1] == decoded[2], 'Decoded GPU pixels differ')
            frames += 1
    require(report['inputs'] == pins(), 'Study inputs changed')
    write(output / 'report.json', {'schema': 1, 'complete': True, 'prototype_only': True, 'production_approved': False,
          'pairs': len(selected), 'appearances': len(rendered['records']), 'candidate_frames': frames, 'pixels_exact': True,
          'selected': selected, 'renderer': rendered['renderer'], 'device': rendered['device'],
          'inputs': pins(), 'build_report_sha256': release.sha(collection / 'report.json'),
          'render_report_sha256': release.sha(output / 'render/report.json')})
    print(f'NEW_PAIR_RENDER_OK pairs={len(selected)} frames={frames}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('audit', 'build', 'render'))
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--audit', type=Path)
    parser.add_argument('--workers', type=int, choices=(1, 2), default=2)
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--limit', type=int)
    parser.add_argument('--collection', type=Path)
    parser.add_argument('--asset', action='append', default=[])
    args = parser.parse_args()
    require(os.environ.get('POKEAETHER_SLOT') == ROOT.parent.name, 'Use slot-env for the assigned slot')
    output = args.output.resolve()
    output.relative_to(ROOT / '.tmp')
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    if args.stage == 'audit':
        audit(args.sources, output, args.workers)
    elif args.stage == 'build':
        require(args.audit is not None, '--audit required for build')
        build(args.sources, args.audit, output, args.resume, args.limit)
    else:
        require(args.collection is not None, '--collection required for render')
        render(args.sources, args.collection, output, args.asset)


if __name__ == '__main__':
    main()
