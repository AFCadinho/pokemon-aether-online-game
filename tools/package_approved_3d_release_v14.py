#!/usr/bin/env python3
"""Bind audited lossless archives and all qualified alternate forms to v14."""
import argparse,copy,hashlib,io,json,zipfile
from probe_v13_compression import unpack_pck,pack_pck,zip_payload
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WORKSPACE=ROOT.parents[2]
REVISION='approved-pokemon-3d-v14'
COHORTS=[('therian','catalog_therian_qualification','therian_qualification_sha256'),('urshifu','catalog_urshifu_qualification','urshifu_qualification_sha256'),('alternate_forms','alternate_forms_qualification','alternate_forms_qualification_sha256'),('alternate_forms_recovery','alternate_forms_recovery_qualification','alternate_forms_recovery_qualification_sha256'),('remaining_forms','remaining_forms_repair_qualification','remaining_forms_repair_qualification_sha256'),('zygarde_ten','zygarde_battle_qualification','zygarde_ten_qualification_sha256'),('remaining_fourteen','remaining_fourteen_qualification','remaining_fourteen_qualification_sha256'),('final_twenty_one','final_twenty_one_qualification','final_twenty_one_qualification_sha256')]
BINDING=ROOT/'release/approved_3d_v14_binding.json'
REGISTRY=ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'

def read(path):return json.loads(Path(path).read_bytes())
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def encoded(v):return (json.dumps(v,sort_keys=True,separators=(',',':'),allow_nan=False)+'\n').encode()
def write(path,value):Path(path).write_bytes(encoded(value))
def checked(path,expected):
 path=Path(path);assert path.is_file() and path.stat().st_size==expected['size_bytes'] and sha(path)==expected['sha256'],str(path)
 return path

def historical_registry(value):
 """Restore the exact pre-v14 admission checkpoint for historical regressions."""
 result=copy.deepcopy(value)
 if 'v14_binding_sha256' not in result:return result
 b=read(BINDING);assert result.pop('v14_binding_sha256')==sha(BINDING)
 for identity,change in b['zip_model_bindings'].items():
  current=result['models'][identity]
  assert current==change['approved'],identity
  result['models'][identity]=copy.deepcopy(change['previous'])
 return result

def versioned_payload(asset, source, output):
    # Native compressed members stay byte-for-byte identical. Only the outer
    # immutable bundle version changes, because installed same-version hashes
    # must never be replaced underneath an existing catalog.
    original=Path(source).read_bytes();asset=copy.deepcopy(asset);asset['version']+=1
    if asset.get('format')=='model-pair-pck-v1':
        baseline=copy.deepcopy(asset);baseline['version']-=1
        members,patch=unpack_pck(original,baseline)
        asset['pair_manifest']['version']=asset['version']
        natives={k:v for k,v in members.items() if k!='bundle.json'}
        members['bundle.json']=encoded(asset['pair_manifest'])
        data=pack_pck(members,asset['pair_manifest']['resource_root'],patch)
        restored,_=unpack_pck(data,asset)
    else:
        with zipfile.ZipFile(io.BytesIO(original)) as z:
            infos=z.infolist();members={i.filename:z.read(i.filename) for i in infos}
        natives={k:v for k,v in members.items() if k!='bundle.json'}
        manifest=json.loads(members['bundle.json']);manifest['version']=asset['version']
        members['bundle.json']=encoded(manifest);data=zip_payload(members,infos)
        with zipfile.ZipFile(io.BytesIO(data)) as z:restored={n:z.read(n) for n in z.namelist()}
    assert {k:v for k,v in restored.items() if k!='bundle.json'}==natives
    asset['sha256']=hashlib.sha256(data).hexdigest();asset['size_bytes']=len(data)
    asset['object_key']=asset['object_key'].rsplit('/',1)[0]+f"/v{asset['version']}-{asset['sha256']}"+Path(source).suffix
    destination=output/'versioned-packs'/asset['object_key'].split('/')[-1];destination.parent.mkdir(exist_ok=True);destination.write_bytes(data)
    assert checked(destination,asset)
    return asset,destination

