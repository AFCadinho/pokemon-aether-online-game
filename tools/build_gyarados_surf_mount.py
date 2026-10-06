"""Rebuild normal and shiny Gyarados using the approved V4 Surf geometry.

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


def build(shiny=False):
    config = json.loads((FOLDER/'design.json').read_text())
    folder = FOLDER.with_name('gyarados_shiny') if shiny else FOLDER
    source = Image.open(folder/'source.png').convert('RGBA')
    if shiny:
        normal = Image.open(FOLDER/'source.png').convert('RGBA')
        assert source.size == normal.size
        assert source.getchannel('A').tobytes() == normal.getchannel('A').tobytes(), 'Shiny silhouette differs from V4'
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
        if not shiny or name in ('rider_mask', 'idle_rider_mask', 'water_contact'):
            assert hashlib.sha256(layers[name].tobytes()).hexdigest() == expected, name+' changed from approved V4'
        else:
            normal = Image.open(FOLDER/(name+'.png')).convert('RGBA')
            assert layers[name].getchannel('A').tobytes() == normal.getchannel('A').tobytes(), name+' shiny geometry changed'
    definitions = json.loads((ROOT/'data/mounts.json').read_text())['mounts']
    definition = definitions['gyarados_shiny' if shiny else 'gyarados']
    assert definition['riderOffsets'] == offsets, 'Catalog differs from V4 seats'
    if shiny:
        expected = definitions['gyarados'].copy()
        for key in ('iconTexture', 'spriteSheet', 'foregroundSheet', 'idleSpriteSheet', 'idleForegroundSheet'):
            expected[key] = expected[key].replace('/gyarados/', '/gyarados_shiny/')
        expected.update(displayName='Shiny Gyarados', unlockItemId='shiny-gyarados-mount')
        assert definition == expected, 'Shiny must share V4 alignment, masks and water'
        for name in ('rider_mask', 'idle_rider_mask', 'water_contact'):
            del layers[name]  # Runtime shares these unchanged normal layers.
    return layers


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    for shiny in (False, True):
        folder = FOLDER.with_name('gyarados_shiny') if shiny else FOLDER
        for name, image in build(shiny).items():
            path = folder/(name+'.png')
            if args.check:
                stored = Image.open(path).convert('RGBA')
                assert stored.size == image.size and stored.tobytes() == image.tobytes(), str(path)+' differs'
            else:
                image.save(path)
    print('Normal/shiny Gyarados V4 pixels and catalog seats verified' if args.check else 'Normal/shiny Gyarados V4 built')
