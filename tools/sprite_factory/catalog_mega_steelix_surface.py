"""Review-only Steelix metal-layer and crystal-light recovery from pinned tables.

This is a static PBR approximation; native view-dependent refraction and probe
reflection are not reproduced. Meshes, UVs, rigs and animation channels remain
unchanged, including the separately reviewed scale.
"""
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageOps

from catalog_remaining_eye_bake import append_png, chunks, write_glb
from catalog_shiny_za_17_probe import restore_fresnel
from phase5_variant_parity import signature
from scvi_material_probe import inspect_materials


def metal_image(row, directory, roughness):
    mask = Image.open(directory / Path(row['textures']['LayerMaskMap']).with_suffix('.png').name).convert('RGBA')
    uv = row['colors'].get('UVScaleOffset', [1, 1, 0, 0])
    if uv == [2, 1, 0, 0] and mask.width != mask.height:
        extended = Image.new('RGBA', (mask.width * 2, mask.height))
        extended.paste(mask, (0, 0)); extended.paste(ImageOps.mirror(mask), (mask.width, 0))
        mask = extended
    elif uv not in ([1, 1, 0, 0], [2, 1, 0, 0]):
        raise ValueError('Unqualified metal UV mapping')
    metal = Image.new('L', mask.size, round(255 * row['floats'].get('Metallic', 0)))
    for i, channel in enumerate(mask.split(), 1):
        value = row['floats'].get('MetallicLayer' + str(i))
        if value is None or not 0 <= value <= 1:
            raise ValueError('Missing or invalid native metal layer')
        weight = channel.point(lambda v: min(255, v * 2))
        metal = Image.composite(Image.new('L', mask.size, round(255 * value)), metal, weight)
    return Image.merge('RGB', (Image.new('L', mask.size, 255),
                              Image.new('L', mask.size, round(255 * roughness)), metal))


def recover(source, target, table):
    before = signature(source)
    document, binary = chunks(source)
    rows = {r['name']: r for r in inspect_materials(table)}
    receipts = []
    for material in document['materials']:
        row = rows[material['name']]
        if material['name'] not in ('body_a', 'body_b', 'body_c'):
            continue
        pbr = material['pbrMetallicRoughness']
        texture = pbr['baseColorTexture']
        packed = BytesIO()
        metal_image(row, table.parent, pbr.get('roughnessFactor', .5)).save(packed, format='PNG')
        sampler = document['textures'][texture['index']].get('sampler', 0)
        index = append_png(document, binary, packed.getvalue(), material['name'] + '_native_metal_layers', sampler)
        pbr['metallicRoughnessTexture'] = {**texture, 'index': index}
        pbr['metallicFactor'] = pbr['roughnessFactor'] = 1.0
        receipts.append({'material': material['name'], 'policy': 'native_layer_mask_metallic_static_pbr'})
    target.parent.mkdir(parents=True, exist_ok=False)
    write_glb(target, document, binary)
    restored = restore_fresnel(target, table, emission=True)
    if restored != ['body_d']:
        raise ValueError('Expected Steelix crystal surface')
    receipts.append({'material': 'body_d', 'policy': 'native_fresnel_layer1_static_emission',
                     'limitation': 'view-dependent refraction and probe reflection not reproduced'})
    if signature(target) != before:
        raise ValueError('Surface recovery changed geometry, rig or motion')
    return receipts
