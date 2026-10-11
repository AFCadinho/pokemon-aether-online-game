#!/usr/bin/env python3
"""Compile only verified smaller geometry pairs; preserve all baseline fallbacks."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def read(path): return json.loads(Path(path).read_bytes())
def sha(path):
    with Path(path).open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
def encode(value): return (json.dumps(value,sort_keys=True,separators=(',',':'))+'\n').encode()


def assemble(report, baseline, held):
    assert report['complete'] and report['prototype_only'] and not report['production_approved']
    records={r['asset']['asset_id']:r for r in report['records']}
    assert len(records)==report['pairs_built']==1031
    assert set(held)<=set(records)
    selected={key:r for key,r in records.items() if r['smaller'] and key not in held}
    assert set(selected) <= {a['asset_id'] for a in baseline['assets']}
    for key,row in selected.items():
        assert row['verification']['ok'] and row['verification']['asset_id']==key
        assert row['asset']['pair_manifest']['schema']==2
        assert row['asset']['size_bytes'] < row['baseline_bytes']
    wire={k:baseline[k] for k in ('schema','kind','runtime_contract')}
    wire.update(catalog_revision='shared-geometry-test-v1',prototype_only=True,production_approved=False,
        assets=[{'format':'model-pair-ref-v1','asset_id':a['asset_id'],'sha256':selected[a['asset_id']]['asset']['sha256']}
                if a['asset_id'] in selected else a for a in baseline['assets']])
    assert len(wire['assets'])==len({a['asset_id'] for a in wire['assets']})==1200
    catalog={'schema':1,'prototype_only':True,'production_approved':False,'assets':[selected[key]['asset'] for key in sorted(selected)]}
    return catalog,wire


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--collection',type=Path,required=True)
    p.add_argument('--hold',action='append',default=[],help='Explicit whole-pair hold; baseline retained')
    args=p.parse_args();report=read(args.collection/'report.json');baseline=read(ROOT/'data/model_pair_qualified.json')
    catalog,wire=assemble(report,baseline,set(args.hold))
    selected={a['asset_id'] for a in catalog['assets']}
    for row in report['records']:
        if row['asset']['asset_id'] in selected: assert sha(row['path'])==row['asset']['sha256']
    for target in (catalog,wire):
        target['geometry_build_sha256']=sha(args.collection/'report.json')
        target['baseline_index_sha256']=sha(ROOT/'data/model_pair_qualified.json')
    assert len(encode(wire))<=1024*1024
    for directory in (ROOT/'data',ROOT/'launcher/data'):
        (directory/'model_pair_geometry_catalog.json').write_bytes(encode(catalog))
        (directory/'model_pair_geometry.json').write_bytes(encode(wire))
    print('GEOMETRY_CATALOG_COMPILED selected=',len(selected),'fallback=',1200-len(selected),'index_bytes=',len(encode(wire)))

if __name__=='__main__':main()
