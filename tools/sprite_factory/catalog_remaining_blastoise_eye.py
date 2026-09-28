"""Review-only Blastoise eye mask: add a light sclera behind the iris."""

from io import BytesIO
from pathlib import Path

from PIL import Image, ImageChops

from catalog_remaining_eye_bake import append_png, chunks, write_glb
from scvi_material_probe import inspect_materials


def repair(source, target, table, resource):
    document, binary = chunks(source)
    official = {row['name']: row for row in inspect_materials(table)}
    fixed = []
    for material in document['materials']:
        name = material.get('name')
        if name not in ('l_eye', 'r_eye'):
            continue
        row = official[name]
        mask_path = resource / Path(row['textures']['LayerMaskMap']).with_suffix('.png').name
        mask = Image.open(mask_path).convert('RGBA')
        alpha = mask.getchannel('R')
        for channel in ('G', 'B', 'A'):
            alpha = ImageChops.lighter(alpha, mask.getchannel(channel))
        pbr = material['pbrMetallicRoughness']
        original = pbr['baseColorTexture']
        texture = document['textures'][original['index']]
        image = document['images'][texture['source']]
        view = document['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        baked = Image.open(BytesIO(binary[start:start + view['byteLength']])).convert('RGBA')
        if baked.size != alpha.size:
            raise ValueError('Official eye mask and baked eye differ in size')
        # The Biochao eye plane is mostly uncoloured black outside the small
        # iris mask. Once the eye layer is baked that black becomes the huge
        # dark triangle seen in battle. Keep the official iris pixels and
        # put a neutral sclera in the remaining eye-plane area for review.
        baked = Image.composite(baked, Image.new('RGBA', baked.size,
                                                (230, 232, 225, 255)), alpha)
        output = BytesIO()
        baked.save(output, format='PNG', optimize=True)
        index = append_png(document, binary, output.getvalue(), name + '_sclera_iris',
                           texture.get('sampler', 0))
        pbr['baseColorTexture'] = {**original, 'index': index}
        material['alphaMode'] = 'BLEND'
        fixed.append(name)
    if fixed != ['l_eye', 'r_eye']:
        raise ValueError('Expected both Blastoise eye materials')
    write_glb(target, document, binary)
    return fixed
