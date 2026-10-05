#!/usr/bin/env python3
"""Package a bounded, emitter-bound SV mask selection for first-pass 3D recipes.

No timeline/simulation conversion. Missing/unsupported sources explicitly reuse
packaged SV art. Supply the user's dump and an external pinned BNTX-Extractor;
no downloads, runtime dump dependency, or writes outside the task checkout.
"""
import argparse, hashlib, json, re, subprocess, sys
from pathlib import Path
from PIL import Image
from extract_sv_ember import inspect_particle, subset_bntx, legacy_bntx, read, text
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/battles/moves_3d/sv_recipes'
FALLBACK='res://assets/battles/moves_3d/sv_shadowball/cpt_2_shock0010.png'
def sha(data): return hashlib.sha256(data).hexdigest()

def build(source,decoder):
    recipes=json.loads((ROOT/'data/battle_move_recipes_3d.json').read_text())['moves']
    OUT.mkdir(parents=True,exist_ok=True)
    report={'conversion':'source-textures-with-authored-3d-motion','native_timeline_converted':False,'native_simulation_converted':False,'decoder_sha256':sha(decoder.read_bytes()),'id_reference':'PokeAPI data/v2/csv/moves.csv; numeric IDs stored per recipe','moves':{}}
    textures={}
    for key,recipe in recipes.items():
        folder=source/f"ew{recipe['source_id']:04}"
        candidates=[]; rejected=[]
        for particle in sorted(folder.glob('*.ptcl')):
            raw=particle.read_bytes()
            try: info,bntx=inspect_particle(raw)
            except (ValueError,UnicodeDecodeError) as exc:
                rejected.append({'particle':particle.name,'reason':str(exc)});continue
            bound={n for e in info['emitters'] for n in e['textures'] if n}
            for i in range(read(bntx,36,'I')[0]):
                pos=read(bntx,read(bntx,40,'Q')[0]+8*i,'Q')[0]
                np=read(bntx,pos+96,'Q')[0]; name=text(bntx,np+2,read(bntx,np,'H')[0])
                if name not in bound or not re.search(r'(shock|flash|circle|fire|water|bubble|smoke|line|obj|ice|leaf|mark)',name):continue
                if re.search(r'(normal|distort|noise)',name):continue
                try: adapted=legacy_bntx(subset_bntx(bntx,[name]),allow_bc5=True,allow_bc3=True,allow_r8=True,allow_bc7=True)
                except ValueError:continue
                score=10*int('hit' in particle.stem)+6*int('shock' in name)+5*int('flash' in name)
                type_terms={'fire':'fire','water':'water','ice':'ice','grass':'obj','electric':'line','poison':'bubble','ghost':'smoke'}
                score+=12*int(type_terms.get(recipe['type'],'shock') in name)
                if recipe['variant'] in ['powder','mist','snow']:score+=18*int('smoke' in name)
                candidates.append((score,particle,name,raw,info,adapted,read(bntx,pos+28,'I')[0],read(bntx,pos+88,'4B')))
        row={'source_id':recipe['source_id'],'source_directory':folder.name,'rejected_particles':rejected,'textures':[]}
        # At most two source textures per move, deduplicated by source bytes/name.
        for _,particle,name,raw,info,adapted,fmt,channels in sorted(candidates,key=lambda c:(-c[0],c[1].name,c[2])):
            if name in [t['source_name'] for t in row['textures']]:continue
            digest=sha(adapted)[:16]; asset=digest+'_'+name
            output=OUT/(asset+'.png')
            if not output.exists():
                work=ROOT/'.tmp/all-moves/decode'/asset;work.mkdir(parents=True,exist_ok=True)
                inp=work/'decoder-input.bntx';inp.write_bytes(adapted)
                run=subprocess.run([sys.executable,str(decoder.resolve()),str(inp.resolve())],cwd=work,capture_output=True,text=True,timeout=60)
                if run.returncode:raise ValueError(run.stderr+run.stdout)
                with Image.open(work/(name+'.dds')) as original:
                    image=original.copy()
                if fmt==0x1E01:
                    r,g,_=image.split();maps={2:r,3:g};image=Image.merge('RGBA',[maps[c] for c in channels])
                if image.width>2048 or image.height>2048 or image.width<image.height:continue
                image.save(output)
            with Image.open(output) as im:
                ratio=im.width/im.height
                frames=int(ratio) if ratio in [1,2,4,8,16] else 1
                alpha=im.mode=='RGBA'
                if not im.getbbox():continue
            row['textures'].append({'path':'res://'+str(output.relative_to(ROOT)),'source_particle':particle.name,'source_name':name,'source_sha256':sha(raw),'png_sha256':sha(output.read_bytes()),'emitters':[e['name'] for e in info['emitters'] if name in e['textures']],'frames':frames,'source_alpha':alpha})
            if len(row['textures'])==2:break
        row['source_mode']='own-move-masks' if row['textures'] else 'shared-SV-mask'
        if not row['textures']:
            row['fallback_reason']='Move directory absent from this SV dump' if not folder.is_dir() else 'No supported emitter-bound mask in this source'
            row['textures']=[{'path':FALLBACK,'source_name':'shared_shadowball_hit','frames':8,'source_alpha':False,'png_sha256':sha((ROOT/FALLBACK.removeprefix('res://')).read_bytes())}]
        for t in row['textures']:textures[t['path']]=True
        report['moves'][key]=row
    (OUT/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
    # Static preloads make resources export-safe (no runtime directory discovery).
    registry='extends RefCounted\n## Generated by package_move_recipe_sources.py; original SV masks, authored motion.\nconst MANIFEST = preload("res://assets/battles/moves_3d/sv_recipes/provenance.json")\nconst TEXTURES := {\n'
    registry+=''.join('\t'+json.dumps(p)+': preload('+json.dumps(p)+'),\n' for p in sorted(textures))+'}\n'
    (ROOT/'scripts/battle/battle_ui/move_recipe_sources_3d.gd').write_text(registry)
    own=sum(r['source_mode']=='own-move-masks' for r in report['moves'].values())
    print(f'SOURCE_RECIPES_OK moves={len(recipes)} own_sources={own} shared_sources={len(recipes)-own} unique_textures={len(textures)}')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--decoder',type=Path,required=True);a=p.parse_args();build(a.source,a.decoder)
