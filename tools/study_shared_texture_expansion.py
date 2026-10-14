#!/usr/bin/env python3
"""Unpublished expansion of v16 texture sharing; never edits client admission."""
import argparse
import copy
from collections import OrderedDict, defaultdict
from pathlib import Path

from probe_v13_compression import checked_bytes, decode, encode, encoded, read, require, unpack_pck, write, Zstd
from study_lossless_texture_storage import ROOT, sha
from study_shared_form_textures import digest, members_manifest, persist
from rebind_release_resource_paths import rebind_release_paths

RECIPE = 'shared-texture-expansion-v16-v1'


def consumer_groups(groups, assets):
    """Each pool has exactly the same consumers for every contained texture.

    No consumer downloads textures used only by other models in its pool.
    Already pooled Minior members are absent and cannot be counted twice.
    """
    files = {key: {r['path']: r for r in a.get('pair_manifest', {}).get('files', [])}
             for key, a in assets.items()}
    result = defaultdict(list)
    for group in groups:
        refs = [r for r in group['references'] if r['path'] in files.get(r['asset_id'], {})]
        consumers = tuple(sorted({r['asset_id'] for r in refs}))
        if len(consumers) < 2:
            continue
        for ref in refs:
            require(files[ref['asset_id']][ref['path']]['bytes'] == ref['bytes'], 'Changed texture size')
        result[consumers].append({'state_signature': group['state_signature'], 'references': refs})
    return dict(sorted(result.items()))


