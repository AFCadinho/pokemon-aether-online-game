"""One collective, hash-bound review for the first five battle forms."""
import argparse
import hashlib
import html
import json
import math
from pathlib import Path
import shutil

from PIL import Image


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build(root, output, revision=6):
    if revision < 1:
        raise ValueError("Revision must be positive")
    intake = json.loads(Path(__file__).with_name('catalog_battle_forms_first_five_intake.json').read_text())
    names = [r['species'] for r in intake['entries']]
    identities = {n + suffix for n in names for suffix in ('', '-shiny')}
    diagnostic = root / f'captures-v{revision}/godot-review.json'
    battle = root / f'battle-v{revision}/status.json'
    reports = [json.loads(p.read_text()) for p in (diagnostic, battle)]
    if not reports[1]['complete'] or reports[1]['failures']:
        raise ValueError('Battle checks have not passed')
    for row in reports[1]['entries']:
        for action, clip in row['clips'].items():
            extent = math.sqrt(sum(v*v for v in clip['envelope_size']))
            if not math.isfinite(extent) or extent > 10:
                raise ValueError(f'Corrupt full-clock geometry: {row["species"]} {action}')
    for report in reports:
        if {r['species'] for r in report['entries']} != identities:
            raise ValueError('Incomplete five-form normal/shiny cohort')
    if any(r['errors'] for r in reports[0]['entries']):
        raise ValueError('Standalone pose checks have not passed')
    if output.exists():
        raise ValueError('Retain completed evidence; choose a new output')
    (output / 'images').mkdir(parents=True)
    mapping = {n: {} for n in identities}
    files = {}

    def image(source, name):
        full = output / 'images' / (name + '.png')
        thumb = full.with_suffix('.webp')
        shutil.copyfile(source, full)
        with Image.open(source) as im:
            im.thumbnail((720, 720))
            im.save(thumb, quality=90)
        for p in (full, thumb):
            files[str(p.relative_to(output))] = sha(p)
        return {'full': str(full.relative_to(output)), 'thumb': str(thumb.relative_to(output))}

    for row in reports[0]['entries']:
        for pose in row['poses']:
            key = 'detail-' + pose['action'] + ('-back' if pose['view'] == 'back' else '')
            mapping[row['species']][key] = image(diagnostic.parent / pose['image'], row['species'] + '-' + key)
    for row in reports[1]['entries']:
        for shot in row['shots']:
            key = f"{shot['arena_camera']}-{shot['side']}-{shot['action']}"
            mapping[row['species']][key] = image(Path(row['evidence_root']) / shot['image'], row['species'] + '-' + key)
    maskless = root / f'maskless-v{revision}/godot-review.json'
    eyes = root / f'eyes-v{revision}/godot-review.json'
    if eyes.exists():
        eye_report = json.loads(eyes.read_text())
        if any(r['errors'] for r in eye_report['entries']):
            raise ValueError('Low eye-camera diagnostic failed')
        for row in eye_report['entries']:
            for pose in row['poses']:
                if pose['action'] == 'idle':
                    mapping[row['species']]['detail-eyes'] = image(eyes.parent / pose['image'], row['species'] + '-eyes')
    if maskless.exists():
        mask_report = json.loads(maskless.read_text())
        if any(r['errors'] for r in mask_report['entries']):
            raise ValueError('Maskless diagnostic failed')
        for row in mask_report['entries']:
            for pose in row['poses']:
                if pose['action'] == 'idle' and pose['view'] == 'front':
                    mapping[row['species']]['detail-maskless'] = image(maskless.parent / pose['image'], row['species'] + '-maskless')
    cards = []
    for name in names:
        figures = []
        for label, identity in [('Normal', name), ('Shiny', name + '-shiny')]:
            data = html.escape(json.dumps(mapping[identity]), quote=True)
            figures.append(f'<figure><figcaption>{label}</figcaption><button class="picture" data-images="{data}"><img src="{mapping[identity]["detail-idle"]["thumb"]}" alt="{identity}"><span></span></button></figure>')
        cards.append(f'<article><h2>{name.replace("-", " ").title()}</h2><div class="pair">{"".join(figures)}</div><button class="large">Groot bekijken</button></article>')
    page = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Vijf battle-vormen</title><style>
