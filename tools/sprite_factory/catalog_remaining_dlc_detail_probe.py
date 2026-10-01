"""Restore full native colour/alpha/emission for the 15 held DLC pairs.

Review proposals only. Eye diffuse remains the separate verified Eye bake.
Full body graphs use original UV0 rather than exporter-generated UV1 atlases;
normal/roughness/metallic bindings and animation accessors remain intact.
Pecharunt excludes its alternate closed shell, absent in the recovered open
source's renderer list. Ogerpon maskless comparison is a separate review view.
"""
import pathlib, json, sys, hashlib, copy
H = pathlib.Path(__file__).resolve().parent
import argparse
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--evidence-root', type=pathlib.Path, required=True)
parser.add_argument('--source-root', type=pathlib.Path, required=True)
parser.add_argument('--species', nargs='*', default=[])
args = parser.parse_args()
P = args.evidence_root.resolve()
sys.path.insert(0, str(H))
from catalog_shiny_za_17_probe import run_flatpak
from catalog_remaining_eye_bake import chunks, append_png, write_glb
from catalog_native_uv_domain_recovery import used_domains
from scvi_material_probe import inspect_materials
from phase5_variant_parity import compare
from rare_material_parameters import color_socket
S = args.source_root.resolve()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
rows = json.loads((H / 'catalog_remaining_final_dlc_intake.json').read_text())['entries']
old = {r['species']: r for r in json.loads((P / 'material-pairs-v1/status-v2.json').read_text())['entries']}

