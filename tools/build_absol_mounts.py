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
# world space. Side seats sit over the shoulders, closer to the head.
# Front seats settle behind the head, four source pixels lower than before.
OFFSETS = {
    'mega_absol': (
        ((0,-38),(0,-40),(0,-40),(0,-38)),
        ((4,-24),(6,-26),(4,-24),(6,-22)),
        ((-4,-24),(-4,-22),(-6,-24),(-6,-26)),
        ((0,-18),(0,-16),(-2,-16),(0,-14)),
    ),
    'mega_absol_z': (
        ((0,-40),(0,-42),(0,-40),(0,-42)),
        ((6,-22),(6,-20),(6,-20),(8,-22)),
        ((-6,-22),(-8,-24),(-6,-22),(-6,-24)),
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
        # Preserve the authored side rider in front of the mount. Its seated
        # hips/near leg are part of the player, not a fixed saddle-shaped hole
        # in mount coordinates. The moving rider envelope is cleared below.
        selection.paste(255, (0,0,64,64))
    else:
        # Keep the rider over the saddle area, but retain the complete outer
        # shoulder fans and the rump. Do not lay the rear head over their face.
        draw.polygon([(0,19),(25,19),(26,29),(26,37),(0,40)], fill=255)
        draw.polygon([(63,19),(39,19),(38,29),(38,37),(63,40)], fill=255)
        draw.rectangle((0,41,63,63),fill=255)
    # The full mount remains underneath, including within this cleared area.
    # In the front view, Absol's complete head sits in front of the rider.
    # Side views preserve the full authored rider; the rear view protects its head.
    # Add one logical pixel in Y to undo the source-to-runtime upward shift.
    dx, dy = OFFSETS[mount_id][row][col]
    rider_left, rider_top = 16 + dx//2, 17 + dy//2
    if row != 0:
        protected_height = 32 if row in (1,2) else 24
        draw.rectangle((rider_left, rider_top, rider_left+31,
                        rider_top+protected_height-1), fill=0)
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
        idle_source_path = folder/'idle_source.png'
        if mount_id == 'mega_absol_z':
            idle_source = Image.open(idle_source_path).convert('RGBA')
            assert idle_source.size == (64,256)
            idle_sheets = {key: Image.new('RGBA',(64,256)) for key in sheets}
            for row in range(4):
                art = idle_source.crop((0,row*64,64,(row+1)*64))
                creature = Image.new('RGBA',(64,64))
                creature.alpha_composite(art,(0,-1))
                foreground = Image.new('RGBA',(64,64))
                foreground.alpha_composite(foreground_pixels(art,mount_id,row,0),(0,-1))
                mask = Image.new('RGBA',(64,64))
                mask.putalpha(foreground.getchannel('A'))
                for key,tile in [('mount',creature),('foreground',foreground),('rider_mask',mask)]:
                    idle_sheets[key].alpha_composite(tile,(0,row*64))
            for key,sheet in idle_sheets.items():
                path = folder/f'idle_{key}.png'
                sheet.resize((128,512),Image.Resampling.NEAREST).save(path)
                write_texture_import(ROOT,path.relative_to(ROOT))
            write_texture_import(ROOT,idle_source_path.relative_to(ROOT))
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
