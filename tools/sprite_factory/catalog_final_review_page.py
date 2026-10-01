"""One local, lazy-loaded appearance/battle review; never records approval in game data."""
import argparse
import hashlib
import json
from pathlib import Path

HTML = r'''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Laatste Pokémon — eindcontrole</title>
<style>body{margin:0;background:#111922;color:#e3ecf4;font:16px system-ui}header{position:sticky;top:0;z-index:2;background:#172534;padding:14px 20px;border-bottom:1px solid #436078}h1{font-size:22px;margin:0 0 8px}button,input,select{font:inherit;color:inherit;background:#26394c;border:1px solid #58718b;border-radius:5px;padding:8px;margin:4px}main{padding:16px;max-width:1500px;margin:auto}#grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:16px}.card{border:1px solid #415870;border-radius:9px;padding:12px;background:#1b2937}.card h2{margin:0 0 8px;font-size:20px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}figure{margin:0}figure img{width:100%;display:block;background:#202020;cursor:zoom-in;min-height:160px;object-fit:contain}figcaption{padding:6px;background:#14202c}.refs img{width:80px;min-height:70px;background:none}.refs{display:flex;gap:20px;justify-content:space-around;margin-top:8px}.note{font-size:14px;color:#bdcddb;margin:8px 0}.hold{margin-top:24px;padding:16px;border:1px solid #8c7451;background:#302a24}dialog{max-width:95vw;background:#182532;color:#fff;border:1px solid #65788b}dialog img{max-width:90vw;max-height:85vh}dialog::backdrop{background:#000b}textarea{display:block;width:95%;min-height:80px;background:#152232;color:white;padding:8px}#count{margin-left:10px}@media(max-width:500px){#grid{display:block}.card{margin-bottom:16px}header{position:static}}</style>
<header><h1>Laatste Pokémon — één eindcontrole</h1><div id="summary"></div><input id="search" placeholder="Zoek Pokémon" aria-label="Zoek Pokémon"><select id="mode"><option value="appearance">Modellen en kleuren</option><option value="battle">In battle</option></select><select id="pose"><option value="idle">Stilstand</option><option value="physical_attack">Aanval 1</option><option value="special_attack">Aanval 2</option><option value="sleep">Slaap</option><option value="faint_start">Flauw</option></select><select id="camera"><option value="classic">Camera 1</option><option value="stadium">Camera 2</option></select><select id="side"><option value="0">Spelerkant</option><option value="1">Tegenstander</option></select><label><input id="refs" type="checkbox" checked>Kleurreferenties</label><button id="all">Alle Pokémon tonen</button><span id="count"></span></header>
<main><p>Bekijk normal én shiny en wissel de poses. Klik op een beeld om het te vergroten. Aanval 1 staat bij ‘Modellen en kleuren’; battlebeelden tonen aanval 2. De beelden zijn voorstellen voor jouw eindcontrole, nog geen goedkeuring of upload.</p><p id="notes"></p><div id="grid"></div><button id="more">Volgende 24 erbij</button><section class="hold"><h2>Nog niet klaar voor goedkeuring</h2><p id="held-summary"></p><div id="held"></div></section><h2>Afwijkingen noteren</h2><p>Noem de Pokémon, normal/shiny en pose. Je kunt deze notities kopiëren naar de chat.</p><textarea id="issues" placeholder="Bijvoorbeeld: Pokémon — shiny — slaap — ogen"></textarea></main><dialog id="large"><button id="close">Sluiten</button><div id="large-title"></div><img id="large-image"></dialog>
<script id="data" type="application/json">__DATA__</script><script>
const data=JSON.parse(document.getElementById('data').textContent),$=id=>document.getElementById(id);let limit=24;
$('summary').textContent=`${data.entries.length} normal/shiny-paren · ${data.held.length} nog niet klaar`;$('notes').textContent=data.notes;$('held-summary').textContent=data.held_summary;
for(const row of data.held){const p=document.createElement('p');p.textContent=row.name+' — '+row.reason;$('held').append(p)}
function image(src,title){const img=document.createElement('img');img.loading='lazy';img.decoding='async';img.src=src;img.alt=title;img.onclick=()=>{$('large-image').src=src;$('large-title').textContent=title;$('large').showModal()};return img}
function render(){const matched=data.entries.filter(r=>r.name.toLowerCase().includes($('search').value.toLowerCase()));$('grid').replaceChildren();const pose=$('pose').value,mode=$('mode').value,camera=$('camera').value,side=$('side').value;
 for(const row of matched.slice(0,limit)){const card=document.createElement('article');card.className='card';const h=document.createElement('h2');h.textContent=row.name;card.append(h);if(row.note){const p=document.createElement('p');p.className='note';p.textContent=row.note;card.append(p)}const pair=document.createElement('div');pair.className='pair';
 for(const variant of ['normal','shiny']){const figure=document.createElement('figure'),label=document.createElement('figcaption');label.textContent=variant==='normal'?'Normal':'Shiny';const captures=row[variant];let src=mode==='battle'?captures.battle?.[`${camera}-${side}-${pose}`]:captures.appearance?.[pose];if(!src){src=captures.appearance?.[pose];label.textContent+=' · modelaanzicht'}if(src)figure.append(image(src,row.name+' · '+label.textContent+' · '+$('pose').selectedOptions[0].textContent));else{const p=document.createElement('p');p.textContent='Dit beeld ontbreekt; niet als gecontroleerd beschouwen.';figure.append(p)}figure.append(label);pair.append(figure)}card.append(pair);
 if($('refs').checked){const refs=document.createElement('div');refs.className='refs';for(const variant of ['normal','shiny'])if(row[variant].reference)refs.append(image(row[variant].reference,row.name+' '+variant+' kleurreferentie'));card.append(refs)}$('grid').append(card)}$('count').textContent=`${Math.min(limit,matched.length)} / ${matched.length}`;$('more').hidden=limit>=matched.length}
for(const id of ['search','mode','pose','camera','side','refs'])$(id).addEventListener('input',render);$('all').onclick=()=>{limit=data.entries.length;render()};$('more').onclick=()=>{limit+=24;render()};$('close').onclick=()=>$('large').close();$('large').onclick=e=>{if(e.target===$('large'))$('large').close()};$('issues').value=localStorage.getItem('remaining-final-model-issues')||'';$('issues').oninput=()=>localStorage.setItem('remaining-final-model-issues',$('issues').value);render();
</script></html>'''


def build(manifest,output):
    data=json.loads(manifest.read_text());output.mkdir(parents=True,exist_ok=False)
    assets=output/'assets';assets.mkdir();seen={}
    def pin(value):
        if isinstance(value,dict):return {k:pin(v) for k,v in value.items()}
        if isinstance(value,list):return [pin(v) for v in value]
        if isinstance(value,str) and value.startswith('/'):
            path=Path(value)
            if path.suffix.lower() not in ['.png','.jpg','.jpeg','.gif','.webp']:raise ValueError('Review assets must be images')
            digest=hashlib.sha256(path.read_bytes()).hexdigest();target=digest+path.suffix.lower()
            if target not in seen:(assets/target).symlink_to(path);seen[target]=str(path)
            return 'assets/'+target
        return value
    data=pin(data)
    payload=json.dumps(data,ensure_ascii=False).replace('<','\\u003c')
    (output/'index.html').write_text(HTML.replace('__DATA__',payload))
    (output/'assets.json').write_text(json.dumps(seen,indent=2))
    print(json.dumps({'pairs':len(data['entries']),'held':len(data['held']),'images':len(seen),'output':str(output)}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--manifest',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();build(a.manifest.resolve(),a.output.resolve())
