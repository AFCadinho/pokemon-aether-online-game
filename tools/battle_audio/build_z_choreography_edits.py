#!/usr/bin/env python3
"""Build 2D-storyboard-aligned Z cues; neither a ROM-audio extractor nor a 2D edit."""
import argparse,hashlib,json,struct,subprocess,wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/battles/moves_3d/audio_z_choreography'
RECIPES=ROOT/'data/battle_move_recipes_3d.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build():
 doc=json.loads(RECIPES.read_text());catalog=json.loads((ROOT/'data/battle_move_animations.json').read_text())['moves'];entries={}
 OUT.mkdir(parents=True,exist_ok=True)
 for key,r in doc['moves'].items():
  if 'z_choreography' not in r:continue
  ref=r['z_choreography'];config=catalog[key];data=json.loads((ROOT/ref['reference_path'].removeprefix('res://')).read_text())
  unique={}
  for event in sorted(data['timings'],key=lambda e:e['frame']):
   if event.get('type')==0 and config['sound_paths'].get(event.get('name','')):unique.setdefault(event['name'],event)
  r['audio']=[]
  if not unique:continue # Breakneck Blitz has no packaged sound in the 2D catalog.
  all_events=list(unique.values());selected=[]
  for frame in [0,ref['release_frame'],(ref['release_frame']+ref['impact_frame'])/2,ref['impact_frame']]:
   candidate=min(all_events,key=lambda e:abs(e['frame']-frame))
   if candidate not in selected:selected.append(candidate)
  selected.sort(key=lambda e:e['frame'])
  for i,event in enumerate(selected):
   name=event['name'];source=ROOT/config['sound_paths'][name].removeprefix('res://')
   # Charge/action sounds use the 2D frame relationship. The last distinct
   # sample is aligned to the authored final impact, including source aliases.
   impact=i==len(selected)-1 and r['damaging'] and len(selected)>1
   at=r['impact_fraction'] if impact else event['frame']/ref['source_frames']
   role='impact' if impact else 'charge' if event['frame']<ref['release_frame'] else 'action'
   limit=min(1.0,at+(0.25 if impact else .28))
   original=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(source)],text=True))
   pitch=max(.01,float(event.get('pitch',100))/100)
   length=min(original,(limit-at)*r['duration_seconds']*pitch,.95)
   end=min(original,length*1.3)
   filters=f'atrim=end={end:.9f},asetpts=PTS-STARTPTS,atempo={end/length:.9f},aresample=44100,alimiter=limit=0.97:level=false:latency=true,apad=whole_dur={length:.9f},atrim=duration={length:.9f},afade=t=in:d=0.005,afade=t=out:st={max(0,length-.055):.9f}:d=0.055'
   out=OUT/f'{key}_{i}.wav'
   subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(source),'-af',filters,'-ar','44100','-c:a','pcm_s16le','-map_metadata','-1',str(out)],check=True)
   cue={'name':name,'path':'res://'+str(out.relative_to(ROOT)),'role':role,'volume':event.get('volume',100),'pitch':event.get('pitch',100),'at_fraction':at,'end_fraction':limit,'source_frame':event['frame']}
   r['audio'].append(cue)
   entries[out.name]={'source':'res://'+str(source.relative_to(ROOT)),'source_sha256':sha(source),'path':cue['path'],'sha256':sha(out),'duration_seconds':length,'filters':filters,'source_frame':event['frame']}
 RECIPES.write_text(json.dumps(doc,indent=2)+'\n')
 (OUT/'manifest.json').write_text(json.dumps({'note':'Edited existing 2D Z-move audio, matched to the 3D interpretation of its storyboard.','entries':entries},indent=2)+'\n')
 audit()
def audit():
 entries=json.loads((OUT/'manifest.json').read_text())['entries']
 for name,e in entries.items():
  for field,h in [('source','source_sha256'),('path','sha256')]:assert sha(ROOT/e[field].removeprefix('res://'))==e[h],name
  with wave.open(str(ROOT/e['path'].removeprefix('res://'))) as w:
   raw=w.readframes(w.getnframes());s=struct.unpack('<'+'h'*(len(raw)//2),raw)
   assert 100<max(abs(v) for v in s)<32767,name
   assert max(abs(v) for v in s[:2]+s[-2:])<200,name
   assert abs(w.getnframes()/w.getframerate()-e['duration_seconds'])<.002,name
 print(f'Z_AUDIO_OK files={len(entries)} original_hashes=true edited_hashes=true fades=true clipping=false')
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();audit() if a.check else build()
