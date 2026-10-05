"""Prepare a review-only native bank-00 motion carrier from retained ZA source files.
Run from the frontend slot that holds the Mega production evidence. The source
files stay in place; outputs go to a separate posture-review directory.
"""
import json,sys,hashlib
from pathlib import Path
root=Path.cwd(); here=root/'tools/sprite_factory';sys.path.insert(0,str(here))
from catalog_shiny_za_17_probe import run_flatpak
work=root/'.tmp/mega-garchomp-posture-v1';out=work/'ground';out.mkdir(exist_ok=True)
j=json.loads((root/'.tmp/mega-production-v1/production-source-ready-v1/garchompmega/import/job.json').read_text())
for group in ['motions','motion_channels']:
 for action,value in j[group].items():
  if value and action!='sleep':
   p=Path(value);name=p.name.replace('pm0445_51_00_2','pm0445_51_00_0');target=p.with_name(name);assert target.is_file();j[group][action]=str(target)
 j[group]['sleep']=j[group]['faint_loop']
j.update(output=str(out/'prepared.blend'),report=str(out/'import.json'),motion_selection_policy='explicit-native-ground-bank-00-review')
j['source_files']={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in set(j['source_files'])|{v for group in ['motions','motion_channels'] for v in j[group].values() if v}}
(out/'job.json').write_text(json.dumps(j,indent=2))
run_flatpak(here/'scvi_import_worker.py',out/'job.json',[(Path(j['model_dir']).parent,':ro'),(Path(j['importer']),':ro'),(Path(j['python_deps']),':ro'),(here,':ro'),(out,'')],out/'import.log')
x=json.loads((out/'import.json').read_text());print('IMPORTED', {k:v['name'] for k,v in x['actions'].items() if v},flush=True)
e={'species':'garchompmega-ground','source':str(out/'prepared.blend'),'source_sha256':x['prepared_sha256'],'actions':{k:v['name'] for k,v in x['actions'].items() if v},'output':str(out/'export'),'scvi_pbr_probe':False,'native_flatten_bone_hierarchy_diagnostic':True}
Path(e['output']).mkdir(exist_ok=True);(out/'export-job.json').write_text(json.dumps(e,indent=2))
run_flatpak(here/'mega_garchomp_motion_export.py',out/'export-job.json',[(out,''),(here,':ro'),(root/'.tmp/mega-production-v1/source',':ro')],out/'motion-export.log')
print('EXPORTED',e['output'])
