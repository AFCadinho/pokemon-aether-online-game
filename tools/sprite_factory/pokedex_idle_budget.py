"""Read-only inventory of a packaged idle-only Pokedex; no asset activation."""

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image


def verified(path, expected):
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise ValueError(f"Hash mismatch: {path}")
    return data


def inventory(catalog_path, output):
    catalog = json.loads(catalog_path.read_text())
    entries = {}
    groups = []
    for key, entry in sorted(catalog['entries'].items()):
        manifest_path = Path(entry['path'])
        manifest = json.loads(verified(manifest_path, entry['sha256']))
        if manifest['cell_size'] != 512 or manifest['fps'] != 60:
            raise ValueError(f"Unexpected source format: {key}")
        views = {}
        all_action_bytes = 0
        for view in ('front', 'back'):
            for spec in manifest['views'][view].values():
                all_action_bytes += sum((manifest_path.parent / p['file']).stat().st_size for p in spec['pages'])
            idle = manifest['views'][view]['idle']
            files = []
            stored_bytes = raw_bytes = frames = 0
            _, _, width, height = idle['stored_cell_rect']
            for page in idle['pages']:
                path = manifest_path.parent / page['file']
                stored_bytes += len(verified(path, page['sha256']))
                with Image.open(path) as image:
                    expected_size = (page['columns'] * width, math.ceil(page['count'] / page['columns']) * height)
                    if image.size != expected_size:
                        raise ValueError(f"Unexpected atlas size: {path}")
                    raw_bytes += image.width * image.height * 4
                files.append(str(path.resolve()))
                frames += page['count']
            if frames != idle['count']:
                raise ValueError(f"Frame count mismatch: {key}/{view}")
            preview = idle['preview_frame']
            preview_bytes = len(verified(manifest_path.parent / preview['file'], preview['sha256']))
            # Portraits upload trimmed individual cells; logical 512 margins
            # are AtlasTexture metadata, not allocated transparent pixels.
            mip_bytes_per_frame = sum(max(1, width >> level) * max(1, height >> level) * 4
                                      for level in range(max(width, height).bit_length()))
            views[view] = dict(bytes=stored_bytes, preview_bytes=preview_bytes,
                               frames=frames, seconds=frames / 60, pages=len(files),
                               atlas_rgba_bytes=raw_bytes,
                               trimmed_frame_mip_rgba_bytes=frames * mip_bytes_per_frame)
            groups.append(dict(label=f'{key}/{view}/idle', files=files))
            groups.append(dict(label=f'{key}/{view}/first-page', files=files[:1]))
        entries[key] = dict(views=views, all_action_bytes=all_action_bytes,
                            idle_bytes=sum(v['bytes'] for v in views.values()),
                            idle_with_previews_bytes=sum(v['bytes'] + v['preview_bytes'] for v in views.values()))
    variants = {}
    for variant in ('normal', 'shiny'):
        selected = [v for k, v in entries.items() if k.endswith(':' + variant)]
        if not selected:
            continue
        totals = {field: sum(v[field] for v in selected) for field in ('idle_bytes', 'idle_with_previews_bytes', 'all_action_bytes')}
        variants[variant] = dict(count=len(selected), **totals,
            mean_idle_pair_bytes=totals['idle_bytes'] / len(selected),
            mean_idle_pair_with_previews_bytes=totals['idle_with_previews_bytes'] / len(selected))
    projections = {}
    for count in (151, 500, 1000):
        projections[str(count)] = {
            variant: count * value['mean_idle_pair_with_previews_bytes']
            for variant, value in variants.items()
        }
    paired = {}
    for key in entries:
        if key.endswith(':normal') and key.replace(':normal', ':shiny') in entries:
            shiny = key.replace(':normal', ':shiny')
            paired[key.split(':')[0]] = entries[shiny]['idle_bytes'] / entries[key]['idle_bytes']
    report = dict(schema=1, catalog_sha256=hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
                  resolution=512, fps=60, entries=entries, variants=variants,
                  projected_bytes_including_previews=projections, paired_shiny_to_normal_ratios=paired,
                  caveats=['Sample means, not complete-catalog counts or confidence intervals.',
                           'Missing shiny species are not generated or assumed identical.',
                           'No resolution, timing, quality, loader or catalog changed.',
                           'Mip memory is theoretical trimmed-frame allocation, not measured process/GPU memory.'])
    output.mkdir(parents=True, exist_ok=False)
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    config = dict(result=str((output / 'godot-runtime.json').resolve()),
                  candidates=[dict(label='512-q95-idle-only', kind='webp', groups=groups)])
    (output / 'runtime-config.json').write_text(json.dumps(config, indent=2) + '\n')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = inventory(args.catalog, args.output)
    print(json.dumps({k: result[k] for k in ('variants', 'projected_bytes_including_previews', 'paired_shiny_to_normal_ratios')}, indent=2))
