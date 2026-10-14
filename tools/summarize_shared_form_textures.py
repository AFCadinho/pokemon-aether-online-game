#!/usr/bin/env python3
"""Reopen every pilot pack and bind the native source/cold/restart evidence."""
import argparse
from pathlib import Path

from probe_v13_compression import checked_bytes, decode, read, require, unpack_pck, write, Zstd
from study_lossless_texture_storage import ROOT, sha
from study_shared_form_textures import rebind_external_paths, SCRIPT
from resume_isolated_texture_audit import SCRIPTS


def validate(study):
    report = read(study/'report.json')
    config = read(study/'configuration.json')
    require(report['complete'] and report['prototype_only'] and not report['production_approved'], 'Incomplete/private status changed')
    require(sha(study/'configuration.json') == report['configuration_sha256'], 'Configuration changed')
    require(config['inputs'] == report['inputs'] and all(sha(ROOT/p) == s for p,s in config['inputs'].items()), 'Experiment inputs changed')
    parent_path = ROOT/'release/full_texture_storage_audit_v15.json'
    require(sha(parent_path) == report['parent_receipt_sha256'] == config['parent_receipt_sha256'], 'Parent audit changed')
    parent = read(parent_path)
    require(sha(parent['report_path']) == parent['report_sha256'] == config['parent_report_sha256'] and
            sha(parent['validated_receipt_path']) == parent['validated_receipt_sha256'] == config['parent_validation_sha256'], 'Full baseline evidence changed')
    require(sha(study/'native-project/project.godot') == config['project_sha256'], 'Native project changed')
    for name in [*SCRIPTS, SCRIPT]:
        link = study/'native-project'/name
        require(link.is_symlink() and link.resolve() == (ROOT/name).resolve(), 'Native script link changed')
    baseline_rows = {r['asset_id']: r for r in parent['records']}
    source = {j['asset']['asset_id']: j for j in config['source_jobs']}
    jobs = {j['asset']['asset_id']: j for j in config['jobs']}
    require(len(source) == len(config['source_jobs']) == len(jobs) == len(config['jobs']) == report['pairs'] == 8 and source.keys() == jobs.keys(), 'Pilot coverage changed')
    codec = Zstd()
    opened = {}
    for job in [*source.values(), *jobs.values(), config['pool']]:
        a = job['asset']
        members, _ = unpack_pck(checked_bytes(job['path'], a), a)
        opened[a['sha256']] = members
    pool = config['pool']
    pooled = opened[pool['asset']['sha256']]
    poolroot = pool['asset']['pair_manifest']['resource_root']
    refs = {}
    for group in pool['groups']:
        require(group['path'] in pooled and len({r['asset_id'] for r in group['references']}) >= 2, 'Unbound/unused pool group')
        for ref in group['references']:
            key = (ref['asset_id'], ref['path'])
            require(key not in refs and key[0] in source, 'Ambiguous shared reference')
            require(source[key[0]]['textures'][key[1]] == group['state_signature'], 'Shared texture state differs')
            require(jobs[key[0]]['texture_paths'][key[1]] == poolroot+'/'+group['path'], 'Shared path differs')
            refs[key] = group['path']
        choices = [opened[source[r['asset_id']]['asset']['sha256']][r['path']] for r in group['references']]
        require(pooled[group['path']] in choices and len(pooled[group['path']]) == min(map(len, choices)), 'Pool did not retain an exact smallest source payload')
    require(set(pooled)-{'bundle.json'} == {g['path'] for g in pool['groups']}, 'Unexpected pool resources')
    for asset_id, original in source.items():
        a = original['asset']
        bound = baseline_rows[asset_id]
        require(a['sha256'] == bound['sha256'] and a['size_bytes'] == bound['selected_bytes'] == bound['candidate_bytes'], 'Unbound selected baseline')
        candidate = jobs[asset_id]
        before = opened[a['sha256']]
        after = opened[candidate['asset']['sha256']]
        oldroot = a['pair_manifest']['resource_root']
        newroot = candidate['asset']['pair_manifest']['resource_root']
        require(newroot != oldroot and newroot != poolroot, 'Namespace was reused')
        mapping = {oldroot+'/'+p: candidate['texture_paths'].get(p, newroot+'/'+p) for p in before if p != 'bundle.json'}
        require(set(after)-{'bundle.json'} == {p for p in before if p != 'bundle.json' and (asset_id,p) not in refs}, 'Pair member closure changed')
        for p in after:
            if p == 'bundle.json': continue
            raw = decode(before[p], codec)
            expected, evidence = rebind_external_paths(raw, mapping)
            require(decode(after[p], codec) == expected and evidence['body_exact'], 'Non-path native content changed')
            if expected == raw: require(after[p] == before[p], 'Unchanged member was rewritten')
    native = {}
    proofs = {}
    for phase, report_key, pack_set in [('source','source_report_sha256',source), ('cold','cold_report_sha256',jobs), ('restart','restart_report_sha256',jobs)]:
        folder = study/phase
        require(sha(folder/'report.json') == report[report_key], 'Native report changed')
        r = read(folder/'report.json')
        expected_jobs = config['source_jobs'] if phase == 'source' else config['jobs']
        if phase == 'restart': expected_jobs = list(reversed(expected_jobs))
        require(read(folder/'input.json') == {'jobs':expected_jobs, 'pool':{} if phase == 'source' else pool}, 'Native configuration differs')
        require(r['complete'] and r['input_sha256'] == sha(folder/'input.json'), 'Native input binding changed')
        require(r['packs'] == {k:j['asset']['sha256'] for k,j in pack_set.items()}, 'Native pack binding changed')
        require(r['pool_sha256'] == ('' if phase == 'source' else pool['asset']['sha256']), 'Native pool binding changed')
        log = (folder/'stdout.log').read_text()
        require('SHARED_FORM_TEXTURE_OK' in log and 'ERROR:' not in log and 'SCRIPT ERROR' not in log, 'Native process did not succeed')
        native[phase] = r
        proofs[phase] = {p:sha(folder/p) for p in ['report.json','input.json','stdout.log','engine.log']}
    require(native['source']['models'] == native['cold']['models'] == native['restart']['models'] and
            native['source']['textures'] == native['cold']['textures'] == native['restart']['textures'], 'Native state/motion changed')
    for phase in ['cold','restart']:
        o = native[phase]['ownership']
        require(o['evicted_pool_resources'] == len(pool['groups']) and o['production_pair_rejections'] == len(jobs) and
                o['simultaneous_actors'] == 2*len(jobs) and o['shared_model_texture_edges'] > len(pool['groups']) and
                o['isolated_material_mutations'] > 0 and o['free_one_survivors_exact'] and o['reload_exact'], 'Incomplete ownership evidence')
    require(report['shared_groups'] == len(pool['groups']) and report['removed_texture_members'] == len(refs) and
            report['looks'] == len(native['cold']['models']) == 16 and
            report['motion_samples'] == sum(len(m['motion']) for m in native['cold']['models'].values()), 'Native coverage differs')
    before = sum(j['asset']['size_bytes'] for j in source.values())
    after = sum(j['asset']['size_bytes'] for j in jobs.values())+pool['asset']['size_bytes']
    total = parent['selected_collection_bytes']-(before-after)
    require((before,after,before-after,total,total<7000000000) ==
            tuple(report[k] for k in ['pilot_before_bytes','pilot_after_including_pool_bytes','net_saved_bytes','combined_prototype_collection_bytes','under_7_decimal_gb']), 'Measured total differs')
    receipt = {k:v for k,v in report.items() if k != 'rewrites'}
    receipt.update(report_path=str(study/'report.json'), report_sha256=sha(study/'report.json'),
                   validator_sha256=sha(Path(__file__)), native_proofs=proofs, all_packs_reopened=True,
                   all_native_bodies_exact=True, physical_packs=17,
                   runtime_release_qualified=False)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--study', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    receipt = validate(args.study.resolve())
    write(args.output, receipt)
    print('SHARED_FORM_TEXTURE_VALIDATED', receipt['combined_prototype_collection_bytes'])


if __name__ == '__main__': main()
