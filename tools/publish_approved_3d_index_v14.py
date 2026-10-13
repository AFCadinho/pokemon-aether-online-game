#!/usr/bin/env python3
"""Publish immutable v14 payloads and index; never activate a player manifest."""
import argparse,concurrent.futures,datetime,hashlib,json
from pathlib import Path
from publish_shared_model_collection import load_credentials,publish_immutable,snapshot_manifests,file_digest
from publish_approved_3d_index_v8 import public_head
ROOT=Path(__file__).resolve().parents[1]
FIELDS=('asset_id','object_key','sha256','size_bytes')
def read(path):return json.loads(Path(path).read_bytes())
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def validate_local():
 meta=read(ROOT/'release/approved_3d_bundles_v14.json');index=ROOT/'release/approved_3d_bundles_v14_index.json';wire=read(index);binding=read(ROOT/'release/approved_3d_v14_binding.json')
 assert meta['revision']==wire['catalog_revision']==binding['revision']=='approved-pokemon-3d-v14'
 assert binding['runtime_approved'] and binding['publication_approved']
 assert wire['production_approved'] and not wire['prototype_only']
 assert sha(index)==meta['index']['sha256']==binding['bundle_index_sha256'] and index.stat().st_size==meta['index']['size_bytes']
 assert len(meta['bundles'])==len(wire['assets'])==1420 and len({a['asset_id'] for a in meta['bundles']})==1420
 assert sum(a['size_bytes'] for a in meta['bundles'])==meta['total_bundle_bytes'] and abs(meta['total_bundle_bytes']-8993498070)<4096
 for path,pin in binding['source_qualification_sha256'].items():assert sha(ROOT/path)==pin
 assert sha(ROOT/'release/v13_full_compression_audit.json')==binding['compression_audit_sha256']
 trusted=read(ROOT/'data/model_pair_release_v14_catalog.json');assert sha(ROOT/'data/model_pair_release_v14_catalog.json')==binding['trusted_catalog_sha256']
 catalog={a['asset_id']:a for a in trusted['assets']};assert len(catalog)==1365
 for side in ['data','launcher/data']:
  assert (ROOT/side/'approved_3d_bundles_v14_index.json').read_bytes()==index.read_bytes()
  assert (ROOT/side/'model_pair_release_v14_catalog.json').read_bytes()==(ROOT/'data/model_pair_release_v14_catalog.json').read_bytes()
  pin=read(ROOT/side/'approved_3d_release_v14.json');assert pin['revision']==meta['revision'] and pin['index']==meta['index'] and pin['requiredAssetIds']==[a['asset_id'] for a in meta['bundles']]
 for compact,row in zip(wire['assets'],meta['bundles'],strict=True):
  asset=catalog[compact['asset_id']] if compact.get('format')=='model-pair-ref-v1' else compact
  assert all(asset[k]==row[k] for k in FIELDS)
  if compact.get('format')=='model-pair-ref-v1':assert compact=={'asset_id':asset['asset_id'],'format':'model-pair-ref-v1','sha256':asset['sha256']}
 receipt=ROOT/'release/approved_3d_bundles_v14_r2_receipt.json'
 if receipt.exists():
  r=read(receipt);assert r['revision']==meta['revision'] and r['content_index']==meta['index'] and r['binding_sha256']==sha(ROOT/'release/approved_3d_v14_binding.json')
  assert len(r['bundles'])==1420
  for row,proof in zip(meta['bundles'],r['bundles'],strict=True):assert all(row[k]==proof[k] for k in FIELDS) and proof['public_get_sha256_verified'] and proof['public_head_size_verified']
  assert r['index_verification']['public_get_sha256_verified'] and r['index_verification']['public_head_size_verified']
 return meta

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sources',type=Path);p.add_argument('--credentials',type=Path);p.add_argument('--apply',action='store_true');p.add_argument('--workers',type=int,default=8,choices=range(1,17));a=p.parse_args();meta=validate_local()
 print('V14_LOCAL_OK pairs=1420 bytes=8993498070',flush=True)
 if not a.apply:return
 config=load_credentials(a.credentials);before=snapshot_manifests();receipt=ROOT/'release/approved_3d_bundles_v14_r2_receipt.json'
 if a.sources:
  source=read(a.sources);assert source['revision']==meta['revision'] and source['metadata_sha256']==sha(ROOT/'release/approved_3d_bundles_v14.json') and set(source['sources'])=={r['asset_id'] for r in meta['bundles']}
  checkpoint=a.sources.parent/'published-v14';checkpoint.mkdir(exist_ok=True)
  def publish(row):
   path=Path(source['sources'][row['asset_id']]);assert path.is_absolute() and path.is_file()
   result=publish_immutable(config,path,row)
   (checkpoint/(row['sha256']+'.json')).write_text(json.dumps(result,sort_keys=True)+'\n')
   print('V14_OBJECT_OK '+row['asset_id'],flush=True);return result
  with concurrent.futures.ThreadPoolExecutor(max_workers=a.workers) as pool:rows=list(pool.map(publish,meta['bundles']))
 else:
  assert receipt.exists(),'Upload retained archives locally before CI publication'
  rows=read(receipt)['bundles']
  with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:assert all(pool.map(public_head,meta['bundles']))
 proof=publish_immutable(config,ROOT/'release/approved_3d_bundles_v14_index.json',meta['index'])
 assert snapshot_manifests()==before,'Active manifests changed during immutable publication'
 result={'schema':1,'revision':meta['revision'],'content_index':meta['index'],'binding_sha256':sha(ROOT/'release/approved_3d_v14_binding.json'),'bundles':rows,'index_verification':proof,'active_manifest_activated':False,'manifest_snapshots':before,'verified_at_utc':datetime.datetime.now(datetime.UTC).isoformat()}
 receipt.write_text(json.dumps(result,sort_keys=True,indent=2)+'\n');print('V14_PUBLICATION_OK pairs=1420 index_verified=true manifest_activated=false',flush=True)
if __name__=='__main__':main()
