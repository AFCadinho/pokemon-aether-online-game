"""Static diagnostic gallery of source renders, including explicit missing rows."""
import argparse
import html
import json
from pathlib import Path

from PIL import Image, ImageDraw

POSES = [('idle', 'front'), ('idle', 'back'),
         ('physical_attack', 'front'), ('physical_attack_2', 'front'),
         ('special_attack', 'front'),
         ('sleep', 'front'), ('faint_start', 'front')]


def build(output):
    catalog = json.loads((output / 'catalog.json').read_text())
    rows = []
    sheets = []
    motion_previews = []
    for index, entry in enumerate(catalog['entries']):
        if index % 5 == 0:
            sheet = Image.new('RGB', ((len(POSES) + 1) * 200, 1160), '#101822')
            sheets.append(sheet)
        draw = ImageDraw.Draw(sheet)
        y = (index % 5) * 230 + 10
        draw.text((10, y), entry['species'], fill='white')
        label = 'EXPERIMENTAL PROBE' if catalog.get('material_probe') else 'SOURCE ONLY'
        draw.text((10, y + 22), label + '\nNot battle approved', fill='#ffd27b')
        row = '<tr><th>' + html.escape(entry['species']) + '<br>' + label + '</th>'
        report = json.loads(Path(entry['report']).read_text()) if entry.get('report') else {}
        if report.get('ambient_frames'):
            frames = []
            for frame in report['ambient_frames']:
                with Image.open(output / 'review' / entry['species'] / frame['image']) as im:
                    frames.append(im.convert('RGB'))
            relative = Path('review') / entry['species'] / 'ambient.webp'
            duration = report['ambient_material_probe']['duration_seconds']
            frames[0].save(output / relative, format='WEBP', save_all=True,
                           append_images=frames[1:], lossless=True, loop=0,
                           duration=round(duration * 1000 / len(frames)))
            motion_previews.append('<h2>' + html.escape(entry['species']) +
                ' — auxiliary material loop</h2><p>Skeleton frozen. Experimental shader, not runtime approved.</p>' +
                '<img width="320" src="' + relative.as_posix() + '">')
        if report:
            dimensions = [round(b - a, 3) for a, b in zip(*report['review_bounds'])]
            draw.text((10, y + 65), 'XYZ units\n' + '\n'.join(map(str, dimensions)), fill='white')
        for column, (action, view) in enumerate(POSES):
            x = (column + 1) * 200
            pose = next((p for p in report.get('poses', []) if p['category'] == action
                         and p['view'] == view and not p.get('sample')), {})
            draw.text((x, y), action + ' / ' + view, fill='white')
            if pose.get('image'):
                relative = Path('review') / entry['species'] / pose['image']
                with Image.open(output / relative) as image:
                    sheet.paste(image.convert('RGB').resize((196, 196)), (x, y + 20))
                row += '<td><a href="' + relative.as_posix() + '"><img width="240" src="' + relative.as_posix() + '"></a><br>' + html.escape(action + ' / ' + view) + '</td>'
            else:
                draw.text((x + 4, y + 60), 'BLOCKED / MISSING', fill='#ff9a9a')
                row += '<td>' + html.escape(entry.get('error', 'Missing or ambiguous pose')) + '</td>'
        rows.append(row + '</tr>')
    for index, sheet in enumerate(sheets):
        sheet.save(output / f'contact-{index + 1}.png')
    (output / 'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Phase 5 source review</title>'
        '<style>body{background:#101822;color:#eee;font:16px sans-serif}td,th{padding:8px;border:1px solid #456}a{color:#8df}</style>'
        '<h1>Phase 5 — source-only review</h1>' +
        ('<p>EXPERIMENTAL MATERIAL PROBE. Not original source shading. Displacement, UV motion and shader parity remain unapproved.</p>'
         if catalog.get('material_probe') else '') + '<p>Normal variants. Auto-fit cameras; images do not show relative battle scale. '
        'Original coordinates preserved. No grounding correction. Source materials, not Godot material conversion. '
        'No model is approved by this report.</p>' + ''.join(motion_previews) + '<table>' + ''.join(rows) + '</table>')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    build(parser.parse_args().output)
