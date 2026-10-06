#!/usr/bin/env python3
"""Coverage/export/provenance contracts for the broad first-pass move catalogue."""
import hashlib,json,re,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DUMP=Path('/home/adinho/Documents/3d_models/SV Every File/romfs/effect/battle_ew')
class RecipeSources(unittest.TestCase):
 def test_complete_and_disjoint(self):
  r=json.loads((ROOT/'data/battle_move_recipes_3d.json').read_text())['moves']
  native=json.loads(re.search(r'const KEYS := (\[.*\])',(ROOT/'scripts/battle/battle_ui/move_effect_3d.gd').read_text())[1])
  catalog=json.loads((ROOT/'data/battle_move_animations.json').read_text())['moves']
  self.assertEqual(len(catalog),193);self.assertEqual(len(r),170)
  self.assertFalse(set(r)&set(native));self.assertEqual(set(catalog)|{'bubblebeam'},set(r)|set(native))
  for k,v in r.items():
   self.assertTrue(0<v['launch_fraction']<v['impact_fraction']<1,k)
   self.assertTrue(.5<=v['duration_seconds']<=(4.6 if v['family']=='z' else 4.0 if k=='terastarstorm' else 3),k)
   self.assertTrue(.5<=v['scale']<=3,k)
   self.assertEqual(v['review'],'2d-inspired-awaiting-review' if v['family']=='z' else 'first-pass')
   if v['family']=='self':self.assertEqual(v['target'],'actor',k)
 def test_packaged_provenance_and_export(self):
  report=json.loads((ROOT/'assets/battles/moves_3d/sv_recipes/provenance.json').read_text())
  registry=(ROOT/'scripts/battle/battle_ui/move_recipe_sources_3d.gd').read_text()
  self.assertFalse(report['native_timeline_converted']);self.assertFalse(report['native_simulation_converted'])
  seen=set();own=0
  for key,row in report['moves'].items():
   self.assertLessEqual(len(row['textures']),2,key)
   if row['source_mode']=='own-move-masks':own+=1
   else:self.assertIn('fallback_reason',row)
   for t in row['textures']:
    p=ROOT/t['path'].removeprefix('res://');seen.add(p)
    self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),t['png_sha256'])
    self.assertIn('preload('+json.dumps(t['path'])+')',registry)
    self.assertIn(t['frames'],[1,2,4,8,16])
    if 'source_particle' in t:
     self.assertTrue(t['emitters'])
     if DUMP.is_dir():
      source=DUMP/row['source_directory']/t['source_particle']
      self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(),t['source_sha256'])
  self.assertEqual(own,126)
  packaged=set((ROOT/'assets/battles/moves_3d/sv_recipes').glob('*.png'))
  self.assertEqual(packaged,{p for p in seen if p.parent.name=='sv_recipes'})
 def test_z_storyboard_provenance(self):
  recipes=json.loads((ROOT/'data/battle_move_recipes_3d.json').read_text())['moves']
  catalog=json.loads((ROOT/'data/battle_move_animations.json').read_text())['moves']
  manifest=json.loads((ROOT/'assets/battles/moves_3d/audio_z_choreography/manifest.json').read_text())['entries']
  count=0
  for key,r in recipes.items():
   if 'z_choreography' not in r:continue
   count+=1;ref=r['z_choreography']
   for path,sha in [('reference_path','reference_sha256'),('sheet_path','sheet_sha256')]:
    self.assertEqual(hashlib.sha256((ROOT/ref[path].removeprefix('res://')).read_bytes()).hexdigest(),ref[sha],key)
   source=json.loads((ROOT/ref['reference_path'].removeprefix('res://')).read_text())
   self.assertEqual(len(source['frames']),ref['source_frames'],key)
   self.assertAlmostEqual(r['impact_fraction'],ref['impact_frame']/ref['source_frames'],places=6)
   for cue in r['audio']:
    self.assertEqual(manifest[Path(cue['path']).name]['source'],catalog[key]['sound_paths'][cue['name']])
    self.assertTrue(any(e.get('name')==cue['name'] and e['frame']==cue['source_frame'] for e in source['timings']),key)
    self.assertTrue(0<=cue['at_fraction']<cue['end_fraction']<=1,key)
  self.assertEqual(count,35)
 def test_audio_references(self):
  r=json.loads((ROOT/'data/battle_move_recipes_3d.json').read_text())['moves']
  manifest=json.loads((ROOT/'assets/battles/moves_3d/audio_recipes/manifest.json').read_text())['entries']
  manifest.update(json.loads((ROOT/'assets/battles/moves_3d/audio_z_choreography/manifest.json').read_text())['entries'])
  seen=set()
  catalog=json.loads((ROOT/'data/battle_move_animations.json').read_text())['moves']
  for k,recipe in r.items():
   for cue in recipe['audio']:
    name=Path(cue['path']).name;seen.add(name)
    self.assertIn(name,manifest,k)
    self.assertEqual(cue['path'],manifest[name]['path'])
    self.assertEqual(manifest[name]['source'],catalog[k]['sound_paths'][cue['name']],k)
    self.assertTrue(0<cue['pitch']<=400)
  self.assertEqual(seen,set(manifest))
if __name__=='__main__':unittest.main()
