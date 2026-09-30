"""Restore an authored eye glint omitted by the flattened SCVI Eye shader.

The Biochao base-colour eye image holds a white glint on black. The official
EyeClearCoat material enables highlights, but the layer-colour bake cannot
represent that separate feature. This keeps the corrected iris colour and
composites only the authored glint onto it.
"""

import argparse
from io import BytesIO

from PIL import Image, ImageChops

from catalog_remaining_eye_bake import append_png, chunks, write_glb


def eye_texture(document, binary, material_name):
    material = next(m for m in document['materials'] if m['name'] == material_name)
    pbr = material['pbrMetallicRoughness']
    texture_info = pbr['baseColorTexture']
    texture = document['textures'][texture_info['index']]
    image = document['images'][texture['source']]
    view = document['bufferViews'][image['bufferView']]
    start = view.get('byteOffset', 0)
    packed = binary[start:start + view['byteLength']]
    return material, texture, Image.open(BytesIO(packed)).convert('RGBA')


def repair(baked_path, source_path, target_path):
    baked, packed = chunks(baked_path)
    source, source_packed = chunks(source_path)
    repaired = []
    for material_name in ('l_eye', 'r_eye'):
        material, texture, iris = eye_texture(baked, packed, material_name)
        _, _, authored = eye_texture(source, source_packed, material_name)
        if authored.getpixel((0, 0))[:3] != (0, 0, 0):
            raise ValueError(f'{material_name}: expected black-backed authored highlight')
        highlight = authored.convert('L').resize(iris.size, Image.Resampling.BILINEAR)
        if highlight.getextrema()[0] != 0 or highlight.getextrema()[1] < 240:
            raise ValueError(f'{material_name}: no unambiguous authored white glint')
        result = Image.composite(Image.new('RGBA', iris.size, 'white'), iris, highlight)
        output = BytesIO()
        result.save(output, format='PNG', optimize=True)
        new_texture = append_png(baked, packed, output.getvalue(),
                                 material_name + '_official_glint', texture.get('sampler', 0))
        material['pbrMetallicRoughness']['baseColorTexture']['index'] = new_texture
        repaired.append(material_name)
    write_glb(target_path, baked, packed)
    return repaired


def repair_mask(baked_path, mask_path, target_path):
    """Composite an explicit achromatic source clearcoat/highlight mask."""
    mask = Image.open(mask_path).convert('RGB')
    red, green, blue = mask.split()
    if (ImageChops.difference(red, green).getbbox() is not None or
            ImageChops.difference(green, blue).getbbox() is not None or
            red.getextrema()[0] != 0 or red.getextrema()[1] < 240):
        raise ValueError('Expected black-backed achromatic highlight mask')
    document, binary = chunks(baked_path)
    repaired = []
    for name in ('l_eye', 'r_eye'):
        material, texture, iris = eye_texture(document, binary, name)
        highlight = red.resize(iris.size, Image.Resampling.BILINEAR)
        result = Image.composite(Image.new('RGBA', iris.size, 'white'), iris, highlight)
        packed = BytesIO()
        result.save(packed, format='PNG', optimize=True)
        index = append_png(document, binary, packed.getvalue(),
                           name + '_authored_clearcoat_glint', texture.get('sampler', 0))
        material['pbrMetallicRoughness']['baseColorTexture']['index'] = index
        repaired.append(name)
    write_glb(target_path, document, binary)
    return repaired


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baked', required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--source')
    source.add_argument('--mask', help='Explicit authored achromatic highlight mask')
    parser.add_argument('--target', required=True)
    args = parser.parse_args()
    print(repair_mask(args.baked, args.mask, args.target) if args.mask else
          repair(args.baked, args.source, args.target))


if __name__ == '__main__':
    main()
