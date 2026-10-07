"""Build five approved native follower rigs with synchronized water contact."""
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from import_player_layered_sprites import write_texture_import
from build_surf_mount_idles import with_surf_idle

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


def shiny_source(base_id):
    normal = Image.open(ROOT/'assets/mounts'/base_id/'source.png').convert('RGBA')
    original = Image.open(ROOT/'assets/followers'/(base_id.upper()+'.png')).convert('RGBA')
    shiny = Image.open(ROOT/'assets/followers_shiny'/(base_id.upper()+'.png')).convert('RGBA')
    assert original.size == shiny.size == normal.size
    if base_id == 'drednaw':
        # Apply the approved rear reposing to the original shiny as well. This
        # preserves region-specific shell/horn colours in its shiny palette.
        result = shiny.copy()
        for col in range(4):
            art = shiny.crop((col*64,192,(col+1)*64,256))
            head = art.crop((0,0,64,44))
            art.paste((0,0,0,0),(0,0,64,44))
            bridge = shiny.crop((col*64+19,192+42,col*64+45,192+46))
            for y in range(22,44,2):
                art.alpha_composite(bridge,(19,y))
            art.alpha_composite(head,(0,-20))
            result.paste(art,(col*64,192))
    elif base_id == 'basculegion':
        # The shiny follower differs by 24 silhouette pixels. Keep the approved
        # normal silhouette and use positional shiny colours where available.
        assert original.tobytes() == normal.tobytes()
        pairs = defaultdict(Counter)
        for a,b in zip(original.getdata(),shiny.getdata()):
            if a[3] and b[3]:
                pairs[a][b[:3]] += 1
        palette = {a: values.most_common(1)[0][0] for a,values in pairs.items()}
        result = Image.new('RGBA', normal.size)
        result.putdata([(b[:3] if b[3] else palette[a])+(a[3],) if a[3] else (0,0,0,0)
                        for a,b in zip(normal.getdata(),shiny.getdata())])
    else:
        result = shiny
    assert result.getchannel('A').tobytes() == normal.getchannel('A').tobytes(), base_id+' shiny geometry changed'
    return result


def definition(mid, cfg):
    folder = f'res://assets/mounts/{mid}'
    base_id = mid.removesuffix('_shiny')
    shared = f'res://assets/mounts/{base_id}'
    shiny = mid.endswith('_shiny')
    return with_surf_idle(mid, dict(displayName=('Shiny ' if shiny else '')+cfg['name'], movementMode='surf',
                unlockItemId=('shiny-' if shiny else '')+base_id+'-mount', iconTexture=folder+'/icon.png',
                spriteSheet=folder+'/mount.png', foregroundSheet=folder+'/foreground.png',
                riderMaskSheet=shared+'/rider_mask.png', waterContactSheet=shared+'/water_contact.png',
                frameSize=[FRAME, FRAME], movementAnimationSpeed=4.0,
                riderOffsets={direction: [[x, y+WORLD_WATERLINE_Y] for x,y in offsets]
                              for direction,offsets in cfg['riderOffsets'].items()},
                surfFishingFullForeground=False,
                surfFishingRiderOffsets={'down':[0,18], 'left':[0,4], 'right':[0,4], 'up':[0,10]}))


def build(update_catalog=False):
    definitions = {}
    jobs = list(CONFIG.items()) + [(mid+'_shiny',cfg) for mid,cfg in CONFIG.items()]
    for mid, cfg in jobs:
        folder = ROOT/'assets/mounts'/mid
        folder.mkdir(exist_ok=True)
        shiny = mid.endswith('_shiny')
        source = shiny_source(mid.removesuffix('_shiny')) if shiny else Image.open(folder/'source.png').convert('RGBA')
        if shiny:
            source.save(folder/'source.png')
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
            if shiny and name == 'rider_mask':
                normal_mask = Image.open(ROOT/'assets/mounts'/mid.removesuffix('_shiny')/'rider_mask.png').convert('RGBA')
                assert sheet.tobytes() == normal_mask.tobytes()
            else:
                sheet.save(folder/(name+'.png'))
        if shiny:
            normal_water = Image.open(ROOT/'assets/mounts'/mid.removesuffix('_shiny')/'water_contact.png').convert('RGBA')
            assert water.tobytes() == normal_water.tobytes()
        else:
            water.save(folder/'water_contact.png')
        icon = source.crop((0,0,size,size))
        icon.crop(icon.getbbox()).save(folder/'icon.png')
        for name in (('source','mount','foreground','icon') if shiny else ('source','mount','foreground','rider_mask','water_contact','icon')):
            write_texture_import(ROOT, (folder/(name+'.png')).relative_to(ROOT))
        definitions[mid] = definition(mid, cfg)
        print(mid, 'native rig and water layers built')
    path = ROOT/'data/mounts.json'
    catalog = json.loads(path.read_text())
    if update_catalog:
        # Replace only these records, preserving all unrelated catalog formatting.
        text = path.read_text()
        for mid,value in definitions.items():
            marker = '    '+json.dumps(mid)+': '
            encoded = json.dumps(value,indent=2).replace('\n','\n    ')
            start = text.find(marker)
            if start >= 0:
                start += len(marker)
                _, length = json.JSONDecoder().raw_decode(text[start:])
                text = text[:start]+encoded+text[start+length:]
            else:
                end = text.rfind('\n  }')
                assert end >= 0
                text = text[:end]+',\n'+marker+encoded+text[end:]
        path.write_text(text)
        catalog = json.loads(path.read_text())
    for mid, expected in definitions.items():
        assert catalog['mounts'][mid] == expected, mid+' catalog differs from generator'


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--sync-catalog', action='store_true')
    build(parser.parse_args().sync_catalog)
