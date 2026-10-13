#!/usr/bin/env python3
"""Seal local upgrade/binding evidence before immutable v14 publication."""
import argparse,hashlib,json,subprocess
from pathlib import Path
from package_approved_3d_release_v14 import ROOT,BINDING,REGISTRY,read,write,sha

def seal(work):
 work=Path(work).resolve();binding=read(BINDING)
 runtime=read(work/'binding-runtime.json');assert runtime['complete'] and runtime['pairs']==1420 and runtime['appearances']==2840
 evidence={}
 for phase in ['original','verify-original','upgrade','verify-upgrade','rollback','verify-rollback']:
  p=work/'upgrade'/(phase+'.json');r=read(p);assert r['complete'] and r['phase']==phase
  log=work/('upgrade-original.log' if phase=='original' else 'upgrade-'+phase+'-gl.log')
  text=log.read_text();assert 'MODEL_V14_UPGRADE_OK' in text and 'ERROR:' not in text and 'SCRIPT ERROR' not in text
  evidence[str(p.relative_to(work))]=sha(p);evidence[str(log.relative_to(work))]=sha(log)
 assert read(work/'upgrade/upgrade.json')['failed_batch_preserved_generation']
 assert read(work/'upgrade/verify-upgrade.json')['appearances_loaded']==22
 assert read(work/'upgrade/verify-rollback.json')['appearances_loaded']==14
 log=work/'binding-runtime-v3.log';assert 'APPROVED_3D_V14_OK' in log.read_text() and 'ERROR:' not in log.read_text()
 for p in [work/'binding-runtime.json',log,work/'upgrade-input.json']:evidence[str(p.relative_to(work))]=sha(p)
 paths=['scripts/services/model_pair_pilot.gd','launcher/scripts/model_pair_pilot.gd','launcher/scripts/release_asset_bundles.gd','tools/package_launcher_release.py','tools/package_approved_3d_release_v14.py','tools/publish_approved_3d_index_v14.py','tools/seal_approved_3d_release_v14.py','tests/approved_3d_release_v14_check.gd','tests/model_release_v14_upgrade_check.gd']
 code={}
 for name in paths:
  previous=subprocess.run(['git','show','8fb8f39eb59ecf71e9fb3e5c8fbf25b783406f58:'+name],cwd=ROOT,capture_output=True)
  code[name]={'sha256':sha(ROOT/name),'previous_sha256':hashlib.sha256(previous.stdout).hexdigest() if previous.returncode==0 else None}
 binding.update(runtime_approved=True,publication_approved=True,platform='Linux Godot 4.6.2; Compatibility GPU installation/instantiate checks; no native Windows/macOS/physical Android certification.',upgrade_qualified=True,rollback_qualified=True,namespace_restart_qualified=True,immutable_versions_incremented=True,code_bindings=code,evidence_sha256=evidence)
 write(BINDING,binding)
 registry=read(REGISTRY);registry['v14_binding_sha256']=sha(BINDING)
 data=(json.dumps(registry,indent='\t',allow_nan=False)+'\n').encode();REGISTRY.write_bytes(data);(ROOT/'launcher/data/reviewed_model_catalog.json').write_bytes(data)
 print('V14_BINDING_QUALIFIED upgrade=true rollback=true publication_pending=true')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--work',type=Path,required=True);seal(p.parse_args().work)
