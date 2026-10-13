"""Admit the complete locally qualified reconstruction batch; never publish."""
import argparse,copy,json,os,subprocess
from pathlib import Path
from final_twenty_one import ROOT,HERE,WORK,NAMES,read,write,sha,run
BASE='62dcfc146bf6f4bef1d6ac02d74991d55e837ed4'
GAME=ROOT/'scripts/battle/battle_ui/reviewed_model_catalog.json'
LAUNCHER=ROOT/'launcher/data/reviewed_model_catalog.json'
RECEIPT=HERE/'final_twenty_one_qualification.json'
INDEX=ROOT/'release/approved_3d_final_twenty_one_index.json'

def canonical(v):
 import hashlib
 return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def clean_log(path,marker=None):
 text=path.read_text()
 assert 'ERROR:' not in text and 'SCRIPT ERROR' not in text,str(path)
 if marker:assert marker in text,str(path)

def qualify():
 authorization=read(WORK/'authorization.json')
 assert authorization['user_statement']=='oke maak het af'
 assert authorization['preview_receipt_sha256']==sha(HERE/'remaining_twenty_one_result.json')
 visual=read(WORK/'visual-assessment.json')
 assert visual['complete'] and visual['runtime_approved'] is False
 assert set(visual['forms'])==set(NAMES)
 for path,digest in visual['contacts_sha256'].items():assert sha(WORK/'review-complete'/path)==digest
 review=read(WORK/'review-complete/godot-review.json')
 assert len(review['entries'])==42 and all(not e['errors'] for e in review['entries'])
 composition=read(WORK/'review-complete/composition.json')
 for path,digest in {**composition['source_sha256'],**composition['artifacts_sha256']}.items():assert sha(WORK/path)==digest,path
 for path in composition['source_sha256']:
  if path.endswith('.log'):clean_log(WORK/path)
 entries={};assets=[];fixtures={};files=[WORK/'authorization.json',WORK/'visual-assessment.json',WORK/'review-complete/catalog.json',WORK/'review-complete/godot-review.json',WORK/'review-complete/composition.json',WORK/'review-complete/index.html']
 for name in NAMES:
  native_path=WORK/'runtime-jobs'/name/'native/report.json';native=read(native_path)
  assert {e['species'] for e in native}=={name,name+'-shiny'}
  clean_log(WORK/('prepare-'+name+'.log'),'FINAL_TWENTY_ONE_PREPARED')
  battle=WORK/'battle'/name;measured=read(battle/'final/battle-review.json');assert measured['complete']
  clean_log(battle/'baseline.log');clean_log(battle/'final.log')
  for row in native:
   assert sha(Path(row['runtime_path']))==row['runtime_sha256']==visual['forms'][name]['scenes'][row['variant']]
   assert row['material_isolation_samples']==5*len(row['animations'])
   m=next(e for e in measured['entries'] if e['species']==row['species'])
   assert m['glb_sha256']==row['glb_sha256']==sha(Path(row['path']))
   assert all(s['in_view'] and not s['model_overlaps_hud_proxy'] for s in m['shots'])
   assert min(s['screen_rect'][3] for s in m['shots'] if s['action']=='idle')>=60.0, name+' is too small'
   assert min(c['minimum_y'] for c in m['corrected_clearance_120hz'].values())>=.025-1e-5
   assert next(e for e in read(WORK/'review-complete/catalog.json')['entries'] if e['species']==row['species'])['runtime_sha256']==row['runtime_sha256']
  delivery=WORK/'delivery'/name;status=read(WORK/'status/delivery'/(name+'.json'));assert status['status']=='delivery_checked'
  for f,k in [('shared/index.json','index_sha256'),('shared/pixel-comparison.json','pixel_report_sha256'),('runtime-check.log','runtime_check_sha256')]:assert sha(delivery/f)==status[k]
  if (delivery/'textures.log').exists():clean_log(delivery/'textures.log')
  else:
   reuse=read(delivery/'texture-cache-reuse.json')
   assert reuse['source_sha256']==sorted(e['runtime_sha256'] for e in native)
   for key in ['report','log']:assert sha(WORK/reuse[key])==reuse[key+'_sha256']
   assert sorted(m['source_sha256'] for m in read(WORK/reuse['report'])['models'])==reuse['source_sha256']
   clean_log(WORK/reuse['log']);files.append(delivery/'texture-cache-reuse.json')
  for log in ['validate.log','pixels.log','runtime-check.log']:clean_log(delivery/log)
  clean_log(delivery/'runtime-check.log','FORM_BATCH_RUNTIME_OK')
  pixels=read(delivery/'shared/pixel-comparison.json');assert pixels['complete'] and len(pixels['models'])==2 and pixels['exact_frames']>=20
  assert all(e['pixels_exact'] for e in pixels['models'])
  asset,=read(delivery/'shared/index.json')['assets'];pack=delivery/'shared/packs'/asset['object_key'].split('/')[-1]
  assert sha(pack)==asset['sha256'] and pack.stat().st_size==asset['size_bytes']
  assert len(asset['appearances'])==2
  fixture=read(delivery/'runtime-fixture.json')
  for appearance in asset['appearances']:
   row=next(e for e in native if e['variant']==appearance['variant'])
   assert appearance['source_sha256']==row['runtime_sha256']==fixture['models'][appearance['runtime_identity']]['sha256']
  samples=0
  for renderer in ['gl_compatibility','mobile']:
   path=WORK/'ui'/name/renderer/'report.json';r=read(path)
   clean_log(WORK/('ui-'+name+'-'+renderer+'.log'),'FINAL_FORMS_BATTLE_UI_OK')
   assert r['ui_check_sha256']==sha(ROOT/'tests/battle_3d_final_forms_check.gd')
   assert r['complete'] and r['pairs']==6 and r['faint_replacements']==6
   expected=18*len(native[0]['animations'])
   assert r['material_isolation_samples']==r['material_source_samples']==expected
   assert r['downloads']<=1 and r['fixture_sha256']==sha(delivery/'runtime-fixture.json') and r['index_sha256']==sha(delivery/'shared/index.json')
   assert len(r['shots'])==2*len(native[0]['animations'])
   samples+=expected;files.extend([path,WORK/('ui-'+name+'-'+renderer+'.log')]);files.extend(path.parent/f for f in r['shots'])
  entries[name]={'runtime_approved':True,'authored_reconstruction':True,'bundle_size_bytes':asset['size_bytes'],'pixel_exact_frames':pixels['exact_frames'],'battle_appearance_samples':samples,'battle_views':sum(len(e['shots']) for e in measured['entries'] if 'clips' in e),'minimum_idle_height_pixels':min(s['screen_rect'][3] for e in measured['entries'] if 'clips' in e for s in e['shots'] if s['action']=='idle'),'variants':{e['variant']:e['runtime_sha256'] for e in native}}
  files.extend([native_path,WORK/('prepare-'+name+'.log'),battle/'catalog.json',battle/'placement.json',battle/'baseline/battle-review.json',battle/'final/battle-review.json',delivery/'runtime-fixture.json',delivery/'shared/index.json',delivery/'shared/pixel-comparison.json',delivery/'shared/validated/receipts.jsonl',delivery/'shared/render-qualified/report.json',delivery/'runtime-check.log'])
  assets.append(asset);fixtures[name]=fixture
 receipt={'schema':1,'runtime_approved':True,'release_approved':False,'published':False,'admitted_registry_check_passed':False,'forms_admitted':21,'remaining_forms':0,'remaining_species':[],'restored_forms_across_original_229':229,'platform':'Linux Godot 4.6.2 Compatibility and Mobile; physical Android, Windows and macOS untested.','scope':'Authorized authored reconstruction, independently checked in local battles. No original-engine parity or form-transition claim.','bundle_size_bytes':sum(a['size_bytes'] for a in assets),'entries':entries,'previous_qualification_sha256':sha(HERE/'remaining_fourteen_qualification.json'),'preview_receipt_sha256':sha(HERE/'remaining_twenty_one_result.json'),'evidence_sha256':{str(p.relative_to(WORK)):sha(p) for p in files}}
 return assets,fixtures,receipt

