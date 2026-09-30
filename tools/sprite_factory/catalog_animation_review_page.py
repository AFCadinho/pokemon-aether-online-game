"""Build one appearance-review page from exact standalone scene capture hashes."""

import argparse
import html
import json
from pathlib import Path

from catalog_remaining_review_page import thumbnail


POSES = [('idle', 'Stilstand'), ('physical_attack', 'Fysieke aanval'),
         ('physical_attack_2', 'Tweede fysieke aanval'),
         ('special_attack', 'Speciale aanval'), ('sleep', 'Slaap'),
         ('faint_start', 'Flauw')]


def build(stage, captures, output):
    expected = {row['species']: row for row in stage}
    if len(expected) != len(stage):
        raise ValueError('Duplicate standalone model identity')
    matched = {}
    for directory in captures:
        report = json.loads((directory / 'review.json').read_text())
        if report.get('capture_profile') != 'quick_pair':
            raise ValueError('Expected a quick motion capture profile')
        for row in report['entries']:
            name = row['species']
            if name not in expected or row['runtime_sha256'] != expected[name]['runtime_sha256']:
                continue
            if name in matched or row['errors']:
                raise ValueError('Duplicate or failed matching capture: ' + name)
            matched[name] = (directory, row)
    if set(matched) != set(expected):
        raise ValueError('Missing exact scene captures: ' + repr(set(expected) - set(matched)))
    output.mkdir(parents=True, exist_ok=True)
    media = output / 'media'
    media.mkdir(exist_ok=True)
    cards = []
    for name in sorted(n for n in expected if '@' not in n):
        columns = []
        for identity, label in [(name, 'Normal'), (name + '@shiny', 'Shiny')]:
            if identity not in expected:
                columns.append('<section><h3>Shiny</h3><p class="pending">Nog in onderzoek</p></section>')
                continue
            directory, record = matched[identity]
            by_action = {c['action']: c for c in record['captures']}
            if not {p[0] for p in POSES if p[0] != 'physical_attack_2'} <= by_action.keys():
                raise ValueError('Incomplete motion captures: ' + identity)
            images = []
            for action, title in POSES:
                actual = action if action in by_action else 'physical_attack'
                capture = by_action[actual]
                destination = media / (Path(capture['image']).stem + '.webp')
                thumbnail(directory / capture['image'], destination)
                images.append(f'<img data-pose="{action}" src="media/{html.escape(destination.name, quote=True)}" '
                              f'alt="{html.escape(identity + " " + title, quote=True)}" loading="lazy" '
                              + ('' if action == 'idle' else 'hidden ') + '>')
            note = '' if 'physical_attack_2' in by_action else '<p class="note">Geen aparte tweede aanval in deze bron.</p>'
            columns.append('<section><h3>' + label + '</h3>' + ''.join(images) + note + '</section>')
        title = html.escape(name.replace('-', ' ').title())
        cards.append(f'<article data-name="{html.escape(name, quote=True)}"><h2>{title}</h2>'
                     '<div class="pair">' + ''.join(columns) + '</div></article>')
    pairs = sum(n + '@shiny' in expected for n in expected if '@' not in n)
    page = '''<!doctype html><html lang="nl"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Animatieherstel — uiterlijkreview</title><style>
body{margin:0;background:#111b25;color:#eef3f8;font:16px system-ui}header{position:sticky;top:0;background:#172737;padding:16px;z-index:2}h1{font-size:1.3rem;margin:0 0 6px}header p{margin:6px 0}main{padding:16px;display:grid;grid-template-columns:repeat(auto-fit,minmax(430px,1fr));gap:14px}article{border:1px solid #435b6f;border-radius:10px;padding:14px;background:#1c2b37}h2{font-size:19px;margin:0 0 10px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px}h3{text-align:center;margin:5px}img{width:100%;background:#1f1f1f}img[hidden],article[hidden]{display:none}select,input,button{font:inherit;padding:8px;margin:4px;border-radius:6px}.pending,.note{color:#cad4df;font-size:.85rem}.pending{padding:60px 10px;text-align:center}body.large main{grid-template-columns:1fr}
</style><header><h1>''' + str(len(cards)) + ' herstelde normale modellen — ' + str(pairs) + ''' shiny-paren</h1>
<p>Controleer ogen, kleuren, onderdelen en poses. Battle-grootte en plaatsing volgen apart. Ontbrekende shiny-versies worden verder onderzocht.</p>
<select id="pose">''' + ''.join(f'<option value="{key}">{label}</option>' for key, label in POSES) + '''</select>
<input id="search" type="search" placeholder="Zoek Pokémon"><button id="large">Groot bekijken</button><span id="count"></span>
</header><main>''' + ''.join(cards) + '''</main><script>
document.querySelector('#pose').onchange=e=>document.querySelectorAll('img[data-pose]').forEach(im=>im.hidden=im.dataset.pose!==e.target.value);
const cards=[...document.querySelectorAll('article')];const search=document.querySelector('#search');function filter(){let n=0;for(const c of cards){c.hidden=!c.dataset.name.includes(search.value.trim().toLowerCase());if(!c.hidden)n++}document.querySelector('#count').textContent=`${n} / ${cards.length} Pokémon`};search.oninput=filter;filter();document.querySelector('#large').onclick=()=>document.body.classList.toggle('large');
</script></html>'''
    (output / 'index.html').write_text(page)
    return {'normal_count': len(cards), 'shiny_pair_count': pairs,
            'scene_count': len(expected), 'runtime_approved': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--captures', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = build(json.loads(args.stage.read_text()), args.captures, args.output)
    print(json.dumps(result))


if __name__ == '__main__':
    main()
