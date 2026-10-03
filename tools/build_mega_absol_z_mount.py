"""Pack the approved Mega Absol Z pixel art around the normal player foot line."""
from pathlib import Path
import json
from PIL import Image
from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/mounts/mega_absol_z'
FRAME = 80
# Approved v2 has 64px logical cells. Padding and translation put paws at the
# same world foot line as Cyclizar; the art and player pixel scale stay intact.
POSITION = (8, -5)
SOURCE_RIDER_OFFSETS = ((0, -11), (5, -2), (-5, -2), (0, 0))
DIRECTIONS = ('down', 'left', 'right', 'up')


def build():
    source = Image.open(ASSETS / 'source.png').convert('RGBA')
    assert source.size == (256, 256)
    sheets = {name: Image.new('RGBA', (FRAME * 4, FRAME * 4))
              for name in ('mount', 'foreground', 'rider_mask')}
    offsets = {}
    for row, direction in enumerate(DIRECTIONS):
        offsets[direction] = []
        for col in range(4):
            art = source.crop((col*64, row*64, (col+1)*64, (row+1)*64))
            creature = Image.new('RGBA', (FRAME, FRAME))
            creature.alpha_composite(art, POSITION)
            assert creature.getchannel('A').histogram()[255] == art.getchannel('A').histogram()[255]
            dx, dy = SOURCE_RIDER_OFFSETS[row]
            dy -= col % 2
            # Center changes from 32 to 40 logical pixels; translate the rig
            # along with the artwork, preserving the approved relative seat.
            offsets[direction].append([dx*2, (dy-13)*2])
            ox, oy = 16+dx, 16+dy
            rect = ((0, oy+20, 64, 64) if row == 0 else
                    (0, oy+21, 64, 64) if row == 3 else
                    (ox+8, oy+23, ox+15, oy+28) if row == 1 else
                    (ox+17, oy+23, ox+24, oy+28))
            foreground = Image.new('RGBA', (FRAME, FRAME))
            foreground.alpha_composite(art.crop(rect), (rect[0]+POSITION[0], rect[1]+POSITION[1]))
            mask = Image.new('RGBA', (FRAME, FRAME))
            mask.putalpha(foreground.getchannel('A'))
            for name, tile in [('mount', creature), ('foreground', foreground), ('rider_mask', mask)]:
                sheets[name].alpha_composite(tile, (col*FRAME, row*FRAME))
    for name, sheet in sheets.items():
        path = ASSETS / f'{name}.png'
        sheet.resize((FRAME*8, FRAME*8), Image.Resampling.NEAREST).save(path)
        write_texture_import(ROOT, path.relative_to(ROOT))
    icon_art = source.crop((0, 0, 64, 64))
    icon_art = icon_art.crop(icon_art.getbbox())
    icon = Image.new('RGBA', (64, 64))
    icon.alpha_composite(icon_art, ((64-icon_art.width)//2, (64-icon_art.height)//2))
    icon.save(ASSETS / 'icon.png')
    for name in ['icon.png', 'source.png']:
        write_texture_import(ROOT, (ASSETS/name).relative_to(ROOT))
    catalog = json.loads((ROOT / 'data/mounts.json').read_text())
    definition = catalog['mounts']['mega_absol_z']
    assert definition['frameSize'] == [160, 160]
    assert definition['riderOffsets'] == offsets
    print('Built Mega Absol Z: approved pixels preserved; ground-aligned 160px frames.')


if __name__ == '__main__':
    build()
