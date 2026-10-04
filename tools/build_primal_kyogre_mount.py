"""Pack the approved v3 Primal Kyogre surf art without resampling its pixels."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/mounts/primal_kyogre'
FRAME = (192, 224)
DIRECTIONS = ('down', 'left', 'right', 'up')
SEATS = (((88,8),)*4, ((96,-20),(96,-20),(96,-2),(96,-2)),
         ((96,-20),(96,-20),(96,-2),(96,-2)), ((88,3),)*4)
# Front/rear positioning remains as approved. Side views anchor the hull,
# not the lower fin tip, on the water tile: move the whole rig down one tile.
# The second source pose drops the hull 18px; compensate before packing so
# the fins swim around a stable hull and the rider does not bounce in midair.
SHIFTS = (((-24,21),)*4,
          ((-32,53),(-32,53),(-32,35),(-32,35)),
          ((-32,53),(-32,53),(-32,35),(-32,35)),
          ((-24,21),)*4)


def definition():
    offsets = {d: [[x+SHIFTS[r][c][0]-(FRAME[0]-64)//2,
                   y+SHIFTS[r][c][1]-(FRAME[1]-64)//2] for c,(x,y) in enumerate(SEATS[r])]
               for r,d in enumerate(DIRECTIONS)}
    return {'displayName':'Primal Kyogre', 'movementMode':'surf',
            'unlockItemId':'primal-kyogre-mount',
            'iconTexture':'res://assets/mounts/primal_kyogre/icon.png',
            'spriteSheet':'res://assets/mounts/primal_kyogre/mount.png',
            'riderMaskSheet':'res://assets/mounts/primal_kyogre/rider_mask.png',
            'foregroundSheet':'res://assets/mounts/primal_kyogre/foreground.png',
            'frameSize':list(FRAME), 'movementAnimationSpeed':7.5,
            'surfFishingFullForeground':False,
            'surfFishingRiderOffsets':{'down':[0,18],'left':[0,4],'right':[0,4],'up':[0,10]},
            'riderOffsets':offsets}


def foreground(art, row, col):
    selection = Image.new('L', art.size)
    draw = ImageDraw.Draw(selection)
    if row == 0:
        draw.polygon([(101,66),(139,66),(149,93),(136,118),(100,118),(91,94)],fill=255)
    elif row == 1:
        points = ([(109,56),(124,63),(135,102),(128,127),(72,127),(78,86)] if col < 2
                  else [(107,82),(119,82),(131,110),(123,122),(69,122),(74,99)])
        draw.polygon(points,fill=255)
    elif row == 2:
        points = ([(147,56),(132,63),(121,102),(128,127),(184,127),(178,86)] if col < 2
                  else [(149,82),(137,82),(125,110),(133,122),(187,122),(182,99)])
        draw.polygon(points,fill=255)
    result = Image.new('RGBA', art.size)
    result.paste(art,(0,0),selection)
    return result


def build():
    source = Image.open(FOLDER/'source.png').convert('RGBA')
    assert source.size == (1024,512)
    sheets = {k:Image.new('RGBA',(FRAME[0]*4,FRAME[1]*4)) for k in ('mount','foreground','rider_mask')}
    for row in range(4):
        for col in range(4):
            art = source.crop((col*256,row*128,(col+1)*256,(row+1)*128))
            base = Image.new('RGBA',FRAME)
            base.alpha_composite(art,SHIFTS[row][col])
            assert sum(base.getchannel('A').histogram()[1:]) == sum(art.getchannel('A').histogram()[1:])
            fg = Image.new('RGBA',FRAME)
            fg.alpha_composite(foreground(art,row,col),SHIFTS[row][col])
            mask = Image.new('RGBA',FRAME)
            mask.putalpha(fg.getchannel('A'))
            for key,tile in [('mount',base),('foreground',fg),('rider_mask',mask)]:
                sheets[key].alpha_composite(tile,(col*FRAME[0],row*FRAME[1]))
    for key,sheet in sheets.items():
        sheet.save(FOLDER/f'{key}.png')
    # Inventory controls fit this tight icon themselves; no oversized padding.
    icon = source.crop((0,0,256,128))
    icon.crop(icon.getbbox()).save(FOLDER/'icon.png')
    for name in ['source','mount','foreground','rider_mask','icon']:
        write_texture_import(ROOT,(FOLDER/f'{name}.png').relative_to(ROOT))
    assert json.loads((ROOT/'data/mounts.json').read_text())['mounts']['primal_kyogre'] == definition()
    print('Primal Kyogre: preserved source art, approved v3 seats, aligned waterline.')


if __name__ == '__main__':
    build()
