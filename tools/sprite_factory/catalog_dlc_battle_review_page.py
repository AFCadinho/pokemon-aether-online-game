"""Build one hash-bound normal/shiny rest and battle review page."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil

from PIL import Image


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(evidence, output):
    battle_path = evidence / 'battle-flat-v4/status.json'
    battle = json.loads(battle_path.read_text())
    diagnostics_path = evidence / 'sleep-flat-captures-v1/godot-review.json'
    diagnostics = json.loads(diagnostics_path.read_text())
    if not battle['complete'] or battle['failures']:
        raise ValueError('Battle qualification is incomplete or has failures')
    if any(r['errors'] for r in diagnostics['entries']):
        raise ValueError('Standalone pose/timing check failed')
    if output.exists():
        raise ValueError('Retain completed review evidence; choose a new output')
    images = output / 'images'
    images.mkdir(parents=True)
    mapping = {}
    files = {}

    def copy_image(source, name):
        full = images / (name + '.png')
        thumbnail = images / (name + '.webp')
        shutil.copyfile(source, full)
        with Image.open(source) as image:
            image.thumbnail((640, 640))
            image.save(thumbnail, quality=88)
        for path in (full, thumbnail):
            files[str(path.relative_to(output))] = sha(path)
        return {'full': str(full.relative_to(output)), 'thumb': str(thumbnail.relative_to(output))}

    for row in battle['entries']:
        name = row['species']
        mapping[name] = {}
        for shot in row['shots']:
            key = f"{shot['arena_camera']}-{shot['side']}-{shot['action']}"
            mapping[name][key] = copy_image(Path(row['evidence_root']) / shot['image'], name + '-' + key)
    for row in diagnostics['entries']:
        for pose in row['poses']:
            if pose['action'] in ('idle', 'sleep') and pose['view'] == 'front':
                key = 'detail-' + pose['action']
                mapping[row['species']][key] = copy_image(diagnostics_path.parent / pose['image'], row['species'] + '-' + key)
    species = [r['species'] for r in battle['entries'] if not r['species'].endswith('-shiny')]
    if len(species) != 15 or len(mapping) != 30:
        raise ValueError('Expected precisely 15 normal/shiny pairs')
    cards = []
    for name in species:
        title = name.replace('-', ' ').title()
        pair = []
        for label, identity in [('Normal', name), ('Shiny', name + '-shiny')]:
            serialized = html.escape(json.dumps(mapping[identity]), quote=True)
            pair.append(f'<figure><figcaption>{label}</figcaption><button class="picture" data-images="{serialized}"><img loading="lazy" alt="{title} {label}" src="{mapping[identity]["detail-sleep"]["thumb"]}"></button></figure>')
        cards.append(f'<article data-name="{name.replace("-", " ")}"><h2>{title}</h2><div class="pair">{"".join(pair)}</div><button class="large">Groot bekijken</button></article>')
    page = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>15 DLC Pokémon — laatste battle-review</title><style>
*{box-sizing:border-box}body{margin:0;background:#111923;color:#eef4fb;font:16px system-ui}header{position:sticky;top:0;z-index:2;background:#172331;padding:14px 20px;border-bottom:1px solid #47566b}h1{font-size:1.35rem;margin:0}p{margin:7px 0;color:#cad6e5}.controls{display:flex;flex-wrap:wrap;gap:8px}button,input,select{font:inherit;color:inherit;background:#26374b;border:1px solid #61758d;border-radius:6px;padding:8px}button{cursor:pointer}main{padding:16px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,680px),1fr));gap:16px}article{padding:14px;background:#1d2a38;border:1px solid #485a70;border-radius:9px}article[hidden]{display:none}h2{margin:0 0 8px;font-size:1.15rem}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}figure{margin:0;text-align:center}figcaption{padding:7px}.picture{padding:0;border:0;background:#202020;width:100%}img{display:block;width:100%;height:auto}.large{margin-top:8px}dialog{color:#fff;background:#172331;border:1px solid #60758e;border-radius:8px;width:min(1500px,98vw);max-height:96vh;padding:14px}dialog::backdrop{background:#000b}.dialog-head{display:flex;justify-content:space-between;align-items:center}dialog img{max-height:76vh;object-fit:contain}
</style><header><h1>15 DLC Pokémon — slaap en battle</h1><p>Controleer de ruststand, grootte en poses naast Dragonite. Normal en shiny staan naast elkaar. Kies ook Aanval, Flauw, de andere camera en kant.</p><p>De slaapstanden zijn gemaakt uit eigen poses. Modellen zonder oogleden kunnen hun ogen open houden; Iron Boulder en Iron Crown zetten hun ooglicht uit.</p><div class="controls"><input id="search" type="search" placeholder="Zoek Pokémon" aria-label="Zoek Pokémon"><select id="view" aria-label="Weergave"><option value="detail">Gezicht / ruststand groot</option><option value="battle">Battle naast Dragonite</option></select><select id="pose" aria-label="Pose"><option value="sleep">Slaap / rust</option><option value="idle">Stilstand</option><option value="special_attack">Aanval</option><option value="faint_start">Flauw</option></select><select id="camera" aria-label="Camera"><option value="classic">Klassieke camera</option><option value="stadium">Stadiumcamera</option></select><select id="side" aria-label="Kant"><option value="0">Links</option><option value="1">Rechts</option></select><span id="count">15 / 15 Pokémon</span></div></header><main>CARDS</main><dialog id="detail"><div class="dialog-head"><h2></h2><button id="close">Sluiten</button></div><div class="pair"></div></dialog><script>
const cards=[...document.querySelectorAll('article')],view=document.querySelector('#view'),pose=document.querySelector('#pose'),camera=document.querySelector('#camera'),side=document.querySelector('#side'),dialog=document.querySelector('#detail');let active=null;
function key(){return view.value==='detail'&&['idle','sleep'].includes(pose.value)?'detail-'+pose.value:camera.value+'-'+side.value+'-'+pose.value}
function show(card){active=card;dialog.querySelector('h2').textContent=card.querySelector('h2').textContent+' · '+pose.options[pose.selectedIndex].text;const pair=dialog.querySelector('.pair');pair.replaceChildren();for(const pic of card.querySelectorAll('.picture')){const f=document.createElement('figure'),c=document.createElement('figcaption'),i=document.createElement('img');c.textContent=pic.parentElement.querySelector('figcaption').textContent;i.src=JSON.parse(pic.dataset.images)[key()].full;i.alt=card.querySelector('h2').textContent+' '+c.textContent;f.append(c,i);pair.append(f)}if(!dialog.open)dialog.showModal()}
function refresh(){for(const pic of document.querySelectorAll('.picture'))pic.querySelector('img').src=JSON.parse(pic.dataset.images)[key()].thumb;camera.disabled=side.disabled=view.value==='detail'&&['idle','sleep'].includes(pose.value);if(dialog.open&&active)show(active)}
for(const card of cards){for(const pic of card.querySelectorAll('.picture'))pic.addEventListener('click',()=>show(card));card.querySelector('.large').addEventListener('click',()=>show(card))}for(const control of [view,pose,camera,side])control.addEventListener('change',refresh);document.querySelector('#search').addEventListener('input',e=>{let n=0;for(const card of cards){card.hidden=!card.dataset.name.includes(e.target.value.trim().toLowerCase());if(!card.hidden)n++}document.querySelector('#count').textContent=n+' / 15 Pokémon'});document.querySelector('#close').addEventListener('click',()=>dialog.close());dialog.addEventListener('click',e=>{if(e.target===dialog)dialog.close()});refresh();
</script></html>'''.replace('CARDS', ''.join(cards))
    (output / 'index.html').write_text(page)
    files['index.html'] = sha(output / 'index.html')
    manifest = {'runtime_approved': False, 'user_battle_approved': False, 'species': species,
                'battle_report_sha256': sha(battle_path), 'standalone_report_sha256': sha(diagnostics_path), 'files': files}
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Prepared', len(species), 'pairs;', len(files), 'hash-bound page/image files')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    build(args.evidence_root.resolve(), args.output.resolve())
