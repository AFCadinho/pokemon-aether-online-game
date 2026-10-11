#!/usr/bin/env python3
"""Check geometry selection, fallback preservation and launcher/game data parity."""
import copy
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]


def check(wire,catalog,baseline,proof):
    assert wire['catalog_revision']=='shared-geometry-test-v1'
    assert wire['prototype_only'] and not wire['production_approved']
    assert not any(k in wire for k in ('qualification_run_sha256','qualification_sha256','storage_audit_sha256'))
    assets={a['asset_id']:a for a in catalog['assets']}
    assert len(assets)==len(catalog['assets'])==proof['selected_pairs']
    assert len(wire['assets'])==len(baseline['assets'])==1200
    rows={r['asset_id']:r for r in proof['pairs']}
    for current,old in zip(wire['assets'],baseline['assets'],strict=True):
        key=current['asset_id'];assert key==old['asset_id']
        if key not in assets:assert current==old;continue
        a=assets[key];r=rows[key]
        assert current=={'asset_id':key,'format':'model-pair-ref-v1','sha256':a['sha256']}
        assert a['sha256']==r['sha256'] and a['size_bytes']==r['candidate_bytes'] < r['baseline_bytes']
        assert r['cold_verified'] and a['pair_manifest']['schema']==2
        assert a['appearances']==a['pair_manifest']['appearances']
        members={f['path']:f for f in a['pair_manifest']['files']}
        assert len(members)==len(a['pair_manifest']['files'])<128
        for appearance in a['appearances']:
            member=members[appearance['runtime_path']]
            assert member['sha256']==appearance['runtime_sha256'] and member['bytes']==appearance['bytes']


def main():
    read=lambda p:json.loads((ROOT/p).read_bytes())
    wire=read('data/model_pair_geometry.json');catalog=read('data/model_pair_geometry_catalog.json')
    baseline=read('data/model_pair_qualified.json');proof=read('release/shared_model_geometry_collection.json')
    for name in ('model_pair_geometry.json','model_pair_geometry_catalog.json'):
        assert (ROOT/'data'/name).read_bytes()==(ROOT/'launcher/data'/name).read_bytes()
    assert len((ROOT/'data/model_pair_geometry.json').read_bytes())<=1024*1024
    assert wire['geometry_build_sha256']==catalog['geometry_build_sha256']==proof['build_report_sha256']
    assert wire['baseline_index_sha256']==hashlib.sha256((ROOT/'data/model_pair_qualified.json').read_bytes()).hexdigest()
    originals={a['asset_id']:a for a in read('release/approved_3d_bundles_v11_index.json')['assets']}
    bindings=read('release/approved_3d_lossless_binding.json')['models']
    for asset in catalog['assets']:
        for appearance,source in zip(asset['appearances'],originals[asset['asset_id']]['appearances'],strict=True):
            assert appearance['runtime_identity']==source['runtime_identity']
            assert appearance['source_sha256']==source['runtime_sha256']
            assert appearance['cache_source_bytes']==bindings[appearance['runtime_identity']]['cache_source_bytes']
    check(wire,catalog,baseline,proof)
    for mutation in ('hash','fallback','duplicate','bytes'):
        w=copy.deepcopy(wire);c=copy.deepcopy(catalog)
        if mutation=='hash':next(a for a in w['assets'] if a['asset_id']==c['assets'][0]['asset_id'])['sha256']='0'*64
        elif mutation=='fallback':next(a for a in w['assets'] if a['asset_id'] not in {b['asset_id'] for b in c['assets']})['sha256']='0'*64
        elif mutation=='duplicate':w['assets'][1]=w['assets'][0]
        else:c['assets'][0]['size_bytes']+=1
        try:check(w,c,baseline,proof)
        except AssertionError:continue
        raise AssertionError('Accepted '+mutation)
    print('SHARED_GEOMETRY_METADATA_OK selected='+str(len(catalog['assets']))+' fallbacks='+str(1200-len(catalog['assets']))+' negative_cases=4')

if __name__=='__main__':main()
