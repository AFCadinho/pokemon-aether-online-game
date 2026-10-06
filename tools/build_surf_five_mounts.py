"""Build five approved native follower rigs with synchronized water contact."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
FRAME = 192
# Lapras and ordinary follower NPCs end 12px below their physical origin:
# native bottom 60 - half cell 32 - Look offset 16. Move the entire rig.
WORLD_WATERLINE_Y = 12
DIRECTIONS = ('down', 'left', 'right', 'up')
CONFIG = json.loads((ROOT/'tools/surf_five_designs.json').read_text())


def count(image):
    return sum(image.getchannel('A').histogram()[1:])


def immerse(art, water_y, depth):
    wet = art.copy()
    for y in range(art.height):
        fraction = min(1, max(0, (y-water_y+1)/depth))
        if not fraction:
            continue
        for x in range(art.width):
            r, g, b, a = art.getpixel((x, y))
            if not a:
                continue
            mix = .40*fraction
            wet.putpixel((x, y), (round(r*(1-mix)+34*mix), round(g*(1-mix)+104*mix),
                                  round(b*(1-mix)+127*mix), round(a*(1-.68*fraction))))
    return wet


def contact(art, base, row, phase, water_y, moving):
    out = Image.new('RGBA', (FRAME, FRAME))
    draw = ImageDraw.Draw(out)
    left, top, right, bottom = art.getbbox()
    # Broken foam touches the actual lower silhouette, including near flippers.
    # No ground shadow, detached ellipse or independently moving water plane.
    for x in range(left, right):
        ys = [y for y in range(max(0, water_y), bottom) if art.getpixel((x, y))[3]]
        if not ys or (x//3+phase)%4 >= 2:
            continue
        y = max(ys)
        draw.point((base[0]+x, base[1]+y), fill=(173,220,223,185))
        if x%2 == 0:
            draw.point((base[0]+x, base[1]+y+1), fill=(93,166,187,125))
    if moving:
        center_x = base[0]+(left+right)//2
        center_y = base[1]+(top+bottom)//2
        for trail in range(2):
            age = (phase/4+trail/2)%1
            distance = 3+round(age*10)
            spread = 6+round(age*7)
            length = 4+round(age*4)
            color = (129,202,215,round((1-age)*150))
            if row in (0, 3):
                # A follower's top can be a spout or raised head, not water.
                # Keep the rear wake beside the hull at its immersion band.
                y = base[1]+(water_y-distance if row==0 else bottom+distance)
                if row == 0:
                    spread = (right-left)//2+distance
                for sign in (-1, 1):
                    x = center_x+sign*spread
                    draw.line((x-length//2,y,x+length//2,y), fill=color)
            else:
                x = base[0]+(right+distance if row==1 else left-distance)
                for sign in (-1, 1):
                    y = center_y+sign*spread
                    draw.line((x,y-length//2,x,y+length//2), fill=color)
    return out


def definition(mid, cfg):
    folder = f'res://assets/mounts/{mid}'
    return dict(displayName=cfg['name'], movementMode='surf',
                unlockItemId=mid+'-mount', iconTexture=folder+'/icon.png',
                spriteSheet=folder+'/mount.png', foregroundSheet=folder+'/foreground.png',
                riderMaskSheet=folder+'/rider_mask.png', waterContactSheet=folder+'/water_contact.png',
                frameSize=[FRAME, FRAME], movementAnimationSpeed=4.0,
                riderOffsets={direction: [[x, y+WORLD_WATERLINE_Y] for x,y in offsets]
                              for direction,offsets in cfg['riderOffsets'].items()},
                surfFishingFullForeground=False,
                surfFishingRiderOffsets={'down':[0,18], 'left':[0,4], 'right':[0,4], 'up':[0,10]})


def build(update_catalog=False):
    definitions = {}
    for mid, cfg in CONFIG.items():
        folder = ROOT/'assets/mounts'/mid
        source = Image.open(folder/'source.png').convert('RGBA')
        size = source.width//4
        assert source.size == (size*4, size*4)
        sheets = {name: Image.new('RGBA', (FRAME*4, FRAME*4)) for name in ('mount','foreground','rider_mask')}
        water = Image.new('RGBA', (FRAME*4, FRAME*8))
        for row in range(4):
            for col in range(4):
                art = source.crop((col*size,row*size,(col+1)*size,(row+1)*size))
                dx, dy = cfg['phaseShifts'][row][col]
                base = ((FRAME-size)//2, 112+WORLD_WATERLINE_Y-cfg['anchor'][row])
                selection = Image.new('L', (size, size))
                draw = ImageDraw.Draw(selection)
                for part in ('foreground', 'near'):
                    polygon = [(size-x,y) for x,y in cfg[part][1]] if row==2 else cfg[part][row]
                    if polygon:
                        draw.polygon([(x+dx,y+dy) for x,y in polygon], fill=255)
                dry_foreground = Image.new('RGBA', art.size)
                dry_foreground.paste(art, (0,0), selection)
                mask = Image.new('RGBA', art.size)
                mask.putalpha(dry_foreground.getchannel('A'))
                water_y = cfg['anchor'][row]-cfg['immersionDepth']+dy
                wet = immerse(art, water_y, cfg['immersionDepth'])
                foreground = immerse(dry_foreground, water_y, cfg['immersionDepth'])
                wet.putalpha(ImageChops.subtract(wet.getchannel('A'), dry_foreground.getchannel('A')))
                for name, layer in [('mount',wet), ('foreground',foreground), ('rider_mask',mask)]:
                    cell = Image.new('RGBA', (FRAME, FRAME))
                    cell.alpha_composite(layer, base)
                    assert count(cell) == count(layer), (mid,row,col,'clipping')
                    sheets[name].alpha_composite(cell, (col*FRAME,row*FRAME))
                for moving in (False, True):
                    water.alpha_composite(contact(art,base,row,col,water_y,moving),
                                          (col*FRAME,(row+4*int(moving))*FRAME))
        for name, sheet in sheets.items():
            sheet.save(folder/(name+'.png'))
        water.save(folder/'water_contact.png')
        icon = source.crop((0,0,size,size))
        icon.crop(icon.getbbox()).save(folder/'icon.png')
        for name in ('source','mount','foreground','rider_mask','water_contact','icon'):
            write_texture_import(ROOT, (folder/(name+'.png')).relative_to(ROOT))
        definitions[mid] = definition(mid, cfg)
        print(mid, 'native rig and water layers built')
    path = ROOT/'data/mounts.json'
    catalog = json.loads(path.read_text())
    if update_catalog:
        # Keep all existing catalog formatting and records intact.
        text = path.read_text()
        end = text.rfind('\n  }')
        assert end >= 0 and not any(mid in catalog['mounts'] for mid in CONFIG)
        entries = ',\n'+',\n'.join('    '+json.dumps(mid)+': '+json.dumps(value,indent=2).replace('\n','\n    ') for mid,value in definitions.items())
        path.write_text(text[:end]+entries+text[end:])
        catalog = json.loads(path.read_text())
    for mid, expected in definitions.items():
        assert catalog['mounts'][mid] == expected, mid+' catalog differs from generator'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--add-catalog', action='store_true')
    build(parser.parse_args().add_catalog)