def save(registry):
 data=(json.dumps(registry,indent='\t',allow_nan=False)+'\n').encode();GAME.write_bytes(data);LAUNCHER.write_bytes(data)

def admit():
 assets,fixtures,receipt=qualify();assert GAME.read_bytes()==LAUNCHER.read_bytes()
 registry=read(GAME);before=json.loads(subprocess.check_output(['git','show',BASE+':scripts/battle/battle_ui/reviewed_model_catalog.json'],cwd=ROOT));assert registry==before
 receipt['previous_registry']={k+'_sha256':canonical(before[k]) for k in ['models','profiles']};receipt['previous_registry_sha256']=sha(GAME)
 for name,fixture in fixtures.items():
  profile=copy.deepcopy(fixture['profiles'][name+'-normal']);profile['motion'].pop('sha256')
  other=copy.deepcopy(fixture['profiles'][name+'-shiny']);other['motion'].pop('sha256');assert profile==other
  assert name not in registry['profiles'] and not any(k in registry['models'] for k in fixture['models'])
  registry['profiles'][name]=profile;registry['models'].update({k:dict(v,profile=name) for k,v in fixture['models'].items()})
 write(INDEX,{'schema':1,'kind':'pokeaether-optional-asset-index','catalog_revision':'final-twenty-one-local-v1','runtime_contract':{'pokemon_3d':2,'godot':'4.6'},'assets':assets})
 receipt['bundle_index_sha256']=sha(INDEX);write(RECEIPT,receipt);registry['final_twenty_one_qualification_sha256']=sha(RECEIPT);save(registry)
 print('FINAL_FORMS_LOCAL_ADMISSION_PENDING_CHECK',flush=True)

