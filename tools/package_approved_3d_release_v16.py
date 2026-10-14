#!/usr/bin/env python3
"""Assemble an unpublished v16 collection from hash-bound lossless studies.

Read retained evidence in place. Never encode textures again or publish objects.
Every changed scene receives a fresh namespace; resource bodies remain exact.
"""
import argparse
import copy
from pathlib import Path

from probe_v13_compression import checked_bytes, decode, encode, encoded, read, require, unpack_pck, write, Zstd
from study_shared_form_textures import digest, members_manifest, persist
from study_lossless_texture_storage import ROOT, sha

from rebind_release_resource_paths import rebind_release_paths

REVISION = 'approved-pokemon-3d-v16'
RECIPE = 'lossless-texture-release-v16'


def assemble(output, sources_path, pilot_path):
    require(output.is_relative_to(ROOT / '.tmp') and not output.exists(), 'Fresh slot-local output required')
    receipt = read(ROOT / 'release/full_texture_storage_audit_v15.json')
    report_path = Path(receipt['report_path'])
    require(sha(report_path) == receipt['report_sha256'], 'Changed full audit')
    report = read(report_path)
    require(report['complete'] and report['measured_complete'], 'Incomplete full audit')
    require(sha(report_path.with_name('configuration.json')) == report['configuration_sha256'], 'Changed audit configuration')
    meta = read(ROOT / 'release/approved_3d_bundles_v15.json')
    source_map = read(sources_path)
    require(source_map['revision'] == meta['revision'] and source_map['metadata_sha256'] == sha(ROOT / 'release/approved_3d_bundles_v15.json'), 'Changed original source map')
    trusted = {a['asset_id']: a for a in read(ROOT / 'data/model_pair_release_v15_catalog.json')['assets']}
    wire = read(ROOT / 'release/approved_3d_bundles_v15_index.json')
    require(sha(ROOT / 'release/approved_3d_bundles_v15_index.json') == meta['index']['sha256'], 'Changed original index')
    originals = {a['asset_id']: trusted[a['asset_id']] if a.get('format') == 'model-pair-ref-v1' else a for a in wire['assets']}
    require(len(originals) == 1420 and set(originals) == set(source_map['sources']), 'Incomplete original collection')
    records = {r['asset_id']: r for r in report['records']}
    require(set(records) == set(trusted), 'Incomplete measured PCK collection')
    pilot = read(pilot_path)
    qualification = read(ROOT / 'release/shared_texture_runtime_qualification.json')
    require(sha(pilot_path) == qualification['fixture_sha256'], 'Changed qualified shared-texture pilot')
    pilot_jobs = {j['asset']['asset_id']: j for j in pilot['jobs']}
    selected, roots = {}, {}
    for key, previous in originals.items():
        if key in pilot_jobs:
            job = pilot_jobs[key]
            selected[key] = (job['asset'], job['path'])
            roots[key] = job['asset']['pair_manifest']['resource_root']
        elif key in records:
            record = records[key]
            require(record['source_sha256'] == previous['sha256'] and record['source_bytes'] == previous['size_bytes'], 'Changed measured source')
            require(record['cold_native_verified'] and record['native_non_texture_bytes_exact'], 'Unqualified candidate')
            if record['candidate_bytes'] < record['source_bytes']:
                path = Path(record['path'])
                asset = read(path.with_name('asset.json'))
                require(asset['sha256'] == record['sha256'] and asset['size_bytes'] == record['candidate_bytes'], 'Changed candidate metadata')
            else:
                asset, path = previous, source_map['sources'][key]
            selected[key] = (asset, str(path))
            roots[key] = 'res://pokemon-pairs/' + digest(encoded([RECIPE, key, asset['sha256']]))
        else:
            selected[key] = (previous, source_map['sources'][key])
    # Bind cross-pair references too (e.g. Dragonite Mega -> base).
    mapping = {}
    for key, (asset, _) in selected.items():
        if key not in roots:
            continue
        oldroot = asset['pair_manifest']['resource_root']
        for row in asset['pair_manifest']['files']:
            source, target = oldroot + '/' + row['path'], roots[key] + '/' + row['path']
            require(source not in mapping or mapping[source] == target, 'Ambiguous source namespace')
            mapping[source] = target
    output.mkdir(parents=True)
    codec, jobs, proofs = Zstd(), [], []
    for number, (key, (source_asset, path)) in enumerate(sorted(selected.items()), 1):
        previous = originals[key]
        if key in pilot_jobs or key not in records:
            checked_bytes(path, source_asset)
            jobs.append({'asset': copy.deepcopy(source_asset), 'path': path})
        else:
            members, _ = unpack_pck(checked_bytes(path, source_asset), source_asset)
            members.pop('bundle.json')
            asset = copy.deepcopy(source_asset)
            asset['version'] = max(previous['version'], asset['version']) + 1
            manifest = asset['pair_manifest']
            manifest.update(version=asset['version'], resource_root=roots[key])
            rewritten = {}
            for name, data in members.items():
                if name.startswith('models/'):
                    raw = decode(data, codec)
                    rebound, proof = rebind_release_paths(raw, mapping, source_asset['pair_manifest']['resource_root'], roots[key])
                    require(proof['body_exact'], 'Scene resource body changed')
                    rewritten[name] = encode(rebound, 262144, 19, codec) if rebound != raw else data
                    require(decode(rewritten[name], codec) == rebound, 'Scene compression changed bytes')
                    proofs.append({'asset_id': key, 'path': name, **proof})
                else:
                    rewritten[name] = data
            manifest['files'] = members_manifest(rewritten, codec)
            files = {r['path']: r for r in manifest['files']}
            for appearance in asset['appearances']:
                row = files[appearance['runtime_path']]
                appearance.update(bytes=row['bytes'], runtime_sha256=row['sha256'])
            manifest['appearances'] = copy.deepcopy(asset['appearances'])
            job = persist(asset, rewritten, output / f'pair-{number:04d}')
            asset['object_key'] = f"optional-assets/pokemon_3d/{asset['species_id']}/{asset['form_id']}/v{asset['version']}-{asset['sha256']}.pck"
            write(Path(job['path']).with_name('asset.json'), asset)
            jobs.append(job)
        if number % 20 == 0:
            print(f'ASSEMBLED {number}/1420', flush=True)
    pool = pilot['pool']
    checked_bytes(pool['path'], pool['asset'])
    jobs.append(copy.deepcopy(pool))
    assets = sorted((j['asset'] for j in jobs), key=lambda a: a['asset_id'])
    total = sum(a['size_bytes'] for a in assets)
    require(total < 7_000_000_000, 'Collection exceeds 7 GB')
    catalog = {'schema': 1, 'kind': 'pokeaether-optional-asset-index', 'catalog_revision': REVISION,
               'runtime_contract': {'pokemon_3d': 3, 'godot': '4.6'}, 'production_approved': False,
               'prototype_only': True, 'assets': assets}
    write(output / 'catalog.json', catalog)
    write(output / 'configuration.json', {'schema': 1, 'revision': REVISION, 'complete': True,
          'production_approved': False, 'jobs': jobs, 'total_bundle_bytes': total,
          'baseline_bytes': meta['total_bundle_bytes'], 'saved_bytes': meta['total_bundle_bytes'] - total,
          'scene_rewrites': proofs, 'catalog_sha256': sha(output / 'catalog.json'),
          'builder_sha256': sha(Path(__file__)), 'audit_report_sha256': sha(report_path),
          'pilot_configuration_sha256': sha(pilot_path)})
    print(f'V16_ASSEMBLED archives={len(assets)} bytes={total}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--previous-sources', type=Path, required=True)
    parser.add_argument('--pilot', type=Path, required=True)
    args = parser.parse_args()
    assemble(args.output.resolve(), args.previous_sources, args.pilot)
