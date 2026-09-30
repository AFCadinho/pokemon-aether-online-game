"""Recover full-resolution source eye atlases for Panpour and Simipour; review only."""
import argparse
import copy
import json
from pathlib import Path
from PIL import Image, ImageChops
from io import BytesIO
from catalog_remaining_eye_bake import chunks, append_png, write_glb, linear_to_srgb
from catalog_shiny_za_17_probe import sha, write
from scvi_material_probe import inspect_materials
from phase5_variant_parity import compare

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--production-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    p = args.production_root.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    original = json.loads((p / 'za-pairs/status.json').read_text())['entries']
    results = []
    for name in ['panpour', 'simipour']:
        r = copy.deepcopy(next((r for r in original if r['species'] == name)))
        for variant in ['normal', 'shiny']:
            v = r['variants'][variant]
            if sha(Path(v['path'])) != v['sha256'] or sha(Path(v['table'])) != v['table_sha256']:
                raise ValueError('Pinned source variant changed')
            doc, binary = chunks(v['path'])
            binary = bytearray(binary)
            table = Path(v['table'])
            rows = {m['name']: m for m in inspect_materials(table)}
            pinned = json.loads((p / 'za-pairs' / name / 'import/job.json').read_text())['source_files']
            proof = []
            for m in doc['materials']:
                if m['name'] not in ['l_eye', 'r_eye']:
                    continue
                source = rows[m['name']]
                textures = source['textures']
                maskpath = table.parent / Path(textures['LayerMaskMap']).with_suffix('.png').name
                basepath = table.parent / Path(textures['BaseColorMap']).with_suffix('.png').name
                if sha(maskpath) != pinned[str(maskpath)] or sha(basepath) != pinned[str(basepath)]:
                    raise ValueError('Pinned eye source texture changed')
                # Preserve the expression atlas resolution; shrinking it to the
                # constant 32px albedo discards its fine facial lines.
                mask = Image.open(maskpath).convert('RGBA')
                base = Image.open(basepath).convert('RGBA').resize(mask.size, Image.Resampling.BILINEAR)
                colour = base.convert('RGB')
                originalcolour = colour.copy()
                for i, channel in enumerate(mask.split(), 1):
                    tint = source['colors'].get(f'BaseColorLayer{i}')
                    if tint is None:
                        assert channel.getextrema()[1] == 0
                        continue
                    layer = ImageChops.multiply(originalcolour, Image.new('RGB', mask.size, tuple((linear_to_srgb(c) for c in tint[:3]))))
                    colour = Image.composite(layer, colour, channel.point(lambda c: min(255, 2 * c)))
                colour.putalpha(base.getchannel('A'))
                pack = BytesIO()
                colour.save(pack, format='PNG')
                old = m['pbrMetallicRoughness']['baseColorTexture']
                idx = append_png(doc, binary, pack.getvalue(), m['name'] + '_source_eye_full_atlas', doc['textures'][old['index']].get('sampler', 0))
                m['pbrMetallicRoughness']['baseColorTexture'] = {**old, 'index': idx}
                proof.append({'material': m['name'], 'layer_mask_sha256': sha(maskpath), 'base_colour_sha256': sha(basepath), 'preserved_atlas_size': list(mask.size)})
            assert len(proof) == 2
            target = out / name / variant / 'model.glb'
            target.parent.mkdir(parents=True, exist_ok=True)
            write_glb(target, doc, binary)
            compare(Path(v['path']), target)
            v.update(path=str(target), sha256=sha(target), eye_atlas_recovery=proof)
        r['geometry_motion_sha256'] = compare(Path(r['variants']['normal']['path']), Path(r['variants']['shiny']['path']))
        results.append(r)
        (out / name / 'export').mkdir(exist_ok=True)
        (out / name / 'export/job.json').write_bytes((p / 'za-pairs' / name / 'export/job.json').read_bytes())
    write(out / 'status.json', {'schema': 1, 'runtime_approved': False, 'processed': 2, 'total': 2, 'entries': results})
if __name__ == '__main__':
    main()
