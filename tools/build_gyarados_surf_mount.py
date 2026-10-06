"""Rebuild the approved Gyarados V4 Surf layers without changing the design.

--check verifies generated pixels, approved V4 hashes and catalog seats.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from build_surf_five_mounts import immerse, contact

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT/'assets/mounts/gyarados'
FRAME = 192
DIRECTIONS = ('down', 'left', 'right', 'up')


def build():
    config = json.loads((FOLDER/'design.json').read_text())
    source = Image.open(FOLDER/'source.png').convert('RGBA')
    layers = {name: Image.new('RGBA', (FRAME*4, FRAME*4))
              for name in ('mount', 'foreground', 'rider_mask')}
    water = Image.new('RGBA', (FRAME*4, FRAME*8))
    offsets = {}
    for row, direction in enumerate(DIRECTIONS):
        offsets[direction] = []
        for col in range(4):
            art = source.crop((col*64, row*64, (col+1)*64, (row+1)*64))
            dx, dy = config['phaseShifts'][row][col]
            selection = Image.new('L', (64, 64))
            draw = ImageDraw.Draw(selection)
            for part in ('foreground', 'near'):
                polygon = [(64-x, y) for x,y in config[part][1]] if row == 2 else config[part][row]
                if polygon:
                    draw.polygon([(x+dx, y+dy) for x,y in polygon], fill=255)
            selected = Image.new('RGBA', art.size)
            selected.paste(art, (0,0), selection)
            wet = immerse(art, config['waterline'][row]+dy, 60-config['waterline'][row])
            front = Image.new('RGBA', art.size)
            front.paste(wet, (0,0), selection)
            back = wet.copy()
            back.putalpha(ImageChops.subtract(wet.getchannel('A'), selected.getchannel('A')))
            mask = Image.new('RGBA', art.size)
            mask.putalpha(selected.getchannel('A'))
            for name, tile in [('mount',back), ('foreground',front), ('rider_mask',mask)]:
                layers[name].alpha_composite(tile, (col*FRAME+64, row*FRAME+64))
            for moving in (False, True):
                water.alpha_composite(contact(art, (64,64), row, col, config['waterline'][row]+dy, moving),
                                      (col*FRAME, (row+4*int(moving))*FRAME))
            sx, sy = config['seats'][row]
            offsets[direction].append([sx+dx-32, sy+dy-52])
    for name in tuple(layers):
        layers['idle_'+name] = layers[name].crop((0,0,FRAME,FRAME*4))
    layers['water_contact'] = water
    icon = source.crop((0,0,64,64))
    layers['icon'] = icon.crop(icon.getbbox())
    for name, expected in config['approvedPixelHashes'].items():
        assert hashlib.sha256(layers[name].tobytes()).hexdigest() == expected, name+' changed from approved V4'
    definition = json.loads((ROOT/'data/mounts.json').read_text())['mounts']['gyarados']
    assert definition['riderOffsets'] == offsets, 'Catalog differs from V4 seats'
    return layers


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for name, image in build().items():
        path = FOLDER/(name+'.png')
        if args.check:
            stored = Image.open(path).convert('RGBA')
            assert stored.size == image.size and stored.tobytes() == image.tobytes(), str(path)+' differs'
        else:
            image.save(path)
    print('Gyarados V4 pixels and catalog seats verified' if args.check else 'Gyarados V4 built')
