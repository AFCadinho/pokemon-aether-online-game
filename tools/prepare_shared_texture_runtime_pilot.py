#!/usr/bin/env python3
"""Derive fresh schema-3 pilot archives from the verified Minior experiment."""
import argparse
import copy
from pathlib import Path
from probe_v13_compression import checked_bytes, decode, encode, encoded, read, require, unpack_pck, write, Zstd
from study_lossless_texture_storage import ROOT, sha
from study_shared_form_textures import digest, members_manifest, persist, rebind_external_paths

RECIPE = 'shared-texture-runtime-minior-v1'


def prepare(output):
    evidence = read(ROOT/'release/shared_form_texture_study_v15.json')
    parent_report = Path(evidence['report_path'])
    require(sha(parent_report) == evidence['report_sha256'], 'Changed shared texture evidence')
    old = read(parent_report.with_name('configuration.json'))
    require(sha(parent_report.with_name('configuration.json')) == evidence['configuration_sha256'], 'Changed source configuration')
    output.mkdir(parents=True, exist_ok=False)
    codec = Zstd()
    source_pool = old['pool']
    pool_members, _ = unpack_pck(checked_bytes(source_pool['path'], source_pool['asset']), source_pool['asset'])
    pool_members.pop('bundle.json')
    source_root = source_pool['asset']['pair_manifest']['resource_root']
    root = 'res://pokemon-pairs/'+digest(encoded([RECIPE, source_pool['asset']['sha256']]))
    species = 'textures-minior-'+digest(encoded([RECIPE, source_pool['asset']['sha256']]))[:16]
    pool = {'asset_id':'pokemon_3d:'+species+':base','asset_type':'pokemon_3d','species_id':species,'form_id':'base',
            'version':1,'dependencies':[],'appearances':[],'format':'model-texture-pck-v1'}
    pool['pair_manifest'] = {'schema':1,'kind':'pokeaether-model-textures','resource_root':root,
                            **{k:copy.deepcopy(pool[k]) for k in ['asset_id','species_id','form_id','version','dependencies','appearances']},
                            'files':members_manifest(pool_members, codec)}
    # Object key is outside the embedded manifest and has no circular hash.
    pool['object_key'] = 'pending.pck'
    pooled = persist(pool, pool_members, output/'pool')
    pool['object_key'] = f"optional-assets/pokemon_3d/{species}/base/v1-{pool['sha256']}.pck"
    write(Path(pooled['path']).with_name('asset.json'), pool)
    jobs = []
    for parent in old['jobs']:
        original = parent['asset']
        members, _ = unpack_pck(checked_bytes(parent['path'], original), original)
        members.pop('bundle.json')
        asset = copy.deepcopy(original)
        asset['version'] += 1
        newroot = 'res://pokemon-pairs/'+digest(encoded([RECIPE, original['sha256'], pool['sha256']]))
        asset['dependencies'] = [pool['asset_id']]
        manifest = asset['pair_manifest']
        manifest.update(schema=3, version=asset['version'],resource_root=newroot,dependencies=asset['dependencies'],texture_pools=[copy.deepcopy(pool)])
        mapping = {original['pair_manifest']['resource_root']+'/'+name:newroot+'/'+name for name in members}
        mapping.update({source_root+'/'+name:root+'/'+name for name in pool_members})
        rewritten = {}
        for name, data in members.items():
            raw = decode(data, codec)
            rebound, proof = rebind_external_paths(raw, mapping)
            require(proof['body_exact'], 'Model body changed')
            rewritten[name] = encode(rebound, 262144, 19, codec) if rebound != raw else data
        manifest['files'] = members_manifest(rewritten, codec)
        by_path = {r['path']:r for r in manifest['files']}
        for a in asset['appearances']:
            row = by_path[a['runtime_path']]
            a.update(bytes=row['bytes'],runtime_sha256=row['sha256'])
        manifest['appearances'] = copy.deepcopy(asset['appearances'])
        job = persist(asset, rewritten, output/asset['species_id'])
        asset['object_key'] = f"optional-assets/pokemon_3d/{asset['species_id']}/{asset['form_id']}/v{asset['version']}-{asset['sha256']}.pck"
        write(Path(job['path']).with_name('asset.json'),asset)
        job.update(textures=parent['textures'],texture_paths={name:path.replace(original['pair_manifest']['resource_root'],newroot).replace(source_root,root) for name,path in parent['texture_paths'].items()})
        jobs.append(job)
    catalog = {'schema':1,'kind':'pokeaether-optional-asset-index','catalog_revision':'shared-textures-minior-runtime-v1',
               'runtime_contract':{'pokemon_3d':3,'godot':'4.6'},'prototype_only':True,'production_approved':False,
               'assets':[pool,*[j['asset'] for j in jobs]]}
    write(output/'catalog.json',catalog)
    receipt = {'schema':1,'complete':True,'prototype_only':True,'production_approved':False,'recipe':RECIPE,
               'source_receipt_sha256':sha(ROOT/'release/shared_form_texture_study_v15.json'),
               'jobs':jobs,'pool':pooled,'catalog_sha256':sha(output/'catalog.json'),
               'total_bundle_bytes':sum(a['size_bytes'] for a in catalog['assets']),
               'builder_sha256':sha(Path(__file__))}
    write(output/'configuration.json',receipt)
    return catalog


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',required=True,type=Path)
    args = parser.parse_args()
    require(args.output.resolve().is_relative_to(ROOT/'.tmp'), 'Outputs must stay in the assigned slot')
    prepare(args.output.resolve())
    print('SHARED_TEXTURE_RUNTIME_PILOT_PREPARED')
