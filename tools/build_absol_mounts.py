"""Pack approved Absol pixels at exact 2x scale with fitted rider layers."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
MOUNTS = ('mega_absol', 'mega_absol_z')
DIRECTIONS = ('down', 'left', 'right', 'up')
# Move the artwork and its approved rider rig up one logical pixel to put
# paws on the same world ground line as Cyclizar. Players retain 64px frames.
# Per-frame seat offsets follow the torso rather than freezing the rider in
# world space. Side seats are further back so the head/feathers have room.
OFFSETS = {
    'mega_absol': (
        ((0,-46),(0,-48),(0,-48),(0,-46)),
        ((16,-24),(18,-26),(16,-24),(18,-22)),
        ((-16,-24),(-16,-22),(-18,-24),(-18,-26)),
        ((0,-18),(0,-16),(-2,-16),(0,-14)),
    ),
    'mega_absol_z': (
        ((0,-48),(0,-50),(0,-48),(0,-50)),
        ((20,-22),(20,-20),(20,-20),(22,-22)),
        ((-20,-22),(-22,-24),(-20,-22),(-20,-24)),
        ((0,-18),(0,-16),(-2,-18),(-2,-20)),
    ),
}


def foreground_pixels(art, mount_id, row, col):
    """Select occluding anatomy, never rectangular pieces through feathers.

    The base mount remains complete. Only rider pixels covered by this exact
    same foreground silhouette are masked. All colors are original artwork.
    """
    selection = Image.new('L', (64,64))
    draw = ImageDraw.Draw(selection)
    if row == 0:
        # The head, horn and shoulder fans are all in front of the rider.
        selection.paste(255, (0,0,64,64))
    elif row in (1,2):
        # The rider may cover the saddle and haunch, but never the raised
        # tail, horn, face or wing outline. A small saddle opening retains
        # the near leg without cutting rectangular holes through anatomy.
        selection.paste(255, (0,0,64,64))
        points = [(34,34),(42,34),(46,40),(44,44),(34,44)]
        if row == 2:
            points = [(63-x,y) for x,y in points]
        draw.polygon(points, fill=0)
    else:
        # Keep the rider over the saddle area, but retain the complete outer
        # shoulder fans and the rump. Do not lay the rear head over their face.
        draw.polygon([(0,19),(25,19),(26,29),(26,37),(0,40)], fill=255)
        draw.polygon([(63,19),(39,19),(38,29),(38,37),(63,40)], fill=255)
        draw.rectangle((0,41,63,63),fill=255)
    if mount_id == 'mega_absol_z' and row in (1,2):
        # Include every magenta feather plus its immediate dark outline.
        # A color silhouette follows each generated pose's actual feather fan.
        for y in range(64):
            for x in range(64):
                r,g,b,a = art.getpixel((x,y))
                if a and r>60 and r>b*1.3 and r>g*2:
                    draw.rectangle((max(0,x-1),max(0,y-1),min(63,x+1),min(63,y+1)),fill=255)
    # Creature anatomy sits in front of the rider's lower body, while the
    # face/helmet remains above the raised horn, feathers and tail. Clearing
    # only the foreground here does not remove art: the full base mount stays
    # underneath. The box follows the seated player's 32px logical frame.
    dx, dy = OFFSETS[mount_id][row][col]
    head_left, head_top = 16 + dx//2, 17 + dy//2
    draw.rectangle((head_left, head_top, head_left+31, head_top+23), fill=0)
    foreground = Image.new('RGBA',(64,64))
    for y in range(64):
        for x in range(64):
            if selection.getpixel((x,y)):
                foreground.putpixel((x,y), art.getpixel((x,y)))
    return foreground


def build():
    catalog = json.loads((ROOT/'data/mounts.json').read_text())
    for mount_id in MOUNTS:
        folder = ROOT/'assets/mounts'/mount_id
        source = Image.open(folder/'source.png').convert('RGBA')
        assert source.size == (256, 256)
        sheets = {k: Image.new('RGBA', (256, 256)) for k in ('mount', 'foreground', 'rider_mask')}
        for row in range(4):
            for col in range(4):
                art = source.crop((col*64, row*64, (col+1)*64, (row+1)*64))
                creature = Image.new('RGBA', (64, 64))
                creature.alpha_composite(art, (0,-1))
                assert creature.getchannel('A').histogram()[255] == art.getchannel('A').histogram()[255]
                foreground = Image.new('RGBA', (64, 64))
                foreground.alpha_composite(foreground_pixels(art, mount_id, row, col), (0,-1))
                mask = Image.new('RGBA', (64, 64))
                mask.putalpha(foreground.getchannel('A'))
                for key, tile in [('mount', creature), ('foreground', foreground), ('rider_mask', mask)]:
                    sheets[key].alpha_composite(tile, (col*64, row*64))
        for key, sheet in sheets.items():
            path = folder/f'{key}.png'
            sheet.resize((512,512), Image.Resampling.NEAREST).save(path)
            write_texture_import(ROOT, path.relative_to(ROOT))
        icon_art = source.crop((0,0,64,64))
        icon_art = icon_art.crop(icon_art.getbbox())
        icon = Image.new('RGBA', (64,64))
        icon.alpha_composite(icon_art, ((64-icon_art.width)//2, (64-icon_art.height)//2))
        icon.save(folder/'icon.png')
        for name in ('source.png', 'icon.png'):
            write_texture_import(ROOT, (folder/name).relative_to(ROOT))
        definition = catalog['mounts'][mount_id]
        assert definition['frameSize'] == [128,128]
        assert definition['riderOffsets'] == {d:[list(v) for v in OFFSETS[mount_id][r]] for r,d in enumerate(DIRECTIONS)}
        print(f'Built {mount_id}: approved pixels, 128px frames, fitted layers and icon.')


if __name__ == '__main__':
    build()