def finalize():
 receipt=read(RECEIPT);assets,_,_=qualify();assert read(INDEX)['assets']==assets and sha(INDEX)==receipt['bundle_index_sha256']
 for name in NAMES:
  label='admitted-check-'+name;env=dict(os.environ,POKEAETHER_FORM_BUNDLE_WORK=str(WORK/'delivery'/name),POKEAETHER_FORM_BATCH_SHARED='1',POKEAETHER_FORM_BATCH_ADMITTED='1',POKEAETHER_CATALOG_WORK_ROOT=str(WORK))
  run(label,['--path',str(ROOT),'--rendering-method','mobile','--script','res://tests/battle_3d_alternate_form_check.gd'],env)
  clean_log(WORK/(label+'.log'),'FORM_BATCH_RUNTIME_OK');receipt['evidence_sha256'][label+'.log']=sha(WORK/(label+'.log'));print('ADMITTED_CHECK_OK',name,flush=True)
 receipt['admitted_registry_check_passed']=True
 paths=list(HERE.glob('final_twenty_one*.py'))+list(HERE.glob('final_twenty_one*.gd'))+[ROOT/'tests/battle_3d_final_forms_check.gd',HERE/'alternate_forms_delivery.py',HERE/'alternate_forms_recovery_battle.py',HERE/'model_pair_texture_probe.gd',ROOT/'tests/battle_3d_alternate_form_check.gd']
 receipt['code_sha256']={str(p.relative_to(ROOT)):sha(p) for p in paths};write(RECEIPT,receipt)
 registry=read(GAME);registry['final_twenty_one_qualification_sha256']=sha(RECEIPT);save(registry)
 print('FINAL_FORMS_QUALIFIED remaining=0 published=false',flush=True)

if __name__=='__main__':
 assert os.environ.get('POKEAETHER_SLOT')==ROOT.parent.name
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('phase',choices=['admit','finalize']);a=p.parse_args();globals()[a.phase]()
