"""Build one verified, lazy-loading regional normal/shiny review page."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from PIL import Image

HTML=r'''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Regionale Pokémon — eindcontrole</title>
<style>body{margin:0;background:#111922;color:#e4edf6;font:16px system-ui}header{position:sticky;top:0;background:#162635;z-index:2;padding:14px 20px;border-bottom:1px solid #496378}h1{font-size:23px;margin:0 0 7px}header p{margin:5px 0 10px}input,select,button{font:inherit;color:inherit;background:#23394b;border:1px solid #638097;border-radius:6px;padding:9px;margin:3px}main{max-width:1600px;margin:auto;padding:18px}#grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,450px),1fr));gap:18px}article{background:#1c2a37;padding:14px;border:1px solid #43586c;border-radius:9px}h2{font-size:19px;margin:0 0 8px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}figure{margin:0}figure button{border:0;margin:0;padding:0;background:#202020;width:100%;cursor:zoom-in}figure img{display:block;width:100%;aspect-ratio:1;object-fit:contain}figcaption{padding:6px}.note{font-size:14px;color:#bed1e0;min-height:18px}.refs{display:flex;justify-content:space-around}.refs img{width:85px;height:85px;object-fit:contain}dialog{border:1px solid #7799b1;background:#142332;color:white;width:min(1500px,96vw);max-height:95vh}dialog img{width:100%;max-height:80vh;object-fit:contain}dialog::backdrop{background:#000c}#top{display:flex;justify-content:space-between}#count{padding-left:12px}.unavailable{padding:35px 12px;text-align:center;color:#d0dbe4}@media(max-width:650px){header{position:static}}</style>
<header><h1>58 regionale vormen — gezamenlijke eindcontrole</h1><p>Vergelijk normal en shiny. Bekijk ook aanvallen, slaap en flauw. Klik op een beeld om het groot te bekijken.</p>
<input id="search" placeholder="Zoek Pokémon" aria-label="Zoek Pokémon"><select id="mode" aria-label="Weergave"><option value="appearance">Model en kleuren</option><option value="battle">Battle naast Dragonite</option></select><select id="pose" aria-label="Pose"><option value="idle">Stilstand</option><option value="physical_attack">Aanval 1</option><option value="physical_attack_2">Extra aanval</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap / rust</option><option value="faint_start">Flauw</option><option value="faint_loop">Flauw — rust</option></select><select id="view" aria-label="Modelaanzicht"><option value="front">Schuin voor</option><option value="face">Gezicht van voren</option><option value="back">Achterkant</option><option value="side">Zijkant</option></select><select id="camera" aria-label="Battlecamera"><option value="classic">Camera 1</option><option value="stadium">Camera 2</option></select><select id="side" aria-label="Battlekant"><option value="0">Spelerkant</option><option value="1">Tegenstander</option></select><span id="count"></span></header>
<main><p>Dit zijn voorstellen voor jouw controle. Bij Pikachu met Alola-pet leveren de bronbestanden dezelfde normal- en shiny-kleuren. Alolan Vulpix gebruikt eigen brongebaren voor zijn aanvallen; Galarian Darmanitan Zen gebruikt een rustpose. Corsola houdt in zijn bronpose de ogen open.</p><div id="grid"></div><button id="more">Volgende 20 tonen</button><button id="all">Alles tonen</button></main>
<dialog id="zoom"><div id="top"><h2 id="title"></h2><button id="close">Sluiten</button></div><div class="pair" id="large"></div></dialog>
<script>const data=DATA,byId=id=>document.getElementById(id),controls=['search','mode','pose','view','camera','side'];let limit=20,active=null;
function current(row,variant){const map=row[variant];if(byId('mode').value==='battle')return map.battle[byId('camera').value+'-'+byId('side').value+'-'+byId('pose').value];return map.appearance[byId('pose').value+'-'+byId('view').value]||map.appearance[byId('pose').value+'-front'];}
function pic(row,v,large=false){const f=document.createElement('figure'),cap=document.createElement('figcaption');cap.textContent=v==='normal'?'Normal':'Shiny';f.append(cap);const p=current(row,v);if(!p){const n=document.createElement('div');n.className='unavailable';n.textContent='Geen aparte opname van deze pose.';f.append(n);return f;}const img=new Image();img.src=large?p.full:p.thumb;img.loading=large?'eager':'lazy';img.alt=row.name+' '+cap.textContent;const b=document.createElement('button');b.title='Groot bekijken';b.append(img);b.onclick=()=>open(row);f.append(b);if(large){const a=document.createElement('a');a.href=p.full;a.target='_blank';a.rel='noopener';a.textContent='Afbeelding apart openen';a.style.color='#9edcff';f.append(a);}return f;}
function open(row){active=row;byId('title').textContent=row.name+' · '+byId('pose').selectedOptions[0].textContent;byId('large').replaceChildren(pic(row,'normal',true),pic(row,'shiny',true));if(!byId('zoom').open)byId('zoom').showModal();}
function render(){const battle=byId('mode').value==='battle';for(const option of byId('pose').options)option.disabled=battle&&!['idle','special_attack','sleep','faint_start'].includes(option.value);if(byId('pose').selectedOptions[0].disabled)byId('pose').value='idle';const found=data.filter(r=>(r.name+' '+r.species).toLowerCase().includes(byId('search').value.toLowerCase())),grid=byId('grid');grid.replaceChildren();for(const r of found.slice(0,limit)){const card=document.createElement('article'),h=document.createElement('h2');h.textContent=r.name;const pair=document.createElement('div');pair.className='pair';pair.append(pic(r,'normal'),pic(r,'shiny'));card.append(h,pair);if(r.note){const p=document.createElement('p');p.className='note';p.textContent=r.note;card.append(p);}const refs=document.createElement('div');refs.className='refs';for(const v of ['normal','shiny'])if(r[v].reference){const i=new Image();i.src=r[v].reference;i.alt=v+' kleurreferentie';i.loading='lazy';refs.append(i);}card.append(refs);grid.append(card);}byId('count').textContent=Math.min(limit,found.length)+' / '+found.length+' vormen';byId('more').hidden=limit>=found.length;byId('view').hidden=byId('mode').value==='battle';byId('camera').hidden=byId('mode').value!=='battle';byId('side').hidden=byId('mode').value!=='battle';if(active&&byId('zoom').open)open(active);}
for(const c of controls)byId(c).addEventListener(c==='search'?'input':'change',render);byId('more').onclick=()=>{limit+=20;render()};byId('all').onclick=()=>{limit=data.length;render()};byId('close').onclick=()=>byId('zoom').close();render();</script></html>'''


def build(appearance,battle,output,frontend):
    report=json.loads((appearance/'godot-review.json').read_text())
    assert len(report['entries'])==116 and all(not r.get('errors') for r in report['entries'])
    rendered={r['species']:r for r in report['entries']}
    battle_report=json.loads((battle/'battle-review.json').read_text())
    assert battle_report['complete']
    battlers={r['species']:r for r in battle_report['entries']if 'shots'in r}
    assert set(battlers)==set(rendered)
    output.mkdir(exist_ok=False);thumbs=output/'thumbs';thumbs.mkdir();evidence=[]
    def picture(path):
        assert path.is_file(),path
        digest=hashlib.sha256(path.read_bytes()).hexdigest();target=thumbs/(digest+'.webp')
        if not target.exists():
            im=Image.open(path);im.thumbnail((460,460));im.convert('RGB').save(target,'WEBP',quality=85)
        evidence.append({'file':os.path.relpath(path,output),'sha256':digest})
        return {'full':os.path.relpath(path,output),'thumb':'thumbs/'+target.name}
    home={folder:{p.stem.lower().replace('-',''):p for p in (frontend/'assets/sprites/pokemon'/folder).glob('*.png')}
          for folder in ['pokemon_home','pokemon_home_shiny']}
    rows=[]
    for n in sorted(k for k in rendered if not k.endswith('-shiny')):
        row={'species':n,'name':n.replace('-',' ').title(),'note':''}
        if n.endswith('totem'):row['note']='Grotere Totem-vorm; vergelijk de grootte ook in battle.'
        if n=='pikachu-alola':row['note']='Alola-pet: normal en rare hebben identieke bronmaterialen.'
        for v,suffix,folder in [('normal','','pokemon_home'),('shiny','-shiny','pokemon_home_shiny')]:
            a=rendered[n+suffix];b=battlers[n+suffix]
            variant={'appearance':{p['action']+'-'+p['view']:picture(appearance/p['image'])for p in a['poses']if 'image'in p},'battle':{}}
            for shot in b['shots']:
                key=str(shot['arena_camera'])+'-'+str(shot['side'])+'-'+shot['action']
                variant['battle'][key]=picture(battle/shot['image'])
            key=n.replace('-','');ref=home[folder].get(key)
            if ref:
                im=Image.open(ref).convert('RGBA');im.thumbnail((180,180));target=thumbs/(n+'-'+v+'-reference.png');im.save(target);variant['reference']='thumbs/'+target.name
            row[v]=variant
        rows.append(row)
    assert len(rows)==58
    (output/'index.html').write_text(HTML.replace('DATA',json.dumps(rows,ensure_ascii=False)))
    (output/'evidence.json').write_text(json.dumps({'runtime_approved':False,'appearance_report_sha256':hashlib.sha256((appearance/'godot-review.json').read_bytes()).hexdigest(),'battle_report_sha256':hashlib.sha256((battle/'battle-review.json').read_bytes()).hexdigest(),'images':evidence},indent=2)+'\n')
    print(output/'index.html')


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ['appearance','battle','output']:p.add_argument('--'+n,type=Path,required=True)
    a=p.parse_args();build(a.appearance.resolve(),a.battle.resolve(),a.output.resolve(),Path(__file__).resolve().parents[2])
