"""Review-only repair of Biochao eye layers using the pinned SCVI material table.

The legacy Blend graph mixes four layer-mask channels into Base Color. glTF
exports the mask image instead of that graph, so the unmodified GLB can show
RGB mask colours as neon eyes or omit the iris entirely. This tool replaces
only eye base-colour textures; it does not approve a model for the catalog.
"""

import argparse
from io import BytesIO
import json
from pathlib import Path
import struct

from PIL import Image

from scvi_material_probe import inspect_materials


def linear_to_srgb(value):
    value = max(0.0, min(1.0, value))
    return round(255 * (12.92 * value if value <= 0.0031308 else
                        1.055 * value ** (1 / 2.4) - 0.055))


def bake_eye(row, resource):
    textures = row['textures']
    if not {'BaseColorMap', 'LayerMaskMap'} <= textures.keys():
        raise ValueError('Eye is missing its official albedo or layer mask')
    if not any(shader['name'] == 'Eye' for shader in row['shaders']):
        raise ValueError('Eye material has no official Eye shader')
    mask = Image.open(resource / Path(textures['LayerMaskMap']).with_suffix('.png').name).convert('RGBA')
    base = Image.open(resource / Path(textures['BaseColorMap']).with_suffix('.png').name).convert('RGBA')
    if base.size != mask.size:
        base = base.resize(mask.size, Image.Resampling.BILINEAR)
    # In SCVI's Eye shader the albedo alpha is not the eye mesh opacity.
    # Biochao's direct Principled translation mistakenly connects it to
    # Alpha; Vulpix/Servine/Torracat can consequently lose the whole iris.
    # An explicit official opacity map would require a different route.
    if 'OpacityMap' in textures or 'OpacityMap1' in textures:
        raise ValueError('Eye has an explicit opacity map; cannot force opaque')
    alpha = Image.new('L', mask.size, 255)
    color = base.convert('RGB')
    channels = mask.split()
    for index, channel in enumerate(channels, 1):
        values = row['colors'].get(f'BaseColorLayer{index}')
        if values is None:
            # A missing layer is safe only when its mask is identically zero.
            if channel.getextrema()[1] != 0:
                raise ValueError(f'Active eye layer {index} has no official colour')
            continue
        if len(values) != 4:
            raise ValueError(f'Invalid eye layer {index} colour')
        tint = Image.new('RGB', mask.size, tuple(linear_to_srgb(v) for v in values[:3]))
        # Biochao's Blender node graph sets Value=2 before splitting RGBA.
        strength = channel.point(lambda value: min(255, value * 2))
        color = Image.composite(tint, color, strength)
    highlight = textures.get('HighlightMaskMap')
    if highlight:
        highlight_mask = Image.open(resource / Path(highlight).with_suffix('.png').name).convert('L')
        if highlight_mask.size != mask.size:
            highlight_mask = highlight_mask.resize(mask.size, Image.Resampling.BILINEAR)
        color = Image.composite(Image.new('RGB', mask.size, 'white'), color, highlight_mask)
    color.putalpha(alpha)
    output = BytesIO()
    color.save(output, format='PNG', optimize=True)
    return output.getvalue()


def chunks(path):
    data = Path(path).read_bytes()
    if data[:4] != b'glTF' or struct.unpack_from('<I', data, 4)[0] != 2:
        raise ValueError('Expected glTF 2 GLB')
    json_size, json_type = struct.unpack_from('<I4s', data, 12)
    if json_type != b'JSON':
        raise ValueError('GLB has no JSON chunk')
    binary_offset = 20 + json_size
    binary_size, binary_type = struct.unpack_from('<I4s', data, binary_offset)
    if binary_type != b'BIN\x00' or binary_offset + 8 + binary_size != len(data):
        raise ValueError('Expected one binary GLB chunk')
    return json.loads(data[20:binary_offset]), bytearray(data[binary_offset + 8:])


def write_glb(path, document, binary):
    document['buffers'][0]['byteLength'] = len(binary)
    payload = json.dumps(document, separators=(',', ':'), ensure_ascii=False).encode()
    payload += b' ' * (-len(payload) % 4)
    binary += b'\0' * (-len(binary) % 4)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(b'glTF' + struct.pack('<II', 2, 28 + len(payload) + len(binary)) +
                           struct.pack('<I4s', len(payload), b'JSON') + payload +
                           struct.pack('<I4s', len(binary), b'BIN\0') + binary)


