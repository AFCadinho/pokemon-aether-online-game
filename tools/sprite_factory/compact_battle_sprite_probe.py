"""Deliberately lossy 512/Q70 and 256/Q75 candidates, all actions at native 60 FPS.

Outputs only probe files; retains reviewed source framing and never emits a
production catalog. Requires the approved lossless source and Q95 package.
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image
from catalog_compaction_benchmark import SPECIES, frame_images


def run(packaged_path, source_path, output):
    packed = json.loads(packaged_path.read_text())
    source = json.loads(source_path.read_text())
    output.mkdir(parents=True, exist_ok=False)
    results = {}
    for species in SPECIES:
        sp = Path(source['entries'][species + ':normal']['path'])
        pp = Path(packed['entries'][species + ':normal']['path'])
        original = json.loads(sp.read_text())
        baseline = json.loads(pp.read_text())
        records = {}
        for view, actions in original['views'].items():
            for name, spec in actions.items():
                originals = frame_images(sp, spec)
                base_spec = baseline['views'][view][name]
                row = {'512-q95': sum((pp.parent / p['file']).stat().st_size for p in base_spec['pages'])}
                for size, quality in ((512, 70), (256, 75)):
                    label = f'{size}-q{quality}'
                    ratio = size / 512
                    x, y, w, h = spec['visual_bounds']
                    rect = (max(0, math.floor(x * ratio) - 4), max(0, math.floor(y * ratio) - 4),
                            min(size, math.ceil((x + w) * ratio) + 4), min(size, math.ceil((y + h) * ratio) + 4))
                    width, height = rect[2] - rect[0], rect[3] - rect[1]
                    total = 0
                    cursor = 0
                    pages = []
                    folder = output / species / label / view
                    folder.mkdir(parents=True, exist_ok=True)
                    for pi, page in enumerate(spec['pages']):
                        columns, count = page['columns'], page['count']
                        atlas = Image.new('RGBA', (columns * width, math.ceil(count / columns) * height))
                        for index, original_frame in enumerate(originals[cursor:cursor + count]):
                            frame = original_frame if size == 512 else original_frame.resize((size, size), Image.Resampling.LANCZOS)
                            atlas.paste(frame.crop(rect), ((index % columns) * width, (index // columns) * height))
                        path = folder / f'{name}-{pi:03d}.webp'
                        atlas.save(path, 'WEBP', quality=quality, method=4, exact=True)
                        with Image.open(path) as decoded:
                            if decoded.convert('RGBA').getchannel('A').tobytes() != atlas.getchannel('A').tobytes():
                                raise ValueError('Alpha mismatch')
                        total += path.stat().st_size
                        pages.append({'file': str(path.resolve()), 'columns': columns, 'count': count})
                        cursor += count
                    row[label] = total
                    if name == 'idle' and view == 'front':
                        (folder / 'preview.json').write_text(json.dumps(dict(pages=pages, rect=rect, size=size, fps=60)))
                records[f'{view}/{name}'] = row
        results[species] = records
        (output / 'report.json').write_text(json.dumps(results, indent=2))
        print('encoded', species, flush=True)
    return results


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packaged_catalog', type=Path)
    parser.add_argument('source_catalog', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    run(args.packaged_catalog, args.source_catalog, args.output)
