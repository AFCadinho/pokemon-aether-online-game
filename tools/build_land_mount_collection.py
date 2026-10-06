"""Rebuild the five land mounts from their checked-in native source sheets.

Run with --check to compare the generated artwork and seat offsets without writes.
Requires Pillow. Design JSON records seats, foreground masks and head cutouts.
"""
from pathlib import Path
import argparse
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
IDS = ('giratina_origin', 'ho_oh', 'yveltal', 'miraidon', 'reshiram')
DIRECTIONS = ('down', 'left', 'right', 'up')
FRAME = 192


def build(mount_id):
    folder = ROOT / 'assets/mounts' / mount_id
    design = json.loads((folder / 'design.json').read_text())
    sheet = Image.open(folder / 'source.png').convert('RGBA')
    width, height = sheet.width // 4, sheet.height // 4
    layers = {name: Image.new('RGBA', (768, 768)) for name in ('mount', 'foreground', 'rider_mask')}
    offsets = {}
    for row, direction in enumerate(DIRECTIONS):
        arts = []
        for col in range(4):
            art = sheet.crop((col*width, row*height, (col+1)*width, (row+1)*height))
            if 'headRepose' in design:
                # Move only the anatomical head. A full-width strip also moves
                # wing/arm tips and overwrites the original torso underneath.
                spec = design['headRepose'][row]
                dx, dy = design['frameShifts'][direction][col]
                selection = Image.new('L', art.size)
                ImageDraw.Draw(selection).polygon(
                    [(x+dx, y+dy) for x,y in spec['polygon']], fill=255)
                head = Image.new('RGBA', art.size)
                head.paste(art, (0,0), selection)
                art.paste((0,0,0,0), (0,0,width,height), selection)
                art.alpha_composite(head, tuple(spec['offset']))
            arts.append(art)
        base_x, base_y = 96-width//2, 112-arts[0].getbbox()[3]
        offsets[direction] = []
        for col, art in enumerate(arts):
            dx,dy = design['frameShifts'][direction][col]
            sx,sy = design['seats'][row]
            offsets[direction].append([base_x+sx+dx-32-64, base_y+sy+dy-52-64])
            selection = Image.new('L',art.size)
            draw = ImageDraw.Draw(selection)
            for key in ('head','near'):
                polygon = design[key][1 if row == 2 else row]
                if row == 2: polygon = [(width-x,y) for x,y in polygon]
                if polygon: draw.polygon([(x+dx,y+dy) for x,y in polygon],fill=255)
            selected = Image.new('RGBA',art.size)
            selected.paste(art,(0,0),selection)
            mount = Image.new('RGBA',(FRAME,FRAME));mount.alpha_composite(art,(base_x,base_y))
            foreground = Image.new('RGBA',(FRAME,FRAME));foreground.alpha_composite(selected,(base_x,base_y))
            mask = Image.new('RGBA',(FRAME,FRAME));mask.putalpha(foreground.getchannel('A'))
            for name,tile in (('mount',mount),('foreground',foreground),('rider_mask',mask)):
                layers[name].alpha_composite(tile,(col*FRAME,row*FRAME))
    for name in tuple(layers):
        layers['idle_'+name] = layers[name].crop((0,0,FRAME,FRAME*4))
    front = layers['mount'].crop((0,0,FRAME,FRAME))
    front = front.crop(front.getbbox())
    icon = Image.new('RGBA',(front.width+4,front.height+4));icon.alpha_composite(front,(2,2))
    layers['icon'] = icon
    return folder,layers,offsets


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args = parser.parse_args()
    catalog_path = ROOT/'data/mounts.json'
    catalog = json.loads(catalog_path.read_text())
    for mount_id in IDS:
        folder,layers,offsets = build(mount_id)
        # Catalog seats are reviewed alongside the pixel art, never silently changed.
        assert catalog['mounts'][mount_id]['riderOffsets'] == offsets, f'{mount_id}: review catalog seat offsets'
        for name,image in layers.items():
            path = folder/(name+'.png')
            if args.check:
                current = Image.open(path).convert('RGBA')
                assert current.size == image.size and current.tobytes() == image.tobytes(), f'{path}: differs from source'
            else:
                image.save(path)
        print(mount_id, 'verified' if args.check else 'built')


if __name__ == '__main__':
    main()
