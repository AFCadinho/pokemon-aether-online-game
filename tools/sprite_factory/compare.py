"""Compare a factory build to a POC master directory or another factory build.

python compare.py BUILD REFERENCE --poc --output evidence.json
All comparisons are decoded RGBA pixels; no images are altered.
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageStat


def compare(build, reference, poc=False):
    records = []
    for path in sorted((build / 'masters').glob('*/*/*.png')):
        view, action, name = path.relative_to(build / 'masters').parts
        if poc:
            source_action = 'faint_hold' if action == 'faint_loop' else action
            target = reference / view / source_action / ('frame_' + str(int(path.stem)).zfill(3) + '.png')
            if action == 'faint_loop' and not target.exists():
                targets = sorted((reference / view / 'faint_start').glob('*.png'))
                target = targets[-1]
        else:
            target = reference / 'masters' / view / action / name
        with Image.open(path) as left, Image.open(target) as right:
            a, b = left.convert('RGBA'), right.convert('RGBA')
            diff = ImageChops.difference(a, b)
            records.append(dict(frame=str(path.relative_to(build)), exact=a.tobytes() == b.tobytes(),
                                mae=ImageStat.Stat(diff).mean,
                                max_channel_error=max(high for low, high in diff.getextrema())))
    return dict(compared=len(records), exact=sum(r['exact'] for r in records),
                max_channel_error=max(r['max_channel_error'] for r in records),
                max_frame_mean_error=max(max(r['mae']) for r in records), frames=records)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('build', type=Path)
    p.add_argument('reference', type=Path)
    p.add_argument('--poc', action='store_true')
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    result = compare(args.build, args.reference, args.poc)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print({k:v for k,v in result.items() if k != 'frames'})
