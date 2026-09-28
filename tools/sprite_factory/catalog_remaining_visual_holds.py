#!/usr/bin/env python3
"""Reproduce ten hash-pinned review candidates; never approve or publish.

Restore old source eye bases/highlights, source-authored layer colours and
emission, opaque body materials, and double-sided Yanma wings. Primarina's
constant ponytail selection is an explicit artistic review proposal, not a
claim to have recovered missing native visibility tracks.

RGBA layer masks contain independent data channels: resize them separately.
Alpha-premultiplied image resampling would erase active RGB under zero alpha.
"""
import argparse, json, hashlib
from pathlib import Path
from PIL import Image
from io import BytesIO
from catalog_remaining_eye_bake import chunks, write_glb, append_png, linear_to_srgb
from scvi_material_probe import inspect_materials
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--work', type=Path, required=True)
parser.add_argument('--materials', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = args.work.resolve()
manifest = json.loads(Path(__file__).with_name('catalog_remaining_visual_holds_inputs.json').read_text())
for base, key in [(root, 'work_files'), (args.materials, 'material_files')]:
    for relative, expected in manifest[key].items():
        if hashlib.sha256((base / relative).read_bytes()).hexdigest() != expected:
            raise ValueError('Source input changed: ' + relative)
rows = json.loads((root / 'before-stage.json').read_text())
for row in rows:
    if hashlib.sha256(Path(row['path']).read_bytes()).hexdigest() != manifest['input_glbs'][row['species']]:
        raise ValueError('Source GLB changed: ' + row['species'])
args.output = args.output.resolve()
args.output.mkdir(parents=True, exist_ok=False)
stages = []
ids = {'blastoise': 'pm0009', 'furret': 'pm0162', 'entei': 'pm0244', 'mudkip': 'pm0258', 'yanma': 'pm0193', 'primarina': 'pm0849', 'incineroar': 'pm0846', 'solosis': 'pm0577', 'reuniclus': 'pm0579', 'dewpider': 'pm0850'}

def packed(im):
    out = BytesIO()
    im.save(out, format='PNG')
    return out.getvalue()

def image(row, key, res):
    return Image.open(res / Path(row['textures'][key]).with_suffix('.png').name).convert('RGBA')

def layers(row, res, base=None, emission=False, mask5=False, mask_override=None):
    mask = mask_override if mask_override is not None else image(row, 'LayerMaskMap', res)
    base = base or image(row, 'BaseColorMap', res)
    size = (max(base.width, mask.width), max(base.height, mask.height))
    base = base.resize(size)
    mask = Image.merge('RGBA', tuple((c.resize(size) for c in mask.split())))
    peak = max([1.0] + [max(v[:3]) * row['floats'].get(k.replace('Color', 'Intensity'), 1) for k, v in row['colors'].items() if k.startswith('EmissionColorLayer')]) if emission else 1
    rgb = Image.new('RGB', size) if emission else base.convert('RGB')
    channels = list(mask.split())
    if mask5:
        channels.append(image(row, 'OpacityMap1', res).convert('L').resize(size))
    for i, channel in enumerate(channels, 1):
        key = ('EmissionColorLayer' if emission else 'BaseColorLayer') + str(i)
        color = row['colors'].get(key)
        if color is None:
            continue
        power = row['floats'].get('EmissionIntensityLayer' + str(i), 0) if emission else 1
        tint = Image.new('RGB', size, tuple((linear_to_srgb(v * power / peak) for v in color[:3])))
        rgb = Image.composite(tint, rgb, channel.point(lambda v: min(255, 2 * v)))
    rgb.putalpha(Image.new('L', size, 255) if emission else base.getchannel('A'))
    return (rgb, peak)
for row in rows:
    name, variant = row['species'].rsplit('-', 1)
    id = ids[name]
    res = args.materials / id / (id + '_00_00')
    official = {r['name']: r for r in inspect_materials(res / (id + '_00_00' + ('_rare' if variant == 'shiny' else '') + '.trmtr'))}
    d, b = chunks(row['path'])
    for m in d['materials']:
        r = official[m['name']]
        p = m['pbrMetallicRoughness']
        bind = p.get('baseColorTexture')
        sampler = d['textures'][bind['index']].get('sampler', 0) if bind else 0
        if r['alpha_type'] == 'Opaque' and (not any((k.startswith('OpacityMap') for k in r['textures']))):
            m['alphaMode'] = 'OPAQUE'
            m.pop('alphaCutoff', None)
            if 'baseColorFactor' in p:
                p['baseColorFactor'][3] = 1
        if name == 'yanma' and m['name'] == 'body_b':
            m['doubleSided'] = True
        if name == 'entei' and m['name'] in ('smoke', 'body_a_01'):
            m.pop('emissiveTexture', None)
            m.pop('emissiveFactor', None)
            if m['name'] == 'smoke':
                im, _ = layers(r, res, Image.open(root / 'source-images/entei/pm0244_00_00_smoke_alb.png').convert('RGBA'), mask_override=Image.open(root / 'source-images/entei/pm0244_00_00_smoke_lym.png').convert('RGBA'))
                idx = append_png(d, b, packed(im), 'smoke_source_colour', sampler)
                p['baseColorTexture'] = {**bind, 'index': idx}
            else:
                m['emissiveFactor'] = [v * r['floats']['EmissionIntensity'] for v in r['colors']['EmissionColor'][:3]]
        if name in ('blastoise', 'furret', 'entei', 'mudkip', 'dewpider') and 'eye' in m['name']:
            base = Image.open(root / 'source-images' / name / (id + '_00_00_eye_alb.png')).convert('RGBA')
            source_mask = Image.open(root / 'source-images' / name / Path(r['textures']['LayerMaskMap']).with_suffix('.png').name).convert('RGBA')
            im, _ = layers(r, res, base, mask_override=source_mask)
            highlight = root / 'source-images' / name / (id + '_00_00_eye_msk.png')
            if str(highlight.relative_to(root)) in manifest['work_files']:
                im = Image.composite(Image.new('RGBA', im.size, 'white'), im, Image.open(highlight).convert('L').resize(im.size))
            im.putalpha(255)
            idx = append_png(d, b, packed(im), m['name'] + '_source_basis', sampler)
            p['baseColorTexture'] = {**bind, 'index': idx}
            p['roughnessFactor'] = 0.5
        if name in ('solosis', 'reuniclus') and m['name'] == 'body_b' or (name == 'dewpider' and m['name'] == 'body_01') or (name == 'incineroar' and m['name'] == 'body_c'):
            im, _ = layers(r, res, mask5=name == 'incineroar')
            idx = append_png(d, b, packed(im), m['name'] + '_source_layers', sampler)
            p['baseColorTexture'] = {**bind, 'index': idx}
            em, peak = layers(r, res, emission=True, mask5=name == 'incineroar')
            idx = append_png(d, b, packed(em), m['name'] + '_source_emission', sampler)
            m['emissiveTexture'] = {'index': idx}
            m['emissiveFactor'] = [1, 1, 1]
            p['roughnessFactor'] = r['floats'].get('RoughnessLayer1', 0.2)
            if peak > 1:
                m.setdefault('extensions', {})['KHR_materials_emissive_strength'] = {'emissiveStrength': peak}
                d.setdefault('extensionsUsed', []).append('KHR_materials_emissive_strength') if 'KHR_materials_emissive_strength' not in d.get('extensionsUsed', []) else None
    path = args.output / name / variant / 'model.glb'
    write_glb(path, d, b)
    stage = {**row, 'path': str(path)}
    if name == 'primarina':
        meshes = [n['name'] for n in d['nodes'] if 'mesh' in n]
        clips = {}
        for action, t in row['action_timing'].items():
            clips[action] = {'duration': t['frames'] / 60, 'loop': t['loop'], 'source_sha256': row['source_sha256'], 'tracks': [{'mesh': m, 'source_target': m + '_shape', 'keys': [[0.0, m != 'pm0849_00_00_hair_b_mesh']]} for m in meshes]}
        stage['visibility'] = {'schema': 1, 'glb_sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'clips': clips, 'policy': 'review-only ponytail selection; loose hair disabled across eight clips, not decoded native visibility'}
    stages.append(stage)
(args.output / 'stage.json').write_text(json.dumps(stages, indent=2))
print('VISUAL_HOLDS_REVIEW_CANDIDATES scenes=', len(stages))