*{box-sizing:border-box}body{margin:0;background:#111923;color:#eef4fb;font:16px system-ui}header{position:sticky;top:0;z-index:2;background:#172331;padding:14px}h1{font-size:1.3rem}p{color:#cad6e5}.controls{display:flex;flex-wrap:wrap;gap:8px}button,select{font:inherit;color:inherit;background:#26374b;border:1px solid #61758d;border-radius:6px;padding:8px}button{cursor:pointer}main{padding:16px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,650px),1fr));gap:16px}article{padding:14px;background:#1d2a38;border:1px solid #485a70;border-radius:9px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}figure{margin:0;text-align:center}figcaption{padding:7px}.picture{padding:0;border:0;background:#202020;width:100%}img{display:block;width:100%;height:auto}.large{margin-top:8px}dialog{color:#fff;background:#172331;border:1px solid #60758e;border-radius:8px;width:min(1500px,98vw);max-height:96vh;padding:14px}dialog::backdrop{background:#000b}dialog img{max-height:76vh;object-fit:contain}
</style><header><h1>Ogerpon-maskers en Terapagos — vijf normal/shiny-paren</h1><p>Controleer ogen, kleuren, onderdelen, rust en battle-grootte. Klik op een model voor het grote beeld. Dit zijn kandidaten vóór toelating in de game.</p><p>Ogerpons shiny-gezicht zit achter het masker: kies ook ‘Ogerpon zonder masker (controlebeeld)’. De rustposes zijn opgebouwd uit hun eigen animaties. Terapagos Terastal gebruikt voor zijn speciale aanval een bron-start, één lus en bron-einde.</p><div class="controls"><select id="view"><option value="detail">Model groot</option><option value="battle">Battle naast Dragonite</option></select><select id="pose"><option value="idle">Stilstand</option><option value="idle-back">Achterkant</option><option value="physical_attack">Fysieke aanval</option><option value="physical_attack_2">Tweede fysieke aanval</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap / rust</option><option value="faint_start">Flauw</option><option value="faint_loop">Blijft flauw</option><option value="eyes">Terapagos ogen — lage camera</option><option value="maskless">Ogerpon zonder masker (controlebeeld)</option></select><select id="camera"><option value="classic">Klassieke camera</option><option value="stadium">Stadiumcamera</option></select><select id="side"><option value="0">Links</option><option value="1">Rechts</option></select></div></header><main>CARDS</main><dialog><button id="close">Sluiten</button><h2></h2><div class="pair"></div></dialog><script>
const view=document.querySelector('#view'),pose=document.querySelector('#pose'),camera=document.querySelector('#camera'),side=document.querySelector('#side'),dialog=document.querySelector('dialog');let active=null;
function key(){return view.value==='detail'?'detail-'+pose.value:camera.value+'-'+side.value+'-'+pose.value}
function fill(pic,full=false){const entry=JSON.parse(pic.dataset.images)[key()],img=pic.querySelector('img'),note=pic.querySelector('span');img.hidden=!entry;note.textContent=entry?'':'Geen beeld voor deze keuze';if(entry)img.src=entry[full?'full':'thumb']}
function show(card){active=card;dialog.querySelector('h2').textContent=card.querySelector('h2').textContent+' · '+pose.options[pose.selectedIndex].text;const pair=dialog.querySelector('.pair');pair.replaceChildren();for(const f of card.querySelectorAll('figure')){const copy=f.cloneNode(true);fill(copy.querySelector('.picture'),true);pair.append(copy)}if(!dialog.open)dialog.showModal()}
function refresh(){for(const pic of document.querySelectorAll('main .picture'))fill(pic);camera.disabled=side.disabled=view.value==='detail';if(dialog.open&&active)show(active)}
for(const card of document.querySelectorAll('article')){for(const pic of card.querySelectorAll('.picture'))pic.onclick=()=>show(card);card.querySelector('.large').onclick=()=>show(card)}for(const c of [view,pose,camera,side])c.onchange=refresh;document.querySelector('#close').onclick=()=>dialog.close();refresh();
</script></html>'''.replace('CARDS', ''.join(cards))
    (output / 'index.html').write_text(page)
    files['index.html'] = sha(output / 'index.html')
    manifest = {'runtime_approved': False, 'visual_approved': False, 'species': names,
                'reports': {str(p.relative_to(root)): sha(p) for p in (diagnostic, battle)}, 'files': files}
    if maskless.exists():
        manifest['reports'][str(maskless.relative_to(root))] = sha(maskless)
    if eyes.exists():
        manifest['reports'][str(eyes.relative_to(root))] = sha(eyes)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Review ready:', len(names), 'pairs,', len(files), 'page/image files')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--revision', type=int, default=6)
    args = parser.parse_args()
    build(args.evidence_root.resolve(), args.output.resolve(), args.revision)
