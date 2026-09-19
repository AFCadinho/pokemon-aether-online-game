"""Repackage a local review catalog into eight-frame lossless runtime pages.

Only derived runtime files are written. Source builds/masters stay unchanged.
Every output cell is decoded and compared byte-for-byte before activation.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

from PIL import Image


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def repack(catalog_path, output, activate=False):
    original = catalog_path.read_bytes()
    catalog = json.loads(original)
    if catalog.get('mode') != 'preview':
        raise ValueError('Only explicit local preview catalogs may be repackaged')
    output.mkdir(parents=True, exist_ok=True)
    result = copy.deepcopy(catalog)
    total = 0
    for key, entry in catalog['entries'].items():
        source = Path(entry['path'])
        if sha(source) != entry['sha256']:
            raise ValueError(f'Manifest hash mismatch: {key}')
        meta = json.loads(source.read_text())
        if meta['cell_size'] != 512 or meta['fps'] not in (24, 60):
            raise ValueError('Unsupported quality baseline')
        target = output / entry['sha256']
        target.mkdir(exist_ok=True)
        for view, actions in meta['views'].items():
            for action, spec in actions.items():
                cells = []
                union = None
                for page in spec['pages']:
                    path = source.parent / page['file']
                    if sha(path) != page['sha256']:
                        raise ValueError(f'Page hash mismatch: {path}')
                    with Image.open(path) as atlas:
                        if atlas.mode != 'RGBA':
                            raise ValueError('Expected lossless RGBA atlas')
                        for i in range(page['count']):
                            x, y = i % page['columns'] * 512, i // page['columns'] * 512
                            cell = atlas.crop((x, y, x + 512, y + 512))
                            cells.append(cell)
                            box = cell.getchannel('A').getbbox()
                            if box:
                                union = box if union is None else (
                                    min(union[0], box[0]), min(union[1], box[1]),
                                    max(union[2], box[2]), max(union[3], box[3]))
                if len(cells) != spec['count'] or union is None:
                    raise ValueError('Invalid action count/bounds')
                pages = []
                (target / view).mkdir(exist_ok=True)
                for start in range(0, len(cells), 8):
                    batch = cells[start:start + 8]
                    columns = min(4, len(batch))
                    sheet = Image.new('RGBA', (columns * 512, ((len(batch) + columns - 1) // columns) * 512))
                    for i, cell in enumerate(batch):
                        sheet.paste(cell, (i % columns * 512, i // columns * 512))
                    name = f'{view}/{action}-{start // 8:03}.png'
                    destination = target / name
                    sheet.save(destination, compress_level=6)
                    with Image.open(destination) as check:
                        for i, cell in enumerate(batch):
                            x, y = i % columns * 512, i // columns * 512
                            if check.crop((x, y, x + 512, y + 512)).tobytes() != cell.tobytes():
                                raise ValueError('Repack changed pixels')
                    pages.append(dict(file=name, count=len(batch), columns=columns, sha256=sha(destination)))
                spec['pages'] = pages
                spec['visual_bounds'] = [union[0], union[1], union[2] - union[0], union[3] - union[1]]
                if action == 'idle':
                    name = f'{view}/idle-preview.png'
                    cells[0].save(target / name)
                    spec['preview_frame'] = dict(file=name, sha256=sha(target / name), visual_bounds=spec['visual_bounds'])
                total += len(cells)
        meta['runtime_packaging'] = dict(version=1, frames_per_page=8, source_manifest=str(source), source_sha256=entry['sha256'])
        write_json(target / 'manifest.json', meta)
        result['entries'][key] = dict(path=str((target / 'manifest.json').resolve()), sha256=sha(target / 'manifest.json'))
    write_json(output / 'preview-batch.json', result)
    if activate:
        backup = output / 'previous-catalog.json'
        if backup.exists() and backup.read_bytes() != original:
            raise ValueError('Refusing to overwrite different rollback catalog')
        backup.write_bytes(original)
        temporary = catalog_path.with_suffix('.repack-tmp')
        write_json(temporary, result)
        temporary.replace(catalog_path)
    print(f'Validated {total} pixel-identical frames across {len(result["entries"])} entries; catalog: {output / "preview-batch.json"}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--activate', action='store_true', help='Back up and atomically update this local preview catalog')
    args = parser.parse_args()
    repack(args.catalog, args.output, args.activate)
