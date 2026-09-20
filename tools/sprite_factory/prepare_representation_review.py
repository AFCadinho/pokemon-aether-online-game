"""Index existing probe files for a standalone moving Godot comparison."""
import argparse
import json
import math
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('packaged_catalog', type=Path)
parser.add_argument('compact_root', type=Path)
parser.add_argument('glb_report', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
catalog = json.loads(args.packaged_catalog.read_text())
entries = []
for exported in json.loads(args.glb_report.read_text()):
    species = exported['species']
    path = Path(catalog['entries'][species + ':normal']['path'])
    manifest = json.loads(path.read_text())
    sprites = {}
    for view, actions in manifest['views'].items():
        sprites[view] = {}
        for action, spec in actions.items():
            profiles = {}
            for label, size in (('512-q95', 512), ('512-q70', 512), ('256-q75', 256)):
                x, y, w, h = spec['stored_cell_rect']
                if label != '512-q95':
                    bx, by, bw, bh = spec['visual_bounds']
                    ratio = size / 512
                    x, y = max(0, math.floor(bx * ratio)-4), max(0, math.floor(by * ratio)-4)
                    w = min(size, math.ceil((bx+bw)*ratio)+4) - x
                    h = min(size, math.ceil((by+bh)*ratio)+4) - y
                pages = []
                for i, page in enumerate(spec['pages']):
                    image = path.parent / page['file'] if label == '512-q95' else args.compact_root / species / label / view / f'{action}-{i:03d}.webp'
                    if not image.is_file():
                        raise ValueError(str(image))
                    pages.append(dict(file=str(image.resolve()), columns=page['columns'], count=page['count']))
                profiles[label] = dict(pages=pages, rect=[x, y, w, h], size=size,
                    loop=spec['loop'], count=spec['count'], speed=spec['speed'])
            sprites[view][action] = profiles
    entries.append(dict(model=exported, sprites=sprites))
with args.output.open('x') as target:
    json.dump(entries, target, indent=2)
