"""Build gentle surf idles from the approved resting poses, at native scale.

Run after the base mount builders. --check verifies pixels and catalog without
writing. Lapras keeps its approved pilot; land/flying mounts are not affected.
"""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops
from build_mount_idle_pilot import move_upper
from import_player_layered_sprites import write_texture_import

ROOT = Path(__file__).resolve().parents[1]
BASE_IDS = ('primal_kyogre', 'magikarp', 'wailmer', 'drednaw', 'mantine',
            'basculegion', 'wailord', 'gyarados')
DIRECTIONS = ('down', 'left', 'right', 'up')
PHASES = (0, -1, 0, 1)
DURATIONS = (0.9, 0.65, 0.9, 0.65)


def with_surf_idle(mid, definition):
    """Shared by source builders so regenerating a rig preserves its idle."""
    cfg = dict(definition)
    folder = f'res://assets/mounts/{mid}'
    shared = f'res://assets/mounts/{mid.removesuffix("_shiny")}'
    cfg.update(idleFrameCount=4, idleAnimationSpeed=1.0,
               idleFrameDurations=list(DURATIONS),
               idleSpriteSheet=folder+'/animated_idle_mount.png',
               idleForegroundSheet=folder+'/animated_idle_foreground.png',
               idleRiderMaskSheet=shared+'/animated_idle_rider_mask.png',
               idleWaterContactSheet=shared+'/animated_idle_water_contact.png',
               idleRiderOffsets={direction: [[x, y+dy] for dy in PHASES]
                                 for direction in DIRECTIONS
                                 for x, y in [cfg['riderOffsets'][direction][0]]})
    return cfg


def open_resource(path):
    return Image.open(ROOT/path.removeprefix('res://')).convert('RGBA')


def build(check=False):
    path = ROOT/'data/mounts.json'
    text = path.read_text()
    catalog = json.loads(text)['mounts']
    for base_id in BASE_IDS:
        for mid in (base_id, base_id+'_shiny'):
            cfg = catalog[mid]
            assert cfg['movementMode'] == 'surf'
            width, height = cfg['frameSize']
            # Read immutable walk frame zero, never our generated idle output.
            sources = {layer: open_resource(cfg[field]) for layer, field in (
                ('mount', 'spriteSheet'), ('foreground', 'foregroundSheet'),
                ('rider_mask', 'riderMaskSheet'), ('water_contact', 'waterContactSheet'))}
            sheets = {layer: Image.new('RGBA', (width*4, height*4)) for layer in sources}
            for row, direction in enumerate(DIRECTIONS):
                tiles = {layer: sheet.crop((0, row*height, width, (row+1)*height))
                         for layer, sheet in sources.items()}
                combined = Image.alpha_composite(tiles['mount'], tiles['foreground'])
                # As with Lapras, keep the lowest two immersed pixel rows fixed.
                # Per-direction bounds also handle Kyogre's taller rectangular rig.
                split = combined.getbbox()[3]-2
                for col, dy in enumerate(PHASES):
                    cels = {}
                    for layer, tile in tiles.items():
                        if layer == 'water_contact':
                            cel = tile.copy()
                            # Soft contact shimmer, at the existing contact points.
                            # Never reuse moving frames: those contain a wake.
                            factor = (1.0, 0.88, 1.0, 1.07)[col]
                            cel.putalpha(tile.getchannel('A').point(
                                [min(255, round(a*factor)) for a in range(256)]))
                            assert cel.getbbox() == tile.getbbox()
                        else:
                            cel = move_upper(tile, split, dy)
                            assert cel.crop((0, split, width, height)).tobytes() == tile.crop((0, split, width, height)).tobytes()
                        if col == 0:
                            assert cel.tobytes() == tile.tobytes(), (mid, layer, 'rest pose changed')
                        cels[layer] = cel
                        sheets[layer].paste(cel, (col*width, row*height))
                    overlap = ImageChops.multiply(cels['mount'].getchannel('A'), cels['foreground'].getchannel('A'))
                    assert overlap.getbbox() is None, (mid, direction, col, 'double-drawn translucent pixels')
            for layer, sheet in sheets.items():
                folder = ROOT/'assets/mounts'/(base_id if layer in ('rider_mask', 'water_contact') else mid)
                target = folder/('animated_idle_'+layer+'.png')
                if check or (mid.endswith('_shiny') and layer in ('rider_mask', 'water_contact')):
                    stored = Image.open(target).convert('RGBA')
                    assert stored.size == sheet.size and stored.tobytes() == sheet.tobytes(), target
                else:
                    sheet.save(target)
                    write_texture_import(ROOT, target.relative_to(ROOT))
            expected = with_surf_idle(mid, cfg)
            if check:
                assert cfg == expected, mid+' idle catalog mismatch'
            else:
                marker = '    '+json.dumps(mid)+': '
                start = text.index(marker)+len(marker)
                _, length = json.JSONDecoder().raw_decode(text[start:])
                text = text[:start]+json.dumps(expected, indent=2).replace('\n', '\n    ')+text[start+length:]
            print(mid+': idle pixels, fixed water contact, rider seats and shared shiny geometry verified')
    if not check:
        path.write_text(text)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)
