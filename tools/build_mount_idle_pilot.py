"""Author four native-pixel idle cels for Arcanine and Lapras.

Frame zero is the approved resting pose. Walking atlases are never modified.
Arcanine's upper body lifts one pixel while the paws stay planted; the one-pixel
join is filled from its existing fur. Lapras rises/falls one pixel above its
unchanged bottom water-contact rows. No scaling, rotation or interpolation.
"""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DIRECTIONS = ('down', 'left', 'right', 'up')
VARIANTS = ('arcanine', 'arcanine_shiny', 'lapras')


def move_upper(image, split, dy):
    if not dy:
        return image.copy()
    out = image.copy()
    out.paste((0, 0, 0, 0), (0, 0, image.width, split))
    upper = image.crop((0, 0, image.width, split))
    out.alpha_composite(upper, (0, dy))
    if dy < 0:
        # Preserve the existing fur connection to the planted legs.
        out.paste(image.crop((0, split-1, image.width, split)), (0, split-1))
    # Paws / the lowest existing waterline always win over the moving upper part.
    out.paste(image.crop((0, split, image.width, image.height)), (0, split))
    return out


def build(check=False):
    path = ROOT/'data/mounts.json'
    text = path.read_text()
    catalog = json.loads(text)['mounts']
    for mid in VARIANTS:
        folder = ROOT/'assets/mounts'/mid
        cfg = catalog[mid]
        size = cfg['frameSize'][0]
        surf = mid == 'lapras'
        # These are immutable approved source poses, not our output idle atlases.
        sources = {}
        for layer in ('mount', 'foreground', 'rider_mask'):
            if surf and layer == 'foreground':
                continue
            filename = layer+'.png' if surf else 'idle_'+layer+'.png'
            sources[layer] = Image.open(folder/filename).convert('RGBA')
        sheets = {k: Image.new('RGBA', (size*4, size*4)) for k in ('mount','foreground','rider_mask')}
        phases = (0, -1, 0, 1) if surf else (0, -1, -1, 0)
        seats = {}
        for row, direction in enumerate(DIRECTIONS):
            tiles = {key: im.crop((0,row*size,size,(row+1)*size)) for key,im in sources.items()}
            if surf:
                tiles['foreground'] = Image.new('RGBA', (size,size))
                if direction == 'down':
                    tiles['foreground'].paste(tiles['mount'].crop((0,0,size,50)), (0,0))
            split = 58 if surf else 118
            seats[direction] = []
            for col,dy in enumerate(phases):
                for key,tile in tiles.items():
                    cel = move_upper(tile, split, dy)
                    assert cel.crop((0,split,size,size)).tobytes() == tile.crop((0,split,size,size)).tobytes()
                    if col == 0:
                        assert cel.tobytes() == tile.tobytes()
                    sheets[key].paste(cel, (col*size,row*size))
                x,y = cfg['riderOffsets'][direction][0]
                seats[direction].append([x,y+dy])
        for layer,im in sheets.items():
            target = folder/('animated_idle_'+layer+'.png')
            if check:
                stored = Image.open(target).convert('RGBA')
                assert stored.size == im.size and stored.tobytes() == im.tobytes(), target
            else:
                im.save(target)
        expected = dict(cfg)
        expected.update(idleFrameCount=4, idleAnimationSpeed=1.0,
                        idleFrameDurations=[0.9,0.65,0.9,0.65] if surf else [1.35,0.35,0.75,0.55],
                        idleRiderOffsets=seats)
        for field,layer in [('idleSpriteSheet','mount'),('idleForegroundSheet','foreground'),('idleRiderMaskSheet','rider_mask')]:
            expected[field] = f'res://assets/mounts/{mid}/animated_idle_{layer}.png'
        if check:
            assert cfg == expected, mid+' idle catalog mismatch'
        else:
            marker = '    '+json.dumps(mid)+': '
            a = text.index(marker)+len(marker)
            _,length = json.JSONDecoder().raw_decode(text[a:])
            text = text[:a]+json.dumps(expected,indent=2).replace('\n','\n    ')+text[a+length:]
        print(mid+': native idle frames, fixed ground/water contact and seats verified')
    if not check:
        path.write_text(text)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)
