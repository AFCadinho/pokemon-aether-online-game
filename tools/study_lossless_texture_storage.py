#!/usr/bin/env python3
"""Offline v15 texture codec study using complete, independently reopened packs."""
import argparse
import copy
import hashlib
import random
import signal
import subprocess
from pathlib import Path

from probe_v13_compression import checked_bytes, decode, encode, encoded, read, require, unpack_pck, pack_pck, write, Zstd
from study_new_pair_geometry import diagnostic_project

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = 'tools/sprite_factory/lossless_texture_storage_probe.gd'
CODE = ['tools/study_lossless_texture_storage.py', SCRIPT, 'tools/probe_v13_compression.py',
        'tools/sprite_factory/lossless_texture_storage_unit.gd',
        'tools/sprite_factory/native_resource_compression_probe.py', 'tools/sprite_factory/model_texture_audit.gd',
        'tools/sprite_factory/shared_geometry_collection.gd', 'scripts/services/model_pair_pack.gd',
        'data/model_pair_release_v15_catalog.json', 'release/approved_3d_bundles_v15.json',
        'release/approved_3d_v15_binding.json']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def catalog():
    meta = read(ROOT / 'release/approved_3d_bundles_v15.json')
    binding = read(ROOT / 'release/approved_3d_v15_binding.json')
    trusted = ROOT / 'data/model_pair_release_v15_catalog.json'
    require(binding['runtime_approved'] and binding['publication_approved'], 'Unqualified v15 baseline')
    require(sha(trusted) == binding['trusted_catalog_sha256'], 'Changed baseline catalog')
    require(meta['total_bundle_bytes'] == 8795326138, 'Unexpected baseline size')
    assets = read(trusted)['assets']
    require(len(assets) == 1365 and len(meta['bundles']) == 1420, 'Incomplete baseline')
    pins = {a['asset_id']: a for a in meta['bundles']}
    require(all(all(a[k] == pins[a['asset_id']][k] for k in ('object_key', 'sha256', 'size_bytes')) for a in assets), 'Unbound source')
    return meta, assets


