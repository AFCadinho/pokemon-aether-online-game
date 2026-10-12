"""Pack the approved Nimbus artwork; no generated rider or resculpted artwork.

Nearest-neighbour sampling matches the reviewed 64px Godot design. --check
verifies checked-in atlases and seats without writing. Requires Pillow.
"""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/mounts/flying_nimbus'
DIRECTIONS = ('down', 'left', 'right', 'up')
SEATS = ((32, 38), (29, 39), (35, 33), (32, 36))
CUTOFFS = (44, 44, 38, 42)


def build():
    source = Image.open(FOLDER / 'source.png').convert('RGBA')
    assert source.size == (1254, 1254)
    layers = {key: Image.new('RGBA', (768, 768)) for key in ('mount', 'foreground', 'rider_mask')}
    offsets = {}
    for row, direction in enumerate(DIRECTIONS):
        x, y = row % 2 * 627, row // 2 * 627
        cloud = source.crop((x, y, x + 627, y + 627)).resize((64, 64), Image.Resampling.NEAREST)
        # Remove near-invisible generated alpha halos before rider masking;
        # native pixel-art layers require a binary silhouette.
        cloud.putalpha(cloud.getchannel("A").point(lambda alpha: 255 if alpha >= 128 else 0))
        origin = (64, 55 + (6 if row >= 2 else 0))
        front = cloud.copy()
        front.paste((0, 0, 0, 0), (0, 0, 64, CUTOFFS[row]))
        mask = Image.new('RGBA', (64, 64))
        mask.putalpha(front.getchannel('A'))
        seat = SEATS[row]
        offsets[direction] = [[origin[0] + seat[0] - 96, origin[1] + seat[1] - 117] for _ in range(4)]
        for col in range(4):
            for key, art in (('mount', cloud), ('foreground', front), ('rider_mask', mask)):
                layers[key].paste(art, (col * 192 + origin[0], row * 192 + origin[1]))
    for key in tuple(layers):
        layers['idle_' + key] = layers[key].crop((0, 0, 192, 768))
    front = layers['mount'].crop((0, 0, 192, 192))
    front = front.crop(front.getbbox())
    icon = Image.new('RGBA', (front.width + 4, front.height + 4))
    icon.paste(front, (2, 2))
    layers['icon'] = icon
    return layers, offsets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    layers, offsets = build()
    catalog = json.loads((ROOT / 'data/mounts.json').read_text())
    assert catalog['mounts']['flying_nimbus']['riderOffsets'] == offsets
    for name, art in layers.items():
        target = FOLDER / (name + '.png')
        if args.check:
            actual = Image.open(target).convert('RGBA')
            assert actual.size == art.size and actual.tobytes() == art.tobytes(), name
        else:
            art.save(target)
    print('Flying Nimbus artwork and seats: PASS')


if __name__ == '__main__':
    main()
