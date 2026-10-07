"""Pack the approved v3 Primal Kyogre surf art without resampling its pixels."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageChops
from primal_kyogre_water_contact import immerse, foam
from import_player_layered_sprites import write_texture_import
from build_surf_mount_idles import with_surf_idle

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'assets/mounts/primal_kyogre'
ART_FRAME = (192, 224)
# Extra transparent canvas preserves all fins/wake below the player anchor.
# The artwork stays at native scale.
FRAME = (192, 320)
DIRECTIONS = ('down', 'left', 'right', 'up')
# Side-view face center was 18.5px below the occupied/interacting tile line.
# Lift the complete rig by an integer amount, identical in every direction,
# so the player does not jump vertically when turning.
FACE_ANCHOR_Y = -18
SEATS = (((88,8),)*4, ((96,-20),(96,-20),(96,-2),(96,-2)),
         ((96,-20),(96,-20),(96,-2),(96,-2)), ((88,3),)*4)
# Original composition coordinates for the approved anatomical water treatment.
# The second source pose drops the hull 18px; compensate before anchoring.
SHIFTS = (((-24,21),)*4,
          ((-32,53),(-32,53),(-32,35),(-32,35)),
          ((-32,53),(-32,53),(-32,35),(-32,35)),
          ((-24,21),)*4)


def definition(shiny=False):
    # The rider follows the same face-alignment shift as every mount layer.
    offsets = {d: [[0, FACE_ANCHOR_Y] for _ in range(4)] for d in DIRECTIONS}
    folder = 'primal_kyogre_shiny' if shiny else 'primal_kyogre'
    return with_surf_idle(folder, {'displayName':'Shiny Primal Kyogre' if shiny else 'Primal Kyogre', 'movementMode':'surf',
            'unlockItemId':'shiny-primal-kyogre-mount' if shiny else 'primal-kyogre-mount',
            'iconTexture':f'res://assets/mounts/{folder}/icon.png',
            'spriteSheet':f'res://assets/mounts/{folder}/mount.png',
            'riderMaskSheet':f'res://assets/mounts/{folder}/rider_mask.png',
            'foregroundSheet':f'res://assets/mounts/{folder}/foreground.png',
            'waterContactSheet':'res://assets/mounts/primal_kyogre/water_contact.png',
            'frameSize':list(FRAME), 'movementAnimationSpeed':7.5,
            'interactionHeightOffsets':{'left':16,'right':16},
            'storePreviewScale':1.0, 'storePreviewOffset':[0,-16],
            'surfFishingFullForeground':False,
            'surfFishingRiderOffsets':{'down':[0,18],'left':[0,4],'right':[0,4],'up':[0,10]},
            'riderOffsets':offsets})


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


# Matches the existing shiny Primal Kyogre reference: charcoal, pale gold and
# rose fin tips. No resampling, silhouette changes or rider geometry changes.
SHINY_PALETTE = {
    (0,0,0):(0,0,0), (13,10,66):(15,21,25),
    (41,37,121):(30,39,43), (89,75,161):(55,68,69),
    (117,97,175):(83,98,96), (95,169,176):(123,157,147),
    (161,200,211):(183,210,195), (188,223,233):(207,227,211),
    (212,234,241):(232,240,221), (248,249,250):(255,253,232),
    (243,238,192):(255,240,155), (233,198,154):(236,204,112),
    (198,127,144):(181,145,82), (30,30,30):(30,30,30),
}
FIN_PALETTE = {
    (95,169,176):(142,62,136), (161,200,211):(186,94,173),
    (188,223,233):(218,126,196), (212,234,241):(241,163,216),
    (248,249,250):(255,201,235),
}


def shiny_source(source):
    result = source.copy()
    for y in range(source.height):
        row, v = divmod(y,128)
        for x in range(source.width):
            pixel = source.getpixel((x,y))
            if not pixel[3]:
                continue
            col, u = divmod(x,256)
            fin_tip = (u < 96 or u > 144) if row in (0,3) else (
                v >= (110 if col < 2 else 100) or v < (32 if col < 2 else 48))
            palette = FIN_PALETTE if fin_tip and pixel[:3] in FIN_PALETTE else SHINY_PALETTE
            result.putpixel((x,y), (*palette[pixel[:3]], pixel[3]))
    assert result.getchannel('A').tobytes() == source.getchannel('A').tobytes()
    return result


def anchor_to_player(tile, row, col):
    seat = SEATS[row][col]
    shift = SHIFTS[row][col]
    # SEATS stores the top-left of a 64px rider cell. Its center must coincide
    # with the mount cell center plus the shared face-alignment correction.
    translation = (FRAME[0]//2 - (seat[0]+shift[0]+32),
                   FRAME[1]//2 - (seat[1]+shift[1]+32) + FACE_ANCHOR_Y)
    result = Image.new('RGBA', FRAME)
    result.alpha_composite(tile, translation)
    assert sum(result.getchannel('A').histogram()[1:]) == sum(tile.getchannel('A').histogram()[1:]), 'Player anchoring must not clip artwork'
    return result


def build_variant(source, folder):
    folder.mkdir(parents=True, exist_ok=True)
    assert source.size == (1024,512)
    sheets = {k:Image.new('RGBA',(FRAME[0]*4,FRAME[1]*4)) for k in ('mount','foreground','rider_mask')}
    for row in range(4):
        for col in range(4):
            art = source.crop((col*256,row*128,(col+1)*256,(row+1)*128))
            base = Image.new('RGBA',ART_FRAME)
            base.alpha_composite(art,SHIFTS[row][col])
            assert sum(base.getchannel('A').histogram()[1:]) == sum(art.getchannel('A').histogram()[1:])
            fg = Image.new('RGBA',ART_FRAME)
            fg.alpha_composite(foreground(art,row,col),SHIFTS[row][col])
            mask = Image.new('RGBA',ART_FRAME)
            mask.putalpha(fg.getchannel('A'))
            # Keep the opaque anatomical mask: submerged fins must not reveal
            # previously hidden player pixels. Draw translucent foreground once.
            wet = immerse(base,row,col)
            wet.putalpha(ImageChops.subtract(wet.getchannel('A'),fg.getchannel('A')))
            base, fg = wet, immerse(fg,row,col)
            for key,tile in [('mount',base),('foreground',fg),('rider_mask',mask)]:
                sheets[key].alpha_composite(anchor_to_player(tile,row,col),(col*FRAME[0],row*FRAME[1]))
    for key,sheet in sheets.items():
        sheet.save(folder/f'{key}.png')
    # Inventory controls fit this tight icon themselves; no oversized padding.
    icon = source.crop((0,0,256,128))
    icon.crop(icon.getbbox()).save(folder/'icon.png')
    for name in ['source','mount','foreground','rider_mask','icon']:
        write_texture_import(ROOT,(folder/f'{name}.png').relative_to(ROOT))
    print(f'{folder.name}: face aligned with interaction line, preserved riding pose and opaque rider mask.')


def build():
    source = Image.open(FOLDER/'source.png').convert('RGBA')
    shiny = shiny_source(source)
    shiny_folder = FOLDER.with_name('primal_kyogre_shiny')
    shiny_folder.mkdir(parents=True, exist_ok=True)
    shiny.save(shiny_folder/'source.png')
    contact = Image.new('RGBA',(FRAME[0]*4,FRAME[1]*8))
    for moving in (False,True):
        for row in range(4):
            for col in range(4):
                contact.alpha_composite(anchor_to_player(foam(row,col/4,moving),row,col),(col*FRAME[0],(row+4*int(moving))*FRAME[1]))
    contact.save(FOLDER/'water_contact.png')
    write_texture_import(ROOT,(FOLDER/'water_contact.png').relative_to(ROOT))
    catalog = json.loads((ROOT/'data/mounts.json').read_text())['mounts']
    for is_shiny, art, folder in [(False,source,FOLDER),(True,shiny,shiny_folder)]:
        build_variant(art,folder)
        mount_id = 'primal_kyogre_shiny' if is_shiny else 'primal_kyogre'
        assert catalog[mount_id] == definition(is_shiny)


if __name__ == '__main__':
    build()