def assemble(output):
    require(output.is_relative_to(ROOT / '.tmp') and not output.exists(), 'Fresh assigned-slot output required')
    binding_path = ROOT / 'release/approved_3d_v16_binding.json'
    binding = read(binding_path)
    assembly_path = Path(binding['assembly_path'])
    require(sha(assembly_path) == binding['assembly_sha256'], 'Changed v16 assembly')
    assembly = read(assembly_path)
    meta = read(ROOT / 'release/approved_3d_bundles_v16.json')
    trusted_path = ROOT / 'data/model_pair_release_v16_catalog.json'
    require(sha(trusted_path) == binding['trusted_catalog_sha256'], 'Changed v16 trusted metadata')
    trusted = {a['asset_id']: a for a in read(trusted_path)['assets']}
    source = {j['asset']['asset_id']: j for j in assembly['jobs']}
    require(len(source) == len(assembly['jobs']) == 1421 and
            sum(j['asset']['size_bytes'] for j in source.values()) == meta['total_bundle_bytes'], 'Incomplete baseline')
    for key, a in trusted.items():
        require(a == source[key]['asset'], 'Assembly differs from approved metadata')
    receipt_path = ROOT / 'release/full_texture_storage_audit_v15.json'
    parent = read(receipt_path)
    require(sha(parent['validated_receipt_path']) == parent['validated_receipt_sha256'] and
            sha(parent['report_path']) == parent['report_sha256'], 'Changed lossless audit evidence')
    validation = read(parent['validated_receipt_path'])
    grouped = consumer_groups(validation['duplicate_groups'], {k: j['asset'] for k, j in source.items()})
    require(grouped, 'No remaining shared textures')
    output.mkdir(parents=True)
    codec = Zstd()
    opened = OrderedDict()

    def members(key):
        if key not in opened:
            j = source[key]
            opened[key], _ = unpack_pck(checked_bytes(j['path'], j['asset']), j['asset'])
        opened.move_to_end(key)
        while len(opened) > 4:
            opened.popitem(last=False)
        return opened[key]

    pools, replacements, model_pools, skipped = [], {}, defaultdict(list), []
    for consumers, groups in grouped.items():
        # Existing schema supports at most 127 files in a pack.
        for offset in range(0, len(groups), 127):
            chunk = groups[offset:offset + 127]
            pooled, refs = {}, []
            for group in chunk:
                rows = group['references']
                choice = min(rows, key=lambda r: (r['bytes'], r['asset_id'], r['path']))
                target = 'textures/' + group['state_signature'] + '.res'
                pooled[target] = members(choice['asset_id'])[choice['path']]
                for ref in rows:
                    original = members(ref['asset_id'])[ref['path']]
                    require(len(original) == ref['bytes'], 'Changed physical texture')
                    declared = next(r for r in source[ref['asset_id']]['asset']['pair_manifest']['files'] if r['path'] == ref['path'])
                    require(digest(original) == declared['sha256'], 'Changed texture hash')
                    refs.append({**ref, 'target': target})
            seed = digest(encoded([RECIPE, consumers, chunk, {k: digest(v) for k, v in pooled.items()}]))
            species = 'textures-shared-' + seed[:16]
            a = {'asset_id': 'pokemon_3d:' + species + ':base', 'asset_type': 'pokemon_3d',
                 'species_id': species, 'form_id': 'base', 'version': 1, 'dependencies': [],
                 'appearances': [], 'format': 'model-texture-pck-v1', 'object_key': 'pending.pck'}
            a['pair_manifest'] = {'schema': 1, 'kind': 'pokeaether-model-textures',
                'resource_root': 'res://pokemon-pairs/' + seed,
                **{k: copy.deepcopy(a[k]) for k in ['asset_id', 'species_id', 'form_id', 'version', 'dependencies', 'appearances']},
                'files': members_manifest(pooled, codec)}
            pool = persist(a, pooled, output / 'pools' / seed)
            a['object_key'] = f"optional-assets/pokemon_3d/{species}/base/v1-{a['sha256']}.pck"
            write(Path(pool['path']).with_name('asset.json'), a)
            # Conservative admission: account for repeated embedded pool metadata,
            # plus a scene rewrite allowance. Actual PCK totals are measured below.
            estimate = sum(r['bytes'] for r in refs) - a['size_bytes'] - len(encoded(a)) * len(consumers)
            if estimate <= 4096 + 512 * len(consumers):
                skipped.append({'consumers': consumers, 'groups': len(chunk), 'estimated_net_bytes': estimate,
                                'unused_candidate_path': pool['path']})
                continue
            pool.update(consumers=list(consumers), groups=chunk)
            pools.append(pool)
            for key in consumers:
                model_pools[key].append(a)
            for ref in refs:
                key = (ref['asset_id'], ref['path'])
                require(key not in replacements, 'Ambiguous texture replacement')
                replacements[key] = a['pair_manifest']['resource_root'] + '/' + ref['target']
    affected = set(model_pools)
    # Preserve explicit cross-model dependencies, including reverse dependents.
    while True:
        added = {key for key, j in source.items() if key not in affected and
                 any(d in affected for d in j['asset'].get('dependencies', []))}
        if not added:
            break
        affected.update(added)
    roots = {key: 'res://pokemon-pairs/' + digest(encoded([RECIPE, source[key]['asset']['sha256'],
             [p['sha256'] for p in model_pools[key]]])) for key in sorted(affected)}
    mapping = {}
    for key, j in source.items():
        a = j['asset']
        old = a.get('pair_manifest', {}).get('resource_root')
        if old:
            for row in a['pair_manifest']['files']:
                mapping[old + '/' + row['path']] = replacements.get((key, row['path']), roots.get(key, old) + '/' + row['path'])
    jobs, proofs = [], []
    for number, key in enumerate(sorted(affected), 1):
        original = source[key]
        a = copy.deepcopy(original['asset'])
        manifest = a['pair_manifest']
        oldroot = manifest['resource_root']
        a['version'] += 1
        a['dependencies'] += [p['asset_id'] for p in model_pools[key]]
        all_pools = manifest.get('texture_pools', []) + model_pools[key]
        require(len(all_pools) <= 16, 'Too many pools for existing runtime contract')
        manifest.update(schema=3, version=a['version'], resource_root=roots[key],
                        dependencies=copy.deepcopy(a['dependencies']), texture_pools=copy.deepcopy(all_pools))
        rewritten = {}
        for name, data in members(key).items():
            if name == 'bundle.json' or (key, name) in replacements:
                continue
            if name.startswith('models/'):
                raw = decode(data, codec)
                rebound, proof = rebind_release_paths(raw, mapping, oldroot, roots[key])
                require(proof['body_exact'], 'Changed native model body')
                data = encode(rebound, 262144, 19, codec) if rebound != raw else data
                require(decode(data, codec) == rebound, 'Changed compressed native body')
                proofs.append({'asset_id': key, 'path': name, **proof})
            rewritten[name] = data
        manifest['files'] = members_manifest(rewritten, codec)
        files = {r['path']: r for r in manifest['files']}
        for appearance in a['appearances']:
            scene = files[appearance['runtime_path']]
            appearance.update(bytes=scene['bytes'], runtime_sha256=scene['sha256'])
        manifest['appearances'] = copy.deepcopy(a['appearances'])
        job = persist(a, rewritten, output / f'pair-{number:04d}')
        a['object_key'] = f"optional-assets/pokemon_3d/{a['species_id']}/{a['form_id']}/v{a['version']}-{a['sha256']}.pck"
        write(Path(job['path']).with_name('asset.json'), a)
        job.update(previous=original['asset'], previous_path=original['path'])
        jobs.append(job)
        # Do not retain gigabytes of original resource buffers.
        opened.pop(key, None)
        if number % 25 == 0:
            print(f'EXPANSION_ASSEMBLED {number}/{len(affected)}', flush=True)
    new = {j['asset']['asset_id']: {'asset': j['asset'], 'path': j['path']} for j in jobs}
    collection = [new.get(key, j) for key, j in sorted(source.items())] + pools
    total = sum(j['asset']['size_bytes'] for j in collection)
    require(total < meta['total_bundle_bytes'], 'Expansion has no net collection saving')
    catalog = {'schema': 1, 'kind': 'pokeaether-optional-asset-index', 'catalog_revision': RECIPE,
               'runtime_contract': {'pokemon_3d': 3, 'godot': '4.6'}, 'production_approved': False,
               'prototype_only': True, 'assets': [j['asset'] for j in collection]}
    write(output / 'catalog.json', catalog)
    config = {'schema': 1, 'complete': True, 'production_approved': False, 'prototype_only': True,
              'recipe': RECIPE, 'baseline_binding_sha256': sha(binding_path),
              'baseline_assembly_path': str(assembly_path), 'baseline_assembly_sha256': sha(assembly_path),
              'baseline_bytes': meta['total_bundle_bytes'], 'total_bundle_bytes': total,
              'net_saved_bytes': meta['total_bundle_bytes'] - total, 'new_pools': pools,
              'baseline_pools': [j for j in source.values() if j['asset'].get('format') == 'model-texture-pck-v1'],
              'jobs': jobs, 'collection': collection, 'skipped_pool_groups': skipped,
              'removed_texture_members': len(replacements), 'groups': sum(len(p['groups']) for p in pools),
              'catalog_sha256': sha(output / 'catalog.json'), 'scene_rewrites': proofs,
              'audit_receipt_sha256': sha(receipt_path), 'audit_validation_sha256': parent['validated_receipt_sha256'],
              'builder_sha256': sha(Path(__file__))}
    write(output / 'configuration.json', config)
    print('EXPANSION_MEASURED', {k: config[k] for k in ['total_bundle_bytes', 'net_saved_bytes', 'groups']},
          'models', len(jobs), 'new_pools', len(pools), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    assemble(parser.parse_args().output.resolve())
