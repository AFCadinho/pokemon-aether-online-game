"""Review-only source material recovery for Vanillish and Skarmory ZA pairs."""
import argparse
import copy
import json
from pathlib import Path
HERE = Path(__file__).resolve().parent
from catalog_shiny_za_17_probe import restore_fresnel, sha, write, run_flatpak
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from scvi_material_probe import inspect_materials
from phase5_variant_parity import compare

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--production-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    p = args.production_root.resolve()
    rows = json.loads((p / 'za-pairs/status.json').read_text())['entries']
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    results = []
    for name in ['vanillish', 'skarmory']:
        r = copy.deepcopy(next((r for r in rows if r['species'] == name)))
        r['material_correction'] = {}
        for variant in ['normal', 'shiny']:
            v = r['variants'][variant]
            target = out / name / variant / 'model.glb'
            target.parent.mkdir(parents=True, exist_ok=True)
            if sha(Path(v['path'])) != v['sha256'] or sha(Path(v['table'])) != v['table_sha256']:
                raise ValueError('Pinned variant source changed')
            target.write_bytes(Path(v['path']).read_bytes())
            table = Path(v['table'])
            if name == 'vanillish':
                record = restore_fresnel(target, table, emission=True)
                r['material_correction'][variant] = {'policy': 'same source Fresnel layer colour/emission restoration as approved Vanilluxe', 'materials': record}
            else:
                doc, binary = chunks(target)
                binary = bytearray(binary)
                base = p / 'za-pairs' / name
                source = next((base / 'import').glob('*-ready.blend'))
                imported = json.loads((base / 'import/import.json').read_text())
                if sha(source) != imported['prepared_sha256']:
                    raise ValueError('Pinned imported Blend changed')
                normal = Path(r['variants']['normal']['table'])
                rare = Path(r['variants']['shiny']['table'])
                nt = {m['name']: m for m in inspect_materials(normal)}
                rt = {m['name']: m for m in inspect_materials(rare)}
                items = []
                for i, m in enumerate(doc['materials']):
                    item = {'name': m['name'], 'output': str(target.parent / f'material-{i:03d}.png')}
                    if variant == 'shiny':
                        # Shadowing colours are outside this albedo bake.
                        item['colour_overrides'] = [{'key': k, 'normal': v, 'rare': rt[m['name']]['colors'][k]} for k, v in nt[m['name']]['colors'].items() if k.startswith('BaseColor') and k in rt[m['name']]['colors'] and (v != rt[m['name']]['colors'][k])]
                    items.append(item)
                job = {'source': str(source), 'source_sha256': sha(source), 'idle_action': json.loads((base / 'export/job.json').read_text())['actions']['idle'], 'materials': items, 'receipt': str(target.parent / 'shader-receipt.json'), 'normal_table': str(normal), 'normal_table_sha256': sha(normal), 'rare_table': str(rare), 'rare_table_sha256': sha(rare)}
                jp = target.parent / 'bake-job.json'
                write(jp, job)
                run_flatpak(HERE / 'catalog_animation_material_worker.py', jp, [(p, ':ro'), (out, ''), (HERE, ':ro')], target.parent / 'bake.log')
                for m, item in zip(doc['materials'], items):
                    old = m['pbrMetallicRoughness']['baseColorTexture']
                    idx = append_png(doc, binary, Path(item['output']).read_bytes(), m['name'] + '_native_graph', doc['textures'][old['index']].get('sampler', 0))
                    m['pbrMetallicRoughness']['baseColorTexture'] = {**old, 'index': idx}
                write_glb(target, doc, binary)
                r['material_correction'][variant] = {'policy': 'connected native source graph colour/alpha with official rare table differences', 'shader_receipt_sha256': sha(target.parent / 'shader-receipt.json')}
            compare(Path(v['path']), target)
            v.update(path=str(target), sha256=sha(target))
        r['geometry_motion_sha256'] = compare(Path(r['variants']['normal']['path']), Path(r['variants']['shiny']['path']))
        results.append(r)
        write(out / 'status.json', {'schema': 1, 'processed': len(results), 'total': 2, 'runtime_approved': False, 'entries': results})
        print(name, 'corrected', flush=True)
if __name__ == '__main__':
    main()