def select(assets):
    # Biased diagnostic controls plus deterministic coverage of size quartiles.
    # This is a representative experiment, not a statistical whole-catalog estimate.
    mandatory = {'pokemon_3d:hydreigon:base', 'pokemon_3d:tyranitar:base', 'pokemon_3d:quaquaval:base',
                 'pokemon_3d:alcremie-caramel-swirl:base', 'pokemon_3d:sinistcha-masterpiece:base',
                 'pokemon_3d:urshifu-rapid-strike:base', 'pokemon_3d:landorus-therian:base'}
    selected = [a for a in assets if a['asset_id'] in mandatory]
    require(len(selected) == 7, 'Missing fixed controls')
    rng = random.Random(20261014)
    for schema, desired in ((2, 16), (1, 4)):
        rest = sorted([a for a in assets if a['pair_manifest']['schema'] == schema and a not in selected],
                      key=lambda a: (a['size_bytes'], a['asset_id']))
        needed = desired - sum(a['pair_manifest']['schema'] == schema for a in selected)
        for i in range(4):
            bucket = rest[len(rest)*i//4:len(rest)*(i+1)//4]
            count = needed//4 + int(i < needed % 4)
            selected.extend(rng.sample(bucket, count))
    require(len(selected) == len({a['asset_id'] for a in selected}) == 20, 'Invalid sample')
    return sorted(selected, key=lambda a: a['asset_id'])


def native_run(mode, config, output):
    output.mkdir(parents=True, exist_ok=False)
    job = output / 'input.json'
    write(job, config)
    log = output / 'engine.stdout.log'
    command = ['godot', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility',
               '--path', str(ROOT), '--log-file', str(output / 'engine.log'), '--script', 'res://' + SCRIPT,
               '--', mode, str(job), str(output)]
    with log.open('w') as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
    require(result.returncode == 0, f'Native {mode} failed: {log}')
    text = log.read_text()
    require('LOSSLESS_TEXTURE_ENGINE_OK' in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text, f'Engine errors: {log}')
    report = read(output / 'report.json')
    require(report['complete'] and report['input_sha256'] == sha(job) and report['pack_sha256'] == config['asset']['sha256'], 'Unbound engine report')
    return report


def rewrite_pack(asset, original, replacements, directory):
    members, patch = unpack_pck(original, asset)
    candidate = copy.deepcopy(asset)
    candidate['version'] += 1
    candidate['pair_manifest']['version'] = candidate['version']
    for row in candidate['pair_manifest']['files']:
        if row['path'] in replacements:
            payload = replacements[row['path']]
            members[row['path']] = payload
            row.update(bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest(), decoded_bytes=len(decode(payload, Zstd())))
    members['bundle.json'] = encoded(candidate['pair_manifest'])
    payload = pack_pck(members, candidate['pair_manifest']['resource_root'], patch)
    candidate.update(size_bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest())
    candidate['object_key'] = asset['object_key'].rsplit('/', 1)[0] + f"/v{candidate['version']}-{candidate['sha256']}.pck"
    destination = directory / 'candidate.pck'
    destination.write_bytes(payload)
    restored, _ = unpack_pck(checked_bytes(destination, candidate), candidate)
    require(restored == members, 'Persisted pack changed')
    before, _ = unpack_pck(original, asset)
    require(all(restored[k] == v for k, v in before.items() if k != 'bundle.json' and k not in replacements), 'Non-texture native bytes changed')
    require(candidate['appearances'] == asset['appearances'], 'Scene/cache/profile bindings changed')
    write(directory / 'asset.json', candidate)
    return candidate, destination


def measure(asset, path, directory):
    directory.mkdir(parents=True)
    original = checked_bytes(path, asset)
    members, _ = unpack_pck(original, asset)
    source = native_run('encode', {'asset': asset, 'path': str(path)}, directory / 'source')
    expected = {r['path'] for r in asset['pair_manifest']['files'] if r['path'].startswith('textures/')}
    require({r['path'] for r in source['textures']} == expected, 'Incomplete texture measurement')
    codec = Zstd()
    sets = {'png': {}, 'webp': {}, 'best': {}}
    textures = []
    for row in source['textures']:
        name = row['path']
        baseline = members[name]
        choices = [(len(baseline), 'original', baseline)]
        measurement = {k: v for k, v in row.items() if k != 'codecs'}
        measurement.update(source_bytes=len(baseline), source_sha256=hashlib.sha256(baseline).hexdigest(), codecs={})
        for label, evidence in row['codecs'].items():
            if not evidence['exact']:
                measurement['codecs'][label] = {'exact': False, 'mips': evidence['mips']}
                continue
            native = Path(evidence['path']).read_bytes()
            raw = decode(native, codec)
            compressed = encode(raw, 262144, 19, codec)
            require(decode(compressed, codec) == raw, 'Outer native compression changed data')
            Path(evidence['path']).write_bytes(compressed)
            sets[label][name] = compressed
            choices.append((len(compressed), label, compressed))
            measurement['codecs'][label] = {'exact': True, 'bytes': len(compressed), 'sha256': hashlib.sha256(compressed).hexdigest(),
                                           'native_raw_sha256': hashlib.sha256(raw).hexdigest(), 'mips': evidence['mips'], 'encode_usec': evidence['encode_usec']}
        _, chosen, payload = min(choices, key=lambda c: (c[0], c[1]))
        if chosen != 'original': sets['best'][name] = payload
        measurement.update(selected=chosen, selected_bytes=len(payload))
        textures.append(measurement)
    candidates = []
    for label, replacements in sets.items():
        output = directory / label
        output.mkdir()
        candidate, candidate_path = rewrite_pack(asset, original, replacements, output)
        record = {'codec': label, 'bytes': candidate['size_bytes'], 'sha256': candidate['sha256'], 'path': str(candidate_path),
                  'changed_textures': len(replacements), 'native_non_texture_bytes_exact': True}
        if label == 'best':
            verified = native_run('verify', {'asset': candidate, 'path': str(candidate_path)}, output / 'cold-verify')
            require(verified['models'] == source['models'], 'Cold scenes, materials, geometry or animation changed')
            require({r['path']: r['state_signature'] for r in verified['textures']} ==
                    {r['path']: r['state_signature'] for r in source['textures']}, 'Cold decoded texture state changed')
            record.update(cold_native_verified=True, engine_report_sha256=sha(output / 'cold-verify/report.json'))
        candidates.append(record)
    require(sha(path) == asset['sha256'], 'Source pack changed')
    result = {'asset_id': asset['asset_id'], 'source_bytes': len(original), 'source_sha256': asset['sha256'],
              'source_texture_bytes': sum(len(members[k]) for k in expected), 'textures': textures, 'candidates': candidates,
              'source_engine_report_sha256': sha(directory / 'source/report.json'),
              'motion_samples': sum(len(m['motion']) for m in source['models'])}
    write(directory / 'checkpoint.json', result)
    return result


def study(sources, output, limit=None):
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    meta, assets = catalog()
    mapping = read(sources)
    require(mapping['revision'] == meta['revision'] and mapping['metadata_sha256'] == sha(ROOT / 'release/approved_3d_bundles_v15.json'), 'Wrong retained source map')
    chosen = select(assets)
    if limit is not None: chosen = chosen[:limit]
    configuration = {'schema': 1, 'baseline_revision': meta['revision'], 'seed': 20261014,
                     'sample_ids': [a['asset_id'] for a in chosen], 'inputs': {p: sha(ROOT / p) for p in CODE},
                     'compression': {'native_block_size': 262144, 'zstd_level': 19, 'webp_method': 6, 'webp_lossless_factor': 100},
                     'sources': {a['asset_id']: {'path': mapping['sources'][a['asset_id']], 'sha256': a['sha256'], 'size_bytes': a['size_bytes']} for a in chosen}}
    if (output / 'configuration.json').exists(): require(read(output / 'configuration.json') == configuration, 'Changed study inputs; use a fresh directory')
    else: write(output / 'configuration.json', configuration)
    records = []
    with diagnostic_project():
        for i, asset in enumerate(chosen):
            folder = output / f'pair-{i:04d}'
            if (folder / 'checkpoint.json').exists():
                record = read(folder / 'checkpoint.json')
                require(record['source_sha256'] == asset['sha256'], 'Changed checkpoint')
                for candidate in record['candidates']: require(sha(candidate['path']) == candidate['sha256'], 'Changed checkpoint pack')
            else:
                # A stopped attempt is retained; never overwrite its reports.
                attempt = 0
                while folder.exists():
                    attempt += 1
                    folder = output / f'pair-{i:04d}-attempt-{attempt}'
                record = measure(asset, Path(mapping['sources'][asset['asset_id']]), folder)
            records.append(record)
            print(f"LOSSLESS_TEXTURE_PAIR_OK {i+1}/{len(chosen)} {asset['asset_id']}", flush=True)
    require(configuration['inputs'] == {p: sha(ROOT / p) for p in CODE}, 'Code/source pins changed during study')
    totals = {label: sum(next(c['bytes'] for c in row['candidates'] if c['codec'] == label) for row in records) for label in ('png', 'webp', 'best')}
    source_bytes = sum(r['source_bytes'] for r in records)
    selected_bytes = sum(min(r['source_bytes'], next(c['bytes'] for c in r['candidates'] if c['codec'] == 'best')) for r in records)
    report = {'schema': 1, 'complete': len(records) == 20, 'sample_complete': len(records) == len(chosen),
              'prototype_only': True, 'production_approved': False, 'baseline_revision': meta['revision'],
              'baseline_collection_bytes': meta['total_bundle_bytes'], 'excluded_zip_pairs': 55,
              'pairs': len(records), 'source_sample_bytes': source_bytes,
              'source_texture_bytes': sum(r['source_texture_bytes'] for r in records), 'candidate_sample_bytes': totals,
              'saved_sample_bytes': {label: source_bytes-total for label, total in totals.items()},
              'selected_sample_bytes': selected_bytes, 'selected_saved_bytes': source_bytes-selected_bytes,
              'textures': sum(len(r['textures']) for r in records), 'motion_samples': sum(r['motion_samples'] for r in records),
              'configuration_sha256': sha(output / 'configuration.json'), 'records': records}
    write(output / 'report.json', report)
    print('LOSSLESS_TEXTURE_STUDY_OK ' + str({k: v for k, v in report.items() if k != 'records'}), flush=True)


if __name__ == '__main__':
    # Ensure diagnostic_project's finally restores the tracked project even
    # when the outer session terminates this process while waiting for Godot.
    def terminated(signum, _frame):
        raise InterruptedError(f'Study interrupted by signal {signum}; partial artifacts retained')
    signal.signal(signal.SIGTERM, terminated)
    signal.signal(signal.SIGHUP, terminated)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--limit', type=int)
    args = parser.parse_args()
    study(args.sources, args.output, args.limit)
