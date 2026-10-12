#!/usr/bin/env python3
"""Package bounded native-clock audio from the supplied SE/Anim source.

Exact normalized move names win. Missing names use an explicit motif sound,
recorded as shared audio (never presented as an original SV soundbank).
"""
import argparse, concurrent.futures, hashlib, json, re, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/battles/moves_3d/audio_extensions'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def key(s):return re.sub('[^a-z0-9]','',s.lower().replace('’',''))
def stem(p):
 s=re.sub(r'^(PRSFX[- ]*|GEN\s*\d+[- ]*)','',p.stem,flags=re.I)
 return re.sub(r'\d+$','',key(s))
FALLBACK={
 'ram':'Tackle','rush':'Quick Attack','punch':'Mega Punch','kick':'Double Kick','slash':'Slash','fang':'Bite','pierce':'Peck','lash':'Vine Whip','spin':'Rapid Spin','hammer':'Slam','grip':'Bind','vanish':'Teleport','swarm':'Bug Buzz',
 'orb':'Shadow Ball','bomb':'Sludge Bomb','shard':'Rock Blast','boomerang':'Bonemerang','beam':'Hyper Beam','cutwave':'Air Slash','sound':'Echoed Voice','pulse':'Confusion','drain':'Absorb','wave':'Surf','vortex':'Whirlpool','rain':'Rock Slide','eruption':'Earthquake','burst':'Explosion','lightning':'Thunderbolt','firestar':'Fire Blast','cage':'Bind','prism':'Tri Attack',
 'shield':'Protect','heal':'Recover','boost':'Swords Dance','heart':'Attract','statussound':'Echoed Voice','statuswave':'Confuse Ray','statuscloud':'Poison Gas','seal':'Mean Look','exchange':'Teleport','ritual':'Metronome','weather':'Rain Dance','room':'Trick Room','max':'Hyper Beam','mist':'Smog',
}
def build(source):
 path=ROOT/'data/battle_move_extensions_3d.json'; catalog=json.loads(path.read_text());OUT.mkdir(parents=True,exist_ok=True)
 available={}
 for p in sorted(source.iterdir()):
  if p.suffix.lower() in ['.wav','.ogg','.mp3']:available.setdefault(stem(p),[]).append(p)
 def find(name):
  # Prefer lossless input and deduplicate alternative encodings of the same cue.
  found={}
  for p in sorted(available.get(key(name),[]),key=lambda p:({'.wav':0,'.ogg':1,'.mp3':2}[p.suffix.lower()],p.name)):
   found.setdefault(key(p.stem),p)
  return list(found.values())
 jobs=[]; manifest={}
 for k,row in catalog['moves'].items():
  exact=find(row['name']); candidates=exact or find(FALLBACK[row['motif']])
  assert candidates, (k,FALLBACK[row['motif']])
  # One release/cast cue; one separately gated impact only with distinct source.
  picked=[('cast' if not row['damaging'] else 'release',candidates[0])]
  if row['damaging'] and len(candidates)>1:picked.append(('impact',candidates[-1]))
  row['audio']=[]
  for role,src in picked:
   start=.06 if role=='cast' else row['impact_fraction'] if role=='impact' else row['launch_fraction']
   end=min(.97,start+(.25 if role=='impact' else .4))
   length=(end-start)*row['duration_seconds']
   dest=OUT/f'{k}_{role}.ogg'; name=f'{k}_{role}'
   # Fixed upper bound, gentle fades and peak limiter; no loudness amplification.
   fade=min(.06,length*.18)
   filters=f'atrim=0:{length:.6f},asetpts=PTS-STARTPTS,afade=t=in:d=0.012,afade=t=out:st={length-fade:.6f}:d={fade:.6f},alimiter=limit=0.85:level=false'
   jobs.append((src,dest,filters))
   row['audio'].append(dict(name=name,path='res://'+str(dest.relative_to(ROOT)),role=role,volume=75,pitch=100,at_fraction=start,end_fraction=end))
   manifest[name]=dict(source_file=src.name,source_sha256=sha(src),selection='exact-move-name' if exact else 'explicit-shared-motif',shared_move=None if exact else FALLBACK[row['motif']],role=role,duration_seconds=length,filters=filters,path=str(dest.relative_to(ROOT)))
 def encode(job):
  src,dest,filters=job
  subprocess.run(['ffmpeg','-v','error','-nostdin','-y','-threads','1','-i',str(src),'-vn','-af',filters,'-ar','24000','-ac','1','-c:a','libvorbis','-q:a','3',str(dest)],check=True,capture_output=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(encode,jobs))
 for row in manifest.values():row['output_sha256']=sha(ROOT/row['path'])
 (OUT/'manifest.json').write_text(json.dumps({'source':'User SE/Anim library; not original SV audio','entries':manifest},indent=2)+'\n')
 path.write_text(json.dumps(catalog,indent=2,ensure_ascii=False)+'\n')
 print('EXTENSION_AUDIO_OK',len(manifest),'cues',sum(r['selection']=='exact-move-name' for r in manifest.values()),'exact-name cues')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);a=p.parse_args();build(a.source)
