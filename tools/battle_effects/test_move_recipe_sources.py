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
   self.assertTrue(.5<=v['duration_seconds']<=3,k)
   self.assertTrue(.5<=v['scale']<=3,k)
   self.assertEqual(v['review'],'first-pass')
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
 def test_audio_references(self):
  r=json.loads((ROOT/'data/battle_move_recipes_3d.json').read_text())['moves']
  manifest=json.loads((ROOT/'assets/battles/moves_3d/audio_recipes/manifest.json').read_text())['entries']
  seen=set()
  for k,recipe in r.items():
   for cue in recipe['audio']:
    name=Path(cue['path']).name;seen.add(name)
    self.assertIn(name,manifest,k)
    self.assertEqual(cue['path'],manifest[name]['path'])
    self.assertTrue(0<cue['pitch']<=400)
  self.assertEqual(seen,set(manifest))
if __name__=='__main__':unittest.main()
