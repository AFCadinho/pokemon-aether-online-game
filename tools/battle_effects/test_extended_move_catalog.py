#!/usr/bin/env python3
"""Focused coverage/provenance checks; no external dump or backend runtime needed."""
import hashlib, json, re, subprocess, unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(path):return json.loads((ROOT/path).read_text())
def normalize(s):return re.sub(r"[\s\-_,'.’]",'',s.lower())
class ExtendedCatalogChecks(unittest.TestCase):
 def test_complete_gameplay_coverage_and_preserved_ownership(self):
  old=read('data/battle_move_recipes_3d.json')['moves'];new=read('data/battle_move_extensions_3d.json');moves=new['moves']
  dedicated=json.loads(re.search(r'const KEYS := (\[.*?\])',(ROOT/'scripts/battle/battle_ui/move_effect_3d.gd').read_text())[1])
  summary=read('data/move_summary_index.json'); covered=set(old)|set(moves)|set(dedicated)
  self.assertEqual(len(moves),707);self.assertEqual(len(covered),901)
  self.assertFalse(set(old)&set(moves));self.assertFalse(set(dedicated)&set(moves))
  for row in summary.values():
   self.assertIn(normalize(row['name']),covered)
   self.assertIn(new['aliases'].get(normalize(row['id']),normalize(row['id'])),covered)
  for k,r in moves.items():
   self.assertLess(r['launch_fraction'],r['impact_fraction'],k)
   self.assertLess(r['impact_fraction'],1,k);self.assertGreaterEqual(r['duration_seconds'],.8,k)
   self.assertLessEqual(r['count'],7,k);self.assertEqual(r['presentation_review'],'implemented-pending-player-review')
   self.assertTrue(r['audio'],k)
 def test_audio_hashes_and_real_duration_bounds(self):
  manifest=read('assets/battles/moves_3d/audio_extensions/manifest.json')['entries']
  catalog=read('data/battle_move_extensions_3d.json')['moves']
  referenced={c['name']:c for r in catalog.values() for c in r['audio']}
  self.assertEqual(set(manifest),set(referenced))
  def check(item):
   name,row=item;path=ROOT/row['path']
   self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),row['output_sha256'],name)
   probe=subprocess.run(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(path)],check=True,capture_output=True,text=True)
   duration=float(json.loads(probe.stdout)['format']['duration'])
   self.assertGreater(duration,0,name);self.assertLessEqual(duration,row['duration_seconds']+.08,name)
   self.assertIn(row['selection'],['exact-move-name','explicit-shared-motif'])
   self.assertEqual(referenced[name]['path'],'res://'+row['path'])
  with ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(check,manifest.items()))
if __name__=='__main__':unittest.main()