def process(row):
    name = row['species']
    r = old[name]
    src = P / 'converted-v2' / name / 'prepared.blend'
    model = S / row['models'][0]
    normal = model.with_suffix('.trmtr')
    rare = normal.with_stem(normal.stem + '_rare')
    tables = [{x['name']: x for x in inspect_materials(t)} for t in [normal, rare]]
    export_job = json.loads((P / 'material-pairs-v1' / name / 'export/job.json').read_text())
    if sha(src) != export_job['source_sha256']:
        raise ValueError('Prepared source changed')
    for variant, table in [('normal', normal), ('shiny', rare)]:
        if sha(table) != r['variants'][variant]['table_sha256']:
            raise ValueError('Pinned native table changed')
    variants = {}
    for variant in ['normal', 'shiny']:
        d = P / 'native-detail-v1' / name / variant
        d.mkdir(parents=True, exist_ok=True)
        original = pathlib.Path(r['variants'][variant]['path'])
        if sha(original) != r['variants'][variant]['sha256']:
            raise ValueError('Pinned input GLB changed')
        doc, bin = chunks(original)
        probe = copy.deepcopy(doc)
        for m in probe['materials']:
            t = m['pbrMetallicRoughness']['baseColorTexture']
            t.get('extensions', {}).pop('KHR_texture_transform', None)
            t['texCoord'] = 0
        domains = {x['material_index']: x for x in used_domains(probe, bin)}
        items = []
        for i, m in enumerate(doc['materials']):
            material = m['name']
            a, b = [t[material] for t in tables]
            item = {'name': material, 'output': str(d / f'colour-{i}.png'), 'glow_output': str(d / f'glow-{i}.png')}
            if i in domains:
                item['source_uv_domain'] = domains[i]['source_uv_domain']
            if variant == 'shiny':
                changes = [{'key': color_socket(k, material), 'normal': v, 'rare': b['colors'][k]} for k, v in a['colors'].items() if k in b['colors'] and v != b['colors'][k] and (color_socket(k, material) == k)]
                item['colour_overrides'] = changes
                x, y = [t['textures'].get('BaseColorMap') for t in [a, b]]
                if x != y:
                    x, y = [model.parent / pathlib.Path(z).with_suffix('.png').name for z in [x, y]]
                    item['texture_overrides'] = [{'normal': str(x), 'rare': str(y), 'normal_sha256': sha(x), 'rare_sha256': sha(y), 'expected_authored_bindings': 2 if name == 'poltchageist' and material == 'body_02' else 1}]
            items.append(item)
        job = {'source': str(src), 'source_sha256': sha(src), 'idle_action': json.loads((P / 'material-pairs-v1' / name / 'export/job.json').read_text())['actions']['idle'], 'materials': items, 'constant_colour_review': True, 'static_fresnel_colour_review': True, 'bake_resolution': 1024, 'receipt': str(d / 'shader-receipt.json'), 'normal_table': str(normal), 'normal_table_sha256': sha(normal), 'rare_table': str(rare), 'rare_table_sha256': sha(rare)}
        (d / 'job.json').write_text(json.dumps(job))
        run_flatpak(H / 'catalog_animation_material_worker.py', d / 'job.json', [(P, ''), (H, ':ro'), (S, ':ro')], d / 'bake.log')
        receipts = json.loads((d / 'shader-receipt.json').read_text())
        bin = bytearray(bin)
        for i, (m, item, receipt) in enumerate(zip(doc['materials'], items, receipts)):
            pbr = m['pbrMetallicRoughness']
            prev = pbr['baseColorTexture']
            sampler = doc['textures'][prev['index']].get('sampler', 0)

            def tex(path, suffix):
                t = {'index': append_png(doc, bin, pathlib.Path(path).read_bytes(), m['name'] + suffix, sampler)}
                if i in domains:
                    t['extensions'] = {'KHR_texture_transform': {k: domains[i][k] for k in ['offset', 'scale']}}
                    if 'KHR_texture_transform' not in doc.setdefault('extensionsUsed', []):
                        doc['extensionsUsed'].append('KHR_texture_transform')
                return t
            if 'eye' not in m['name']:
                pbr['baseColorTexture'] = tex(item['output'], '_native_detail')
                pbr['baseColorFactor'] = [1, 1, 1, 1]
            m.pop('emissiveTexture', None)
            m.pop('emissiveFactor', None)
            if not receipt['native_emission_output_zero']:
                m['emissiveTexture'] = tex(item['glow_output'], '_native_glow')
                m['emissiveFactor'] = [1, 1, 1]
                m.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {'emissiveStrength': receipt['emission_strength']}
                if 'KHR_materials_emissive_strength' not in doc.setdefault('extensionsUsed', []):
                    doc['extensionsUsed'].append('KHR_materials_emissive_strength')
        if name == 'pecharunt':
            # The recovered open source has nine visible mesh renderers and
            # no closed shell. Keep this as a review proposal, not a recovered
            # native visibility animation. Check all other geometry first.
            material_only = d / 'material-only.glb'
            write_glb(material_only, doc, bin)
            compare(original, material_only)
            motion_intake = json.loads((H / 'catalog_remaining_dlc_motion_intake.json').read_text())
            source_pin = next(x['source_sha256'] for x in motion_intake['entries'] if x['species'] == name)
            if sha(P / 'bundles' / name / 'source.unity3d') != source_pin:
                raise ValueError('Open-shell motion source changed')
            removed = []
            for node in doc['nodes']:
                if node.get('name') == 'pm1131_00_00_closedshell_mesh' and 'mesh' in node:
                    removed.append(node['name'])
                    node.pop('mesh')
                    node.pop('skin', None)
            if removed != ['pm1131_00_00_closedshell_mesh']:
                raise ValueError('Closed shell is not uniquely bound')
        target = d / 'model.glb'
        write_glb(target, doc, bin)
        parity = compare(original, target) if name != 'pecharunt' else 'closed_shell_visibility_corrected'
        variants[variant] = {'path': str(target), 'sha256': sha(target), 'materials': r['variants'][variant]['materials'], 'table_sha256': sha(normal if variant == 'normal' else rare), 'source_blend_sha256': sha(src), 'native_shader_receipt': receipts}
        print(name, variant, 'OK', flush=True)
    return {**r, 'variants': variants, 'geometry_motion_sha256': compare(pathlib.Path(variants['normal']['path']), pathlib.Path(variants['shiny']['path']))}
selected = [r for r in rows if not args.species or r['species'] in args.species]
out = []
for row in selected:
    try:
        out.append(process(row))
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(row['species'], 'FAIL', e, flush=True)
        out.append({'species': row['species'], 'status': 'held', 'reason': str(e)})
    (P / 'native-detail-v1').mkdir(exist_ok=True)
    (P / 'native-detail-v1/status.json').write_text(json.dumps({'entries': out}, indent=2))
