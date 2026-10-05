"""A single before/after page for the regional eye review follow-up."""
import json
import os
from pathlib import Path
from PIL import Image
from catalog_galar_birds_candidates import sha

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'.tmp/regional-production-v1'
HTML='''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Regionale Pokémon — ogencontrole</title>
<style>body{margin:0;background:#111a24;color:#e3edf5;font:16px system-ui}header{position:sticky;top:0;background:#172b3b;padding:18px;z-index:2;border-bottom:1px solid #52738b}h1{font-size:24px;margin:0}p{line-height:1.5}main{max-width:1500px;margin:auto;padding:18px}article{background:#20313e;border:1px solid #547085;padding:15px;border-radius:10px;margin:18px 0}h2{margin:0 0 12px;font-size:21px}.images{display:grid;grid-template-columns:repeat(4,1fr);gap:8px}figure{margin:0}img{width:100%;display:block;aspect-ratio:1;object-fit:contain;background:#202020}figcaption{padding:6px}a{color:#8bdcff}select,input,button{background:#253f52;color:white;padding:10px;border:1px solid #6e93af;border-radius:6px;font:inherit;margin:5px}dialog{width:min(1100px,94vw);max-height:95vh;background:#182a38;color:white;border:1px solid #7097b3}dialog img{max-height:82vh}dialog::backdrop{background:#000c}small{color:#bdd2e2}@media(max-width:700px){.images{grid-template-columns:repeat(2,1fr)}header{position:static}}</style>
<header><h1>Ogencontrole — 22 gecorrigeerde paren</h1><p>Vergelijk de ogen bij Voor en Na. De lichamen en animaties zijn behouden. Klik op een afbeelding om te vergroten.</p><input id="search" placeholder="Zoek Pokémon"><select id="scope"><option value="changed">Alleen de correcties</option><option value="all">Alle 58 paren</option></select><select id="pose"><option value="idle">Stilstand</option><option value="physical_attack">Aanval 1</option><option value="physical_attack_2">Extra aanval</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap / rust</option><option value="faint_start">Flauw</option></select><span id="count"></span></header><main><p>Zorua, Slowpoke en Slowking kregen hun ontbrekende oogdetails terug. Bij andere vormen was dezelfde fout alleen tijdens bepaalde animaties zichtbaar. Arcanines donkere oogdelen gebruiken nu hun oorspronkelijke materiaaleigenschappen.</p><div id="grid"></div></main><dialog id="zoom"><button id="close">Sluiten</button><h2 id="title"></h2><img id="large"></dialog>
<script>const data=DATA,$=id=>document.getElementById(id);function render(){const rows=data.filter(r=>($('scope').value==='all'||r.changed)&&r.name.toLowerCase().includes($('search').value.toLowerCase()));$('count').textContent=rows.length+' paren';$('grid').replaceChildren();for(const r of rows){const card=document.createElement('article'),h=document.createElement('h2');h.textContent=r.name+(r.changed?'':' · ongewijzigd');card.append(h);const grid=document.createElement('div');grid.className='images';for(const v of ['normal','shiny'])for(const state of ['before','after']){const f=document.createElement('figure'),cap=document.createElement('figcaption');cap.textContent=(v==='normal'?'Normal':'Shiny')+' · '+(state==='before'?'Voor':'Na');f.append(cap);const p=r[v][state][$('pose').value];if(p){const a=document.createElement('a'),img=new Image();a.href=p.full;a.target='_blank';img.src=p.thumb;img.alt=r.name+' '+cap.textContent;img.loading='lazy';a.append(img);a.onclick=e=>{e.preventDefault();$('title').textContent=img.alt;$('large').src=p.full;$('zoom').showModal()};f.append(a);}else{const p=document.createElement('p');p.textContent='Geen aparte opname van deze aanval.';f.append(p);}grid.append(f);}card.append(grid);const face=r.normal.face[$('pose').value];if(face){const a=document.createElement('a');a.href=face.full;a.target='_blank';a.textContent='Gezicht van voren bekijken (Na)';card.append(a);} $('grid').append(card);}}for(const id of ['scope','pose','search'])$(id).addEventListener(id==='search'?'input':'change',render);$('close').onclick=()=>$('zoom').close();render();</script></html>'''


def main():
    before_dir=WORK/'appearance-final-v1';after_dir=WORK/'eyes-followup-v2/appearance'
    before=json.loads((before_dir/'godot-review.json').read_text())['entries']
    after=json.loads((after_dir/'godot-review.json').read_text())['entries']
    assert len(before)==116 and len(after)==44 and all(not r['errors']for r in after)
    old={r['species']:r for r in before};new={r['species']:r for r in after}
    out=WORK/'eyes-review-v1';out.mkdir(exist_ok=False);(out/'thumbs').mkdir();proof=[]
    def picture(folder,pose):
        path=(folder/pose['image']).resolve();digest=sha(path);target=out/'thumbs'/(digest+'.webp')
        if not target.exists():
            im=Image.open(path);im.thumbnail((400,400));im.convert('RGB').save(target,'WEBP',quality=90)
        proof.append({'file':str(path.relative_to(ROOT)),'sha256':digest})
        return {'full':os.path.relpath(path,out),'thumb':'thumbs/'+target.name}
    rows=[]
    for name in sorted(n for n in old if not n.endswith('-shiny')):
        row={'name':name.replace('-',' ').title(),'changed':name in new}
        for variant,suffix in [('normal',''),('shiny','-shiny')]:
            n=name+suffix;record={}
            for label,entry,folder in [('before',old[n],before_dir),('after',new.get(n,old[n]),after_dir if n in new else before_dir)]:
                record[label]={p['action']:picture(folder,p)for p in entry['poses']if p['view']=='front'and'image'in p}
            record['face']={p['action']:picture(after_dir,p)for p in new.get(n,{}).get('poses',[])if p['view']=='face'and'image'in p};row[variant]=record
        rows.append(row)
    (out/'index.html').write_text(HTML.replace('DATA',json.dumps(rows)))
    (out/'evidence.json').write_text(json.dumps({'runtime_approved':False,'before_report_sha256':sha(before_dir/'godot-review.json'),'after_report_sha256':sha(after_dir/'godot-review.json'),'images':proof},indent=2)+'\n')
    print(out/'index.html')


if __name__=='__main__':main()
