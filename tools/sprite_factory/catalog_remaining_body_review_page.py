"""Generate a normal/shiny before/after page for contaminated body textures."""

import argparse
import html
import json
import os
from pathlib import Path

from catalog_remaining_review_page import thumbnail


def images(root):
    found = {}
    folders = ([root] if (root / 'review.json').is_file()
               else sorted(root.glob('captures-*'),
                           key=lambda path: int(path.name.split('-')[-1])))
    for folder in folders:
        report = folder / 'review.json'
        if not report.is_file():
            continue
        for row in json.loads(report.read_text())['entries']:
            for capture in row['captures']:
                if capture['action'] == 'idle':
                    found[row['species']] = folder / capture['image']
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--status', type=Path, required=True)
    parser.add_argument('--before', type=Path, required=True)
    parser.add_argument('--after', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    before = images(args.before)
    after = images(args.after)
    thumbs = args.output / 'thumbs'
    thumbs.mkdir(exist_ok=True)
    cards = []
    repaired = [row for row in json.loads(args.status.read_text())['entries']
                if row['status'] == 'repaired_for_review']
    for row in repaired:
        species = row['species']
        figures = []
        for variant in ('normal', 'shiny'):
            key = species + '-' + variant
            for label, source in (('Voor', before[key]), ('Na', after[key])):
                dest = thumbs / f'{key}-{label.lower()}.webp'
                thumbnail(source, dest)
                link = os.path.relpath(dest, args.output)
                figures.append('<figure><img loading="lazy" src="' + html.escape(link, quote=True) +
                               '"><figcaption>' + variant.title() + ' · ' + label + '</figcaption></figure>')
        cards.append('<article data-name="' + html.escape(species, quote=True) + '"><h2>' +
                     html.escape(species.title()) + '</h2><p>' +
                     str(len(row['normal']['restored'])) + ' lichaamsmaterialen met de officiële albedo hersteld</p>' +
                     '<div class="images">' + ''.join(figures) + '</div></article>')
    page = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lichaamskleuren — voor en na</title><style>
body{margin:0;background:#121a24;color:#edf3f8;font:16px system-ui,sans-serif}header{position:sticky;top:0;background:#1b2b3a;padding:12px 20px;z-index:2;border-bottom:1px solid #496277}h1{font-size:1.25rem;margin:0}header p{margin:5px 0}input{background:#263c50;border:1px solid #657e92;border-radius:6px;padding:8px;color:white}main{padding:15px;display:grid;grid-template-columns:repeat(auto-fit,minmax(640px,1fr));gap:12px}article{border:1px solid #496277;border-radius:8px;background:#1c2b3a;padding:10px}h2{font-size:1.05rem;margin:0 0 4px}article p{font-size:.8rem;margin:0 0 8px;color:#cbd6df}.images{display:grid;grid-template-columns:repeat(4,1fr);gap:6px}figure{margin:0;text-align:center}img{width:100%;background:#222;border-radius:4px}figcaption{font-size:.75rem;color:#cbd6df}
</style><header><h1>''' + str(len(repaired)) + ''' Pokémon: lichaamskleuren voor en na</h1><p>Normal en shiny. Reviewversie; deze modellen zijn nog niet goedgekeurd.</p><input id="search" placeholder="Zoek Pokémon"><span id="count"></span></header><main>''' + ''.join(cards) + '''</main><script>
const cards=[...document.querySelectorAll('article')],input=document.querySelector('#search'),count=document.querySelector('#count');function update(){let n=0;for(const card of cards){card.hidden=!card.dataset.name.includes(input.value.trim().toLowerCase());if(!card.hidden)n++}count.textContent=` ${n} / ${cards.length}`};input.addEventListener('input',update);update();
</script></html>'''
    target = args.output / 'index.html'
    target.write_text(page)
    print(target)


if __name__ == '__main__':
    main()
