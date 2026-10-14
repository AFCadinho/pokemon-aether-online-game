#!/usr/bin/env python3
"""Independently reopen expansion packs and bind cold/restart native evidence."""
import argparse
from pathlib import Path

from probe_v13_compression import checked_bytes, decode, read, require, unpack_pck, write, Zstd
from study_lossless_texture_storage import ROOT, sha
from study_shared_form_textures import digest
from rebind_release_resource_paths import rebind_release_paths


def validate(qualification_path, contract_log):
    proof = read(qualification_path)
    configuration = Path(proof['configuration_path'])
    require(sha(configuration) == proof['configuration_sha256'], 'Changed assembly configuration')
    config = read(configuration)
    require(sha(config['baseline_assembly_path']) == config['baseline_assembly_sha256'], 'Changed baseline')
    binding = ROOT / 'release/approved_3d_v16_binding.json'
    require(sha(binding) == config['baseline_binding_sha256'], 'Changed approved baseline binding')
    for name, expected in proof['driver_inputs'].items():
        require(sha(ROOT / name) == expected, 'Changed qualification driver: ' + name)
    work = qualification_path.parent
    for name, expected in proof['inputs'].items():
        require(sha(work / name) == expected, 'Changed linked native input: ' + name)
    for name, expected in proof['reports'].items():
        require(sha(work / name) == expected, 'Changed native report: ' + name)
    baseline = {j['asset']['asset_id']: j for j in read(config['baseline_assembly_path'])['jobs']}
    changed = {j['asset']['asset_id']: j for j in config['jobs']}
    new_pools = {j['asset']['asset_id']: j for j in config['new_pools']}
    require(len(changed) == len(config['jobs']) and not (baseline.keys() & new_pools.keys()), 'Duplicate asset identity')
    collection = {j['asset']['asset_id']: j for j in config['collection']}
    require(len(collection) == len(config['collection']) and collection.keys() == baseline.keys() | new_pools.keys(), 'Collection coverage changed')
    for key, job in baseline.items():
        expected = changed.get(key, job)
        require(collection[key]['asset'] == expected['asset'] and collection[key]['path'] == expected['path'], 'Collection member changed')
    for key, job in new_pools.items():
        require(collection[key] == job, 'Pool collection member changed')
    before = sum(j['asset']['size_bytes'] for j in baseline.values())
    after = sum(j['asset']['size_bytes'] for j in collection.values())
    require((before, after, before - after) == tuple(config[k] for k in
            ['baseline_bytes', 'total_bundle_bytes', 'net_saved_bytes']), 'Collection accounting changed')
    codec = Zstd()
    originals = {}
    replacements = {}
    for key, job in changed.items():
        require(job['previous'] == baseline[key]['asset'] and job['previous_path'] == baseline[key]['path'], 'Unbound original')
        originals[key], _ = unpack_pck(checked_bytes(job['previous_path'], job['previous']), job['previous'])
    for pool in new_pools.values():
        a = pool['asset']
        packed, _ = unpack_pck(checked_bytes(pool['path'], a), a)
        expected_paths = set()
        for group in pool['groups']:
            path = 'textures/' + group['state_signature'] + '.res'
            expected_paths.add(path)
            refs = group['references']
            require(sorted({r['asset_id'] for r in refs}) == pool['consumers'], 'Pool adds unrelated consumer downloads')
            choices = [originals[r['asset_id']][r['path']] for r in refs]
            require(packed[path] in choices and len(packed[path]) == min(map(len, choices)), 'Pool texture changed')
            for ref in refs:
                pair = (ref['asset_id'], ref['path'])
                require(pair not in replacements, 'Ambiguous texture reference')
                replacements[pair] = a['pair_manifest']['resource_root'] + '/' + path
        require(set(packed) == expected_paths | {'bundle.json'}, 'Pool member set changed')
    mapping = {}
    for key, job in baseline.items():
        old = job['asset'].get('pair_manifest', {}).get('resource_root')
        if old:
            new = changed[key]['asset']['pair_manifest']['resource_root'] if key in changed else old
            for row in job['asset']['pair_manifest']['files']:
                mapping[old + '/' + row['path']] = replacements.get((key, row['path']), new + '/' + row['path'])
    for key, job in changed.items():
        asset = job['asset']
        old = job['previous']
        packed, _ = unpack_pck(checked_bytes(job['path'], asset), asset)
        original = originals.pop(key)
        require(set(packed) == {p for p in original if (key, p) not in replacements}, 'Model member set changed')
        for path, data in packed.items():
            if path == 'bundle.json':
                continue
            if path.startswith('models/'):
                expected, exact = rebind_release_paths(decode(original[path], codec), mapping,
                    old['pair_manifest']['resource_root'], asset['pair_manifest']['resource_root'])
                require(exact['body_exact'] and decode(data, codec) == expected, 'Native model content changed')
            else:
                require(data == original[path], 'Non-scene resource changed')
        for previous, current in zip(old['appearances'], asset['appearances']):
            require({k: v for k, v in previous.items() if k not in ['bytes', 'runtime_sha256']} ==
                    {k: v for k, v in current.items() if k not in ['bytes', 'runtime_sha256']}, 'Appearance identity or source budget changed')
    native = {r['asset_id']: r for r in proof['records']}
    require(native.keys() == changed.keys() and len(native) == proof['pairs'], 'Native coverage changed')
    for key, job in changed.items():
        require(native[key]['source_sha256'] == job['previous']['sha256'] and
                native[key]['candidate_sha256'] == job['asset']['sha256'], 'Native pack binding changed')
        require({r['identity'] for r in native[key]['looks']} ==
                {a['runtime_identity'] for a in job['asset']['appearances']}, 'Native appearance coverage changed')
    require(proof['complete'] and proof['prototype_only'] and not proof['runtime_approved'] and
            not proof['publication_approved'], 'Unexpected approval state')
    contract_text = contract_log.read_text()
    require(f'SHARED_TEXTURE_EXPANSION_CONTRACT_OK pairs={len(changed)} ' in contract_text and
            'production_unchanged=true' in contract_text and 'ERROR:' not in contract_text,
            'Missing successful dependency/admission contract check')
    receipt = dict(proof)
    receipt.update(qualification_path=str(qualification_path), qualification_sha256=sha(qualification_path),
                   validator_sha256=sha(Path(__file__)), all_changed_packs_reopened=True,
                   all_non_path_native_bytes_exact=True, removed_texture_members=len(replacements),
                   contract_check={'log_path': str(contract_log), 'log_sha256': sha(contract_log),
                       'script_sha256': sha(ROOT / 'tests/shared_texture_expansion_contract_check.gd'),
                       'game_index_sha256': sha(ROOT / 'scripts/services/asset_bundle_index.gd'),
                       'game_pack_sha256': sha(ROOT / 'scripts/services/model_pair_pack.gd'),
                       'launcher_pack_sha256': sha(ROOT / 'launcher/scripts/model_pair_pack.gd')})
    return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qualification', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--contract-log', type=Path, required=True)
    args = parser.parse_args()
    receipt = validate(args.qualification.resolve(), args.contract_log.resolve())
    write(args.output, receipt)
    print('SHARED_TEXTURE_EXPANSION_VALIDATED', receipt['net_saved_bytes'], receipt['total_bundle_bytes'])
