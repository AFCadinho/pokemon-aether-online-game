"""Build a before/after eye-material review page from pinned Godot captures."""

import argparse
import html
import json
import os
from pathlib import Path

from catalog_remaining_review_page import thumbnail


POSES = ('idle', 'sleep')


def build(status, receipt, runtime, original, capture_root):
    rows = {row['species']: row for row in status['entries']}
    runtime_hashes = {row['species']: row['runtime_sha256'] for row in runtime}
    candidates = [row for row in receipt['entries']
                  if row['status'] == 'normal_shiny_technical_candidate']
    captured = {}
    for folder in sorted(capture_root.glob('captures-*'),
                         key=lambda path: int(path.name.split('-')[-1])):
        if not (folder / 'review.json').is_file():
            continue
        shard = int(folder.name.split('-')[-1])
        report = json.loads((folder / 'review.json').read_text())
        if report['capture_profile'] != 'eye_pair':
            raise ValueError('Expected eye review captures')
        for entry in report['entries']:
            if entry['errors'] or len(entry['captures']) != len(POSES):
                raise ValueError('Incomplete Godot capture: ' + entry['species'])
            captured[entry['species']] = (shard, entry)
    if len(candidates) != 156 or len(captured) != 312:
        raise ValueError('Expected all 156 normal/shiny pairs')
    thumbs = capture_root / 'thumbs'
    thumbs.mkdir(exist_ok=True)
    old_prefix = os.path.relpath(original / 'thumbs', capture_root)
    cards = []
    for candidate in candidates:
        species = candidate['species']
        row = rows[species]
        sections = []
        for variant in ('normal', 'shiny'):
            key = species + '-' + variant
            shard, record = captured[key]
            if record['runtime_sha256'] != runtime_hashes[key]:
                raise ValueError('Scene hash mismatch: ' + key)
            pictures = {}
            for capture in record['captures']:
                src = capture_root / f'captures-{shard}' / capture['image']
                dest = thumbs / (src.stem + '.webp')
                thumbnail(src, dest)
                pictures[capture['action']] = 'thumbs/' + dest.name
            original_name = species + ('@shiny' if variant == 'shiny' else '')
            original_idle = old_prefix + '/' + original_name + '-idle-50.webp'
            poses = ''.join(f'<figure><img loading="lazy" src="{html.escape(pictures[action], quote=True)}">'
                            f'<figcaption>{html.escape(action)}</figcaption></figure>'
                            for action in POSES if action != 'idle')
            sections.append(f'<section><h3>{variant.title()}</h3><div class="pair">'
                            f'<figure><img loading="lazy" src="{html.escape(original_idle, quote=True)}">'
                            '<figcaption>Voor</figcaption></figure>'
                            f'<figure><img loading="lazy" src="{html.escape(pictures["idle"], quote=True)}">'
                            '<figcaption>Na</figcaption></figure></div>'
                            f'<details><summary>Andere poses na correctie</summary><div class="poses">{poses}</div></details></section>')
        note = ('Oorspronkelijke ogen behouden na visuele vergelijking'
                if row['status'] == 'retained_original_eye_after_visual_review'
                else 'Geen oogmateriaal van dit type'
                if row['status'] == 'unchanged_no_matching_eye_material'
                else f'{len(row["normal"]["eye_materials"])} oogmaterialen hersteld')
        cards.append(f'<article data-name="{html.escape(species, quote=True)}">'
                     f'<h2>#{candidate["national_dex"]} {html.escape(species.title())}</h2>'
                     f'<p>{html.escape(note)}</p><div class="variants">{"".join(sections)}</div></article>')
    return '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>156 Pokémon — ogen voor/na</title><style>
body{margin:0;background:#111923;color:#edf3f8;font:16px system-ui,sans-serif}header{position:sticky;top:0;background:#172331;padding:12px 20px;border-bottom:1px solid #40556a;z-index:2}h1{font-size:1.25rem;margin:0 0 5px}header p{margin:4px 0 8px;color:#c6d2df}input{background:#26384a;color:white;border:1px solid #526c83;border-radius:6px;padding:8px;font:inherit}main{padding:14px;display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:12px}article{background:#1d2b39;border:1px solid #40556a;border-radius:9px;padding:12px}h2{font-size:1.1rem;margin:0 0 4px}article p{font-size:.8rem;color:#c6d2df;margin:0 0 6px}.variants{display:grid;grid-template-columns:1fr 1fr;gap:8px}h3{text-align:center;font-size:.95rem;margin:5px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:4px}figure{margin:0;text-align:center}img{width:100%;border-radius:4px;background:#222}.pair img{max-height:230px;object-fit:contain}figcaption{font-size:.72rem;color:#c6d2df}details{font-size:.8rem}summary{cursor:pointer;padding:5px}.poses{display:grid;grid-template-columns:repeat(2,1fr);gap:4px}
</style><header><h1>Ogen: voor en na — 156 Pokémon</h1><p>Normal en shiny naast de oorspronkelijke render. Dit is een visuele review, geen catalogusgoedkeuring.</p><input id="search" placeholder="Zoek Pokémon"><span id="count"></span></header><main>''' + ''.join(cards) + '''</main><script>
const cards=[...document.querySelectorAll('article')],search=document.querySelector('#search'),count=document.querySelector('#count');const focus=new URLSearchParams(location.search).get('focus')?.split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);function update(){let n=0;for(const card of cards){card.hidden=!(card.dataset.name.includes(search.value.trim().toLowerCase())&&(!focus||focus.includes(card.dataset.name)));if(!card.hidden)n++}count.textContent=` ${n} / ${cards.length}`};search.addEventListener('input',update);update();
</script></html>'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--status', type=Path, required=True)
    parser.add_argument('--receipt', type=Path, required=True)
    parser.add_argument('--runtime-report', type=Path, required=True)
    parser.add_argument('--original', type=Path, required=True)
    parser.add_argument('--capture-root', type=Path, required=True)
    args = parser.parse_args()
    page = build(json.loads(args.status.read_text()), json.loads(args.receipt.read_text()),
                 json.loads(args.runtime_report.read_text()),
                 args.original.resolve(), args.capture_root.resolve())
    target = args.capture_root / 'index.html'
    target.write_text(page)
    print(target)


if __name__ == '__main__':
    main()
