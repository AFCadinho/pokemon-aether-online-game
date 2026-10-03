"""Pack approved Absol pixels at exact 2x scale with fitted rider layers."""
from pathlib import Path
import json
from PIL import Image
from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
MOUNTS = ('mega_absol', 'mega_absol_z')
DIRECTIONS = ('down', 'left', 'right', 'up')
# Move the artwork and its approved rider rig up one logical pixel to put
# paws on the same world ground line as Cyclizar. Players retain 64px frames.
OFFSETS = ((0, -40), (10, -20), (-10, -20), (0, -18))
# Source-space foreground: frontal head, far leg, far leg, rear rump.
# Near legs remain visible. Masks only remove rider pixels behind artwork.
REGIONS = ((0, 24, 64, 64), (29, 30, 36, 38),
           (28, 30, 35, 38), (0, 41, 64, 64))


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
                rect = REGIONS[row]
                foreground.alpha_composite(art.crop(rect), (rect[0], rect[1]-1))
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
        assert definition['riderOffsets'] == {d:[list(OFFSETS[r]) for _ in range(4)] for r,d in enumerate(DIRECTIONS)}
        print(f'Built {mount_id}: approved pixels, 128px frames, fitted layers and icon.')


if __name__ == '__main__':
    build()
