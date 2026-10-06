#!/usr/bin/env python3
"""Build bounded first-pass edits of existing move audio; keep dedicated edits intact."""
import argparse, hashlib, json, struct, subprocess, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/battles/moves_3d/audio_recipes'
RECIPE=ROOT/'data/battle_move_recipes_3d.json'
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def build():
    doc=json.loads(RECIPE.read_text());catalog=json.loads((ROOT/'data/battle_move_animations.json').read_text())['moves'];entries={}
    OUT.mkdir(parents=True,exist_ok=True)
    previous=json.loads((OUT/"manifest.json").read_text())["entries"] if (OUT/"manifest.json").exists() else {}
    for key,r in doc['moves'].items():
        if "z_choreography" in r: continue
        config=catalog[key];data=json.loads((ROOT/config['data_path'].removeprefix('res://')).read_text())
        start=config.get('animation_start_frame',0);end=config.get('animation_end_frame',len(data['frames'])-1)
        if end<0:end=len(data['frames'])-1
        events=[] if config.get('disable_data_sound_events',False) else [e for e in data.get('timings',[]) if e.get('type')==0]
        events+=config.get('custom_sound_events',[])
        unique={}
        for e in sorted(events,key=lambda e:e.get('frame',0)):
            name=e.get('name','')
            if name and start<=e.get('frame',0)<=end and config.get('sound_paths',{}).get(name): unique.setdefault(name,e)
        selected=list(unique)
        if len(selected)>1:selected=[selected[0],selected[-1]]
        r['audio']=[]
        for i,name in enumerate(selected):
            e=unique[name];source=ROOT/config['sound_paths'][name].removeprefix('res://')
            if not source.is_file():raise ValueError(f'Missing audio: {source}')
            role='impact' if r['contact'] and len(selected)==1 or i==1 and r['damaging'] else 'cast' if not r['damaging'] else 'launch'
            original=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=noprint_wrappers=1:nokey=1',str(source)],text=True))
            at=r['impact_fraction'] if role=='impact' else r['launch_fraction'] if role=='launch' else .08
            if role=='cast' and i>0:
                at=max(.28,min(r['impact_fraction'],(e.get('frame',start)-start)/max(1,end-start)))
            cue_end=min(1.0,at+(.28 if role=='impact' else .48))
            max_seconds=r['duration_seconds']*min(.25 if role=='impact' else .46,cue_end-at)
            # Preserve the opening transient, cap compression at 2x, fade the tail.
            pitch=max(.01,float(e.get('pitch',100))/100)
            length=min(original,max_seconds*pitch)
            trim_end=min(original,length*1.7)
            filters=f'atrim=end={trim_end:.9f},asetpts=PTS-STARTPTS,atempo={trim_end/length:.9f},aresample=44100,alimiter=limit=0.97:level=false:latency=true,apad=whole_dur={length:.9f},atrim=duration={length:.9f},afade=t=in:d=0.005,afade=t=out:st={max(0,length-.05):.9f}:d=0.05'
            out=OUT/(f'{key}_{role}_{i}.wav' if role=='cast' and len(selected)>1 else f'{key}_{role}.wav')
            subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(source),'-af',filters,'-ar','44100','-c:a','pcm_s16le','-map_metadata','-1',str(out)],check=True)
            cue={'name':name,'path':'res://'+str(out.relative_to(ROOT)),'role':role,'volume':e.get('volume',100),'pitch':e.get('pitch',100),'at_fraction':at,'end_fraction':cue_end}
            r['audio'].append(cue)
            entries[out.name]={'source':'res://'+str(source.relative_to(ROOT)),'source_sha256':sha(source),'path':cue['path'],'sha256':sha(out),'filters':filters,'duration_seconds':length}
    RECIPE.write_text(json.dumps(doc,indent=2)+'\n')
    (OUT/'manifest.json').write_text(json.dumps({'note':'Authored edits of existing 2D WAVs. Original SV audio is not present in this dump.','entries':entries},indent=2)+'\n')
    for obsolete in previous.keys()-entries.keys():
        path=OUT/obsolete
        if path.parent==OUT and path.suffix=='.wav':path.unlink(missing_ok=True)
    audit()
def audit():
    entries=json.loads((OUT/'manifest.json').read_text())['entries']
    for name,e in entries.items():
        for field,hash_field in [('source','source_sha256'),('path','sha256')]:assert sha(ROOT/e[field].removeprefix('res://'))==e[hash_field],name
        with wave.open(str(ROOT/e['path'].removeprefix('res://'))) as wav:
            assert wav.getsampwidth()==2
            raw=wav.readframes(wav.getnframes());s=struct.unpack('<'+'h'*(len(raw)//2),raw)
            assert 100<max(abs(v) for v in s)<32767,name
            assert max(abs(v) for v in s[:2]+s[-2:])<200,name
            assert abs(wav.getnframes()/wav.getframerate()-e['duration_seconds'])<.002,name
    print(f'RECIPE_AUDIO_OK edits={len(entries)} hashes=true faded_edges=true non_silent=true clipping=false')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--check',action='store_true');a=p.parse_args();audit() if a.check else build()
