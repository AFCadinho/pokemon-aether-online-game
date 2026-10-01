"""Restore Terastal shell alpha and apply an explicit reference fur proposal."""
import copy
import hashlib
import json
from pathlib import Path

from PIL import Image

from catalog_remaining_eye_bake import chunks, append_png, write_glb
from phase5_variant_parity import compare
from scvi_material_probe import inspect_materials


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def propose(source, target, table, fur, palette_receipt, renderer_receipt):
    if target.exists():
        raise ValueError('Retain previous material proposals')
    palette = json.loads(palette_receipt.read_text())
    if not palette['authored_review_proposal'] or palette['runtime_approved']:
        raise ValueError('Expected explicitly authored review palette')
    if palette['table_sha256'] != sha(table) or palette['material'] != 'body_c1':
        raise ValueError('Authored palette does not match this material table')
    doc, binary = chunks(source)
    rows = {r['name']: r for r in inspect_materials(table)}
    materials = {m['name']: m for m in doc['materials']}
    if set(materials) != {'body_a1', 'body_b_01', 'body_b_02', 'body_c1', 'body_d1', 'l_eye', 'r_eye'}:
        raise ValueError('Unexpected Terastal materials')
    glass_row = rows['body_d1']
    alpha = glass_row['colors']['BaseColor'][3]
    if glass_row['alpha_type'] != 'BlendPreMultiAlpha' or not 0 < alpha < 1:
        raise ValueError('Expected native thin glass alpha')
    glass = materials['body_d1']
    glass['alphaMode'] = 'BLEND'
    glass['pbrMetallicRoughness']['baseColorFactor'] = [1, 1, 1, alpha]
    # Stable alpha compositing is a review approximation of native Thin
    # refraction. It exposes the real source shield and type decals below.
    mark_row = rows['body_b_02']
    if not any(s['values'].get('EnableAlphaTest') == 'True' for s in mark_row['shaders']):
        raise ValueError('Source type glyphs have no alpha test')
    marks = materials['body_b_02']
    marks['alphaMode'] = 'MASK'
    marks['alphaCutoff'] = mark_row['floats']['DiscardValue']
    binary = bytearray(binary)
    coat = materials['body_c1']['pbrMetallicRoughness']
    previous = copy.deepcopy(coat['baseColorTexture'])
    sampler = doc['textures'][previous['index']].get('sampler', 0)
    with Image.open(fur) as image:
        if image.convert('RGBA').getchannel('A').getextrema() != (255, 255):
            raise ValueError('Fur proposal changed opaque coverage')
    previous['index'] = append_png(doc, binary, fur.read_bytes(), 'body_c1_reference_fur', sampler)
    coat['baseColorTexture'] = previous
    target.parent.mkdir(parents=True, exist_ok=True)
    material_only = target.with_name('materials-only.glb')
    write_glb(material_only, doc, binary)
    parity = compare(source, material_only)
    prefab = json.loads(renderer_receipt.read_text())
    if prefab['source_sha256'] != '4783c0200525d130fc0fc72219fbb7d6c468cecaffc0f384b225ccf9fbc1b5d4':
        raise ValueError('Unexpected Terastal converted source prefab')
    visible = set(prefab['visible_renderers'])
    if visible != {r['name'] for r in prefab['renderers'] if r['enabled'] and r['game_object_active']}:
        raise ValueError('Renderer visibility receipt is inconsistent')
    drawn = {n['name'] for n in doc['nodes'] if 'mesh' in n}
    extra_name = 'pm1130_12_00_tail_mesh'
    if drawn - visible != {extra_name} or visible - drawn:
        raise ValueError('Source prefab does not identify exactly one extra SCVI mesh')
    extra = [n for n in doc['nodes'] if n.get('name') == extra_name and 'mesh' in n]
    if len(extra) != 1:
        raise ValueError('Extra source mesh has no unique draw binding')
    # Geometry, named joints and motion remain in the file. Only the extra
    # draw binding absent from the converted prefab is disabled for review.
    extra[0].pop('mesh')
    extra[0].pop('skin', None)
    write_glb(target, doc, binary)
    return {'runtime_approved': False, 'visual_approved': False,
            'source_sha256': sha(source), 'glb_sha256': sha(target),
            'material_table_sha256': sha(table), 'fur_texture_sha256': sha(fur),
            'authored_palette_receipt_sha256': sha(palette_receipt),
            'material_only_geometry_skin_animation_sha256': parity,
            'source_prefab_receipt_sha256': sha(renderer_receipt),
            'excluded_extra_draw_binding': extra_name,
            'visible_meshes': sorted(visible),
            'glass_base_alpha': alpha, 'type_glyph_alpha_cutoff': marks['alphaCutoff'],
            'policy': 'native source glass alpha and glyph cutout; authored reference fur colours through original layer masks; extra SCVI draw binding excluded to match converted prefab; static alpha blend, not native Thin refraction'}
