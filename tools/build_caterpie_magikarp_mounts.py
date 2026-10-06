"""Rebuild approved V2 Caterpie/Magikarp layers at native pixel scale.

--check verifies reproducible artwork and reviewed catalog seats without writes.
World alignment moves the entire rig: Caterpie +16px to the grounded foot line,
Magikarp +8px to Lapras's waterline. Relative approved rider geometry is retained.
"""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ('down', 'left', 'right', 'up')
FRAME = 192


def caterpie_source(original):
    result = original.copy()
    # Approved rear V2: head farther ahead of the rider, native back extended
    # beneath the rider. Front/side pixels stay exactly as supplied.
    for col, dy in enumerate((0, 2, 2, 4)):
        art = original.crop((col*64, 192, (col+1)*64, 256))
        selection = Image.new('L', (64, 64))
        ImageDraw.Draw(selection).rectangle((0, 0, 63, 47+dy), fill=255)
        head = Image.new('RGBA', (64, 64))
        head.paste(art, (0, 0), selection)
        art.paste((0, 0, 0, 0), (0, 0, 64, 64), selection)
        bridge = original.crop((col*64+28, 192+46+dy, col*64+36, 192+50+dy))
        for y in range(24+dy, 48+dy, 2):
            art.alpha_composite(bridge, (28, y))
        shifted = Image.new('RGBA', (64, 64))
        shifted.alpha_composite(head, (0, -22))
        assert sum(shifted.getchannel('A').histogram()[1:]) == sum(head.getchannel('A').histogram()[1:])
        art.alpha_composite(shifted)
        result.paste(art, (col*64, 192))
    assert result.crop((0, 0, 256, 192)).tobytes() == original.crop((0, 0, 256, 192)).tobytes()
    return result


def build(mount_id):
    folder = ROOT/'assets/mounts'/mount_id
    config = json.loads((folder/'design.json').read_text())
    source = (caterpie_source(Image.open(folder/'follower_original.png').convert('RGBA'))
              if mount_id == 'caterpie' else Image.open(folder/'source.png').convert('RGBA'))
    assert source.size == (256, 256)
    layers = {key: Image.new('RGBA', (768, 768)) for key in ('mount', 'foreground', 'rider_mask')}
    offsets = {}
    for row, direction in enumerate(DIRECTIONS):
        base = (64, 112-config['anchor'][row]+config['worldOffsetY'])
        offsets[direction] = []
        for col in range(4):
            art = source.crop((col*64, row*64, (col+1)*64, (row+1)*64))
            dx, dy = config['frameShifts'][direction][col]
            selection = Image.new('L', art.size)
            draw = ImageDraw.Draw(selection)
            for key in ('foreground', 'near'):
                polygon = config[key][1 if row == 2 else row]
                if row == 2:
                    polygon = [(64-x, y) for x, y in polygon]
                if polygon:
                    draw.polygon([(x+dx, y+dy) for x, y in polygon], fill=255)
            selected = Image.new('RGBA', art.size)
            selected.paste(art, (0, 0), selection)
            mount = Image.new('RGBA', (FRAME, FRAME))
            mount.alpha_composite(art, base)
            assert sum(mount.getchannel('A').histogram()[1:]) == sum(art.getchannel('A').histogram()[1:])
            front = Image.new('RGBA', mount.size)
            front.alpha_composite(selected, base)
            mask = Image.new('RGBA', mount.size)
            mask.putalpha(front.getchannel('A'))
            for name, tile in [('mount', mount), ('foreground', front), ('rider_mask', mask)]:
                layers[name].alpha_composite(tile, (col*FRAME, row*FRAME))
            sx, sy = config['seats'][row]
            offsets[direction].append([base[0]+sx+dx-32-64, base[1]+sy+dy-52-64])
    for name in tuple(layers):
        layers['idle_'+name] = layers[name].crop((0, 0, FRAME, FRAME*4))
    art = layers['mount'].crop((0, 0, FRAME, FRAME))
    art = art.crop(art.getbbox())
    icon = Image.new('RGBA', (art.width+4, art.height+4))
    icon.alpha_composite(art, (2, 2))
    layers['icon'] = icon
    layers['source'] = source
    return folder, layers, offsets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    catalog = json.loads((ROOT/'data/mounts.json').read_text())['mounts']
    for mount_id in ('caterpie', 'magikarp'):
        folder, layers, offsets = build(mount_id)
        assert catalog[mount_id]['riderOffsets'] == offsets, f'{mount_id}: review seat offsets'
        for name, art in layers.items():
            path = folder/(name+'.png')
            if args.check:
                stored = Image.open(path).convert('RGBA')
                assert stored.size == art.size and stored.tobytes() == art.tobytes(), f'{path}: differs'
            else:
                art.save(path)
        print(mount_id, 'verified' if args.check else 'built')


if __name__ == '__main__':
    main()
