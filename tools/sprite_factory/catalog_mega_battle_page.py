"""Build a joint Mega visual review without granting motion/runtime approval."""
import argparse
import json
from pathlib import Path

from catalog_battle_forms_next_seven_review import build
from catalog_mega_3d_production import sha


def page(report, catalog, output, expected_pairs=71):
    data = json.loads(report.read_text())
    rows = [r for r in data['entries'] if 'shots' in r]
    if expected_pairs < 1 or not data.get('complete') or len(rows) != expected_pairs * 2:
        raise ValueError(f'All {expected_pairs} normal/shiny visual capture pairs required')
    names = {r['species'] for r in rows}
    normal = {n for n in names if not n.endswith('-shiny')}
    if len(names) != len(rows) or len(normal) != expected_pairs or names != normal | {n + '-shiny' for n in normal}:
        raise ValueError('Unique complete normal/shiny capture pairs required')
    framing = [(r['species'], s['action'], s['arena_camera'], s['side'])
               for r in rows for s in r['shots']
               if not s['in_view'] or s['model_overlaps_hud_proxy']]
    outside = [(r['species'], shot['action'], shot['arena_camera'], shot['side'])
               for r in rows for shot in r['shots'] if not shot['in_view']]
    if outside:
        raise ValueError('Resolve off-screen captures before visual review: ' + str(outside))
    build(report, output, catalog)
    target = output / 'index.html'
    content = target.read_text().replace('Battle-vormen — battlecontrole', f'{expected_pairs} Mega-paren — battlecontrole')
    if not any(s['action'] == 'physical_attack_2' for r in rows for s in r['shots']):
        content = content.replace('<option value="physical_attack_2">Tweede fysieke aanval</option>', '')
    content = content.replace('</header>', '<p>De uitgebreide technische controle loopt apart. '
        'Deze pagina beoordeelt grootte en poses; er zijn nog geen modellen toegelaten of geüpload. '
        'Niet iedere Mega heeft een tweede fysieke aanval.</p></header>')
    intake = json.loads(Path(__file__).with_name('catalog_mega_3d_source_intake.json').read_text())
    for row in intake['entries']:
        old = row['showdown_id'].replace('-', ' ').title()
        new = row['name'].replace('-', ' ').title()
        content = content.replace('<h2>' + old + '</h2>', '<h2>' + new + '</h2>')
    # HUD conflicts remain technical holds; showing them is review evidence,
    # never a change to the independent qualification thresholds.
    for species in sorted({item[0].removesuffix('-shiny') for item in framing}):
        marker = '<article data-name="' + species + '">'
        note = ('<p class="note">Aandachtspunt: de speciale aanval raakt in de klassieke '
                'camera de gereserveerde ruimte voor de HP-balk. De eerder goedgekeurde '
                'grootte is behouden; dit blijft technisch geblokkeerd.</p>')
        content = content.replace(marker, marker + note)
    target.write_text(content)
    manifest = output / 'manifest.json'; receipt = json.loads(manifest.read_text())
    receipt.update(battle_visual_approved=False, independent_motion_validation_pending=True,
                    captured_framing_holds=framing)
    receipt['files']['index.html'] = sha(target)
    manifest.write_text(json.dumps(receipt, indent=2) + '\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('report', 'catalog', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    p.add_argument('--expected-pairs', type=int, default=71)
    a = p.parse_args(); page(a.report.resolve(), a.catalog.resolve(), a.output.resolve(), a.expected_pairs)
