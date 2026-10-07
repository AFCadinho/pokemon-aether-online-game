#!/usr/bin/env python3
"""Measure decoded albedo/alpha differences; metrics are not visual approval.
Normal maps are compared on X/Y channels separately from albedo color.
Requires Pillow. Read/write only generated diagnostics beneath this checkout.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageStat
ROOT = Path(__file__).resolve().parents[1]

def measure(a, b):
    with Image.open(a) as left, Image.open(b) as right:
        left, right = left.convert('RGBA'), right.convert('RGBA')
        if left.size != right.size:
            raise ValueError('Image dimensions differ')
        diff = ImageChops.difference(left, right)
        rms = ImageStat.Stat(diff).rms
        # Ignore invisible cutout RGB for the visible-color metric. Include alpha
        # separately so missing/changed silhouettes cannot be hidden by masking.
        mask = ImageChops.lighter(left.getchannel('A'), right.getchannel('A'))
        visible_rms = ImageStat.Stat(diff.convert('RGB'), mask=mask).rms
        mse = sum(v*v for v in visible_rms) / 3
        return {'size': list(left.size), 'rgba_rmse': rms, 'visible_rgb_rmse': math.sqrt(mse),
                'visible_rgb_psnr_db': 10*math.log10(255*255/mse) if mse else None,
                'alpha_rmse': rms[3], 'exact_pixels': diff.getbbox(alpha_only=False) is None}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', type=Path, required=True)
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    assets = args.assets.resolve()
    assets.relative_to(ROOT / '.tmp')
    folders = [assets / variant / 'decoded' for variant in ['desktop-art', 'android-etc2-art']]
    lists = [json.loads((folder / 'textures.json').read_text()) for folder in folders]
    if any(len(rows) != 42 or any(row['decode_error'] != 0 for row in rows) for rows in lists):
        raise ValueError('All 42 textures must decode before comparison')
    rows = []
    for left, right in zip(*lists, strict=True):
        if left['decoded'] != right['decoded'] or (left['width'], left['height'], left['mipmaps']) != (right['width'], right['height'], right['mipmaps']):
            raise ValueError('Texture identity/dimensions/mip chain mismatch')
        name = left['decoded']
        row = {'texture': name, 'dimensions_unchanged': True}
        if '_normal' in name:
            metric = measure(folders[0]/name, folders[1]/name)
            row['normal_xy_rmse'] = math.sqrt(sum(v*v for v in metric['rgba_rmse'][:2])/2)
            row['encoded_format'] = [left['format'], right['format']]
        else:
            row.update(measure(folders[0]/name, folders[1]/name))
        rows.append(row)
    report = {'textures': rows, 'production_approved': False,
              'limit': 'PSNR is an A/B diagnostic, not an acceptance threshold or proof of losslessness.'}
    if args.native:
        native = args.native.resolve()
        native.relative_to(ROOT / '.tmp')
        report['native_capture'] = measure(native/'desktop-art/capture.png',native/'android-etc2-art/capture.png')
        report['native_capture_sha256'] = [hashlib.sha256((native/v/'capture.png').read_bytes()).hexdigest() for v in ['desktop-art', 'android-etc2-art']]
    (assets/'image-comparison.json').write_text(json.dumps(report, indent=2)+'\n')
    color = [r for r in rows if 'visible_rgb_psnr_db' in r]
    print(json.dumps({'decoded':len(rows), 'albedo_alpha_scored':len(color),
                     'min_psnr_db':min(r['visible_rgb_psnr_db'] for r in color if r['visible_rgb_psnr_db'] is not None),
                     'max_alpha_rmse':max(r['alpha_rmse'] for r in color), 'native':report.get('native_capture')},indent=2))
if __name__ == '__main__':
    main()