def build(output):
 output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
 registry=read(REGISTRY);assert REGISTRY.read_bytes()==(ROOT/'launcher/data/reviewed_model_catalog.json').read_bytes()
 if BINDING.exists():
  original=historical_registry(registry)
 else:original=copy.deepcopy(registry)
 old_meta=read(ROOT/'release/approved_3d_bundles_v13.json');audit=read(ROOT/'release/v13_full_compression_audit.json')
 assert audit['complete'] and audit['summary']['selected_total_bytes']==7659148338 and len(audit['pairs'])==1200
 compression=WORKSPACE/'.worktrees/slot-d/frontend'
 for file,pin in audit['artifacts'].items():checked(compression/pin['path'],dict(size_bytes=pin['bytes'],sha256=pin['sha256']))
 full=read(compression/audit['artifacts']['report.json']['path']);details={p['asset_id']:p for p in full['pairs']}
 assert len(details)==1200 and full['complete']
 assets=[];sources={};zip_changes={};proofs={}
 for pair in audit['pairs']:
  key=pair['asset_id'];assert pair['persisted_streams_byte_exact'] and pair['linux_appearances_loaded']==2
  row=details[key];config,=row['configurations'];candidate=checked(config['path'],dict(size_bytes=pair['candidate']['size_bytes'],sha256=pair['candidate']['sha256']))
  assert pair['measurement_sha256']==hashlib.sha256(encoded(row)).hexdigest()
  a=read(config['asset_path']);assert (a['sha256'],a['size_bytes'])==(pair['candidate']['sha256'],pair['candidate']['size_bytes'])
  assert pair['source']['sha256']==row['source_sha256']
  a,candidate=versioned_payload(a,candidate,output)
  sources[key]=str(candidate);assets.append(a);proofs[key]={'compression':True,'source_sha256':pair['source']['sha256'],'measurement_sha256':pair['measurement_sha256'],'engine_evidence_sha256':pair['engine_evidence_sha256']}
  if pair['format']=='zip':
   for appearance in a['appearances']:
    identity=appearance['runtime_identity'];previous=copy.deepcopy(original['models'][identity]);digest=appearance['runtime_sha256'];approved=copy.deepcopy(previous)
    assert digest!=previous['sha256'] and digest not in previous.get('previous_sha256',[])
    approved.setdefault('previous_sha256',[]).append(digest)
    zip_changes[identity]={'previous':previous,'approved':approved,'candidate_sha256':digest,'source_archive_sha256':pair['source']['sha256'],'decoded_byte_exact':True}
 # Read retained qualified payloads in place; no artifact/caches are copied.
 roots=[WORKSPACE/'.worktrees'/s/'frontend/.tmp' for s in ['slot-a','slot-b','slot-c','slot-d']]
 candidates={}
 for root in roots:
  for pattern in ['*/delivery/*/shared/packs/*.pck','*/shared/packs/*.pck','*/delivery/shared/packs/*.pck']:
   for path in root.glob(pattern):candidates.setdefault(path.name,[]).append(path)
 qualifications={}
 for cohort,file,tag in COHORTS:
  p=ROOT/'tools/sprite_factory'/(file+'.json');q=read(p);index=ROOT/'release'/('approved_3d_'+cohort+'_index.json');j=read(index)
  assert q['runtime_approved'] and q['admitted_registry_check_passed'] and original[tag]==sha(p)
  assert q['bundle_index_sha256']==sha(index)
  qualifications[str(p.relative_to(ROOT))]=sha(p)
  for a in j['assets']:
   assert a['asset_id'] not in sources
   paths=candidates.get(a['object_key'].split('/')[-1],[]);assert paths,a['asset_id']
   path=checked(paths[0],a);sources[a['asset_id']]=str(path);assets.append(a);proofs[a['asset_id']]={'qualification_sha256':sha(p),'cohort':cohort}
 assert len(assets)==len(sources)==1420 and len(zip_changes)==110
 assert abs(sum(a['size_bytes'] for a in assets)-8993498070)<4096
 for asset in assets:asset.setdefault('asset_type','pokemon_3d')
 assets.sort(key=lambda a:a['asset_id'])
 covered={}
 for a in assets:
  assert len(a['appearances'])==2 and {p['variant'] for p in a['appearances']}=={'normal','shiny'}
  for p in a['appearances']:
   identity=p['runtime_identity'];assert identity not in covered;model=original['models'][identity]
   if a.get('format')=='model-pair-pck-v1':assert p['source_sha256'] in [model['sha256'],*model.get('previous_sha256',[])]
   else:assert identity in zip_changes
   covered[identity]=True
 assert set(covered)==set(original['models']) and len(covered)==2840
 trusted={'schema':1,'kind':'pokeaether-model-pair-catalog','catalog_revision':REVISION,'assets':[a for a in assets if a.get('format')=='model-pair-pck-v1']}
 wire={'schema':1,'kind':'pokeaether-optional-asset-index','catalog_revision':REVISION,'runtime_contract':{'pokemon_3d':2,'godot':'4.6'},'production_approved':True,'prototype_only':False,'assets':[{'asset_id':a['asset_id'],'format':'model-pair-ref-v1','sha256':a['sha256']} if a.get('format')=='model-pair-pck-v1' else a for a in assets]}
 data=encoded(wire);assert len(data)<=1024*1024
 pin={'object_key':'optional-assets/pokemon_3d/index/v14-'+hashlib.sha256(data).hexdigest()+'.json','sha256':hashlib.sha256(data).hexdigest(),'size_bytes':len(data)}
 meta={'schema':1,'kind':'pokeaether-approved-3d-release','revision':REVISION,'index':pin,'bundles':[{k:a[k] for k in ['asset_id','object_key','sha256','size_bytes']} for a in assets],'total_bundle_bytes':sum(a['size_bytes'] for a in assets),'new_pairs':220,'compression_saved_bytes':audit['summary']['saved_bytes'],'source_qualification_sha256':qualifications,'compression_audit_sha256':sha(ROOT/'release/v13_full_compression_audit.json'),'previous_index_sha256':old_meta['index']['sha256']}
 client={'schema':1,'revision':REVISION,'index':pin,'requiredAssetIds':[a['asset_id'] for a in assets]}
 for side in ['data','launcher/data']:
  write(ROOT/side/'model_pair_release_v14_catalog.json',trusted);write(ROOT/side/'approved_3d_release_v14.json',client);(ROOT/side/'approved_3d_bundles_v14_index.json').write_bytes(data)
 (ROOT/'release/approved_3d_bundles_v14_index.json').write_bytes(data);write(ROOT/'release/approved_3d_bundles_v14.json',meta)
 binding={'schema':1,'revision':REVISION,'runtime_approved':False,'publication_approved':False,'previous_registry_sha256':hashlib.sha256((json.dumps(original,indent='\t',allow_nan=False)+'\n').encode()).hexdigest(),'zip_model_bindings':zip_changes,'source_qualification_sha256':qualifications,'compression_audit_sha256':meta['compression_audit_sha256'],'bundle_index_sha256':pin['sha256'],'trusted_catalog_sha256':sha(ROOT/'data/model_pair_release_v14_catalog.json'),'pairs':1420,'appearances':2840,'profiles_unchanged':True,'proofs':proofs}
 write(BINDING,binding)
 for identity,change in zip_changes.items():registry['models'][identity]=change['approved']
 registry['v14_binding_sha256']=sha(BINDING)
 data=(json.dumps(registry,indent='\t',allow_nan=False)+'\n').encode();REGISTRY.write_bytes(data);(ROOT/'launcher/data/reviewed_model_catalog.json').write_bytes(data)
 write(output/'sources.json',{'revision':REVISION,'sources':sources,'metadata_sha256':sha(ROOT/'release/approved_3d_bundles_v14.json')})
 print('V14_PREPARED pairs=1420 bytes='+str(meta['total_bundle_bytes'])+' index_bytes='+str(pin['size_bytes']),flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build(a.output)