def append_png(document, binary, packed, name, sampler):
    offset = len(binary)
    binary.extend(packed)
    binary.extend(b'\0' * (-len(binary) % 4))
    view = len(document.setdefault('bufferViews', []))
    document['bufferViews'].append({'buffer': 0, 'byteOffset': offset,
                                    'byteLength': len(packed)})
    image = len(document.setdefault('images', []))
    document['images'].append({'name': name, 'mimeType': 'image/png', 'bufferView': view})
    texture = len(document['textures'])
    document['textures'].append({'sampler': sampler, 'source': image})
    return texture


def repair(source, target, material_table, resource, official_body_albedo=()):
    document, binary = chunks(source)
    official = {row['name']: row for row in inspect_materials(material_table)}
    repaired = []
    restored_body_albedo = []
    cleared_false_emission = []
    for material in document['materials']:
        name = material.get('name')
        row = official.get(name)
        if (row is not None and material.get('emissiveFactor') == [1, 1, 1]
                and 'emissiveTexture' not in material
                and not row['floats'].get('EmissionIntensity', 0)):
            # The glTF translator emitted a full white glow for a disconnected
            # source emission input. In this case the official shader has no
            # body emission, so the glow is demonstrably spurious.
            material.pop('emissiveFactor')
            cleared_false_emission.append(name)
        if name in official_body_albedo:
            if (row is None or not any(shader['name'] == 'SSS' for shader in row['shaders'])
                    or 'BaseColorMap' not in row['textures']
                    or any(row['colors'].get(f'BaseColorLayer{i}') != [1.0] * 4
                           for i in range(1, 5))
                    or any(value != 0 for key, value in row['floats'].items()
                           if key.startswith('EmissionIntensity'))):
                raise ValueError(f'{name}: official body is not simple unlit albedo')
            pbr = material.get('pbrMetallicRoughness', {})
            if 'baseColorTexture' not in pbr:
                raise ValueError(f'{name}: no body albedo binding')
            old_texture = document['textures'][pbr['baseColorTexture']['index']]
            official_image = resource / Path(row['textures']['BaseColorMap']).with_suffix('.png').name
            texture = append_png(document, binary, official_image.read_bytes(),
                                 name + '_official_body_albedo', old_texture.get('sampler', 0))
            pbr['baseColorTexture'] = {**pbr['baseColorTexture'], 'index': texture}
            material.pop('emissiveTexture', None)
            material.pop('emissiveFactor', None)
            restored_body_albedo.append(name)
        if row is None or not any(shader['name'] == 'Eye' for shader in row['shaders']):
            continue
        pbr = material.get('pbrMetallicRoughness', {})
        if 'baseColorTexture' not in pbr:
            raise ValueError(f'{name}: no GLB base-colour binding')
        old_texture = document['textures'][pbr['baseColorTexture']['index']]
        packed = bake_eye(row, resource)
        texture = append_png(document, binary, packed, name + '_official_eye_bake',
                             old_texture.get('sampler', 0))
        pbr['baseColorTexture'] = {**pbr['baseColorTexture'], 'index': texture}
        official_roughness = row['floats'].get('Roughness')
        if official_roughness is not None:
            if not 0.0 <= official_roughness <= 1.0:
                raise ValueError(f'{name}: official roughness outside PBR range')
            pbr['roughnessFactor'] = official_roughness
        # The old emission texture is the raw RGB layer mask, not authored
        # emission. Its literal colours cause neon eyes in Godot.
        material.pop('emissiveTexture', None)
        material.pop('emissiveFactor', None)
        repaired.append(name)
    if set(official_body_albedo) != set(restored_body_albedo):
        raise ValueError('Requested body albedo material was not bound')
    if not repaired and not cleared_false_emission and not restored_body_albedo:
        raise ValueError('No supported eye or emission material matched the GLB')
    write_glb(target, document, binary)
    return {'eye_materials': repaired, 'cleared_false_emission': cleared_false_emission,
            'restored_body_albedo': restored_body_albedo}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--target', type=Path, required=True)
    parser.add_argument('--table', type=Path, required=True)
    args = parser.parse_args()
    repaired = repair(args.source, args.target, args.table, args.table.parent)
    print(json.dumps({'target': str(args.target), **repaired}))


if __name__ == '__main__':
    main()
