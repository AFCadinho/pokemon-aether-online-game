"""Create a review page from the seven battle-form pose capture receipts."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil

from PIL import Image


LABELS = {
    'idle': 'Stilstand', 'physical_attack': 'Fysieke aanval',
    'physical_attack_2': 'Tweede fysieke aanval', 'special_attack': 'Speciale aanval',
    'sleep': 'Slaap', 'faint_start': 'Flauw', 'faint_loop': 'Blijft flauw',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(report_path, output, catalog_path=None, detail_report_path=None):
    report_path = Path(report_path)
    report = json.loads(report_path.read_text())
    if any(row.get('errors') for row in report.get('entries', [])):
        raise ValueError('Standalone pose report contains errors')
    battle = 'complete' in report
    if battle and not report['complete']:
        raise ValueError('Battle capture report is incomplete')
    entries = {row['species']: row for row in report['entries']
               if not battle or 'shots' in row}
    catalog = {}
    if catalog_path:
        raw_catalog = json.loads(Path(catalog_path).read_text())
        catalog = {row['species']: row for row in raw_catalog.get('entries', [])}
    names = sorted(name for name in entries if not name.endswith('-shiny'))
    if not names or any(name + '-shiny' not in entries for name in names):
        raise ValueError('Every candidate needs a normal/shiny pair')
    if output.exists():
        raise ValueError('Keep completed evidence; choose a new output directory')
    images = output / 'images'
    images.mkdir(parents=True)
    hashes = {}
    mapping = {}
    for name, row in entries.items():
        mapping[name] = {}
        for pose in row['shots' if battle else 'poses']:
            view = str(pose['arena_camera']) + '-' + str(pose['side']) if battle else pose['view']
            key = pose['action'] + '-' + view
            source = report_path.parent / pose['image']
            png = images / source.name
            webp = png.with_suffix('.webp')
            shutil.copyfile(source, png)
            with Image.open(source) as im:
                im.thumbnail((700, 700))
                im.save(webp, quality=90)
            for path in (png, webp):
                hashes[str(path.relative_to(output))] = sha(path)
            mapping[name][key] = {'full': str(png.relative_to(output)), 'thumb': str(webp.relative_to(output))}
    if detail_report_path:
        detail_report_path = Path(detail_report_path)
        details = json.loads(detail_report_path.read_text())
        if any(r.get('errors') for r in details['entries']):
            raise ValueError('Detail report contains errors')
        if {r['species'] for r in details['entries']} != set(entries):
            raise ValueError('Detail report cohort mismatch')
        for row in details['entries']:
            for pose in row['poses']:
                key = pose['action'] + '-detail'
                if key in mapping[row['species']] and pose['view'] != 'front':
                    continue
                source = detail_report_path.parent / pose['image']
                png = images / source.name
                webp = png.with_suffix('.webp')
                shutil.copyfile(source, png)
                with Image.open(source) as im:
                    im.thumbnail((700, 700))
                    im.save(webp, quality=90)
                for path in (png, webp):
                    hashes[str(path.relative_to(output))] = sha(path)
                mapping[row['species']][key] = {'full': str(png.relative_to(output)), 'thumb': str(webp.relative_to(output))}
    cards = []
    blocked = []
    reviewable = []
    for name in names:
        note = catalog.get(name, {}).get('review_notes', '')
        if note.startswith('HOLD:'):
            blocked.append((name, note[5:].strip()))
            continue
        reviewable.append(name)
        columns = []
        for identity, label in ((name, 'Normal'), (name + '-shiny', 'Shiny')):
            serialized = html.escape(json.dumps(mapping[identity]), quote=True)
            columns.append(f'<figure><figcaption>{label}</figcaption><button class="picture" data-images="{serialized}"><img alt="{html.escape(identity)}" src="{mapping[identity]["idle-classic-0" if battle else "idle-front"]["thumb"]}"></button></figure>')
        title = html.escape(name.replace('-', ' ').title())
        note = catalog.get(name, {}).get('review_notes', '')
        note_html = f'<p class="note">{html.escape(note)}</p>' if note else ''
        cards.append(f'<article data-name="{html.escape(name, quote=True)}"><h2>{title}</h2>{note_html}<div class="pair">{"".join(columns)}</div><button class="large">Groot bekijken</button></article>')
    for name, reason in blocked:
        title = html.escape(name.replace('-', ' ').title())
        cards.append(f'<article class="held" data-name="{html.escape(name, quote=True)}"><h2>{title} · nog niet te beoordelen</h2><p>{html.escape(reason)}</p></article>')
    page = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Battle-vormen — uiterlijkcontrole</title><style>
*{box-sizing:border-box}body{margin:0;background:#111923;color:#eef4fb;font:16px system-ui}header{position:sticky;top:0;z-index:2;background:#172331;padding:14px 20px;border-bottom:1px solid #47566b}h1{font-size:1.3rem;margin:0}p{color:#cad6e5;margin:7px 0}.controls{display:flex;gap:8px;flex-wrap:wrap}button,select,input{font:inherit;color:inherit;background:#26374b;border:1px solid #61758d;border-radius:6px;padding:8px}button{cursor:pointer}main{padding:16px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,680px),1fr));gap:16px}article{padding:14px;background:#1d2a38;border:1px solid #485a70;border-radius:9px}article[hidden]{display:none}.note{padding:8px 10px;background:#25364a;border-left:3px solid #f1bd54;border-radius:4px}article.held{border-color:#d49a38;background:#30291f}h2{margin:0 0 8px;font-size:1.15rem}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}figure{margin:0;text-align:center}figcaption{padding:7px}.picture{padding:0;border:0;background:#202020;width:100%;min-height:64px}.picture.missing img{visibility:hidden}.picture.missing:after{content:'Geen controlebeeld voor deze keuze';display:block;padding:20px 8px;color:#cad6e5}img{display:block;width:100%;height:auto}.large{margin-top:8px}dialog{color:#fff;background:#172331;border:1px solid #60758e;border-radius:8px;width:min(1400px,98vw);max-height:96vh;padding:14px}dialog::backdrop{background:#000b}dialog img{max-height:78vh;object-fit:contain}body.large main{grid-template-columns:1fr}
</style><header><h1>Battle-vormen — uiterlijkcontrole</h1><p>Controleer normal en shiny op ogen, kleuren, details en poses. Dit zijn offline modellen ter review; battle-grootte volgt hierna.</p><div class="controls"><select id="pose"><option value="idle">Stilstand</option><option value="physical_attack">Fysieke aanval</option><option value="physical_attack_2">Tweede fysieke aanval</option><option value="special_attack">Speciale aanval</option><option value="sleep">Slaap</option><option value="faint_start">Flauw</option><option value="faint_loop">Blijft flauw</option></select><select id="view"><option value="front">Voorkant</option><option value="back">Achterkant</option></select><input id="search" type="search" placeholder="Zoek vorm"><button id="large">Groot bekijken</button><span id="count"></span></div></header><main>CARDS</main><dialog><button id="close">Sluiten</button><h2></h2><div class="pair"></div></dialog><script>
const pose=document.querySelector('#pose'),view=document.querySelector('#view'),search=document.querySelector('#search'),dialog=document.querySelector('dialog');let active=null;function key(){return pose.value+'-'+view.value}function fill(pic,full=false){const e=JSON.parse(pic.dataset.images)[key()],img=pic.querySelector('img');pic.classList.toggle('missing',!e);if(!e){img.removeAttribute('src');img.alt='Deze combinatie is niet vastgelegd';return}img.src=e[full?'full':'thumb'];img.alt=key()}function show(card){active=card;dialog.querySelector('h2').textContent=card.querySelector('h2').textContent+' · '+pose.options[pose.selectedIndex].text;const pair=dialog.querySelector('.pair');pair.replaceChildren();for(const f of card.querySelectorAll('figure')){const c=f.cloneNode(true);fill(c.querySelector('.picture'),true);pair.append(c)}if(!dialog.open)dialog.showModal()}function refresh(){for(const p of document.querySelectorAll('main .picture'))fill(p);if(dialog.open&&active)show(active)}for(const card of document.querySelectorAll('article')){for(const p of card.querySelectorAll('.picture'))p.onclick=()=>show(card);const large=card.querySelector('.large');if(large)large.onclick=()=>show(card)}for(const c of [pose,view])c.onchange=refresh;search.oninput=()=>{let n=0;for(const c of document.querySelectorAll('article')){c.hidden=!c.dataset.name.includes(search.value.trim().toLowerCase());if(!c.hidden)n++}document.querySelector('#count').textContent=n+' / '+document.querySelectorAll('article').length+' vormen'};document.querySelector('#large').onclick=()=>document.body.classList.toggle('large');document.querySelector('#close').onclick=()=>dialog.close();refresh();search.oninput();
</script></html>'''.replace('CARDS', ''.join(cards))
    if battle:
        page = page.replace('Battle-vormen — uiterlijkcontrole', 'Battle-vormen — battlecontrole')
        page = page.replace('Controleer normal en shiny op ogen, kleuren, details en poses. Dit zijn offline modellen ter review; battle-grootte volgt hierna.', 'Controleer grootte en poses naast Dragonite, voor normal en shiny. Bekijk ook slaap, flauw, beide camera’s en beide kanten.')
        page = page.replace('<option value="front">Voorkant</option><option value="back">Achterkant</option>', '<option value="classic-0">Klassiek · eigen kant</option><option value="classic-1">Klassiek · tegenstander</option><option value="stadium-0">Stadium · eigen kant</option><option value="stadium-1">Stadium · tegenstander</option>')
    if not battle:
        available_views = {pose['view'] for row in entries.values() for pose in row['poses']}
        extra_views = ''.join(f'<option value="{view}">{label}</option>'
                              for view, label in [('face', 'Gezicht · lage camera'), ('side', 'Schuin zijaanzicht'), ('eye', 'Ogen · lage camera')]
                              if view in available_views)
        page = page.replace('</select><input id="search"', extra_views + '</select><input id="search"')
    if detail_report_path:
        page = page.replace('</select><input id="search"', '<option value="detail">Model dichtbij</option></select><input id="search"')
    (output / 'index.html').write_text(page)
    hashes['index.html'] = sha(output / 'index.html')
    (output / 'manifest.json').write_text(json.dumps({'runtime_approved': False,
        'visual_approved': False, 'species': reviewable, 'held': dict(blocked), 'capture_report_sha256': sha(report_path), 'detail_report_sha256': sha(detail_report_path) if detail_report_path else None,
        'files': hashes}, indent=2) + '\n')
    print(f'Review page ready: {len(names)} pairs; {len(hashes)} pinned files')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--detail-report', type=Path)
    parser.add_argument('--catalog', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.report.resolve(), args.output.resolve(), args.catalog.resolve() if args.catalog else None,
          args.detail_report.resolve() if args.detail_report else None)
